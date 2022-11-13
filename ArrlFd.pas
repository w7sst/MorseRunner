unit ARRLFD;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Contest, DxStn;

type
  TFdCallRec = class
  public
    Call: string;     // call sign
    StnClass: string; // station classification (e.g. 3A)
    Section: string;  // ARRL/RAC section (e.g. OR)
    UserText: string; // club name
    function GetString: string; // returns 3A OR [club name]
    class function compareCall(const left, right: TFdCallRec) : integer; static;
  end;

TArrlFieldDay = class(TContest)
private
  FdCallList: TObjectList<TFdCallRec>;
  Comparer: IComparer<TFdCallRec>;

public
  constructor Create;
  destructor Destroy; override;
  procedure LoadCallHistory(const AUserCallsign : string); override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id : integer): string; override; // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

  function getExch1(id:integer): string;    // returns station info (e.g. 3A)
  function getExch2(id:integer): string;    // returns section info (e.g. OR)
  function getClass(id:integer): string;    // returns station class (e.g. 3A)
  function getSection(id:integer): string;  // returns section (e.g. OR)
  function getUserText(id:integer): string; // returns optional club name
  //function IsNum(Num: String): Boolean;
  function FindCallRec(out fdrec: TFdCallRec; const ACall: string): Boolean;
  function GetStationInfo(const ACallsign: string) : string; override;
end;


implementation

uses
  SysUtils, Classes, Log, PerlRegEx, pcre, ARRL;

procedure TArrlFieldDay.LoadCallHistory(const AUserCallsign : string);
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TFdCallRec;
begin
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;

  try
    FdCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'FD_2022-004.TXT');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then begin
          if (tl.Strings[0] = '!!Order!!') then continue;

          rec := TFdCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.StnClass := UpperCase(tl.Strings[1]);
          rec.Section := UpperCase(tl.Strings[2]);
          if (tl.Count >= 4) then rec.UserText := tl.Strings[3];
          if rec.Call='' then continue;
          if rec.StnClass='' then continue;
          if rec.Section='' then continue;
          //if IsNum(rec.Number) = False then  continue;
          //if length(rec.Name) > 10 then continue;
          //if length(rec.Name) > 12 then continue;

          FdCallList.Add(rec);
      end;
    end;

  finally
    slst.Free;
    tl.Free;
  end;
end;


constructor TArrlFieldDay.Create;
begin
    inherited Create;
    FdCallList:= TObjectList<TFdCallRec>.Create;
    Comparer := TComparer<TFdCallRec>.Construct(TFdCallRec.compareCall);
end;


destructor TArrlFieldDay.Destroy;
begin
  FreeAndNil(FdCallList);
  inherited;
end;


function TArrlFieldDay.PickStation(): integer;
begin
     result := random(FdCallList.Count);
end;


procedure TArrlFieldDay.DropStation(id : integer);
begin
  assert(id < FdCallList.Count);
  FdCallList.Delete(id);
end;


function TArrlFieldDay.FindCallRec(out fdrec: TFdCallRec; const ACall: string): Boolean;
var
  rec: TFdCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TFdCallRec.Create();
  rec.Call := ACall;
  fdrec:= nil;
  try
    if FdCallList.BinarySearch(rec, index, Comparer) then
      fdrec:= FdCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= fdrec <> nil;
end;


// return status bar information string from field day call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from fdCallHistoryFile> [- Entity/Continent]'
function TArrlFieldDay.GetStationInfo(const ACallsign: string) : string;
var
  fdrec : TFdCallRec;
  dxrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  fdrec := nil;
  dxrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if FindCallRec(fdrec, ACallsign) then
    begin
    userText:= fdrec.UserText;

    // if caller is DX station, include its Continent/Entity
    if (fdrec.Section = 'DX') and
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


// returns station callsign
function TArrlFieldDay.GetCall(id : integer): string;
begin
  result := FdCallList.Items[id].Call;
end;


procedure TArrlFieldDay.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(id);
  station.Exch2 := getExch2(id);
  station.UserText := getUserText(id);
end;


function TArrlFieldDay.getExch1(id:integer): string;    // returns station info (e.g. 3A)
begin
  result := FdCallList.Items[id].StnClass;
end;


function TArrlFieldDay.getExch2(id:integer): string;    // returns section info (e.g. OR)
begin
  result := FdCallList.Items[id].Section;
end;


function TArrlFieldDay.getClass(id:integer): string;  // returns section (e.g. OR)
begin
  result := FdCallList.Items[id].StnClass;
end;


function TArrlFieldDay.getSection(id:integer): string;  // returns section (e.g. OR)
begin
  result := FdCallList.Items[id].Section;
end;


function TArrlFieldDay.getUserText(id:integer): string; // returns optional club name
begin
  result := FdCallList.Items[id].UserText;
end;


class function TFdCallRec.compareCall(const left, right: TFdCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TFdCallRec.GetString: string; // returns 3A OR [club name]
begin
  Result := Format(' - %s %s %s', [StnClass, Section, UserText]);
end;


end.



