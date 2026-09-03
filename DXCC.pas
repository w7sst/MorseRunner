unit DXCC;

interface

uses
  Generics.Collections,
  PerlRegEx,
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
    DXCCList: TObjectList<TDXCCRec>;
    RegExList: TObjectList<TPerlRegEx>;
    procedure LoadDxCCList;
    procedure Delimit(var AStringList: TStringList; const AText: string);
    function SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function FindRec(out dxrec : TDXCCRec; const ACallsign : string) : Boolean;
    function GetStationInfo(const ACallsign: string): string;
    function Search(ACallsign: string): string;
  end;

var
    gDXCCList: TDXCC;

implementation

uses
    AppPaths,
    SysUtils, Contnrs, CallsignUtils;

procedure TDXCC.LoadDxCCList;
var
    slst, tl: TStringList;
    i: integer;
    AR: TDXCCRec;
begin
    slst:= TStringList.Create;
    tl:= TStringList.Create;
    try
        DXCCList:= TObjectList<TDXCCRec>.Create;
        slst.LoadFromFile(TAppPaths.ContestDataFile('DXCC.LIST'));

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

        RegExList := TObjectList<TPerlRegEx>.Create;

        // initialize RegExList with nil pointers, one for each DXCC record.
        RegExList.Count := DXCCList.Count;

    finally
        slst.Free;
        tl.Free;
    end;
end;

constructor TDXCC.Create;
begin
    inherited Create;
    DxCCList := nil;
    RegExList := nil;

    LoadDxCCList;
end;


destructor TDXCC.Destroy;
begin
  FreeAndNil(RegExList);
  FreeAndNil(DXCCList);
end;

// search ARRL DXCC prefix records for given callsign prefix.
function TDXCC.SearchPrefix(out index : integer; const ACallPrefix : string) : Boolean;
var
    reg: TPerlRegEx;
    s: string;
    i: integer;
begin
    if ACallPrefix.IsEmpty then Exit(False);

    try
        Result:= False;

        // scan the DXCCList looking for the first match
        for i:= DXCCList.Count - 1 downto 0 do begin
            reg := RegExList[i];
            if not Assigned(reg) then begin
              RegExList[i] := TPerlRegEx.Create;
              reg := RegExList[i];

              s:= '^(' + DXCCList[i].prefixReg + ')';
              reg.RegEx:= UTF8Encode(s);
              reg.Compile;
              reg.Study;
            end;

            reg.Subject := UTF8Encode(ACallPrefix);
            if Reg.Match then begin
                index:= i;
                Result:= True;
                Break;
            end;
        end;
    finally
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
  if     sP.StartsWith('KG4') and
     not sP.StartsWith('KG44') and
    ((sP.Length = 6) or (sP.Length = 4)) then
    begin
      // KG4abc problem ... this is hard coded
      sP := 'K';
    end;

  // special case for Antarctica prefix (CE9/ or KC4/) and patterns...
  // leading or trailing prefixes of the form CE9/W7SST, W7SST/KC4, KC4/W7SST
  // and the pattern KC4(AA|US)[A-Z] are hard coded to match KC4AAA.
  if ((sP.Length = 3) and (sP = 'CE9') or (sP = 'KC4')) or
     ((sP.Length = 6) and (sP.StartsWith('KC4AA') or sP.StartsWith('KC4US'))) then
    sP := 'CE9KC4';

  // special case for 4U1WB...
  // 4U1WB is from DC, not DX. DX is flagged as an Invalid Section by N1MM.
  if sP.Equals('4U1WB') then
    sP := 'W0';

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
