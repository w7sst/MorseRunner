unit CWOPS;

interface

uses
  Classes, Generics.Defaults, Generics.Collections, Contest, Contnrs,
  Station, DxStn, Log;

type
    TCWOPSRec= class
    public
        Call: string;     // Station Callsign
        Exch1: string;    // Operator Name
        Exch2: string;    // Number/State/Province/Country Prefix
        UserText: string; // station location/information string

        function IsCWOpsMember: Boolean;  // return whether operator is a member
        class function compareCall(const left, right: TCWOPSRec) : integer; static;
    end;

  TCWOPS= class(TContest)
  private
    CWOPSList: TObjectList<TCWOPSRec>;
    Comparer: IComparer<TCWOPSRec>;
    procedure Delimit(var AStringList: TStringList; const AText: string);

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;

    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id : integer): string; override;
    function FindCallRec(out outrec: TCWOPSRec; const ACall: string): Boolean;
    procedure GetExchange(id : integer; out station : TDxStation); override;
    procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); override;
    function GetStationInfo(const ACallsign: string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;

  function IsNum(Num: String): Boolean;


implementation

uses
    SysUtils, ARRL;

function TCWOPS.LoadCallHistory(const AUserCallsign : string) : boolean;
const
    // !!Order!!,Call,Name,Exch1,UserText,
    CallInx : integer = 0;
    NameInx : integer = 1;
    ExchInx : integer = 2;
    UserTextInx : integer = 3;
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

        for i:= 0 to slst.Count-1 do begin
            if (slst.Strings[i].StartsWith('!!Order!!')) then continue;
            if (slst.Strings[i].StartsWith('#')) then continue;

            self.Delimit(tl, slst.Strings[i]);

            if (tl.Count >= 3) then begin
                if CWO = nil then
                  CWO:= TCWOPSRec.Create;

                CWO.Call:= UpperCase(tl.Strings[CallInx]);
                CWO.Exch1:= UpperCase(tl.Strings[NameInx]);
                CWO.Exch2:= UpperCase(tl.Strings[ExchInx]);
                if tl.Count > UserTextInx then
                  CWO.UserText:= Trim(tl.Strings[UserTextInx]);
                if CWO.Call='' then continue;
                if CWO.Exch1='' then  continue;
                if CWO.Exch2='' then continue;
                if length(CWO.Exch1) > 10 then continue;
                if length(CWO.Exch2) > 5 then continue;

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
    CWOPSList:= TObjectList<TCWOPSRec>.Create;
    Comparer := TComparer<TCWOPSRec>.Construct(TCWOPSRec.compareCall);
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
     result := CWOPSList[id].Call;
end;


function TCWOPS.FindCallRec(out outrec: TCWOPSRec; const ACall: string): Boolean;
var
  rec: TCWOPSRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TCWOPSRec.Create();
  rec.Call := ACall;
  outrec:= nil;
  try
    if CWOPSList.BinarySearch(rec, index, Comparer) then
      outrec:= CWOPSList.Items[index];
  finally
    rec.Free;
  end;
  Result:= outrec <> nil;
end;


procedure TCWOPS.GetExchange(id : integer; out station : TDxStation);
begin
  station.OpName := CWOPSList.Items[id].Exch1;
  station.Exch1 := CWOPSList.Items[id].Exch1;
  station.Exch2 := CWOPSList.Items[id].Exch2;
end;


{
  Overrides TContest.SendMsg() to send contest-specific messages.

  Adding a contest: TContest.SendMsg(AMsg): send contest-specfic messages
}
procedure TCWOPS.SendMsg(const AStn: TStation; const AMsg: TStationMessage);
begin
  case AMsg of
    msgCQ: SendText(AStn, 'CQ CWT <my>');
    msgR_NR:
      if (random < 0.9)
        then SendText(AStn, '<#>')
        else SendText(AStn, 'R <#>');
    msgR_NR2:
      if (random < 0.9)
        then SendText(AStn, '<#> <#>')
        else SendText(AStn, 'R <#> <#>');
    msgLongCQ: SendText(AStn, 'CQ CQ CWT <my> <my>');  // QrmStation only
    else
      inherited SendMsg(AStn, AMsg);
  end;
end;


{
  return status bar information string from CWOPS call history file.
  for members (w/ numeric Exch2), return their QTH string (UserText)
  for DX Stations (not USA or Canada), return their Entity/Continent.
  this string is used in MainForm.sbar.Caption (status bar).
  We are careful not to disclose information that would give hints during
  exchange copy (e.g. for non-members in US or Canada, we do not return
  their city/state/province).
  Format:  '<call> [- <user text from CWOPS.LIST>] [- Entity/Continent]'
}
function TCWOPS.GetStationInfo(const ACallsign: string) : string;
var
  cwopsrec : TCWOPSRec;
  dxrec : TDXCCRec;
  userText : string;
begin
  cwopsrec := nil;
  dxrec := nil;
  userText := '';
  result:= '';

  if FindCallRec(cwopsrec, ACallsign) then
    begin
      // if caller is a member, include their UserText string.
      // if non-member calling from USA or Canada, use either NA/USA or NA/Canada
      // (otherwise UserText string gives a hint for State/Province).
      // if UserText is empty, always return DXCC Continent/Entity.
      userText := cwopsrec.UserText;
      if gDXCCList.FindRec(dxrec, ACallsign) then
        if userText.IsEmpty or
          (not cwopsrec.IsCWOpsMember and
            (dxrec.Entity.Equals('United States of America') or
             dxrec.Entity.Equals('Canada'))) then
          userText:= dxRec.Continent + '/' + dxRec.Entity;

      if not userText.IsEmpty then
        result:= ACallsign + ' - ' + userText;
    end;
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


function TCWOPSRec.IsCWOpsMember: Boolean;
begin
  Result := IsNum(Exch2);
end;

class function TCWOPSRec.compareCall(const left, right: TCWOPSRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
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



