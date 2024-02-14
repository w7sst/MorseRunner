unit CQWW;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Contest, DxStn, Log;

type
  TCqWwCallRec = class
  public
    Call: string;     // call sign
    CQZone: string;   // CQ-Zone
    UserText: string; // optional UserText (displayed in status bar)
    function GetString: string; // returns CQ-Zone N (e.g. 'CQ-Zone 3')
    class function compareCall(const left, right: TCqWwCallRec) : integer; static;
  end;

TCqWw = class(TContest)
private
  CqWwCallList: TObjectList<TCqWwCallRec>;
  Comparer: IComparer<TCqWwCallRec>;
  MyContinent : string;
  MyEntity : string;

public
  constructor Create;
  destructor Destroy; override;
  function LoadCallHistory(const AUserCallsign : string) : Boolean; override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id:integer): string; override;     // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

  function getExch1(id:integer): string;    // returns RST (e.g. 5NN)
  function getExch2(id:integer): string;    // returns section info (e.g. 3)
  function getZone(id:integer): string;     // returns CQZone (e.g. 3)
  function FindCallRec(out fdrec: TCqWwCallRec; const ACall: string): Boolean;
  function GetStationInfo(const ACallsign: string) : string; override;
  function ExtractMultiplier(Qso: PQso) : string; override;
  function IsNum(Num: String): Boolean;
end;

implementation

uses
  SysUtils, Classes, ARRL;

function TCqWw.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TCqWwCallRec;
  dxrec : TDXCCRec;
begin
  // reload call history if empty
  Result := CqWwCallList.Count <> 0;
  if Result then
    Exit;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;

  try
    CqWwCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'CQWWCW.TXT');

    for i:= 0 to slst.Count-1 do begin
      if (slst.Strings[i].StartsWith('!!Order!!')) then continue;
      if (slst.Strings[i].StartsWith('#')) then continue;

      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then begin
          if rec = nil then
            rec := TCqWwCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.CQZone := UpperCase(tl.Strings[1]);
          rec.UserText := '';
          if tl.Count >= 3 then rec.UserText := Trim(tl.Strings[2]);
          if rec.Call='' then continue;
          if rec.CQZone='' then continue;
          if IsNum(rec.CQZone) = False then continue;
//{$define CutNumberTesting}
{$ifdef CutNumberTesting}
          case rec.CQZone.ToInteger of
          9,10,19,20,29,30:
            ;
          else
            continue;
          end;
{$endif}

          CqWwCallList.Add(rec);
          rec := nil;
      end;
    end;

    // load MyContinent and MyEntity - used by ExtractMultiplier
    if gDXCCList.FindRec(dxrec, AUserCallsign) then
      begin
        MyContinent := dxRec.Continent;
        MyEntity := dxRec.Entity;
      end;

    Result := True;

  finally
    slst.Free;
    tl.Free;
    if rec <> nil then rec.Free;
  end;
end;


constructor TCqWw.Create;
begin
    inherited Create;
    CqWwCallList := TObjectList<TCqWwCallRec>.Create;
    Comparer := TComparer<TCqWwCallRec>.Construct(TCqWwCallRec.compareCall);
end;


destructor TCqWw.Destroy;
begin
  FreeAndNil(CqWwCallList);
  inherited;
end;


function TCqWw.PickStation(): integer;
begin
     result := random(CqWwCallList.Count);
end;


procedure TCqWw.DropStation(id : integer);
begin
  assert(id < CqWwCallList.Count);
  CqWwCallList.Delete(id);
end;


function TCqWw.FindCallRec(out fdrec: TCqWwCallRec; const ACall: string): Boolean;
var
  rec: TCqWwCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TCqWwCallRec.Create();
  rec.Call := ACall;
  fdrec:= nil;
  try
    if CqWwCallList.BinarySearch(rec, index, Comparer) then
      fdrec:= CqWwCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= fdrec <> nil;
end;


// return status bar information string from CQWW call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from fdCallHistoryFile> [- Entity/Continent]'
function TCqWw.GetStationInfo(const ACallsign: string) : string;
var
  fdrec : TCqWwCallRec;
  dxrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  fdrec := nil;
  dxrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if Self.FindCallRec(fdrec, ACallsign) then
    begin
    userText:= fdrec.UserText;

    // find caller's Continent/Entity
    if gDXCCList.FindRec(dxrec, ACallsign) then
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
  For CQ WW, the multiplier is the sum of zone and country multipliers.
  Return a composite string of the form: 'ZN-<CqZone>;<country>'

  Also sets contest-specific Qso.Points for this QSO.
  QSO points are based on the location of the station worked.
  - Contacts between stations on different continents count three (3) points.
  - Contacts between stations on the same continent but in different countries
    count one (1) point. Exception: Contacts between stations in different
    countries within the North American boundaries count two (2) points.
  - Contacts between stations in the same country have zero (0) QSO point value,
    but count for zone and country multiplier credit.
}
function TCqWw.ExtractMultiplier(Qso: PQso) : string;
var
  dxrec : TDXCCRec;
begin
  dxrec := nil;

  // first multiplier is CQ-Zone
  Result := Format('ZN-%d', [Qso^.Nr]);

  // Maritime-mobile stations count only as a Zone multiplier.
  if Qso^.Call.EndsWith('/MM') then
    begin
      Qso^.Points := 0;
      Exit;
    end;

  // the code below (checking for Alaska and Hawaii) assumes USA Entity
  // string is 'United States of America'.
  assert(gDXCCList.FindRec(dxrec, 'W7SST') and
         dxrec.Entity.Equals('United States of America'));

  // second multiplier is unique country names
  if gDXCCList.FindRec(dxrec, Qso^.Call) then
    begin
      // Alaska and Hawaii are part of 50 US states
      if dxrec.Entity.Equals('Alaska') or
         dxrec.Entity.Equals('Hawaii') then
        Result := Format('%s;%s', [Result, 'United States of America'])
      else
        Result := Format('%s;%s', [Result, dxrec.Entity]);

      // QSO points are based on the location of the station worked.
      if dxrec.Continent <> MyContinent then
        Qso^.Points := 3
      else if dxrec.Entity = MyEntity then
        Qso^.Points := 0
      else if dxrec.Continent = 'NA' then
        Qso^.Points := 2
      else
        Qso^.Points := 1;
    end;
end;


function TCqWw.getCall(id : integer): string;     // returns station callsign
begin
  result := CqWwCallList.Items[id].Call;
end;


procedure TCqWw.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);  // RST
  station.Exch2 := getExch2(station.Operid);
  station.NR := StrToInt(station.Exch2);
end;



function TCqWw.getExch1(id:integer): string;    // returns RST (e.g. 599)
begin
  result := '599';
end;


function TCqWw.getExch2(id:integer): string;    // returns section info (e.g. 3)
begin
  result := CqWwCallList.Items[id].CQZone;
end;


function TCqWw.getZone(id:integer): string;     // returns CQZone (e.g. 3)
begin
  result := CqWwCallList.Items[id].CQZone;
end;


class function TCqWwCallRec.compareCall(const left, right: TCqWwCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TCqWwCallRec.GetString: string; // returns CQ-Zone N (e.g. 'CQ-Zone 3')
begin
  Result := Format(' - CQ-Zone %s', [CQZone]);
end;


function TCqWw.IsNum(Num: String): Boolean;
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



