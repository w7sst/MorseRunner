unit ALLJA;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  System.StrUtils,
  Generics.Defaults, Generics.Collections, Contest, DxStn, Log;

type
  TAllJaCallRec = class
  public
    Call: string;     // call sign
    Number: string;   // CQ-Zone
    UserText: string; // optional UserText (displayed in status bar)
    function GetString: string; // returns CQ-Zone N (e.g. 'CQ-Zone 3')
    class function compareCall(const left, right: TAllJaCallRec) : integer; static;
  end;

  TALLJA = class(TContest)
  private
    CallList: TObjectList<TAllJaCallRec>;
    Comparer: IComparer<TAllJaCallRec>;

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
    function FindCallRec(out fdrec: TAllJaCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign: string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;

implementation

uses
  SysUtils, Classes;

function TALLJA.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = #09;
var
  slst, tl: TStringList;
  i: integer;
  rec: TAllJaCallRec;
begin
  // reload call history if empty
  Result := CallList.Count <> 0;
  if Result then
    Exit;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;

  try
    CallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'DIC_ALLJA.DAT');

    for i:= 0 to slst.Count-1 do begin
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 1) then begin
          if (tl.Strings[0] = '!!Order!!') then continue;

          rec := TAllJaCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.Number := UpperCase(tl.Strings[1]);
          if (tl.Count >= 3) then rec.UserText := tl.Strings[2];
          if rec.Call = '' then continue;
          if rec.Number = '' then continue;

          CallList.Add(rec);
      end;
    end;

    Result := True;
  finally
    slst.Free;
    tl.Free;
  end;
end;


constructor TALLJA.Create;
begin
    inherited Create;
    CallList := TObjectList<TAllJaCallRec>.Create;
    Comparer := TComparer<TAllJaCallRec>.Construct(TAllJaCallRec.compareCall);
end;


destructor TALLJA.Destroy;
begin
  FreeAndNil(CallList);
  inherited;
end;


function TALLJA.PickStation(): integer;
begin
  result := random(CallList.Count);
end;


procedure TALLJA.DropStation(id : integer);
begin
  assert(id < CallList.Count);
  CallList.Delete(id);
end;


function TALLJA.FindCallRec(out fdrec: TAllJaCallRec; const ACall: string): Boolean;
var
  rec: TAllJaCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TAllJaCallRec.Create();
  rec.Call := ACall;
  fdrec:= nil;
  try
    if CallList.BinarySearch(rec, index, Comparer) then
      fdrec:= CallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= fdrec <> nil;
end;

function TALLJA.GetStationInfo(const ACallsign: string) : string;
var
  fdrec : TAllJaCallRec;
  userText : string;
begin
  fdrec := nil;
  userText := '';
  result:= '';

  if Self.FindCallRec(fdrec, ACallsign) then
    begin
      userText:= fdrec.UserText;
    end;

  if (userText <> '') then
    begin
      result:= ACallsign;
      if userText <> '' then
        result:= result + ' - ' + userText;
    end;
end;

// Exch2
// <pref><power>
//
// <pref> 02-49    2digits prefecture code
//        101-114  3digits Hokkaido branch office code
// <power> L|M|H|P 1digit
//
function TALLJA.ExtractMultiplier(Qso: PQso) : string;
var
  S: string;
  P: Char;
begin
  S := Qso.Exch2;
  P := S[Length(S)];
  if CharInSet(P, ['L', 'M', 'H', 'P']) then begin
    Result := Copy(S, 1, Length(S) - 1);
  end
  else begin
    Result := S;
  end;

  Qso^.Points := 1;
end;


function TALLJA.getCall(id : integer): string;     // returns station callsign
begin
  result := CallList.Items[id].Call;
end;


procedure TALLJA.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);  // RST
  station.Exch2 := getExch2(station.Operid);
end;

function TALLJA.getExch1(id:integer): string;    // returns RST (e.g. 599)
begin
  result := '599';
end;

function TALLJA.getExch2(id:integer): string;    // returns section info (e.g. 3)
begin
  result := CallList.Items[id].Number;
end;

class function TAllJaCallRec.compareCall(const left, right: TAllJaCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;

function TAllJaCallRec.GetString: string; // returns CQ-Zone N (e.g. 'CQ-Zone 3')
begin
  Result := Format(' - NR %s', [Number]);
end;

end.

