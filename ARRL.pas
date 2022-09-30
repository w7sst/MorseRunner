unit ARRL;

interface

uses
  SysUtils, Classes, Contnrs, PerlRegEx, pcre;

type
    TARRLRec= class
    public
        prefixReg: string;
        Entity: string;
        Continent: string;
        ITU: string;
        CQ: string;
        function GetString: string;
    end;

  TARRL= class
  private
    ARRLList: TList;
    procedure LoadARRL;
    procedure Delimit(var AStringList: TStringList; const AText: string);
    function SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
  public
    constructor Create;
    function FindRec(out dxrec : TARRLRec; const ACallsign : string) : Boolean;
    function GetStationInfo(const ACallsign: string): string;
    function Search(ACallsign: string): string;
  end;

var
    ARRLDX: TARRL;

implementation

uses
    log;

procedure TARRL.LoadARRL;
var
    slst, tl: TStringList;
    i: integer;
    AR: TARRLRec;
begin
    slst:= TStringList.Create;
    tl:= TStringList.Create;
    try
        ARRLList:= TList.Create;
        slst.LoadFromFile(ParamStr(1) + 'ARRL.LIST');
        slst.Sort;
        for i:= 0 to slst.Count-1 do begin
            self.Delimit(tl, slst.Strings[i]);
            if (tl.Count = 7) then begin
                AR:= TARRLRec.Create;
                AR.prefixReg:= tl.Strings[1];
                AR.Entity:= tl.Strings[2];
                AR.Continent:= tl.Strings[3];
                AR.ITU:= tl.Strings[4];
                AR.CQ:= tl.Strings[5];
                ARRLList.Add(AR);
            end;
        end;
    finally
        slst.Free;
        tl.Free;
    end;
end;

constructor TARRL.Create;
begin
    inherited Create;
    LoadARRL;
end;

// search ARRL prefix records for given callsign prefix.
function TARRL.SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
var
    reg: TPerlRegEx;
    s: string;
    i: integer;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= False;
        reg.Subject := UTF8Encode(ACallPrefix);
        for i:= ARRLList.Count - 1 downto 0 do begin
            s:= '^(' + TARRLRec(ARRLList.Items[i]).prefixReg + ')';
            reg.RegEx:= UTF8Encode(s);
            if Reg.Match then begin
                index:= i;
                Result:= True;
                Break;
            end;
        end;
    finally
        reg.Free;
    end;
end;

function TARRL.FindRec(out dxrec : TARRLRec; const ACallsign : string) : Boolean;
var
  sC, sP: string;
  index : integer;
begin
  dxrec:= nil;
  sC:= ExtractCallsign(ACallsign);
  sP:= ExtractPrefix(sC);
  Result:= SearchPrefix(index, sP);
  if Result then
    dxrec:= TARRLRec(ARRLList.Items[index]);
end;

// return status bar information string.
function TARRL.GetStationInfo(const ACallsign: string): string;
var
  i : integer;
  sC, sP: string;
begin
  Result:= 'Unknown';
  sC:= ExtractCallsign(ACallsign);
  sP:= ExtractPrefix(sC);
  if SearchPrefix(i, sP) then
    Result:= sC + '  ' + TARRLRec(ARRLList[i]).GetString;
end;

function TARRL.Search(ACallsign: string): string;
var
    reg: TPerlRegEx;
    i: integer;
    s, sC, sP: string;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= '';
        sC:= ExtractCallsign(ACallsign);
        sP:= ExtractPrefix(sC);
        reg.Subject := UTF8Encode(sP);
        for i:= ARRLList.Count - 1 downto 0 do begin
            s:= '^(' + TARRLRec(ARRLList.Items[i]).prefixReg + ')';
            reg.RegEx:= UTF8Encode(s);
            if Reg.Match then begin
                Result:= sC + '  ' + TARRLRec(ARRLList[i]).GetString;
                Break;
            end;
        end;
    finally
        reg.Free;
    end;
end;

procedure TARRL.Delimit(var AStringList: TStringList; const AText: string);
const
    DelimitChar: char= ';';
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

{ TARRLRec }

function TARRLRec.GetString: string;
begin
    Result:= Format('%s/%s;  ITU Zone:%s;  CQ Zone:%s', [Entity, Continent, ITU, CQ]);
end;

end.
