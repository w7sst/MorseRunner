unit CWOPS;

interface

uses
  SysUtils, Classes, Contnrs, PerlRegEx, pcre;

type
    TCWOPSRec= class
    public
        call: string;
        Name: string;
        Number: string;
    end;

  TCWOPS= class
  private
    CWOPSList: TList;
    procedure LoadCWOPS;
    procedure Delimit(var AStringList: TStringList; const AText: string);

  public
    constructor Create;
    function getcwopsid(): integer;
    function getcwopscall(id:integer): string;
    function getcwopsname(id:integer): string;
    function getcwopsnum(id:integer): integer;
    function IsNum(Num: String): Boolean;
  end;

var
    CWOPSCWT: TCWOPS;


implementation

uses
    log;

procedure TCWOPS.LoadCWOPS;
var
    slst, tl: TStringList;
    i: integer;
    CWO: TCWOPSRec;
begin
    slst:= TStringList.Create;
    tl:= TStringList.Create;
    try
        CWOPSList:= TList.Create;
        slst.LoadFromFile(ParamStr(1) + 'CWOPS.LIST');
        slst.Sort;

        for i:= 0 to slst.Count-1 do begin
            self.Delimit(tl, slst.Strings[i]);
            if (tl.Count = 4) then begin
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


            end;
        end;

    finally
        slst.Free;
        tl.Free;
    end;


end;

constructor TCWOPS.Create;
begin
    inherited Create;
    LoadCWOPS;
end;

function TCWOPS.getcwopsid(): integer;
begin
     result := random(CWOPSList.Count);
end;


function TCWOPS.getcwopscall(id:integer): string;

begin
     result := TCWOPSRec(CWOPSList.Items[id]).Call;
end;

function TCWOPS.getcwopsname(id:integer): string;

begin
     result := TCWOPSRec(CWOPSList.Items[id]).Name;
end;

function TCWOPS.getcwopsnum(id:integer): integer;

begin
     result := strtoint(TCWOPSRec(CWOPSList.Items[id]).Number);
end;

function TCWOPS.IsNum(Num: String): Boolean;
var
   X : Integer;
begin
   Result := True;
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
var
    i, l: integer;
    s: string;
begin
    AStringList.Clear;
    l:= Length(AText);
    s:= '';
    for i := 1 to l do begin
        if(AText[i] = DelimitChar) or (i=l) then begin
            AStringList.Add(s);
            s:= '';
        end
        else
            s:= s + AText[i];
    end;
end;

end.



