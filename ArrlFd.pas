unit ARRLFD;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Contest, Station, DxStn, Log;

type
  TFdCallRec = class
  private
    function GetTxCnt : integer;
  public
    Call: string;     // call sign
    StnClass: string; // station classification (e.g. 3A)
    Section: string;  // ARRL/RAC section (e.g. OR)
    UserText: string; // club name
    function GetString: string; // returns 3A OR [club name]
    class function compareCall(const left, right: TFdCallRec) : integer; static;
    property TxCnt : integer read GetTxCnt;
  end;

  TPendingCall = record
    TxCnt: UInt16;    // transmitter count (sorting in descending order)
    Index: UInt16;    // index into original slst

    constructor Create(txcnt : Integer; inx : Integer);
    class function comparePendingCall(const left, right : TPendingCall) : integer; static;
  end;

  { Holds stations for a given club name, sort by TxCnt }
  TPendingClubCalls = class(TList<TPendingCall>)
  private
    Sorted: Boolean;
  public
    constructor Create(PendingCallComparer : IComparer<TPendingCall>);
    destructor Destroy; override;

    procedure AddCall(I: Integer; const rec: TFdCallRec);
    function PickPendingCallIdx : Integer;
  end;

  TPendingStations = class(TObjectDictionary<String, TPendingClubCalls>)
    PendingCallComparer: IComparer<TPendingCall>;

    constructor Create;
    destructor Destroy; override;

    procedure AddPendingCall(const ClubName : String; const rec: TFdCallRec; I: Integer);
  end;

TArrlFieldDay = class(TContest)
private
  FdCallList: TObjectList<TFdCallRec>;
  Comparer: IComparer<TFdCallRec>;

public
  constructor Create;
  destructor Destroy; override;
  function LoadCallHistory(const AUserCallsign : string) : boolean; override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id : integer): string; override; // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

  function getExch1(id:integer): string;    // returns station info (e.g. 3A)
  function getExch2(id:integer): string;    // returns section info (e.g. OR)
  function getClass(id:integer): string;    // returns station class (e.g. 3A)
  function getSection(id:integer): string;  // returns section (e.g. OR)
  function getUserText(id:integer): string; // returns optional club name
  function FindCallRec(out fdrec: TFdCallRec; const ACall: string): Boolean;
  procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); override;
  function GetStationInfo(const ACallsign: string) : string; override;
  function ExtractMultiplier(Qso: PQso) : string; override;

//{$define DISTRIBUTION_REPORT}
{$ifdef DISTRIBUTION_REPORT}
  function GetDistributionReport : string;
{$endif}
end;

implementation

uses
  SysUtils, Classes,
  Ini,
  System.Generics.Collections,
{$ifdef DISTRIBUTION_REPORT}
  Dialogs,      // for ShowMessage
  Vcl.Clipbrd,  // for TClipBoard
{$endif}
  DXCC;

var
  IntegerComparer: IComparer<Integer>;

{ TPendingCall }

constructor TPendingCall.Create(txcnt : Integer; inx : Integer);
begin
  Self.TxCnt := UInt16(txcnt);
  Self.Index := UInt16(inx);
end;

class function TPendingCall.comparePendingCall(const left, right : TPendingCall) : integer;
begin
  Result := IntegerComparer.Compare(right.TxCnt, left.TxCnt);
end;

{ TPendingClubCalls }

constructor TPendingClubCalls.Create(PendingCallComparer : IComparer<TPendingCall>);
begin
  inherited Create(PendingCallComparer);
  Sorted := False;
end;

destructor TPendingClubCalls.Destroy;
begin
end;

procedure TPendingClubCalls.AddCall(I: Integer; const rec: TFdCallRec);
begin
  Self.Add(TPendingCall.Create(rec.TxCnt, I));
  Sorted := False;
end;

function TPendingClubCalls.PickPendingCallIdx : Integer;
const
  BeginIdx : Integer = 0;
var
  EndIdx, Idx : Integer;
  Item : TPendingCall;
begin
  // sort PendingCall record by decreasing TxCnt
  if not Sorted then
  begin
    Sort;
    Sorted := True;
  end;

  if First.TxCnt = Last.TxCnt then
    EndIdx := Count
  else begin
    Item.TxCnt := First.TxCnt;
    EndIdx := LastIndexOf(Item)+1;
  end;
  if (EndIdx - BeginIdx) > 1 then
    Idx := BeginIdx + Random(EndIdx - BeginIdx)
  else
    Idx := BeginIdx;
  Result := Items[Idx].Index;
end;

{ TPendingStations }

constructor TPendingStations.Create;
begin
  inherited Create([doOwnsValues]);
  PendingCallComparer := TComparer<TPendingCall>.Construct(TPendingCall.comparePendingCall);
end;

destructor TPendingStations.Destroy;
begin
  inherited Destroy;
end;

procedure TPendingStations.AddPendingCall(
  const ClubName : String;
  const rec: TFdCallRec;
  I: Integer);
var
  pending: TPendingClubCalls;
begin
  if not TryGetValue(ClubName, pending) then begin
    pending := TPendingClubCalls.Create(Self.PendingCallComparer);
    Add(ClubName, pending);
  end;

  pending.AddCall(I, rec);
  pending := nil;
end;


{ TArrlFieldDay }

function TArrlFieldDay.LoadCallHistory(const AUserCallsign : string) : boolean;
const
  DelimitChar: char = ',';
var
  slst, tl: TStringList;
  i: integer;
  S : String;
  ClubNames : TDictionary<String, TFdCallRec>;
  PendingStations: TPendingStations;
  PendingCalls : TPendingClubCalls;
  Pair : TPair<String, TPendingClubCalls>;
  HomeStn, PortableStn : Boolean;
  rec: TFdCallRec;
  existing: TFdCallRec;
begin
  // reload call history if empty
  Result := FdCallList.Count <> 0;
  if Result then
    Exit;

  slst:= TStringList.Create;
  tl:= TStringList.Create;
  ClubNames := TDictionary<String, TFdCallRec>.Create;
  PendingStations := TPendingStations.Create;
  tl.Delimiter := DelimitChar;
  tl.StrictDelimiter := True;
  rec := nil;
  existing := nil;

  try
    FdCallList.Clear;

    slst.LoadFromFile(ParamStr(1) + 'FDGOTA.TXT');

    // Pass 1 - find and process all club stations (class A, C or F).
    //        - deffer all home/portable stations w/ a club name to Pass 2.
    for i:= 0 to slst.Count-1 do
    begin
      if (slst.Strings[i].StartsWith('!!Order!!')) then continue;
      if (slst.Strings[i].StartsWith('#')) then continue;

      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then
      begin
          if rec = nil then
            rec := TFdCallRec.Create;
          rec.Call := UpperCase(tl.Strings[0]);
          rec.StnClass := UpperCase(tl.Strings[1]);
          rec.Section := UpperCase(tl.Strings[2]);
          rec.UserText := '';
          if (tl.Count >= 4) then rec.UserText := Trim(tl.Strings[3]);

          if rec.Call='' then continue;
          if rec.StnClass='' then continue;
          if rec.Section='' then continue;

          // In 2020, Covid resulted in FD rule changes allowing home stations
          // to be used and contribute to the operator's club score. This
          // resulted in an above average number of home stations since these
          // stations were connected to the clubs score.
          //
          // Skip home (D/E) and portable (B) stations with a club name by
          // assuming they are associated with a club.
          S := rec.StnClass.Substring(rec.StnClass.Length-1);
          HomeStn := S.Equals('D') or S.Equals('E');
          PortableStn := S.Equals('B');
          if HomeStn or PortableStn then
          begin
            if rec.UserText.IsEmpty then
            begin
              if Random < 0.25 then
              begin
                // home/portable stations w/o club name can be added
                FdCallList.Add(rec);
                rec := nil;
              end;
              continue
            end
            else
            begin
              // retain this call and club name to see if it is part of a club.
              PendingStations.AddPendingCall(rec.UserText, rec, I);
            end;
            continue;
          end
          else
          begin
            // this is a club station (A, C, or F)
            if not rec.UserText.IsEmpty then
            begin
              // have we seen this club name before?
              if ClubNames.TryGetValue(rec.UserText, existing) then
              begin
                // keep the station with the higher transmitter count
                if rec.TxCnt > existing.TxCnt then
                begin
                  FdCallList.Delete(FdCallList.IndexOf(existing));
                  existing := nil;
                  FdCallList.Add(rec);
                  ClubNames.Items[rec.UserText] := rec;
                  rec := nil;
                end;
                continue;
              end;

              ClubNames.Add(rec.UserText, rec);
            end;

            FdCallList.Add(rec);
            rec := nil;
          end;
      end;
    end;

    // Pass 2 - add any portable/home (B, D, E) stations not associated
    //          with a named club station from pass 1 above.
    for Pair in PendingStations do
    begin
      // does this group of home/portable stations have an associated club name?
      if ClubNames.TryGetValue(Pair.Key, existing) then
        continue;

      // this group of pending stations is not associated with a club.
      // pick a call from this group.
      i := Pair.Value.PickPendingCallIdx;
      tl.DelimitedText := slst.Strings[i];

      if (tl.Count > 2) then
      begin
        if rec = nil then
          rec := TFdCallRec.Create;
        rec.Call := UpperCase(tl.Strings[0]);
        rec.StnClass := UpperCase(tl.Strings[1]);
        rec.Section := UpperCase(tl.Strings[2]);
        rec.UserText := '';
        if (tl.Count >= 4) then rec.UserText := Trim(tl.Strings[3]);

        if rec.Call='' then continue;
        if rec.StnClass='' then continue;
        if rec.Section='' then continue;

        assert(Pair.Key.Equals(rec.UserText));

        // keep all portable stations and 25% of the home stations
        if rec.StnClass.EndsWith('B') or (Random < 0.25) then
        begin
          FdCallList.Add(rec);
          ClubNames.Add(rec.UserText, rec);
          rec := nil;
        end;
      end;
    end; // end for pair in PendingStations

    FdCallList.Sort;

{$ifdef DISTRIBUTION_REPORT}
    S := GetDistributionReport;
    ShowMessage(S);
    ClipBoard.AsText := S;
{$endif}

    Result := True;

  finally
    slst.Free;
    tl.Free;
    ClubNames.Free;
    PendingStations.Free;
    if rec <> nil then rec.Free;
  end;
end;


constructor TArrlFieldDay.Create;
begin
    inherited Create;
    Comparer := TComparer<TFdCallRec>.Construct(TFdCallRec.compareCall);
    FdCallList:= TObjectList<TFdCallRec>.Create(Comparer);
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


{
  Overrides TContest.SendMsg() to send contest-specific messages.

  Adding a contest: TContest.SendMsg(AMsg): send contest-specfic messages
}
procedure TArrlFieldDay.SendMsg(const AStn: TStation; const AMsg: TStationMessage);
begin
  case AMsg of
    msgCQ: SendText(AStn, 'CQ FD <my>');
    msgNrQm:
      case Random(5) of
        0,1: SendText(AStn, 'NR?');
        2: SendText(AStn, 'SECT?');
        3: SendText(AStn, 'CLASS?');
        4: SendText(AStn, 'CL?');
      end;
    msgLongCQ: SendText(AStn, 'CQ CQ FD <my> <my> FD');  // QrmStation only
    else
      inherited SendMsg(AStn, AMsg);
  end;
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


{
  Field Day doesn't have an expliclit multiplier; return a non-empty string.
  Also sets contest-specific Qso.Points for this QSO.
}
function TArrlFieldDay.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso^.Points := 2;
  Result:= '1';
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


{$ifdef DISTRIBUTION_REPORT}
function TArrlFieldDay.GetDistributionReport : string;
const
  CallsPerDot : Integer = 20;
var
  dist : TDictionary<String, Integer>;
  summary : TList<String>;
  Value : Integer;
  Comparison: TComparison<String>;
begin
  dist := TDictionary<String, Integer>.Create;
  summary := TList<String>.Create;

  try
    // count calls by classification
    for var rec : TFdCallRec in FdCallList do
    begin
      if not dist.TryGetValue(rec.StnClass, Value) then
        dist.Add(rec.StnClass, 0);
      dist[rec.StnClass] := Value + 1;
    end;

    // format summary lines
    for var item : TPair<String, Integer> in dist do
    begin
      var Len : integer := (item.Value div CallsPerDot);
      var Str : String := StringOfChar('*', Len);
      if Ini.IsNum(item.Key.Substring(0,2)) then
        summary.Add(Format('%3s: %4d %s',
          [item.Key, item.Value, Str]))
      else
        summary.Add(Format('0%2s: %4d %s',
          [item.Key, item.Value, Str]));
    end;

    // sort summary by station class, then by transmitter count
    Comparison :=
      function(const Left, Right: String): Integer
      begin
        Result := CompareText(Left.Substring(2,1), Right.Substring(2,1));
        if Result = 0 then
          Result := CompareText(Left.Substring(0,2), Right.Substring(0,2));
      end;
    summary.Sort(TComparer<String>.Construct(Comparison));

    // format summary report
    Result := Format(
      'ARRL FD - Call History Distribution by Classification (%d calls/dot)' +
      sLineBreak, [CallsPerDot]);
    for var S : String in summary do
      if S.StartsWith('0') then
        Result := Result + S.Replace('0', ' ', []) + sLineBreak
      else
        Result := Result + S + sLineBreak;

  finally
    dist.Free;
    summary.Free;
  end;
end;
{$endif}


class function TFdCallRec.compareCall(const left, right: TFdCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TFdCallRec.GetString: string; // returns 3A OR [club name]
begin
  Result := Format(' - %s %s %s', [StnClass, Section, UserText]);
end;


function TFdCallRec.GetTxCnt : integer;
var
  L : integer;
begin
  for L := 1 to length(Self.StnClass) do
    if Pos(copy(StnClass,L,1),'0123456789') = 0 then break;
  Result := StnClass.Substring(0, L-1).ToInteger;
end;


initialization
  IntegerComparer := TComparer<Integer>.Default;


end.



