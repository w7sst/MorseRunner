unit ARRLDX;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Classes, DualExchContest, DxStn,
  ArrlDx.Types,
  Log;

type
  TArrlDx = class(TDualExchContest)
  private
    ArrlDxCallList: TObjectList<TArrlDxCallRec>;
    Comparer: IComparer<TArrlDxCallRec>;

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;
    function OnSetMyCall(const AUserCallsign : string; out err : string) : boolean; override;
    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id:integer): string; override;  // returns station callsign
    procedure GetExchange(id : integer; out station : TDxStation); override;

    function getExch1(id:integer): string;    // returns default RST value
    function getExch2(id:integer): string;    // returns State/Prov (US/Canada) or Power (DX)
    function getUserText(id:integer): string; // returns optional club name
    function IsNum(Num: String): Boolean;
    function FindCallRec(out dxrec: TArrlDxCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign : string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;


implementation

uses
  SysUtils, DXCC, CallLst,
  ExchFields,
  AppPaths,
  Ini, Main;


constructor TArrlDx.Create;
begin
  inherited Create(etRST, etStateProv,  // US/CA station exchange
                   etRST, etPower);     // DX station exchange
  ArrlDxCallList:= TObjectList<TArrlDxCallRec>.Create;
  Comparer := TComparer<TArrlDxCallRec>.Construct(TArrlDxCallRec.compareCall);
end;


destructor TArrlDx.Destroy;
begin
  FreeAndNil(ArrlDxCallList);
  inherited;
end;


// load call history file iff user's callsign has changed.
// for US/CA calls, load DX callsigns; for DX calls, load US/CA calls.
function TArrlDx.LoadCallHistory(const AUserCallsign: string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TArrlDxCallRec;
  CallInx, StateInx, PowerInx, UserTextInx: integer;

  { Find the named string. Throw an exception if required field is missing. }
  function FindIndex(const AFieldName: String; ARequiredField: Boolean) : Integer;
  begin
    Result := tl.IndexOf(AFieldName);
    assert((Result >= 0) or not ARequiredField);
    if ARequiredField and (Result = -1) then
      raise Exception.CreateFmt(
        'Invalid call history file: ''!!Order!!'' record is missing required ''%s'' field. Line %d, File "%s"',
        [AFieldName, i+1, ParamStr(1) + 'ARRLDXCW_USDX.txt']);
  end;

  { Returns the field value for the specified column index.
    If the index is invalid or the column is missing, an empty string is returned.
    Leading and trailing whitespace is removed.
  }
  function GetValue(ColumnInx: Integer): String;
  begin
    if Cardinal(ColumnInx) < Cardinal(tl.Count) then
      Result := tl[ColumnInx].Trim
    else
      Result := '';
  end;

begin
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;
  CallInx := -1;
  StateInx := -1;
  PowerInx := -1;
  UserTextInx := -1;

  try
    ArrlDxCallList.Clear;

    slst.LoadFromFile(TAppPaths.ContestDataFile('ARRLDXCW_USDX.txt'));

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      // skip empty or comment lines
      if (tl.Count = 0) or tl[0].TrimLeft.StartsWith('#') then continue;

      if (tl[0] = '!!Order!!') then
        begin
          // !!Order!!,Call,Name,State,Power,UserText,  // Dx Stations
          // !!Order!!,Call,Name,State,                 // US Stations
          tl.Delete(0); // shifts others down by one

          // DX sends Call,Power
          // W/VE sends Call,State
          CallInx := FindIndex('Call', True);
          StateInx := FindIndex('State', False);
          PowerInx := FindIndex('Power', False);
          UserTextInx := FindIndex('UserText', False);

          continue;
        end;

      if rec = nil then
        rec := TArrlDxCallRec.Create;

      rec.Call := GetValue(CallInx).ToUpper;
      rec.State := GetValue(StateInx).ToUpper;
      rec.Power := GetValue(PowerInx).ToUpper;
      rec.UserText := GetValue(UserTextInx);

      if rec.Call.IsEmpty then continue;

      // W/VE stations work only DX stations (those with non-empty Power field);
      // DX Stations work only W/VE stations (those with non-empty State field)
      if (    HomeCallIsLocal and not rec.Power.IsEmpty) or
         (not HomeCallIsLocal and not rec.State.IsEmpty) then
        begin
          ArrlDxCallList.Add(rec);
          rec := nil;
        end;
    end;

    Result := True;

  finally
    if rec <> nil then rec.Free;
    slst.Free;
    tl.Free;

  end;
end;


{
  OnSetMyCall is overriden for ARRL DX Contest to determine whether user's
  callsign is within US/CA. In other words, is the user's station within the
  home region of this contest?

  Sets TDualExchContest.HomeCallIsLocal. Used by GetExchangeTypes() to
  determine sent messages types (US/CA send State/Province; DX sends Power).
}
function TArrlDx.OnSetMyCall(const AUserCallsign : string;
  out err : string) : boolean;
var
  dxcc: TDxCCRec;
begin
  Result:= True;
  err:= '';

  // select calls based on location of user's station (US/CA work only DX)
  if gDxCCList.FindRec(dxcc, AUserCallsign) then
    // Is home call local to contest (i.e. a W/VE Station)?
    HomeCallIsLocal := dxcc.Entity.Equals('United States of America') or
                       dxcc.Entity.Equals('Canada')
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
                         AUserCallsign.StartsWith('VE');
      Result := False;
    end;

  // call baseclass to update Me.MyCall and Me.SentExchTypes
  if not inherited OnSetMyCall(AUserCallsign, err) then
    Result:= False;
end;


function TArrlDx.PickStation(): integer;
var
  dxcc: TDxCCRec;
begin
  result := random(ArrlDxCallList.Count);
  while (ArrlDxCallList.Count > 1) do
    begin
      // Keep stations that have a valid DXCC entry
      if gDXCCList.FindRec(dxcc, ArrlDxCallList[result].Call) then
        break;

      // drop this station and try again
      DropStation(result);
      result := random(ArrlDxCallList.Count);
    end;
end;


procedure TArrlDx.DropStation(id : integer);
begin
  ArrlDxCallList.Delete(id)
end;


function TArrlDx.FindCallRec(out dxrec: TArrlDxCallRec; const ACall: string): Boolean;
var
  rec: TArrlDxCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TArrlDxCallRec.Create();
  rec.Call := ACall;
  dxrec:= nil;
  try
    if ArrlDxCallList.BinarySearch(rec, index, Comparer) then
      dxrec:= ArrlDxCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= dxrec <> nil;
end;


// return status bar information string from call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from ArrlDxCallHistoryFile> [- Entity/Continent]'
function TArrlDx.GetStationInfo(const ACallsign: string) : string;
var
  dxrec : TArrlDxCallRec;
  dxccrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  dxrec := nil;
  dxccrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if FindCallRec(dxrec, ACallsign) then
    begin
    userText:= dxrec.UserText;

    // if caller is DX station, include its Continent/Entity
    if Self.HomeCallIsLocal and gDXCCList.FindRec(dxccrec, ACallsign) then
      dxEntity:= dxccrec.Continent + '/' + dxccrec.Entity;
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


function TArrlDx.getCall(id:integer): string;     // returns station callsign
begin
  result := ArrlDxCallList.Items[id].Call;
end;


procedure TArrlDx.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(id);
  station.Exch2 := getExch2(id);
  station.UserText := getUserText(id);
end;

function TArrlDx.getExch1(id:integer): string;    // returns default RST value
begin
  result := '599';
end;


function TArrlDx.getExch2(id:integer): string;    // returns State/Prov (US/Canada) or Power (DX)
begin
  result := ArrlDxCallList.Items[id].State +
            ArrlDxCallList.Items[id].Power;
end;


function TArrlDx.getUserText(id:integer): string; // returns optional club name
begin
  result := ArrlDxCallList.Items[id].UserText;
end;


{
  Extract multiplier string for ARRL DX Contest.

  ARRL DX Rules state: "Multiply total QSO points by the number of DXCC
  entities (W/VE stations) or states and provinces (DX stations) contacted
  to get your final score."

  Also sets contest-specific Qso.Points for this QSO.

  return either DXCC Entity string or US state or CA province.
}
function TArrlDx.ExtractMultiplier(Qso: PQso) : string;
var
  dxrec: TDXCCRec;
begin
  dxrec:= nil;
  Result:= '';

  Qso^.Points := 3;
  if Self.HomeCallIsLocal then
    begin
      if gDXCCList.FindRec(dxrec, Qso^.Call) then
        Result:= dxrec.Entity;
    end
  else
    Result:= Qso.Exch2;
end;


function TArrlDx.IsNum(Num: String): Boolean;
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



