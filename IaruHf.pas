unit IARUHF;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Classes, DualExchContest, DxStn,
  Log;

type
  TIaruHfCallRec = class
  public
    Call: string;     // call sign
    Sect: string;     // IARU Society or ITU Zone
    UserText: string; // user-defined string
    function GetString: string; // returns (<society> | <itu-zone>) [user-text]
    class function compareCall(const left, right: TIaruHfCallRec) : integer; static;
  end;

  TIaruHf = class(TDualExchContest)
  private
    IaruHfCallList: TObjectList<TIaruHfCallRec>;
    Comparer: IComparer<TIaruHfCallRec>;
    MyContinent: string;  // set by OnSetMyCall

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
    function getExch2(id:integer): string;    // returns Society (Headquarters, etc) or ITU Zone (others)
    function getUserText(id:integer): string; // returns optional UserText
    function IsNum(Num: String): Boolean;
    function FindCallRec(out dxrec: TIaruHfCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign : string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;


implementation

uses
  SysUtils, PerlRegEx, pcre, ARRL, CallLst, Contest,
  Ini, Main;


constructor TIaruHf.Create;
begin
  inherited Create(etRST, etGenericField,   // IARU Society (Hdgtrs, AC, EC)
                   etRST, etGenericField);  // regular station's exchange
  IaruHfCallList:= TObjectList<TIaruHfCallRec>.Create;
  Comparer := TComparer<TIaruHfCallRec>.Construct(TIaruHfCallRec.compareCall);
end;


destructor TIaruHf.Destroy;
begin
  FreeAndNil(IaruHfCallList);
  inherited;
end;


{
  Load the call history file.
  While loading, check for duplicate callsign due to multiple sections
  being added to the history file.

  Note: the IARU_HF.txt file is created in the following manner:
  1) K6OK created a history file by combining several public logs from
     different regions around the world.
  2) W7SST appended the latest IARU HF Call History file as downloaded
     from N1MM call history files. The idea was to add as many Society
     callsigns as we can to get a slightly higher percentage of Society
     vs. total calls in the history file.
}
function TIaruHf.LoadCallHistory(const AUserCallsign: string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  dupList: TStringList;
  i, Index: integer;
  rec: TIaruHfCallRec;
  dxcc: TDxCCRec;
  CallInx, SectInx, UserTextInx: integer;
begin
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  dupList:= TStringList.Create(dupIgnore, {Sorted} True, {CaseSensitive} False);
  CallInx := -1;
  SectInx := -1;
  UserTextInx := -1;
  rec := nil;

  try
    IaruHfCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'IARU_HF.txt');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if tl.Strings[0].StartsWith('#') or (tl.Count < 3) then continue;
      if (tl.Strings[0] = '!!Order!!') then
        begin
          // !!Order!!,Call,Sect,UserText,
          tl.Delete(0); // shifts others down by one
          CallInx := tl.IndexOf('Call');
          SectInx := tl.IndexOf('Sect');
          UserTextInx := tl.IndexOf('UserText');
          assert(CallInx <> -1);
          assert(SectInx <> -1);
          assert(UserTextInx <> -1);
          continue;
        end;

      if rec = nil then
        rec := TIaruHfCallRec.Create;

      // Using .Trim() to remove unexpected spaces in some records
      rec.Call := UpperCase(tl.Strings[CallInx].Trim);
      rec.Sect := UpperCase(tl.Strings[SectInx].Trim);
      if tl.Count > UserTextInx then
        rec.UserText := tl.Strings[UserTextInx].Trim
      else
        rec.UserText := '';

      if rec.Call.IsEmpty then continue;
      if rec.Sect.IsEmpty then continue;

      // eliminate duplicates
      if dupList.Find(rec.Call, Index) then continue;
      dupList.Add(rec.Call);

      // only include calls with useable DXCC lookup
      if gDxCCList.FindRec(dxcc, AUserCallsign) then
        begin
          IaruHfCallList.Add(rec);
          rec := nil;
        end;
    end;

    // do a final sort incase of multiple file sections
    IaruHfCallList.Sort(Comparer);

    Result := True;

  finally
    if rec <> nil then rec.Free;
    slst.Free;
    tl.Free;
    dupList.Free;
  end;
end;


{
  OnSetMyCall is overriden for IARU HF Contest to determine which exchange
  will be sent by this user.

  Sets TDualExchContest.HomeCallIsLocal. Used by GetExchangeTypes() to
  determine sent messages types (regular stations send ITU-Zone,
  IARU Headquarters send Headquarter abbreviations).
}
function TIaruHf.OnSetMyCall(const AUserCallsign : string;
  out err : string) : boolean;
var
  dxcc: TDxCCRec;
begin
  Result:= True;
  err:= '';

  // exchange is based on user's ITU Zone (numeric zone or IATU Headquarter abbreviations
  if gDxCCList.FindRec(dxcc, AUserCallsign) then
    begin
      // numeric Sect value is regular Itu-Zone
      HomeCallIsLocal := IsNum(dxcc.Entity);
      MyContinent := dxcc.Continent;
    end
  else
    begin
      // report an error
      err := Format('Error: ''%s'' is not recognized as a valid DXCC callsign.',
        [AUserCallsign]);

      // for the error case, treat as regular station.
      HomeCallIsLocal := true;
      Result := False;
    end;

  // call baseclass to update Me.MyCall and Me.SentExchTypes
  if not inherited OnSetMyCall(AUserCallsign, err) then
    Result:= False;
end;


function TIaruHf.PickStation(): integer;
begin
     result := random(IaruHfCallList.Count);
end;


procedure TIaruHf.DropStation(id : integer);
begin
  IaruHfCallList.Delete(id)
end;


function TIaruHf.FindCallRec(out dxrec: TIaruHfCallRec; const ACall: string): Boolean;
var
  rec: TIaruHfCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TIaruHfCallRec.Create();
  rec.Call := ACall;
  dxrec:= nil;
  try
    if IaruHfCallList.BinarySearch(rec, index, Comparer) then
      dxrec:= IaruHfCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= dxrec <> nil;
end;


// return status bar information string from call history file.
// Format:  '<call> - <user text from ArrlDxCallHistoryFile> [- Entity/Continent]'
function TIaruHf.GetStationInfo(const ACallsign: string) : string;
var
  dxrec : TIaruHfCallRec;
  dxccrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  dxrec := nil;
  dxccrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  // find caller's optional UserText
  if FindCallRec(dxrec, ACallsign) then
    userText:= dxrec.UserText;

  // find caller's Continent/Entity
  if gDXCCList.FindRec(dxccrec, ACallsign) then
    dxEntity:= dxccrec.Continent + '/' +
      StringReplace(dxccrec.Entity, 'United States of America', 'USA', []);

  if (userText <> '') or (dxEntity <> '') then
    begin
    result:= ACallsign;
    if userText <> '' then
      result:= result + ' - ' + userText;
    if dxEntity <> '' then
      result:= result + ' - ' + dxEntity;
    end;
end;


function TIaruHf.getCall(id:integer): string;     // returns station callsign
begin
  result := IaruHfCallList.Items[id].Call;
end;


procedure TIaruHf.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(id);
  station.Exch2 := getExch2(id);
  station.UserText := getUserText(id);
end;

function TIaruHf.getExch1(id:integer): string;    // returns default RST value
begin
  result := '599';
end;


function TIaruHf.getExch2(id:integer): string;    // returns State/Prov (US/Canada) or Power (DX)
begin
  result := IaruHfCallList.Items[id].Sect;
end;


function TIaruHf.getUserText(id:integer): string; // returns optional club name
begin
  result := IaruHfCallList.Items[id].UserText;
end;


{
  Extract multiplier string for IARU HF Contest.

  IARU HF Rules state:
    "To calculate your final score, multiply the total QSO points by
    the number of ITU zones and official IARU stations as described
    in the Special Rules."

  Multipliers:
    - Each ITU zone once per band
    - Each IARU HQ and each IARU official once per band

  QSO Points:
    - 1 point per QSO with same zone or with HQ stations
    - 3 points per QSO with different zone on same continent
    - 5 points per QSO with different zone on different continent

  Sets contest-specific Qso.Points for this QSO.
  Returns either IARU Society abbreviation or ITU-Zone string.
}
function TIaruHf.ExtractMultiplier(Qso: PQso) : string;
var
  dxrec: TDXCCRec;
begin
  dxrec:= nil;
  Result:= '';

  // determine QSO Points
  // 1 point per QSO with same zone or with HQ stations
  // 3 points per QSO with different zone on same continent
  // 5 points per QSO with different zone on different continent

  if Qso^.Exch2.Equals(Tst.Me.Exch2) or   // with same Zone, or
     not IsNum(Qso^.Exch2) then           // with HQ society
    Qso^.Points := 1
  else if gDXCCList.FindRec(dxrec, Qso^.Call) then
    begin
      if dxrec.Continent = Self.MyContinent then
        Qso^.Points := 3
      else
        Qso^.Points := 5;
    end
  else
    Qso^.Points := 1;

  // return multiplier string
  Result := Qso^.Exch2;
end;


function TIaruHf.IsNum(Num: String): Boolean;
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


class function TIaruHfCallRec.compareCall(const left, right: TIaruHfCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TIaruHfCallRec.GetString: string; // returns <ITU Zone>|<IARU Society> [UserText]
begin
  Result := Format(' - %s', [Sect]);
  if UserText <> '' then
    Result := Result + ' ' + UserText;
end;


end.



