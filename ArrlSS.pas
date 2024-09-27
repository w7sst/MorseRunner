unit ArrlSS;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults,
  Generics.Collections,
  Classes,  // for TStringList
  Log,      // for TQso
  SSExchParser,
  Contest, Station, DxStn;

type
  TSweepstakesCallRec = class
  public
    Call: string;     // call sign
    Section: string;  // ARRL/RAC Section (e.g. OR)
    Check: integer;   // Check (2-digit year first licensed or station first licensed)
    UserText: string; // optional UserText (displayed in status bar)
    function GetString: string; // returns <precedence> <CK> <Sect> (.e.g 'A 72 OR')
    class function compareCall(const left, right: TSweepstakesCallRec) : integer; static;
  end;

TSweepstakes = class(TContest)
private
  SweepstakesCallList: TObjectList<TSweepstakesCallRec>;
  Comparer: IComparer<TSweepstakesCallRec>;
  ExchValidator: TSSExchParser;
  Sections2Idx: TDictionary<string, integer>;

  function GetAlternateSection(const ASection: string): string;

public
  constructor Create;
  destructor Destroy; override;
  function LoadCallHistory(const AUserCallsign : string) : boolean; override;

  function ValidateMyExchange(const AExchange: string;
    ATokens: TStringList;
    out AExchError: string): boolean; override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id : integer): string; override; // returns station callsign
  procedure GetExchange(id: integer; out station: TDxStation); override;

  function FindCallRec(out ssrec: TSweepstakesCallRec; const ACall: string): Boolean;
  procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); override;
  procedure OnWipeBoxes; override;
  function OnExchangeEdit(const ACall, AExch1, AExch2: string;
    out AExchSummary: string) : Boolean; override;
  procedure OnExchangeEditComplete; override;
  procedure SetHisCall(const ACall: string); override;
  function CheckEnteredCallLength(const ACall: string;
    out AExchError: String) : boolean; override;
  function ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
    out AExchError: String) : boolean; override;
  procedure SaveEnteredExchToQso(var Qso: TQso; const AExch1, AExch2: string); override;
  function GetStationInfo(const ACallsign: string) : string; override;
  function ExtractMultiplier(Qso: PQso) : string; override;
  function GetCheckSection(const ACallsign: string; AThreshold: Single = 0): String;
  function IsNum(Num: String): Boolean;
end;

implementation

uses
  SysUtils,
  PerlRegEx,      // for regular expression support
  Ini,            // for ActiveContest
  ArrlSections,   // SectionsTbl
  DXCC;

function TSweepstakes.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  Lexer: TSSLexer;
  slst, tl: TStringList;
  i: integer;
  rec: TSweepstakesCallRec;
begin
  // reload call history if empty
  Result := SweepstakesCallList.Count <> 0;
  if Result then
    Exit;

  Lexer := TSSLexer.Create;
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;

  try
    slst.LoadFromFile(ParamStr(1) + 'SSCW.TXT');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 3) then begin
          if (tl.Strings[0] = '!!Order!!') then continue;

          if rec = nil then
            rec := TSweepstakesCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.Section := UpperCase(tl.Strings[1]);
          if not TryStrToInt(tl.Strings[3], rec.Check) then continue;
          if (tl.Count >= 5) then rec.UserText := tl.Strings[4]
                             else rec.UserText := '';
          if rec.Call='' then continue;
          if not Lexer.IsValidCall(rec.Call) then continue;
          if rec.Section='' then continue;

          SweepstakesCallList.Add(rec);
          rec := nil;
      end;
    end;

    SweepstakesCallList.Sort(Comparer);
    Result := True;

  finally
    Lexer.Free;
    slst.Free;
    tl.Free;
    if rec <> nil then rec.Free;
  end;
end;


constructor TSweepstakes.Create;
var
  I: integer;
begin
  inherited Create;
  Comparer := TComparer<TSweepstakesCallRec>.Construct(TSweepstakesCallRec.compareCall);
  SweepstakesCallList := TObjectList<TSweepstakesCallRec>.Create(Comparer);
  ExchValidator := TSSExchParser.Create;
  Sections2Idx := TDictionary<string, integer>.Create;

  // load Sections2Idx...
  for I := Low(SectionsTbl) to High(SectionsTbl) do
    Sections2Idx.Add(SectionsTbl[I], I);
end;


destructor TSweepstakes.Destroy;
begin
  FreeAndNil(SweepstakesCallList);
  FreeAndNil(ExchValidator);
  FreeAndNil(Sections2Idx);
  inherited;
end;


{
  ValidateMyExchange will validate user-entered exchange and
  return Exch1 and Exch2 tokens. These tokens will be stored to send
  as my transmissions.

  Syntax: [nr | #] <Precedence> <Check> <Section>
  Entered Exchange: # <precedence> * <check> <section>
  where precedence=Q,A,B,U,M,S, check='year licenced', ARRL/RAC section.
  Sent Exchange: # A W7SST 72 OR

  Entered: [123|#] <prec> <check> <section>
  Returned: Exch1 = '[123|#] <prec>', Exch2 = '<check> <section>'
}
function TSweepstakes.ValidateMyExchange(const AExchange: string;
  ATokens: TStringList;
  out AExchError: string): boolean;
const
  // Syntax: [123|#][ ]<Precedence> <Check> <Section>
  Regexpr: string = ' *(?P<exch1>(?P<nr>[0-9]+|#)? *(?P<prec>[QABUMS])) +'
                  + '(?P<chk>[0-9]{2}) +(?P<sect>[A-Z]+) *';
var
  reg: TPerlRegEx;
  Exch1, Exch2: string;
begin
  reg := TPerlRegEx.Create();
  try
    // parse into two strings [Exch1, Exch2]
    reg.Subject := UTF8Encode(AExchange);
    reg.RegEx	:= UTF8Encode('^' + Regexpr + '$');
    Result := Reg.Match;
    if Result then
      begin
        Exch1 := String(Reg.Groups[Reg.NamedGroup('exch1')]);
        Exch2 := format('%s %s',
          [Reg.Groups[Reg.NamedGroup('chk')], Reg.Groups[Reg.NamedGroup('sect')]]);
        ATokens.Clear;
        ATokens.Add(Exch1);
        ATokens.Add(Exch2);
      end
    else
      begin
      if not Result then
        AExchError := Format('Invalid exchange: ''%s'' - expecting %s.',
              [AExchange, ActiveContest.Msg]);
      end;

  finally
    reg.Free;
  end;
end;


function TSweepstakes.PickStation(): integer;
begin
  result := random(SweepstakesCallList.Count);
end;


procedure TSweepstakes.DropStation(id : integer);
begin
  assert(id < SweepstakesCallList.Count);
  SweepstakesCallList.Delete(id);
end;


function TSweepstakes.FindCallRec(out ssrec: TSweepstakesCallRec; const ACall: string): Boolean;
var
  rec: TSweepstakesCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TSweepstakesCallRec.Create();
  rec.Call := ACall;
  ssrec:= nil;
  try
    if SweepstakesCallList.BinarySearch(rec, index, Comparer) then
      ssrec:= SweepstakesCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= ssrec <> nil;
end;


{
  Overrides TContest.SendMsg() to send contest-specific messages.

  Adding a contest: TContest.SendMsg(AMsg): send contest-specfic messages
}
procedure TSweepstakes.SendMsg(const AStn: TStation; const AMsg: TStationMessage);
begin
  case AMsg of
    msgCQ: SendText(AStn, 'CQ SS <my>');
    msgLongCQ: SendText(AStn, 'CQ CQ SS <my> <my> SS');  // QrmStation only
    else
      inherited SendMsg(AStn, AMsg);
  end;
end;


{
  Called after a QSO has completed or when user wipes (clears) all exchange
  entry boxes on the GUI.
}
procedure TSweepstakes.OnWipeBoxes;
begin
  inherited OnWipeBoxes;
  ExchValidator.OnWipeBoxes;
end;


{
  User has finished typing in the exchange fields and has pressed Enter or
  another command keystroke.
  Set Log.CallSent to False if the callsign has been modified or corrected.
}
procedure TSweepstakes.OnExchangeEditComplete;
begin
  if ExchValidator.Call.IsEmpty then
    inherited OnExchangeEditComplete
  else if ExchValidator.Call <> Self.Me.HisCall then
    Log.CallSent := False;
end;


{
  This overriden SetHisCall will:
  - if the exchange field contains a callsign correction, apply it here;
    otherwise call the base class.
  - sets TContest.Me.HisCall.
  - sets Log.CallSent to False if the callsign should be sent.
}
procedure TSweepstakes.SetHisCall(const ACall: string);
begin
  var CorrectedCallsign: string := ExchValidator.Call;
  if CorrectedCallsign <> '' then
    begin
      // resend Callsign if it has changed since last time it was sent
      if (CorrectedCallsign <> Self.Me.HisCall) and
        not Self.Me.UpdateCallInMessage(CorrectedCallsign) then
          begin
            Self.Me.HisCall := CorrectedCallsign;
            Log.CallSent := True;
          end
      else if (CorrectedCallsign = Self.Me.HisCall) and not CallSent then
        Log.CallSent := True;
    end
  else
    inherited SetHisCall(ACall);
end;


{
  Called after each keystoke for the Exch2 entry field.
  Parse user-entered Exchange and returns the Exchange summary.
  Overriden here to handle complex ARRL Sweepstakes exchange.
  Returns whether Exchange summary is non-empty.
}
function TSweepstakes.OnExchangeEdit(
  const ACall, AExch1, AExch2: string; out AExchSummary: string) : Boolean;
var
  ExchError: string;
begin
  // incrementally parse the exchange with each keystroke
  ExchValidator.ValidateEnteredExchange(ACall, AExch1, AExch2, ExchError);

  // return summary (displayed above Exch2's Caption)
  AExchSummary := ExchValidator.ExchSummary;
  Result := not AExchSummary.IsEmpty;
end;


{
  Verify callsign using length-based check.
  For ARRL SS, if Call has been parsed, it is assumed valid; otherwise
  call the base class implementation.
}
function TSweepstakes.CheckEnteredCallLength(const ACall: string;
  out AExchError: String) : boolean;
begin
  AExchError := '';
  if ExchValidator.Call.IsEmpty then
    Result := inherited CheckEnteredCallLength(ACall, AExchError)
  else
    Result := True;
end;


{
  Validate user-entered Exchange before sending TU and logging the QSO.
  Overriden here to handle complex ARRL Sweepstakes exchange.
}
function TSweepstakes.ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
  out AExchError: String) : boolean;
begin
  Result := ExchValidator.ValidateEnteredExchange(ACall, AExch1, AExch2, AExchError);
end;


{
  ARRL Sweepstakes has a specialized exchange and requires special processing
  when saving exchange information into the QSO.
}
procedure TSweepstakes.SaveEnteredExchToQso(var Qso: TQso; const AExch1, AExch2: string);
begin
  Qso.Nr := ExchValidator.NR;
  Qso.Prec := ExchValidator.Precedence;
  Qso.Check := StrToIntDef(ExchValidator.Check, 0);
  Qso.Sect := ExchValidator.Section;

  if Qso.Prec.IsEmpty then Qso.Prec := '?';
  if Qso.Sect.IsEmpty then Qso.Sect := '?';

  if not ExchValidator.Call.IsEmpty then
    Qso.Call := ExchValidator.Call;

  Qso.Exch1 := format('%d %s', [Qso.Nr, Qso.Prec]);
  Qso.Exch2 := format('%.02d %s', [Qso.Check, Qso.Sect]);
end;


// return status bar information string from SSCW call history file.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text>'
function TSweepstakes.GetStationInfo(const ACallsign: string) : string;
var
  ssrec : TSweepstakesCallRec;
begin
  if FindCallRec(ssrec, ACallsign) and not ssrec.UserText.IsEmpty then
    result:= ACallsign + ' - ' + ssrec.UserText
  else
    result:= '';
end;


function TSweepstakes.getCall(id:integer): string;     // returns station callsign
begin
  result := SweepstakesCallList.Items[id].Call;
end;


{
  Called by TDxStation.CreateStation.
  Constructs the Exchange values for this station.
  Overriden for complex exchanges.
}
procedure TSweepstakes.GetExchange(id : integer; out station : TDxStation);
const
  PrecedenceTbl: array[0..5] of string = ('A', 'B', 'U', 'Q', 'M', 'S');
begin
  station.NR := GetRandomSerialNR;  // serial number

  // Mark, KD0EE, recommends 50% calls are A, 20% B, 20% U, 10% for the rest.
  // Jim, K6OK, reported     37% calls are A, 19% B, 36% U, 10% for the rest.
  // Using the average ...             43% A, 19% B, 28% U, 10% for Q, M and S.
  var R: Single := Random;
  if R < 0.43 then
    station.Prec := PrecedenceTbl[0]
  else if R < 0.62 then
    station.Prec := PrecedenceTbl[1]
  else if R < 0.90 then
    station.Prec := PrecedenceTbl[2]
  else
    station.Prec := PrecedenceTbl[3+Random(3)];

  station.Chk := SweepstakesCallList.Items[id].Check;
  station.Sect := SweepstakesCallList.Items[id].Section;
  station.UserText := SweepstakesCallList.Items[id].UserText;

  // Exch1: <Number> <Precedence> (e.g. 123 A)
  station.Exch1 := format('%d %s', [station.NR, station.Prec]);

  // Exch2: <Check> <Section> (e.g. 72 OR)
  station.Exch2 := format('%.02d %s', [station.Chk, station.Sect]);
end;


class function TSweepstakesCallRec.compareCall(const left, right: TSweepstakesCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TSweepstakesCallRec.GetString: string; // returns <precedence> <CK> <Sect> (.e.g 'A 72 OR')
begin
  Result := Format(' - CK %.02d, Sect %s', [Check, Section]);
end;


{
  Extract multiplier string for ARRL Sweepstakes Contest.

  ARRL Sweepstakes Rules state:
    "Each contact counts for 2 QSO points. To calculate your final score,
    multiply the total QSO points by the number of ARRL and RAC sections
    you contacted."

  Sets contest-specific Qso.Points for this QSO.
  Returns ARRL/RAC Section string.
}
function TSweepstakes.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso^.Points := 2;
  Result := Qso^.Sect;
end;


{
  MRCE will insert <Check><Section> into the exchange field to match
  other logging program behaviors. Periodically this value will be modified
  so the user has to correct the string being copied.
}
function TSweepstakes.GetCheckSection(const ACallsign: string;
  AThreshold: Single): String;
var
  ssrec: TSweepstakesCallRec;
  section: string;
begin
  if FindCallRec(ssrec, ACallsign) then
    begin
      if (Random < AThreshold) then
        section := GetAlternateSection(ssrec.Section)
      else
        section := ssrec.Section;
      result := format('%.02d %s', [ssrec.Check, section]);
    end
  else
    result:= '';
end;

function TSweepstakes.GetAlternateSection(const ASection: string): string;
var
  index: integer;
begin
  index := Sections2Idx.Items[ASection];
  if ((Random < 0.5) and (index > 0)) or (index = High(SectionsTbl)) then
    Dec(index)
  else
    Inc(index);
  Result := SectionsTbl[index];
end;


function TSweepstakes.IsNum(Num: String): Boolean;
var
   X : Integer;
begin
   Result := Length(Num) > 0;
   for X := 1 to Length(Num) do begin
       if Pos(copy(Num,X,1),'0123456789') = 0 then begin
           Result := False;
           Exit;
       end;
   end;
end;


end.



