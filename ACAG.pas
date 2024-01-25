unit ACAG;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  System.StrUtils,
  Generics.Defaults, Generics.Collections, Contest, DxStn, Log;

type
  TAcagCallRec = class
  public
    Call: string;     // call sign
    Number: string;   // <city|gun|ku><power>
    UserText: string; // optional UserText (displayed in status bar)
    function GetString: string;
    class function compareCall(const left, right: TAcagCallRec) : integer; static;
  end;

  TACAG = class(TContest)
  private
    CallList: TObjectList<TAcagCallRec>;
    Comparer: IComparer<TAcagCallRec>;

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : Boolean; override;

    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id:integer): string; override;     // returns station callsign
    procedure GetExchange(id : integer; out station : TDxStation); override;

    function getExch1(id:integer): string;    // returns RST (e.g. 5NN)
    function getExch2(id:integer): string;    // return <city|gun|ku><power> (e.g. 1002H)
    function FindCallRec(out fdrec: TAcagCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign: string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;

implementation

uses
  SysUtils, Classes;

function TACAG.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  rec: TAcagCallRec;
begin
  // reload call history if empty
  Result := CallList.Count <> 0;
  if Result then
    Exit;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;

  try
    CallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'JARL_ACAG.TXT');

    for i:= 0 to slst.Count-1 do begin
      if (slst.Strings[i].StartsWith('!!Order!!')) then continue;
      if (slst.Strings[i].StartsWith('#')) then continue;

      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 1) then begin
        if rec = nil then begin
          rec := TAcagCallRec.Create;
        end;

        rec.Call := UpperCase(tl.Strings[0]);
        rec.Number := UpperCase(tl.Strings[1]);
        rec.UserText := '';
        if (tl.Count >= 3) then rec.UserText := Trim(tl.Strings[2]);
        if rec.Call = '' then continue;
        if rec.Number = '' then continue;

        CallList.Add(rec);
        rec := nil;
      end;
    end;

    Result := True;
  finally
    slst.Free;
    tl.Free;
    if rec <> nil then rec.Free;
  end;
end;


constructor TACAG.Create;
begin
    inherited Create;
    CallList := TObjectList<TAcagCallRec>.Create;
    Comparer := TComparer<TAcagCallRec>.Construct(TAcagCallRec.compareCall);
end;


destructor TACAG.Destroy;
begin
  FreeAndNil(CallList);
  inherited;
end;


function TACAG.PickStation(): integer;
begin
  result := random(CallList.Count);
end;


procedure TACAG.DropStation(id : integer);
begin
  assert(id < CallList.Count);
  CallList.Delete(id);
end;


function TACAG.FindCallRec(out fdrec: TAcagCallRec; const ACall: string): Boolean;
var
  rec: TAcagCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TAcagCallRec.Create();
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

function TACAG.GetStationInfo(const ACallsign: string) : string;
var
  fdrec : TAcagCallRec;
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

//
// The extracted multiplier string is simply the <city|gun|ku> location number from Exchange Field 2.
// however, exclude <power> string from multiplier string.
//
// Exchange number format is follows.
// Exch1 Exch2
// 599   <city|gun|ku><power>
//
// <city> 0102-4715     4digits, city-code
// <gun>  01001-47005   5digits, gun(country)-code
// <ku>   010101-430105 6digits, ku(ward)-code
//
// <power> L|M|H|P      1digit
//
function TACAG.ExtractMultiplier(Qso: PQso) : string;
var
  S: string;
  P: Char;
begin
  S := Qso.Exch2;
  P := S[Length(S)];
  if CharInSet(P, ['L', 'M', 'H', 'P']) then begin
    // If the last letter is P, L, M, H, the string without them will be the multiplier.
    Result := Copy(S, 1, Length(S) - 1);
  end
  else begin
    // If the last letter is not P, L, M, H, consider the whole as a multiplier.
    Result := S;
  end;

  Qso^.Points := 1;
end;

function TACAG.getCall(id : integer): string; // returns station callsign
begin
  result := CallList.Items[id].Call;
end;

procedure TACAG.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);  // RST
  station.Exch2 := getExch2(station.Operid);  // <city|gun|ku><power>
end;

function TACAG.getExch1(id:integer): string;  // returns RST (e.g. 5NN)
begin
  result := '599';
end;

function TACAG.getExch2(id:integer): string;  // return <city|gun|ku><power> (e.g. 1002H)
begin
  result := CallList.Items[id].Number;
end;

class function TAcagCallRec.compareCall(const left, right: TAcagCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;

function TAcagCallRec.GetString: string;
begin
  Result := Format(' - NR %s', [Number]);
end;

end.

