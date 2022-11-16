unit NAQP;

interface

uses
  Generics.Defaults, Generics.Collections, Contest, DxStn;

type
  TNaQpCallRec = class
  public
    Call: string;     // call sign
    Name: string;     // operator name (e.g. MIKE)
    State: string;    // STATE/PROV (e.g. OR)
    UserText: string; // optional user text
    function GetString: string; // returns <name> <state> (e.g. MIKE OR)
    class function compareCall(const left, right: TNaQpCallRec) : integer; static;
  end;

TNcjNaQp = class(TContest)
private
  NaQpCallList: TList<TNaQpCallRec>;
  Comparer: IComparer<TNaQpCallRec>;

public
  constructor Create;
  destructor Destroy; override;
  function LoadCallHistory(const AUserCallsign : string) : boolean; override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id : integer): string; override; // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

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
  StrUtils, SysUtils, Classes, Contnrs, PerlRegEx, pcre,
  log, ARRL;

function TNcjNaQp.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TNaQpCallRec;
begin
  // reload call history if empty
  Result := NaQpCallList.Count <> 0;
  if Result then
    Exit;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;

  try
    NaQpCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'NAQPCW.TXT');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then begin
          if (tl.Strings[0] = '!!Order!!') then continue;
          if (AnsiLeftStr(tl.Strings[0], 1) = '#') then continue;

          rec := TNaQpCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.Name := UpperCase(tl.Strings[1]);
          rec.State := UpperCase(tl.Strings[2]);
          rec.UserText := IfThen(tl.Count >= 4, Trim(tl.Strings[3]), '');
          if rec.Call='' then continue;
          if rec.Name='' then continue;
          if rec.State='' then continue;
          if length(rec.Name) > 12 then continue;

          NaQpCallList.Add(rec);
      end;
    end;

    // retain user's callsign after successful load
    SetUserCallsign(AUserCallsign);
    Result := True;

  finally
    slst.Free;
    tl.Free;
  end;
end;


constructor TNcjNaQp.Create;
begin
    inherited Create;
    NaQpCallList := TList<TNaQpCallRec>.Create;
    Comparer := TComparer<TNaQpCallRec>.Construct(TNaQpCallRec.compareCall);
end;


destructor TNcjNaQp.Destroy;
begin
  FreeAndNil(NaQpCallList);
  inherited;
end;


function TNcjNaQp.PickStation(): integer;
begin
     result := random(NaQpCallList.Count);
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
// Format:  '<call> - <user text from fdCallHistoryFile> [- Entity/Continent]'
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

    // if caller is DX station, include its Continent/Entity
    if (rec.State = 'DX') and
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


function TNcjNaQp.GetCall(id : integer): string;     // returns station callsign
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

function TNcjNaQp.getExch1(id:integer): string;    // returns station info (e.g. MIKE)
begin
  result := NaQpCallList.Items[id].Name;
end;


function TNcjNaQp.getExch2(id:integer): string;    // returns section info (e.g. OR)
begin
  result := NaQpCallList.Items[id].State;
end;


function TNcjNaQp.getName(id:integer): string;  // returns Name (e.g. MIKE)
begin
  result := NaQpCallList.Items[id].Name;
end;


function TNcjNaQp.getState(id:integer): string;  // returns state (e.g. OR)
begin
  result := NaQpCallList.Items[id].State;
end;


function TNcjNaQp.getUserText(id:integer): string; // returns optional UserText
begin
  result := NaQpCallList.Items[id].UserText;
end;


{ TODO - this can refactor into a common base class }
class function TNaQpCallRec.compareCall(const left, right: TNaQpCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TNaQpCallRec.GetString: string; // returns MIKE OR
begin
  Result := Format(' - %s %s', [Name, State]);
end;


end.



