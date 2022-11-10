unit CQWW;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Contest, DxStn;

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

public
  constructor Create;
  destructor Destroy; override;
  procedure LoadCallHistory(const AUserCallsign : string); override;

  function PickStation(): integer; override;
  function GetCall(id:integer): string; override;     // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

  function getExch1(id:integer): string;    // returns RST (e.g. 5NN)
  function getExch2(id:integer): string;    // returns section info (e.g. 3)
  function getZone(id:integer): string;     // returns CQZone (e.g. 3)
  function FindCallRec(out fdrec: TCqWwCallRec; const ACall: string): Boolean;
  function GetStationInfo(const ACallsign: string) : string; override;
  function IsNum(Num: String): Boolean;
end;

implementation

uses
  SysUtils, Classes, log, ARRL;

procedure TCqWw.LoadCallHistory(const AUserCallsign : string);
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TCqWwCallRec;
begin
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;

  try
    CqWwCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'CQWWCW.TXT');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then begin
          if (tl.Strings[0] = '!!Order!!') then continue;

          rec := TCqWwCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.CQZone := UpperCase(tl.Strings[1]);
          if (tl.Count >= 3) then rec.UserText := tl.Strings[2];
          if rec.Call='' then continue;
          if rec.CQZone='' then continue;
          if IsNum(rec.CQZone) = False then continue;

          CqWwCallList.Add(rec);
      end;
    end;

  finally
    slst.Free;
    tl.Free;
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


function TCqWw.getCall(id : integer): string;     // returns station callsign
begin
  result := CqWwCallList.Items[id].Call;
end;


procedure TCqWw.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch2 := getExch2(station.Operid);
  station.NR := StrToInt(getExch2(station.Operid));
end;



function TCqWw.getExch1(id:integer): string;    // returns RST (e.g. 5NN)
begin
  result := '5NN';
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



