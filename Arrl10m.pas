//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ARRL10M;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Classes, Contest, DxStn,
  DXCC,
  Arrl10m.Types,
  Station, Log;

type
  TArrl10m = class(TContest)
  private
    Arrl10mCallList: TObjectList<TArrl10mCallRec>;
    Comparer: IComparer<TArrl10mCallRec>;
    FIsCallLocalLastCall: String;     // used to optimize IsCallLocalToContest
    FIsCallLocalLastResult: Boolean;  // used to optimize IsCallLocalToContest
    HomeCallIsLocal: Boolean;

    function GetExchangeTypesByCall(const ACallsign : String) : TExchTypes;
    function IsEntityLocalToContest(const dxcc: TDxccRec) : boolean;

  protected
    function GetCallHistoryCount: Integer; override;

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;

    function ValidateMyExchange(const AExchange: string;
      ATokens: TStringList;
      out AExchError: string): boolean; override;
    function OnSetMyCall(const AUserCallsign : string; out err : string) : boolean; override;
    function GetExchangeTypes(
      const AStationKind : TStationKind;
      const ARequestedMsgType : TRequestedMsgType;
      const AStationCallsign : String;
      const ARemoteCallsign : String) : TExchTypes; override;
    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id:integer): string; override;  // returns station callsign
    procedure GetExchange(id : integer; station : TDxStation); override;

    function getExch1(id:integer): string;    // returns default RST value
    function getExch2(id:integer): string;    // returns State/Prov, or
    function getUserText(id:integer): string; // returns optional user text
    function IsNum(Num: String): Boolean;
    function FindCallRec(out dxrec: TArrl10mCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign : string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
    function IsCallLocalToContest(const ACallsign: string) : boolean;
  end;


implementation

uses
  SysUtils,
  StrUtils,
  ContestFileFormat,
  ContestFileReader,        // for TRecordConsumer<>
  Arrl10m.Reader,           // TArrl10mContestFileReader
  Arrl10m.Policy,           // TArrl10mPolicy.IsCallLocalToContest
  PerlRegEx,                // for regular expression support
  AppPaths,
  Ini, Main;

{$ifdef DEBUG}
type
  // Callsign Distribution Report
  TDistributionReport = class
    const
      LocalKeys: array[0..4] of string = (
        'United States of America',
        'Canada', 'Mexico', 'Alaska', 'Hawaii');
      DxKeys: array[0..6] of String = (
        'NA', 'SA', 'EU', 'AS', 'AF', 'OC', 'MM');

    private
      FContest: TArrl10m;
      FDetails: TDictionary<String, integer>;
      FContinentNames: TDictionary<String, String>;
      TurkeyCnt: Integer;     // Turkey splits between Europe and Asia
      MaldivesCnt: Integer;   // Maldives splits between Asia and Africa
      FTotal: Integer;

    public
      constructor Create(const AContest: TArrl10m);
      destructor Destroy; override;

      procedure AddCall(const Call: String; const dxcc: TDxccRec);
      procedure WriteReport;
  end;

constructor TDistributionReport.Create(const AContest: TArrl10m);
var
  Key: String;
begin
  FContest := AContest;
  FDetails := TDictionary<String, integer>.Create;
  for Key in LocalKeys do
    FDetails.Add(Key, 0);
  for Key in DxKeys do
    FDetails.Add(Key, 0);
  TurkeyCnt := 0;
  MaldivesCnt := 0;
  FTotal := 0;

  FContinentNames := TDictionary<String, String>.Create;
  FContinentNames.Add('AF', 'Africa');
  FContinentNames.Add('AS', 'Asia');
  FContinentNames.Add('EU', 'Europe');
  FContinentNames.Add('NA', 'N. America');
  FContinentNames.Add('NA/Other', 'NA/Other');
  FContinentNames.Add('SA', 'S. America');
  FContinentNames.Add('OC', 'Oceania');
  FContinentNames.Add('MM', 'Maritime');
end;

destructor TDistributionReport.Destroy;
begin
  FDetails.Free;
  FContinentNames.Free;
  inherited;
end;

procedure TDistributionReport.AddCall(const Call: String; const dxcc: TDxccRec);
var
  Key: String;
  Count: Integer;
begin
  assert(dxcc <> nil);
  if dxcc = nil then Exit;

  if Call.Contains('/MM') then
    Key := 'MM'
  else if FContest.IsEntityLocalToContest(dxcc) then
    Key := dxcc.Entity
  else if dxcc.Continent = 'EU/AS' then
    begin
      assert(dxcc.Entity = 'Turkey');
      Inc(TurkeyCnt, 1);
      Key := IfThen((TurkeyCnt mod 2) = 1, 'EU', 'AS');
    end
  else if dxcc.Continent = 'AS/AF' then
    begin
      assert(dxcc.Entity = 'Maldives');
      Inc(MaldivesCnt, 1);
      Key := IfThen((MaldivesCnt mod 2) = 1, 'AS', 'AF');
    end
  else
    Key := dxcc.Continent;

  if FDetails.TryGetValue(Key, Count) then
    FDetails[Key] := Count + 1
  else
    FDetails.Add(Key, 1);

  Inc(FTotal, 1);
end;

procedure TDistributionReport.WriteReport;
var
  Key: String;
  Count, SubTotal: Integer;
  Pair: TPair<String, Integer>;
begin
  DebugLn('# Callsign Distribution...');
  DebugLn('# %-13s   %5d (%5.1f%%)', ['Total Calls', FTotal, 100.0]);

  // Write Local keys...
  SubTotal := 0;
  for Key in LocalKeys do
    Inc(SubTotal, FDetails[Key]);
  DebugLn('# %-12s    %5d (%5.1f%%)',
    ['Local...', SubTotal, 100.0*SubTotal/FTotal]);
  for Key in LocalKeys do
  begin
    Count := FDetails[Key];
    DebugLn('#  - %-12s %5d (%5.1f%%)',
      [IfThen(Key = 'United States of America', 'USA', Key),
      Count, 100.0*Count/FTotal]);
  end;

  // Write DX keys...
  SubTotal := 0;
  for Key in DxKeys do
    Inc(SubTotal, FDetails[Key]);
  DebugLn('# %-12s    %5d (%5.1f%%)',
    ['DX...', SubTotal, 100.0*SubTotal/FTotal]);
  for Key in DxKeys do
  begin
    Count := FDetails[Key];
    DebugLn('#  - %-12s %5d (%5.1f%%)',
      [FContinentNames[Key], Count, 100.0*Count/FTotal]);
  end;

  // print missing keys
  for Pair in FDetails do
  begin
    if not MatchText(Pair.Key, LocalKeys) and
       not MatchText(Pair.Key, DxKeys) then
      DebugLn('# ** %-12s %5d (%5.1f%%) missing',
        [Pair.Key, Pair.Value, 100.0*Pair.Value/FTotal]);
  end;
end;
{$endif}

// --- TArrl10m ---

constructor TArrl10m.Create;
begin
  inherited Create;
  Arrl10mCallList:= TObjectList<TArrl10mCallRec>.Create;
  Comparer := TComparer<TArrl10mCallRec>.Construct(TArrl10mCallRec.compareCall);

  FIsCallLocalLastCall := '';
  FIsCallLocalLastResult := False;
end;


destructor TArrl10m.Destroy;
begin
  FreeAndNil(Arrl10mCallList);
  inherited;
end;


// load call history file iff user's callsign has changed.
function TArrl10m.LoadCallHistory(const AUserCallsign: string) : boolean;
var
  Reader: TArrl10mContestFileReader;
  FileName: String;
  ConsumeCallRec: TRecordConsumer<TArrl10mCallRec>;
{$ifdef DEBUG}
  Report: TDistributionReport;
  dict: TDictionary<string,integer>;
  dxcc: TDxCCRec;
  R: TArrl10mCallRec;
{$endif}

begin
  Reader := TArrl10mContestFileReader.Create;
{$ifdef DEBUG}
  Report := TDistributionReport.Create(Self);;
  dict := TDictionary<string,integer>.Create;
{$endif}

  try
    Arrl10mCallList.Clear;
    FIsCallLocalLastCall := '';
    FIsCallLocalLastResult := False;

    FileName := 'arrl-10-2025.tsv';

    ConsumeCallRec := procedure(rec: TArrl10mCallRec)
      begin
{$ifdef DEBUG}
        if not gDXCCList.FindRec(dxcc, rec.Call) then
        begin
          rec.Free;
          Exit;
        end;
        Report.AddCall(rec.Call, dxcc);

        assert(not Dict.ContainsKey(rec.Call));
        Dict.Add(rec.Call, 0);
{$endif}

        Arrl10mCallList.Add(rec);
      end;

    Reader.ReadFile(TAppPaths.ContestDataFile(FileName), ConsumeCallRec);

    Arrl10mCallList.Sort(Self.Comparer);

    Result := True;

{$ifdef DEBUG}
    // Write Callsign Distribution Report
    Report.WriteReport;

    // check for callsigns that did not end up in the calllist
    for R in Self.Arrl10mCallList do
    begin
      if not dict.ContainsKey(R.Call) then
        DebugLn('"%s" not in TDict!', [R.Call]);
    end;
{$endif}

  finally
    Reader.Free;
{$ifdef DEBUG}
    Report.Free;
    dict.Free;
{$endif}
  end;
end;


function TArrl10m.GetCallHistoryCount: Integer;
begin
  Result := Self.Arrl10mCallList.Count;
end;


{
  OnSetMyCall is overriden for ARRL 10M Contest to determine whether user's
  callsign is within US/CA/Mexico/Alaska/Hawaii. In other words, is the user's
  station within the home region of this contest?

  Sets Self.HomeCallIsLocal. Used by GetExchangeTypes() to
  determine sent messages types:
  - (US/CA/XE/AK/HI sends State/Province
  - DX sends Serial NR
  - Maritime Mobile sends ITU Region
}
function TArrl10m.OnSetMyCall(const AUserCallsign : string;
  out err : string) : boolean;
var
  dxcc: TDxCCRec;
begin
  Result:= True;
  err:= '';

  // select calls based on location of user's station (US/CA/Xe/AK/HI send
  // State; DX Sends serial #; Maritime mobile sends ITU Region)
  if gDxCCList.FindRec(dxcc, AUserCallsign) then
    // Is home call local to contest (i.e. a W/VE/XE/AK/HI Station)?
    HomeCallIsLocal := IsEntityLocalToContest(dxcc)
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


{
  ValidateMyExchange will validate user-entered exchange and
  return Exch1 and Exch2 tokens. These tokens will be stored to send
  as my transmissions.

  Syntax: RST <State>|<Province>|[NR | #]|[123]
  Entered Exchange: RST <state|province|#|ITU>
  where state=US/XE state, VE province; DX sends NR; /MM sends ITU (1,2.3).
  where RST = 599 | 5NN
  Sent Exchange: 5NN OR

  Entered: RST <state|province|([0-9]*|#)|ITU>
  Returned: Exch1 = 'RST', Exch2 = <state> | <province> | <[123|#]> | <ITU Zone>'
}
function TArrl10m.ValidateMyExchange(const AExchange: string;
  ATokens: TStringList;
  out AExchError: string): boolean;
const
  // Syntax: RST <State>|<NR>|<ITU Region>
  Regexpr: array[0..2] of string = (
    ' *(?P<exch1>[1-5E][1-9N]{2}) +(?P<exch2>([A-Z]{2,3}))',
    ' *(?P<exch1>[1-5E][1-9N]{2}) +(?P<exch2>([0-9TAN]+)|(#))',
    ' *(?P<exch1>[1-5E][1-9N]{2}) +(?P<exch2>([123]))'
  );
  const ErrStrs: array[0..2] of string = (
    '''RST <State|Province>'' (e.g. 5NN OR)',
    '''RST <#|123>'' (e.g. 5NN #)',
    '''RST <ITU Region>'' (e.g. 5NN 2)'
  );
var
  reg: TPerlRegEx;
  Exch1, Exch2: string;
  SubType: Integer;
begin
  reg := TPerlRegEx.Create();
  try
    if Self.Me.SentExchTypes.Exch2AsITURegion then
      SubType := 2
    else if Self.Me.SentExchTypes.Exch2AsSerialNR then
      SubType := 1
    else
      SubType := 0;

    // parse into two strings [Exch1, Exch2]
    reg.Subject := UTF8Encode(AExchange);
    reg.RegEx	:= UTF8Encode('^' + Regexpr[SubType] + '$');
    Result := Reg.Match;
    if Result then
      begin
        Exch1 := String(Reg.Groups[Reg.NamedGroup('exch1')]);
        Exch2 := String(Reg.Groups[Reg.NamedGroup('exch2')]);
        ATokens.Clear;
        ATokens.Add(Exch1);
        ATokens.Add(Exch2);
      end
    else
      AExchError := Format('Invalid exchange: ''%s'' - expecting %s.',
                  [AExchange, ErrStrs[SubType]]);

  finally
    reg.Free;
  end;
end;


{
  returns exchange types for this contest and sending station.

  For the ARRL 10M Contest, the exchange being sent is determined by the
  sending station's callsign:
  - US/CA/XE/AK/HI stations        - send RST and State
  - DX Stations                    - send serial number
  - Maritime mobile stations (/MM) - send ITU Zone
  - This function is called for each new contact to determine whether the
    calling station is a DX contact (outside of local contest). If so,
    the Non-US/CA/XE/AK/HI station will send serial number or ITU Region and
    the rule checking will adapt accordingly.
}
function TArrl10m.GetExchangeTypes(
  const AStationKind : TStationKind;
  const ARequestedMsgType : TRequestedMsgType;
  const AStationCallsign : String;
  const ARemoteCallsign : String) : TExchTypes;
begin
  if ARequestedMsgType = mtSendMsg then
    Result := GetExchangeTypesByCall(AStationCallsign)
  else
    Result := GetExchangeTypesByCall(ARemoteCallsign);
end;


{
  exchange type being sent is determined by the sending station's location
}
function TArrl10m.GetExchangeTypesByCall(const ACallsign : String) : TExchTypes;
begin
  Result.Exch1 := ActiveContest.ExchType1;    // etRST
  Result.Exch2 := ActiveContest.ExchType2;    // etGenericField
  assert(Result.Exch2AsITURegion = False);
  assert(Result.Exch2AsSerialNR = False);

  if ACallsign.IsEmpty then Exit;

  if ACallsign.EndsWith('/MM') then       // sends ITU Region (1, 2 or 3)
    Result.Exch2AsITURegion := True
  else if IsCallLocalToContest(ACallsign) then
    Result.Exch2AsSerialNR := False   // sends state|province|ITU
  else
    Result.Exch2AsSerialNR := True;   // DX stations send serial NR
end;


function TArrl10m.PickStation(): integer;
begin
  if Arrl10mCallList.Count = 0 then
    raise Exception.Create(
      'Internal error: callsign array is empty; please restart');

  Result := random(Arrl10mCallList.Count)
end;


procedure TArrl10m.DropStation(id : integer);
begin
  Arrl10mCallList.Delete(id)
end;


function TArrl10m.FindCallRec(out dxrec: TArrl10mCallRec; const ACall: string): Boolean;
var
  rec: TArrl10mCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TArrl10mCallRec.Create();
  rec.Call := ACall;
  dxrec:= nil;
  try
    if Arrl10mCallList.BinarySearch(rec, index, Comparer) then
      dxrec:= Arrl10mCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= dxrec <> nil;
end;


// return status bar information string from call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from Call History File> [- Entity/Continent]'
function TArrl10m.GetStationInfo(const ACallsign: string) : string;
var
  rec : TArrl10mCallRec;
  dxccrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  rec := nil;
  dxccrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if FindCallRec(rec, ACallsign) then
    begin
    userText:= rec.UserText;

    // include caller's Continent/Entity
    if gDXCCList.FindRec(dxccrec, ACallsign) then
      dxEntity:= dxccrec.Continent + '/' + dxccrec.Entity;
    end;

  if (userText <> '') or (dxEntity <> '') then
    begin
    result:= ACallsign;
    if userText <> '' then
      result:= result + ' - ' + userText
    else if dxEntity <> '' then
      result:= result + ' - ' + dxEntity;
    end;
end;


{
  Return whether Station is within the US/CA/XE/AK/HI Contest region.
}
function TArrl10m.IsEntityLocalToContest(const dxcc: TDxccRec) : boolean;
begin
  Result := TArrl10mPolicy.IsEntityLocalToContest(dxcc);
end;


{
  Return whether Station is within the US/CA/XE/AK/HI Contest region.
}
function TArrl10m.IsCallLocalToContest(const ACallsign: string) : boolean;
begin
  if FIsCallLocalLastCall <> ACallsign then
    begin
      FIsCallLocalLastCall := ACallsign;
      FIsCallLocalLastResult := TArrl10mPolicy.IsCallLocalToContest(ACallsign);
    end;
  Result := FIsCallLocalLastResult;
end;


function TArrl10m.getCall(id:integer): string;     // returns station callsign
begin
  result := Arrl10mCallList.Items[id].Call;
end;


procedure TArrl10m.GetExchange(id : integer; station : TDxStation);
begin
  station.Exch1 := getExch1(id);
  if station.MyCall.EndsWith('/MM') then
    station.Exch2 := getExch2(id)   // ITU Region
  else if station.SentExchTypes.Exch2AsSerialNR then
    begin
      station.NR := Self.GetRandomSerialNR;
      station.Exch2 := IntToStr(station.NR);
    end
  else
    station.Exch2 := getExch2(id);
  station.UserText := getUserText(id);
end;

function TArrl10m.getExch1(id:integer): string;    // returns default RST value
begin
  result := '599';
end;


function TArrl10m.getExch2(id:integer): string;    // returns State/Province
begin
  result := Arrl10mCallList.Items[id].State;
end;


function TArrl10m.getUserText(id:integer): string; // returns optional club name
begin
  result := Arrl10mCallList.Items[id].UserText;
end;


{
  Extract multiplier string for ARRL 10M Contest.

  ARRL 10M Rules state:
  - Each CW contact counts for four (4) QSO points.
  - To calculate your final score, multiply the total QSO points by the number
    of US states (plus the District of Columbia), Canadian Provinces and
    Territories, Mexican states, DXCC entities, and ITU regions you contacted.

  Sets contest-specific Qso.Points for this QSO.

  Return US state, CA province/territories, Mexican States, DXCC entity names,
  or ITU region string.
}
function TArrl10m.ExtractMultiplier(Qso: PQso) : string;
var
  dxrec: TDXCCRec;
begin
  dxrec:= nil;
  Result:= '';

  Qso^.Points := 4;
  if Qso^.Call.EndsWith('/MM') then
    Result := IntToStr(StrToIntDef(Qso^.Exch2,1))
  else if gDXCCList.FindRec(dxrec, Qso^.Call) then
    begin
      if IsEntityLocalToContest(dxrec) then
        Result := Qso^.Exch2
      else
        Result := dxrec.Entity;
    end
  else
    Result := Qso^.Exch2;
end;


function TArrl10m.IsNum(Num: String): Boolean;
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



