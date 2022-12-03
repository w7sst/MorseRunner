unit CWOPS;

interface

uses
  Classes, Contest, Contnrs, DxStn, Log;

type
    TCWOPSRec= class
    public
        call: string;
        Name: string;
        Number: string;
    end;

  TCWOPS= class(TContest)
  private
    CWOPSList: TList;
    procedure Delimit(var AStringList: TStringList; const AText: string);

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;

    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id : integer): string; override;
    procedure GetExchange(id : integer; out station : TDxStation); override;
    function ExtractMultiplier(Qso: PQso) : string; override;

    function getcwopsname(id:integer): string;
    function getcwopsnum(id:integer): integer;
  end;

  function IsNum(Num: String): Boolean;


implementation

uses
    SysUtils;

function TCWOPS.LoadCallHistory(const AUserCallsign : string) : boolean;
var
    slst, tl: TStringList;
    i: integer;
    CWO: TCWOPSRec;
begin
    // reload call history if empty
    Result := CWOPSList.Count <> 0;
    if Result then
      Exit;

    slst:= TStringList.Create;
    tl:= TStringList.Create;
    CWO := nil;

    try
        CWOPSList.Clear;

        slst.LoadFromFile(ParamStr(1) + 'CWOPS.LIST');
        slst.Sort;

        for i:= 0 to slst.Count-1 do begin
            self.Delimit(tl, slst.Strings[i]);
            if (tl.Count = 4) then begin
                if CWO = nil then
                  CWO:= TCWOPSRec.Create;

                CWO.Call:= UpperCase(tl.Strings[0]);
                CWO.Name:= UpperCase(tl.Strings[1]);
                CWO.Number:= tl.Strings[2];
                if CWO.Call='' then continue;
                if CWO.Name='' then  continue;
                if CWO.Number='' then continue;
                if IsNum(CWO.Number) = False then  continue;
                if length(CWO.Name) > 10 then continue;
                if length(CWO.Name) > 12 then continue;

                CWOPSList.Add(CWO);
                CWO := nil;
            end;
        end;

        Result := True;

    finally
        slst.Free;
        tl.Free;
        if CWO <> nil then CWO.Free;
    end;


end;

constructor TCWOPS.Create;
begin
    inherited Create;
    CWOPSList:= TList.Create;
end;

destructor TCWOPS.Destroy;
begin
  FreeAndNil(CWOPSList);
  inherited;
end;


function TCWOPS.PickStation(): integer;
begin
     result := random(CWOPSList.Count);
end;


procedure TCWOPS.DropStation(id : integer);
begin
  assert(id < CWOPSList.Count);
  CWOPSList.Delete(id);
end;


function TCWOPS.GetCall(id : integer): string;
begin
     result := TCWOPSRec(CWOPSList.Items[id]).Call;
end;


procedure TCWOPS.GetExchange(id : integer; out station : TDxStation);
begin
  station.OpName := getcwopsname(id);
  station.NR :=  getcwopsnum(id);
end;


{
  CWOPS CWT contest uses number of unique callsigns worked as the multiplier.
  Also sets contest-specific Qso.Points for this QSO.
}
function TCWOPS.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso^.Points := 1;
  Result:= Qso^.Call;
end;


function TCWOPS.getcwopsname(id:integer): string;

begin
     result := TCWOPSRec(CWOPSList.Items[id]).Name;
end;

function TCWOPS.getcwopsnum(id:integer): integer;

begin
     result := strtoint(TCWOPSRec(CWOPSList.Items[id]).Number);
end;

function IsNum(Num: String): Boolean;
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




procedure TCWOPS.Delimit(var AStringList: TStringList; const AText: string);
const
    DelimitChar: char= ',';
begin
    AStringList.Clear;
    AStringList.Delimiter := DelimitChar;
    AStringList.StrictDelimiter := True;
    AStringList.DelimitedText := AText;
end;

end.



