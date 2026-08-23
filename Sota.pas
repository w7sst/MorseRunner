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
  WeakRst       = 339;       // the report a barely-readable caller sends
  WeakFraction  = 0.15;      // callers who report me as barely readable
  WeakAmplitude = 14000;     // TDxStation.Amplitude below this reads as 339

type
  TSota = class(TContest)
  private
    SotaCallList: TStringList;
    // association (e.g. 'W7O', 'JA5', 'VE9') -> summit codes in it. Owns the
    // lists. Indexed per association, not per country, so that a caller in
    // one call area does not get a summit from another (see PickSummitFor).
    SummitsByAssoc: TObjectDictionary<string, TStringList>;
    // country (cty.dat primary prefix) -> the associations inside it
    AssocsByEntity: TObjectDictionary<string, TStringList>;
    // association -> its call-area digit, #0 when it has none ('G', 'JA')
    AssocArea: TDictionary<string, Char>;
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

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;

    function PickStation: integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id : integer): string; override;
    procedure GetExchange(id: Integer; station: TDxStation); override;
    procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); override;
    function ValidateMyExchange(const AExchange: string;
      ATokens: TStringList; out AExchError: string): boolean; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
    function CallerCopiesPoorly(const AStn: TStation): boolean; override;

    // returns a summit reference in the country ACall is operating from, or
    // '' when there are no summits there
    function PickSummitFor(const ACall: string): string;
    // Where the operator actually is, from the callsign he signs. Returns the
    // prefix or callsign that names the location, and the call-area digit
    // that applies there (#0 when the location carries none).
    //   'LX/AB1DE/P' -> 'LX'      + area from LX     (operating in Luxembourg)
    //   'K0EMT/VE9'  -> 'VE9'     + area 9           (a US call, but in VE9)
    //   'JL1EFV/5'   -> 'JL1EFV'  + area 5           (same country, area 5)
    //   'DL1GG/P'    -> 'DL1GG'   + area 1           ('/P' is only a modifier)
    //   '2W0ILQ/M'   -> '2W0ILQ'  + area 0           ('/M' is mobile, not England)
    class procedure SplitLocation(const ACall: string;
      out ALocation: string; out AArea: Char);
    // just the location half of SplitLocation
    class function LocationPart(const ACall: string): string;
    // the call-area digit of a prefix or callsign: 'K0EMT' -> '0',
    // 'VE9' -> '9', 'W7O' -> '7', 'JA' -> #0
    class function AreaDigitOf(const ACall: string): Char;
    // whether ACall is signing portable or with a foreign prefix
    class function IsPortable(const ACall: string): boolean;
    // put a reference into canonical form, or '' if it is not one at all:
    // 'PA-PA003', 'PA/PA003' and 'papa003' all become 'PA/PA-003'
    class function NormaliseRef(const ARef: string): string;
    // the country a callsign (or a summit association) belongs to, as a
    // cty.dat primary prefix
    function EntityOf(const ACall: string): string;
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

  // Per association rather than per country: keeping every one of the ~181,000
  // summits costs far more memory than the variety is worth, but the cap has
  // to leave every association populated or a whole call area disappears.
  MaxSummitsPerAssoc = 200;


constructor TSota.Create;
begin
  inherited Create;
  SotaCallList := TStringList.Create;
  SummitsByAssoc := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  AssocsByEntity := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  AssocArea := TDictionary<string, Char>.Create;
  CtyPrefix := TDictionary<string, string>.Create;
  CtyExact := TDictionary<string, string>.Create;
end;


destructor TSota.Destroy;
begin
  FreeAndNil(CtyExact);
  FreeAndNil(CtyPrefix);
  FreeAndNil(AssocArea);
  FreeAndNil(AssocsByEntity);
  FreeAndNil(SummitsByAssoc);
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
  Where the operator actually is, worked out from the callsign he signs.

  Three things can appear around the base callsign, and they mean different
  things:

    a leading prefix   'LX/AB1DE/P'  he is in Luxembourg -- the prefix wins
    a trailing prefix  'K0EMT/VE9'   a US call operating in VE9 (mostly NA use)
    a trailing digit   'JL1EFV/5'    same country, call area 5 (JA, W, ...)

  Everything else after the callsign is a modifier -- /P, /M, /QRP, /MM -- and
  says nothing about location. That matters because some modifiers are also
  valid prefixes: the 'M' of 2W0ILQ/M is mobile, not England, so a trailing
  single letter is always read as a modifier.
}
class procedure TSota.SplitLocation(const ACall: string;
  out ALocation: string; out AArea: Char);
var
  Parts: TStringList;
  i: integer;
  P: string;
begin
  ALocation := ACall;
  AArea := #0;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := '/';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := UpperCase(Trim(ACall));
    if Parts.Count = 0 then Exit;

    // The base callsign is the longest element; a leading element shorter than
    // it is a location prefix ('LX/AB1DE'), not the call itself.
    ALocation := Parts.Strings[0];
    for i := 1 to Parts.Count-1 do
      if Length(Parts.Strings[i]) > Length(ALocation) then
        ALocation := Parts.Strings[i];

    if Parts.Strings[0] <> ALocation then
      begin
      // a leading prefix names the location outright and outranks any suffix
      ALocation := Parts.Strings[0];
      AArea := AreaDigitOf(ALocation);
      Exit;
      end;

    AArea := AreaDigitOf(ALocation);

    // walk the suffixes; the last one that carries location information wins
    for i := 1 to Parts.Count-1 do
      begin
      P := Parts.Strings[i];
      if P = '' then Continue;

      // '/5' - same country, different call area
      if (Length(P) = 1) and CharInSet(P[1], ['0'..'9']) then
        AArea := P[1]
      // a single letter is always a modifier (/P, /M, /A, /R)
      else if Length(P) = 1 then
        Continue
      else if (P = 'MM') or (P = 'AM') or (P = 'QRP') or (P = 'QRPP') or
              (P = 'LH') or (P = 'BCN') then
        Continue
      // '/VE9' - operating in another prefix's area altogether
      else
        begin
        ALocation := P;
        AArea := AreaDigitOf(P);
        end;
      end;
  finally
    Parts.Free;
  end;
end;


class function TSota.LocationPart(const ACall: string): string;
var
  Area: Char;
begin
  SplitLocation(ACall, Result, Area);
end;


{
  The call-area digit: the last digit that is followed only by letters, which
  is where the prefix ends in any callsign or prefix. 'K0EMT' -> '0',
  'JL1EFV' -> '1', '2W0ILQ' -> '0', 'VE9' -> '9', 'JA' -> #0.
}
class function TSota.AreaDigitOf(const ACall: string): Char;
var
  i, j: integer;
  OnlyLetters: boolean;
begin
  Result := #0;
  for i := Length(ACall) downto 1 do
    if CharInSet(ACall[i], ['0'..'9']) then
      begin
      OnlyLetters := True;
      for j := i+1 to Length(ACall) do
        if not CharInSet(ACall[j], ['A'..'Z', 'a'..'z']) then
          begin OnlyLetters := False; Break; end;
      if OnlyLetters then
        begin Result := ACall[i]; Exit; end;
      end;
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
  Read summitslist.txt and index the summit codes by their association, and
  the associations by the country they sit in. Line 1 is a title, line 2 the
  CSV header; SummitCode is the first column, so everything up to the first
  comma is taken without having to parse the quoted fields that follow.

  Indexing per association (not per country) is what lets PickSummitFor keep a
  caller in his own call area: 'W5T' and 'W7O' are both the USA, but only one
  of them is where a W5 station is standing.
}
procedure TSota.LoadSummits;
var
  slst: TStringList;
  AssocEntity: TDictionary<string, string>;  // association -> entity ('' = none)
  SeenPerAssoc: TDictionary<string, integer>;
  Codes, Assocs: TStringList;
  i, n, Seen: integer;
  Line, Code, Assoc, Entity: string;
begin
  SummitsByAssoc.Clear;
  AssocsByEntity.Clear;
  AssocArea.Clear;
  slst := TStringList.Create;
  AssocEntity := TDictionary<string, string>.Create;
  SeenPerAssoc := TDictionary<string, integer>.Create;
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

        if Entity <> '' then
          begin
          if not AssocsByEntity.TryGetValue(Entity, Assocs) then
            begin
            Assocs := TStringList.Create;
            AssocsByEntity.Add(Entity, Assocs);
            end;
          Assocs.Add(Assoc);
          AssocArea.AddOrSetValue(Assoc, AreaDigitOf(Assoc));
          end;
        end;
      if Entity = '' then Continue;

      if not SummitsByAssoc.TryGetValue(Assoc, Codes) then
        begin
        Codes := TStringList.Create;
        SummitsByAssoc.Add(Assoc, Codes);
        end;

      // reservoir sampling: keep MaxSummitsPerAssoc of them, uniformly, so
      // the choice is spread over the association rather than biased to '-001'
      if not SeenPerAssoc.TryGetValue(Assoc, Seen) then Seen := 0;
      Inc(Seen);
      SeenPerAssoc.AddOrSetValue(Assoc, Seen);

      if Codes.Count < MaxSummitsPerAssoc then
        Codes.Add(Code)
      else
        begin
        n := Random(Seen);
        if n < MaxSummitsPerAssoc then Codes.Strings[n] := Code;
        end;
      end;
  finally
    SeenPerAssoc.Free;
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


{
  A summit reference for where ACall is actually operating.

  The association has to match the operator's call area, not just his country:
  a station signing /VE9 belongs on a VE9 summit, and JL1EFV/5 on a JA5 one.
  When the country's associations carry no digit at all (G, DL, LX) or none
  matches (a JA1 station: Japan indexes only JA5, JA6 and JA8 separately, the
  rest are plain 'JA'), the digit-less associations are the right answer.
}
function TSota.PickSummitFor(const ACall: string): string;
var
  Codes, Assocs, Candidates: TStringList;
  Entity, Location: string;
  Area, AssocDigit: Char;
  i: integer;
begin
  Result := '';
  SplitLocation(ACall, Location, Area);
  Entity := EntityOf(Location);
  if Entity = '' then Exit;
  if not AssocsByEntity.TryGetValue(Entity, Assocs) then Exit;
  if Assocs.Count = 0 then Exit;

  Candidates := TStringList.Create;
  try
    // first choice: an association in the operator's own call area
    if Area <> #0 then
      for i := 0 to Assocs.Count-1 do
        if AssocArea.TryGetValue(Assocs.Strings[i], AssocDigit) and
           (AssocDigit = Area) then
          Candidates.Add(Assocs.Strings[i]);

    // otherwise the associations that cover the whole country
    if Candidates.Count = 0 then
      for i := 0 to Assocs.Count-1 do
        if AssocArea.TryGetValue(Assocs.Strings[i], AssocDigit) and
           (AssocDigit = #0) then
          Candidates.Add(Assocs.Strings[i]);

    // last resort: anywhere in the country, as before
    if Candidates.Count = 0 then
      Candidates.Assign(Assocs);

    if Candidates.Count = 0 then Exit;
    if not SummitsByAssoc.TryGetValue(
         Candidates.Strings[Random(Candidates.Count)], Codes) then Exit;
    if Codes.Count = 0 then Exit;
    Result := Codes.Strings[Random(Codes.Count)];
  finally
    Candidates.Free;
  end;
end;


{
  A realistic report. Only the readability digit moves: a weak caller gets
  339, everyone else 5x9 with x in 3..9.
}
class function TSota.MakeRst(AIsWeak: boolean): integer;
begin
  if AIsWeak then
    Result := WeakRst
  else
    Result := 509 + 10 * (3 + Random(7));   // 539..599
end;


 {
  A caller who reports me WeakRst can barely hear me, so he mis-copies what I
  send more often and asks for more repeats. See TContest.CallerCopiesPoorly.
}
function TSota.CallerCopiesPoorly(const AStn: TStation): boolean;
begin
  Result := Assigned(AStn) and (AStn.RST = WeakRst);
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


procedure TSota.GetExchange(id: Integer; station: TDxStation);
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
    // I send my own reference with F6, keyed twice as on the air. A caller's
    // own doubled reference is rendered by TStation.NrAsText instead.
    msgSotaRef: SendText(AStn, 'REF <exch2> <exch2>');
    msgAgnQm:   SendText(AStn, 'AGN?');
    msgTu73:    SendText(AStn, 'TU 73');
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
