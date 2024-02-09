unit ARRL;

interface

uses
  Classes;

type
    TDXCCRec= class
    public
        prefixReg: string;
        Entity: string;
        Continent: string;
        ITU: string;
        CQ: string;
        function GetString: string;
    end;

  TDXCC= class
  private
    DXCCList: TList;
    procedure LoadDxCCList;
    procedure Delimit(var AStringList: TStringList; const AText: string);
    function SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
  public
    constructor Create;
    function FindRec(out dxrec : TDXCCRec; const ACallsign : string) : Boolean;
    function GetStationInfo(const ACallsign: string): string;
    function Search(ACallsign: string): string;
  end;

var
    gDXCCList: TDXCC;

implementation

uses
    SysUtils, Contnrs, log, PerlRegEx, pcre, Ini;

procedure TDXCC.LoadDxCCList;
var
    slst, tl: TStringList;
    i: integer;
    AR: TDXCCRec;
begin
    slst:= TStringList.Create;
    tl:= TStringList.Create;
    try
        DXCCList:= TList.Create;
        slst.LoadFromFile(ParamStr(1) + 'ARRL.LIST');

        // The search algorithm walks this list in reverse order.
        for i:= 0 to slst.Count-1 do begin
            if slst.Strings[i].StartsWith('#') then continue;
            self.Delimit(tl, slst.Strings[i]);
            if (tl.Count = 7) then begin
                // some expressions are ignored because they mask other entities
                if tl.Strings[1].StartsWith('!ignore') then continue;
                AR:= TDXCCRec.Create;
                AR.prefixReg:= tl.Strings[1];
                AR.Entity:= tl.Strings[2];
                AR.Continent:= tl.Strings[3];
                AR.ITU:= tl.Strings[4];
                AR.CQ:= tl.Strings[5];
                DXCCList.Add(AR);
            end;
        end;
    finally
        slst.Free;
        tl.Free;
    end;
end;

constructor TDXCC.Create;
begin
    inherited Create;
    LoadDxCCList;
end;

// search ARRL DXCC prefix records for given callsign prefix.
function TDXCC.SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
var
    reg: TPerlRegEx;
    s: string;
    i: integer;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= False;
        reg.Subject := UTF8Encode(ACallPrefix);
        for i:= DXCCList.Count - 1 downto 0 do begin
            s:= '^(' + TDXCCRec(DXCCList.Items[i]).prefixReg + ')';
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

function TDXCC.FindRec(out dxrec : TDXCCRec; const ACallsign : string) : Boolean;
var
  sP : string;
  index : integer;
begin
  dxrec:= nil;

  // Use full call when extracting prefix, not user's call.
  // Example: F6/W7SST should return 'F6' not 'W7' (station located within F6)
  // Also, do not delete trailing letters of call or prefix to allow
  // regular expressions to match correctly (e.g. RC2F, Kaliningrad).
  sP:= ExtractPrefix(ACallsign, {DeleteTrailingLetters=} False);

  // special case for KG4 prefix...
  // 2x1 and 2x3 callsigns are US; 2x2 calls assumed to be Guantanamo Bay.
  // (Special thanks to F6FVY for a code example on how to solve this.)
  if     ACallsign.StartsWith('KG4') and
     not ACallsign.StartsWith('KG44') and
    ((Length(ACallsign) = 6) or (Length(ACallsign) = 4)) then
    begin
      // KG4abc problem ... this is hard coded
      Result:= SearchPrefix(index, 'K');
    end
  else
    Result:= SearchPrefix(index, sP);

  if Result then
    dxrec:= TDXCCRec(DXCCList.Items[index]);
end;

// return status bar information string.
function TDXCC.GetStationInfo(const ACallsign: string): string;
var
  i : integer;
  sP: string;
begin
  Result:= 'Unknown';

  // Use full call when extracting prefix, not user's call.
  sP:= ExtractPrefix(ACallsign);

  if SearchPrefix(i, sP) then
    Result:= sP + ':  ' + TDXCCRec(DXCCList[i]).GetString;
end;

function TDXCC.Search(ACallsign: string): string;
var
    reg: TPerlRegEx;
    i: integer;
    s, sP: string;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= '';
        // Use full call when extracting prefix, not user's call.
        sP:= ExtractPrefix(ACallsign);
        reg.Subject := UTF8Encode(sP);
        for i:= DXCCList.Count - 1 downto 0 do begin
            s:= '^(' + TDXCCRec(DXCCList.Items[i]).prefixReg + ')';
            reg.RegEx:= UTF8Encode(s);
            if Reg.Match then begin
                Result:= sP + ':  ' + TDXCCRec(DXCCList[i]).GetString;
                Break;
            end;
        end;
    finally
        reg.Free;
    end;
end;

procedure TDXCC.Delimit(var AStringList: TStringList; const AText: string);
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

function TDXCCRec.GetString: string;
begin
  // make the long USA entry a little shorter (similar to N1MM)
  if Entity = 'United States of America' then
    Result:= Format('%s/United States;  ITU Zone: %s;  CQ Zone: %s', [Continent, ITU, CQ])
  else
    Result:= Format('%s/%s;  ITU Zone: %s;  CQ Zone: %s', [Continent, Entity, ITU, CQ]);
end;

end.
