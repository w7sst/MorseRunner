//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Sota;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

{
  SOTA (Summits on the Air) activation practice.

  This is an activity rather than a contest. The user is the activator calling
  from a summit; the callers are chasers. A plain QSO exchanges signal reports
  only. About one caller in ten is himself on a summit and sends his own
  summit reference twice, making it a summit-to-summit (S2S) QSO.

  Two data files, both in the directory the program is run from:

    SOTA_Calls_CW.txt   plain list of caller callsigns, one per line
    summitslist.txt     the official summits list, CSV; only the first column
                        (SummitCode, e.g. 'G/LD-001') is used

  Only a caller who is signing portable or with a foreign prefix is treated as
  being on a summit -- a plain home callsign is someone at his own station.
  His reference then has to belong to where he is actually operating:

    LX/AB1DE/P   operating in Luxembourg  -> an LX summit
    DL1GG/P      portable at home in DL   -> a DL summit
    DL1GG        not portable             -> never on a summit

  The country is resolved with cty.dat, the standard AD1C country file, in the
  project folder. The part of a summit code before the '/' is its association,
  which by SOTA convention is itself a callsign prefix, so the same lookup maps
  associations to countries and a caller is given a summit from his own.

  Reports are realistic rather than the usual 599: a weak caller sends 339,
  everyone else 5x9 with only the readability digit varying. The report the
  user sends is generated the same way from the caller's own signal level, so
  it varies per QSO without having to be typed (see GetSentRst).
}

interface

uses
  Classes, Generics.Collections, Contest, DxStn, Station, Log, ExchFields;

const
  // Share of portable or foreign-prefixed callers who are on a summit. About
  // a quarter of the caller list signs that way, so this lands near one
  // caller in ten overall.
  S2S_FRACTION = 0.40;

  // How weak signals are decided. The two directions are independent on
  // purpose: how well a caller hears me has nothing to do with how well I
  // hear him, so his report of me is drawn at random while my report of him
  // follows his actual level in the receiver.
  WeakFraction  = 0.15;      // callers who report me as barely readable
  WeakAmplitude = 14000;     // TDxStation.Amplitude below this reads as 339

type
  TSota = class(TContest)
  private
    SotaCallList: TStringList;
    // country (cty.dat primary prefix) -> summit codes there. Owns the lists.
    SummitsByEntity: TObjectDictionary<string, TStringList>;
    // cty.dat: callsign prefix -> primary prefix, and exact-callsign overrides
    CtyPrefix: TDictionary<string, string>;
    CtyExact: TDictionary<string, string>;
    // the report I am sending in the current QSO, cached so that repeats of
    // the same exchange do not change it mid-QSO
    FSentRstCall: string;
    FSentRst: integer;

    procedure RequireFile(const AName: string);
    procedure LoadCountryFile;
    procedure LoadSummits;
    function EntityOf(const ACall: string): string;

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;

    function PickStation: integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id : integer): string; override;
    procedure GetExchange(id : integer; var station : TDxStation); override;
    procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); override;
    function ValidateMyExchange(const AExchange: string;
      ATokens: TStringList; out AExchError: string): boolean; override;
    function ExtractMultiplier(Qso: PQso) : string; override;

    // returns a summit reference in the country ACall is operating from, or
    // '' when there are no summits there
    function PickSummitFor(const ACall: string): string;
    // the part of a callsign that says where the operator actually is:
    // 'LX/AB1DE/P' -> 'LX', 'DL1GG/P' -> 'DL1GG', 'DL1GG' -> 'DL1GG'
    class function LocationPart(const ACall: string): string;
    // whether ACall is signing portable or with a foreign prefix
    class function IsPortable(const ACall: string): boolean;
    // put a reference into canonical form, or '' if it is not one at all:
    // 'PA-PA003', 'PA/PA003' and 'papa003' all become 'PA/PA-003'
    class function NormaliseRef(const ARef: string): string;
    // the country a callsign (or a summit association) belongs to, as a
    // cty.dat primary prefix. Public so the checker can verify the pairing.
    function EntityOfPublic(const ACall: string): string;
    // a realistic report: 339 for a weak signal, otherwise 5x9
    class function MakeRst(AIsWeak: boolean): integer;
    // a report as it is actually keyed: 599 -> 5NN, 579 -> 57N, 339 -> 33N
    class function RstAsText(ARst: integer): string;
    // the report the user sends the station he is working, from its signal
    function GetSentRst: integer;
  end;

implementation

uses
  SysUtils, Math, StrUtils, Ini;

const
  CallHistoryFile = 'SOTA_Calls_CW.txt';
  SummitsFile     = 'summitslist.txt';
  CountryFile     = 'cty.dat';

  // Keeping every one of the ~181,000 summits would cost far more memory than
  // the variety is worth; this many per entity is already more than a user
  // will ever see in a session. Kept by reservoir sampling so the choice is
  // spread over the whole association rather than biased to '-001'.
  MaxSummitsPerEntity = 500;


constructor TSota.Create;
begin
  inherited Create;
  SotaCallList := TStringList.Create;
  SummitsByEntity := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  CtyPrefix := TDictionary<string, string>.Create;
  CtyExact := TDictionary<string, string>.Create;
end;


destructor TSota.Destroy;
begin
  FreeAndNil(CtyExact);
  FreeAndNil(CtyPrefix);
  FreeAndNil(SummitsByEntity);
  FreeAndNil(SotaCallList);
  inherited;
end;


{
  Read cty.dat. Each record is a header line ending in the country's primary
  prefix, followed by continuation lines holding a comma-separated alias list
  terminated by ';'. An alias may carry CQ/ITU/lat/lon/continent overrides in
  brackets, which are of no interest here and are stripped; an alias starting
  with '=' is an exact callsign rather than a prefix.
}
procedure TSota.LoadCountryFile;
var
  slst, aliases: TStringList;
  i, j, n: integer;
  Line, Primary, Alias: string;
begin
  slst := TStringList.Create;
  aliases := TStringList.Create;
  try
    slst.LoadFromFile(ParamStr(1) + CountryFile);
    Primary := '';

    for i := 0 to slst.Count-1 do
      begin
      Line := slst.Strings[i];
      if Trim(Line) = '' then Continue;

      if Line[1] <> ' ' then
        begin
        // header line: the primary prefix is the 8th ':'-delimited field
        aliases.Clear;
        aliases.Delimiter := ':';
        aliases.StrictDelimiter := True;
        aliases.DelimitedText := Line;
        if aliases.Count >= 8 then
          Primary := UpperCase(Trim(aliases.Strings[7]))
        else
          Primary := '';
        Continue;
        end;

      if Primary = '' then Continue;

      // continuation line: comma-separated aliases, ';' ends the record
      aliases.Clear;
      aliases.Delimiter := ',';
      aliases.StrictDelimiter := True;
      aliases.DelimitedText := StringReplace(Trim(Line), ';', '', [rfReplaceAll]);

      for j := 0 to aliases.Count-1 do
        begin
        Alias := UpperCase(Trim(aliases.Strings[j]));
        // strip any CQ/ITU/coordinate/continent/offset override
        n := 1;
        while (n <= Length(Alias)) and
              not CharInSet(Alias[n], ['(', '[', '<', '{', '~']) do
          Inc(n);
        Alias := Copy(Alias, 1, n-1);
        if Alias = '' then Continue;

        if Alias[1] = '=' then
          CtyExact.AddOrSetValue(Copy(Alias, 2, MaxInt), Primary)
        else
          // first definition wins; cty.dat lists the owning country first
          if not CtyPrefix.ContainsKey(Alias) then
            CtyPrefix.Add(Alias, Primary);
        end;
      end;
  finally
    aliases.Free;
    slst.Free;
  end;
end;


{
  The part of a callsign that says where the operator actually is. Only a
  leading element can be a location prefix; anything after the callsign is a
  suffix such as /P or /M. 'M' in 2W0ILQ/M is a suffix, not England.
}
class function TSota.LocationPart(const ACall: string): string;
var
  n: integer;
begin
  // It is always the first element, whether that is a prefix or the callsign
  // itself: 'LX/AB1DE/P' -> LX, 'DL1GG/P' -> DL1GG, '2W0ILQ/M' -> 2W0ILQ.
  // Taking anything later would read the 'M' of 2W0ILQ/M as England.
  n := Pos('/', ACall);
  if n = 0 then
    Result := ACall
  else
    Result := Copy(ACall, 1, n-1);
end;


class function TSota.IsPortable(const ACall: string): boolean;
begin
  Result := Pos('/', ACall) > 0;
end;


{
  A reference is <association>/<region>-<number>, where the association is
  1..3 characters, the region two letters and the number three digits. The
  separators are the easiest part to get wrong, so they are optional on entry
  and put back here: 'PA-PA003' and 'PA/PA003' both mean PA/PA-003.
  Returns '' when the text cannot be a reference at all.
}
class function TSota.NormaliseRef(const ARef: string): string;
var
  S, Assoc: string;
  i, n: integer;
begin
  Result := '';

  // strip spaces and the optional separators, then rebuild them
  S := '';
  for i := 1 to Length(ARef) do
    if not CharInSet(ARef[i], [' ', '/', '-']) then
      S := S + UpCase(ARef[i]);

  // <assoc><region:2 letters><number:3 digits>
  n := Length(S);
  if n < 6 then Exit;                       // shortest is e.g. G LD 001
  if n > 8 then Exit;                       // longest is 3 + 2 + 3

  for i := n-2 to n do
    if not CharInSet(S[i], ['0'..'9']) then Exit;
  if not CharInSet(S[n-3], ['A'..'Z']) then Exit;
  if not CharInSet(S[n-4], ['A'..'Z']) then Exit;

  Assoc := Copy(S, 1, n-5);
  if Assoc = '' then Exit;
  for i := 1 to Length(Assoc) do
    if not CharInSet(Assoc[i], ['A'..'Z', '0'..'9']) then Exit;

  Result := Assoc + '/' + Copy(S, n-4, 2) + '-' + Copy(S, n-2, 3);
end;


{
  Resolve a callsign to the primary prefix of the country it is operating
  from, or '' if it cannot be resolved. Longest prefix wins, as in cty.dat.
}
function TSota.EntityOf(const ACall: string): string;
var
  S: string;
  n: integer;
begin
  Result := '';
  S := UpperCase(LocationPart(ACall));
  if S = '' then Exit;

  if CtyExact.TryGetValue(S, Result) then Exit;

  for n := Length(S) downto 1 do
    if CtyPrefix.TryGetValue(Copy(S, 1, n), Result) then Exit;

  Result := '';
end;


{
  Read summitslist.txt and group summit codes by the DXCC entity of their
  association. Line 1 is a title, line 2 the CSV header; SummitCode is the
  first column, so everything up to the first comma is taken without having
  to parse the quoted fields that follow.
}
procedure TSota.LoadSummits;
var
  slst: TStringList;
  AssocEntity: TDictionary<string, string>;  // association -> entity ('' = none)
  SeenPerEntity: TDictionary<string, integer>;
  Codes: TStringList;
  i, n, Seen: integer;
  Line, Code, Assoc, Entity: string;
begin
  SummitsByEntity.Clear;
  slst := TStringList.Create;
  AssocEntity := TDictionary<string, string>.Create;
  SeenPerEntity := TDictionary<string, integer>.Create;
  try
    slst.LoadFromFile(ParamStr(1) + SummitsFile);

    for i := 2 to slst.Count-1 do
      begin
      Line := slst.Strings[i];
      n := Pos(',', Line);
      if n < 2 then Continue;
      Code := UpperCase(Copy(Line, 1, n-1));

      n := Pos('/', Code);
      if n < 2 then Continue;
      Assoc := Copy(Code, 1, n-1);

      // resolve each association to an entity once
      if not AssocEntity.TryGetValue(Assoc, Entity) then
        begin
        // An association code is itself a callsign prefix, so the same
        // longest-prefix lookup applies: 'W7O' -> W, 'KLA' -> KL, 'G' -> G.
        Entity := EntityOf(Assoc);
        AssocEntity.Add(Assoc, Entity);
        end;
      if Entity = '' then Continue;

      if not SummitsByEntity.TryGetValue(Entity, Codes) then
        begin
        Codes := TStringList.Create;
        SummitsByEntity.Add(Entity, Codes);
        end;

      // reservoir sampling: keep MaxSummitsPerEntity of them, uniformly
      if not SeenPerEntity.TryGetValue(Entity, Seen) then Seen := 0;
      Inc(Seen);
      SeenPerEntity.AddOrSetValue(Entity, Seen);

      if Codes.Count < MaxSummitsPerEntity then
        Codes.Add(Code)
      else
        begin
        n := Random(Seen);
        if n < MaxSummitsPerEntity then Codes.Strings[n] := Code;
        end;
      end;
  finally
    SeenPerEntity.Free;
    AssocEntity.Free;
    slst.Free;
  end;
end;


{
  Fail with something the user can act on. Without this a missing file
  surfaces as a bare EFOpenError naming a path, and SOTA needs three of them.
}
procedure TSota.RequireFile(const AName: string);
begin
  if not FileExists(ParamStr(1) + AName) then
    raise Exception.CreateFmt(
      'The SOTA activity needs the file %s, which was not found in %s.' +
      sLineBreak + sLineBreak +
      'Put it there, or pick a different contest.',
      [AName, ExpandFileName(ParamStr(1) + '.')]);
end;


function TSota.LoadCallHistory(const AUserCallsign : string) : boolean;
var
  slst: TStringList;
  i: integer;
  S: string;
begin
  // reload call history if empty
  Result := SotaCallList.Count <> 0;
  if Result then
    Exit;

  RequireFile(CallHistoryFile);
  RequireFile(SummitsFile);
  RequireFile(CountryFile);

  slst := TStringList.Create;
  try
    SotaCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + CallHistoryFile);

    // one callsign per line; ignore blanks and '#' comments so the list can
    // be hand-edited without breaking the simulation
    for i := 0 to slst.Count-1 do
      begin
      S := UpperCase(Trim(slst.Strings[i]));
      if S = '' then Continue;
      if S.StartsWith('#') then Continue;
      SotaCallList.Add(S);
      end;

    LoadCountryFile;
    LoadSummits;

    Result := SotaCallList.Count > 0;
  finally
    slst.Free;
  end;
end;


function TSota.PickStation: integer;
begin
  Result := Random(SotaCallList.Count);
end;


procedure TSota.DropStation(id : integer);
begin
  assert(id < SotaCallList.Count);
  SotaCallList.Delete(id);
end;


function TSota.GetCall(id : integer): string;
begin
  Result := SotaCallList.Strings[id];
end;


function TSota.PickSummitFor(const ACall: string): string;
var
  Codes: TStringList;
  Entity: string;
begin
  Result := '';
  Entity := EntityOf(ACall);
  if Entity = '' then Exit;
  if not SummitsByEntity.TryGetValue(Entity, Codes) then Exit;
  if Codes.Count = 0 then Exit;
  Result := Codes.Strings[Random(Codes.Count)];
end;


{
  A realistic report. Only the readability digit moves: a weak caller gets
  339, everyone else 5x9 with x in 3..9.
}
class function TSota.MakeRst(AIsWeak: boolean): integer;
begin
  if AIsWeak then
    Result := 339
  else
    Result := 509 + 10 * (3 + Random(7));   // 539..599
end;


function TSota.EntityOfPublic(const ACall: string): string;
begin
  Result := EntityOf(ACall);
end;


class function TSota.RstAsText(ARst: integer): string;
begin
  // only the 9s are cut; '339' stays '33N', which is what operators send
  Result := StringReplace(IntToStr(ARst), '9', 'N', [rfReplaceAll]);
end;


{
  The report the user sends the station he is working, derived from that
  station's signal level so that it varies per QSO without having to be typed.
  TDxStation.Amplitude is set at creation from 9000 + 18000*(1 + RndUShaped),
  i.e. roughly 9000..45000; the bottom of that range is "very weak" here.

  Cached against the callsign being worked so that repeating the exchange
  (or answering a 'NR?') does not change the report mid-QSO.
}
function TSota.GetSentRst: integer;
var
  i: integer;
  Call: string;
begin
  Call := Me.HisCall;
  if (Call <> '') and (Call = FSentRstCall) then
    Exit(FSentRst);

  FSentRst := MakeRst(False);
  for i := Stations.Count-1 downto 0 do
    if (Stations[i] is TDxStation) and (Stations[i].MyCall = Call) then
      begin
      FSentRst := MakeRst(Stations[i].Amplitude < WeakAmplitude);
      Break;
      end;

  FSentRstCall := Call;
  Result := FSentRst;
end;


procedure TSota.GetExchange(id : integer; var station : TDxStation);
begin
  // The caller's report of me, drawn at random (see WeakFraction above).
  station.RST := MakeRst(Random < WeakFraction);
  station.Exch1 := IntToStr(station.RST);

  // Only a caller signing portable or with a foreign prefix can be on a
  // summit; a plain home callsign is someone at his own station.
  if IsPortable(station.MyCall) and (Random < S2S_FRACTION) then
    station.Exch2 := PickSummitFor(station.MyCall)
  else
    station.Exch2 := '';
end;


{
  The Exchange box holds only the user's own summit reference -- the report he
  sends is generated per caller. The base class splits the box on spaces and
  validates token 0 against exchange field 1 (RST), which does not apply here,
  so the reference is placed in token 1 and token 0 is synthesised.
}
function TSota.ValidateMyExchange(const AExchange: string;
  ATokens: TStringList; out AExchError: string): boolean;
var
  S: string;
begin
  S := Trim(AExchange);

  // An empty reference is allowed: the user need not be on a summit himself.
  if S = '' then
    Result := True
  else
    begin
    S := NormaliseRef(S);
    Result := S <> '';
    end;

  ATokens.Clear;
  ATokens.Add('599');   // placeholder; the real report comes from GetSentRst
  ATokens.Add(S);

  if not Result then
    AExchError := Format(
      'Not a summit reference: ''%s''. Expecting <association>/<region>-<number>,'
      + ' for example G/LD-001 or PA/PA-003.', [Trim(AExchange)]);
end;


{
  Overrides TContest.SendMsg() to send contest-specific messages.

  Adding a contest: TContest.SendMsg(AMsg): send contest-specfic messages
}
procedure TSota.SendMsg(const AStn: TStation; const AMsg: TStationMessage);
begin
  case AMsg of
    msgCQ:     SendText(AStn, 'CQ SOTA <my>');
    msgLongCQ: SendText(AStn, 'CQ CQ SOTA <my> <my>');  // QrmStation only

    // What I send a caller is a report generated from his signal rather than
    // the fixed '<#>' the other contests send. Callers keep using '<#>',
    // which TStation.NrAsText renders as their report plus, for a
    // summit-to-summit QSO, their own reference twice.
    msgNR:
      if AStn = Me then
        SendText(AStn, RstAsText(GetSentRst))
      else
        inherited SendMsg(AStn, AMsg);
    msgR_NR, msgR_NR2:
      if AStn = Me then
        SendText(AStn, 'R ' + RstAsText(GetSentRst))
      else if (AMsg = msgR_NR2) and (AStn.Exch2 <> '') then
        // a summit-to-summit exchange already carries the reference twice;
        // the doubled 'R <#> <#>' would key it four times
        SendText(AStn, 'R <#>')
      else
        inherited SendMsg(AStn, AMsg);

    // 'REF?' on its own is me asking (F7); a caller asking sends its own
    // exchange along with the question
    msgRefQm:
      if AStn = Me then
        SendText(AStn, 'REF?')
      else
        SendText(AStn, 'R <#> REF?');
    else
      inherited SendMsg(AStn, AMsg);
  end;
end;


{
  SOTA has no contest scoring -- an activation is counted in chasers worked.
  One point per QSO and a constant multiplier make the Score column show the
  running QSO count. Only fully-correct QSOs reach the Verified column, so
  that is where "a point only if the whole exchange is copied" shows up.
}
function TSota.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso.Points := 1;
  Result := 'SOTA';
end;


end.
