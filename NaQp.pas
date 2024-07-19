unit NAQP;

interface

uses
  Generics.Defaults, Generics.Collections, DualExchContest, DxStn, Log,
  Station;

type
  TNaQpCallRec = class
  public
    Call: string;     // call sign
    Name: string;     // operator name
    State: string;    // State/Prov/DXCC Entity
    UserText: string; // optional user text
    function GetString: string; // returns <name> <state> (e.g. MIKE OR)
    class function compareCall(const left, right: TNaQpCallRec) : integer; static;
  end;

TNcjNaQp = class(TDualExchContest)
private
  NaQpCallList: TList<TNaQpCallRec>;
  Comparer: IComparer<TNaQpCallRec>;

public
  constructor Create;
  destructor Destroy; override;
  function GetExchangeTypes(
    const AStationKind : TStationKind;
    const ARequestedMsgType : TRequestedMsgType;
    const AStationCallsign : string) : TExchTypes; override;
  function LoadCallHistory(const AUserCallsign : string) : boolean; override;
  function OnSetMyCall(const AUserCallsign : string; out err : string) : boolean; override;
  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id : integer): string; override; // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;
  function ExtractMultiplier(Qso: PQso) : string; override;
  function IsCallLocalToContest(const ACallsign: string) : boolean;

  function getExch1(id:integer): string;    // returns station info (e.g. MIKE)
  function getExch2(id:integer): string;    // returns section info (e.g. OR)
  function getName(id:integer): string;     // returns station op name (e.g. MIKE)
  function getState(id:integer): string;    // returns state (e.g. OR)
  function getUserText(id:integer): string; // returns optional UserText
  function FindCallRec(out recOut: TNaQpCallRec; const ACall: string): Boolean;
  function GetStationInfo(const ACallsign: string) : string; override;
end;


implementation

uses
  SysUtils, Classes, Contnrs, PerlRegEx,
  Ini, ARRL, Contest;

function TNcjNaQp.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TNaQpCallRec;
{$ifdef DEBUG}
  dxcc: TDxCCRec;
  DxOnly, DxccTest, HiOnly, AkOnly, NaOnly: boolean;
{$endif}
begin
  NaQpCallList.Clear;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;
{$ifdef DEBUG}
  DxOnly := False;
  DxccTest := False;
  HiOnly := False;
  AkOnly := False;
  NaOnly := False;
{$endif}

  try
    NaQpCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'NAQPCW.TXT');

    for i:= 0 to slst.Count-1 do begin
      if (slst.Strings[i].StartsWith('!!Order!!')) then continue;
      if (slst.Strings[i].StartsWith('#')) then continue;

{$ifdef DEBUG}
      // look for debugging hooks...
      if (slst.Strings[i].Equals('break')) then break
      else if (slst.Strings[i].Equals('DxccTest')) then DxccTest := True
      else if (slst.Strings[i].Equals('DxOnly')) then DxOnly := True
      else if (slst.Strings[i].Equals('HiOnly')) then HiOnly := True
      else if (slst.Strings[i].Equals('AkOnly')) then AkOnly := True
      else if (slst.Strings[i].Equals('NaOnly')) then NaOnly := True;
{$endif}

      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then begin
          if rec = nil then
            rec := TNaQpCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.Name := UpperCase(tl.Strings[1]);
          rec.State := UpperCase(tl.Strings[2]);
          rec.UserText := '';
          if tl.Count >= 4 then rec.UserText := Trim(tl.Strings[3]);
          if rec.Call='' then continue;
          if rec.Name='' then continue;
          if length(rec.Name) > 12 then continue;
          if rec.State='' then continue;

{$ifdef DEBUG}
          // debug hook to force each call to look up DXCC Record
          if DxccTest and not gDXCCList.FindRec(dxcc, rec.Call) then begin
            assert(false);
            continue;
          end;

          // debug hooks provide ability to load subset of call history
          if DxOnly and (rec.State <> '') then continue
          else if HiOnly and (not rec.State.Equals('HI')) then continue
          else if AkOnly and (not rec.State.Equals('AK')) then continue
          else if NaOnly and not (gDXCCList.FindRec(dxcc, rec.Call) and
                (dxcc.Entity.Equals('United States of America') or
                 dxcc.Entity.Equals('Hawaii') or
                 dxcc.Entity.Equals('Canada') or
                 dxcc.Entity.Equals('Mexico'))) then
            continue;

          // 4U1WB is from DC, not DX. DX is flagged as an Invalid Section by N1MM.
          //if not rec.Call.Equals('4U1WB') then continue;

          // KP2M is from KP2, not VI. Virgin Islands? N1MM logs 'VI' as 'KP2'.
          //if not rec.Call.Equals('KP2M') then continue;
{$endif}

          NaQpCallList.Add(rec);
          rec := nil;
      end;
    end;

    Result := True;

  finally
    slst.Free;
    tl.Free;
    if rec <> nil then rec.Free;
  end;
end;


{
  OnSetMyCall is overriden for NCJ NAQP Contest to determine whether user's
  callsign is within NA or Hawaii. In other words, is the user's station
  within the home region of this contest?

  Sets TDualExchContest.HomeCallIsLocal.
}
function TNcjNaQp.OnSetMyCall(const AUserCallsign : string;
  out err : string) : boolean;
var
  dxcc: TDxCCRec;
begin
  Result:= True;
  err:= '';

  // select calls based on location of user's station.
  // (NA works everyone, non-NA works only NA)
  if gDxCCList.FindRec(dxcc, AUserCallsign) then
    // Is home call local to contest (i.e. a North American (NA) Station)?
    HomeCallIsLocal := dxcc.Continent.Equals('NA') or dxcc.Entity.Equals('Hawaii')
  else
    begin
      // report an error
      err := Format('Error: ''%s'' is not recognized as a valid DXCC callsign.',
        [AUserCallsign]);

      // for the error case, make a best-guess effort to determine US/VE
      HomeCallIsLocal := AUserCallsign.StartsWith('A') or
                         AUserCallsign.StartsWith('K') or
                         AUserCallsign.StartsWith('N') or
                         AUserCallsign.StartsWith('W') or
                         AUserCallsign.StartsWith('VE') or
                         AUserCallsign.StartsWith('XE');
      Result := False;
    end;

  // call baseclass to update Me.MyCall and Me.SentExchTypes
  if not inherited OnSetMyCall(AUserCallsign, err) then
    Result:= False;
end;


constructor TNcjNaQp.Create;
begin
    inherited Create(etOpName, etNaQpExch2,     // NA station exchange
                     etOpName, etNaQpNonNaExch2); // non-NA station exchange
    NaQpCallList := TList<TNaQpCallRec>.Create;
    Comparer := TComparer<TNaQpCallRec>.Construct(TNaQpCallRec.compareCall);
end;


destructor TNcjNaQp.Destroy;
begin
  FreeAndNil(NaQpCallList);
  inherited;
end;


{
  returns exchange types for this contest and sending station.

  For the NCJ NAQP Contest, the exchange being sent if determined by the
  sending station's callsign:
  - NA stations send Name and Location (State, Province or Entity prefix)
  - Non-NA stations send only Name
}
function TNcjNaQp.GetExchangeTypes(
  const AStationKind : TStationKind;
  const ARequestedMsgType : TRequestedMsgType;
  const AStationCallsign : string) : TExchTypes;
begin
  // exchange type being sent are determine by sending station's location
  if (Tst as TNcjNaQp).IsCallLocalToContest(AStationCallsign) then
    Result := Self.LocalTypes
  else
    Result := Self.DxTypes;
end;


{
  PickStation will randomly pick the next station from NaQpCallList.

  Also performs several filtering actions which have been deferred
  from LoadCallHistoryFile. This prevents an O(n**2) situation in
  LoadCallHistoryFile where DXCC lookup would be performed on each callsign
  being loaded from the file. If a callsign is rejected, it is dropped
  from NaQpCallList.

  Returns the index of the next station callsign to be used.
}
function TNcjNaQp.PickStation(): integer;
var
  HomeCallIsDX: Boolean;
  Keep: Boolean;
  rec: TNaQpCallRec;
  dxcc: TDxCCRec;
begin
  HomeCallIsDX:= not Self.HomeCallIsLocal;

  result := random(NaQpCallList.Count);
  while (NaQpCallList.Count > 1) do
    begin
      rec := NaQpCallList[result];

      // Keep stations that have a valid DXCC entry
      Keep := gDXCCList.FindRec(dxcc, rec.Call);
      if Keep and rec.State.IsEmpty then
        begin
          // This record has no State.
          // Consider whether call is within NAQP contest region
          if (dxcc.Continent.Equals('NA') or dxcc.Entity.Equals('Hawaii')) then
            begin
              // Call is local to NAQP contest. Use dxcc prefix if it is simple
              // and contains no regular expression syntax; otherwise skip it.
              // (this occurs when NAQPCW.txt file has missing information)
              Keep := not dxcc.prefixReg.Contains('()|,[]*+-');
              if Keep then
                rec.State := dxcc.prefixReg;
            end;
        end;

      // Non-NA stations (their home call is outside of NAQP contest region),
      // skip all other Non-NA stations since non-NA stations only work NA stations
      if Keep and HomeCallIsDX and not IsCallLocalToContest(rec.Call) then
        Keep := False;

      if Keep then
        break;

      // drop this station and try again
      DropStation(result);
      result := random(NaQpCallList.Count);
    end;
end;


procedure TNcjNaQp.DropStation(id : integer);
begin
  assert(id < NaQpCallList.Count);
  NaQpCallList.Delete(id);
end;


function TNcjNaQp.FindCallRec(out recOut: TNaQpCallRec; const ACall: string): Boolean;
var
  rec: TNaQpCallRec;
  index: integer;
begin
  rec := TNaQpCallRec.Create();
  rec.Call := ACall;
  recOut:= nil;
  try
    if NaQpCallList.BinarySearch(rec, index, Comparer) then
      recOut:= NaQpCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= recOut <> nil;
end;


// return status bar information string from field day call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from CallHistoryFile> [- Entity/Continent]'
function TNcjNaQp.GetStationInfo(const ACallsign: string) : string;
var
  rec : TNaQpCallRec;
  dxrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  rec := nil;
  dxrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if FindCallRec(rec, ACallsign) then
    begin
    userText:= rec.UserText;

    // if caller is outside NA Contest, include its Continent/Entity
    if (rec.State = '') and
        gDXCCList.FindRec(dxrec, ACallsign) then
      dxEntity:= dxRec.Continent + '/' + dxRec.Entity;
    end;

  if (userText <> '') or (dxEntity <> '') then
    begin
    result:= ACallsign;
    if userText <> '' then
      result:= result + ' - ' + userText;
    if dxEntity <> '' then
      result:= result + ' - ' + dxEntity;
    end;
end;


{
  Extract multiplier string for a given contest.
  Also sets contest-specific Qso.Points for this QSO.

  For NCJ NAQP Contest, the State/Prov value is returned;
  non-NA (DX) stations do not count as a multiplier.

  Return the multiplier string used by this contest. This string is accumlated
  in the Log.RawMultList and Log.VerifiedMultList to count the multiplier value.
}
function TNcjNaQp.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso^.Points := 1;

  // NA stations use State/Prov as multiplier string; non-NA use ''.
  if Self.IsCallLocalToContest(Qso.Call) then
    Result := Qso^.Exch2
  else
    Result := '';
end;


{
  Return whether Station is within the NAQP Contest region.
}
function TNcjNaQp.IsCallLocalToContest(const ACallsign: string) : boolean;
var
  dxrec : TDXCCRec;
begin
  Result := gDXCCList.FindRec(dxrec, ACallsign) and
            (dxrec.Continent.Equals('NA') or dxrec.Entity.Equals('Hawaii'));
end;


function TNcjNaQp.GetCall(id : integer): string;
begin
  result := NaQpCallList.Items[id].Call;
end;


procedure TNcjNaQp.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);
  station.OpName := station.Exch1; // TODO - refactor etOpName to use Exch1
  station.Exch2 := getExch2(station.Operid);
  station.UserText := getUserText(station.Operid);
end;


function TNcjNaQp.getExch1(id:integer): string;
begin
  result := NaQpCallList.Items[id].Name;
end;


function TNcjNaQp.getExch2(id:integer): string;
begin
  result := NaQpCallList.Items[id].State;
end;


function TNcjNaQp.getName(id:integer): string;
begin
  result := NaQpCallList.Items[id].Name;
end;


function TNcjNaQp.getState(id:integer): string;
begin
  result := NaQpCallList.Items[id].State;
end;


function TNcjNaQp.getUserText(id:integer): string;
begin
  result := NaQpCallList.Items[id].UserText;
end;


{ TODO - this can refactor into a common base class }
class function TNaQpCallRec.compareCall(const left, right: TNaQpCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TNaQpCallRec.GetString: string;
begin
  Result := Format(' - %s %s', [Name, State]);
end;


end.



