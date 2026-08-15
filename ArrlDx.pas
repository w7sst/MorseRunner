//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ARRLDX;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Defaults, Generics.Collections, Classes, DualExchContest, DxStn,
  ArrlDx.Types,
  Log;

type
  TArrlDx = class(TDualExchContest)
  private
    ArrlDxCallList: TObjectList<TArrlDxCallRec>;
    Comparer: IComparer<TArrlDxCallRec>;

  protected
    function GetCallHistoryCount: Integer; override;

  public
    constructor Create;
    destructor Destroy; override;
    function LoadCallHistory(const AUserCallsign : string) : boolean; override;
    function OnSetMyCall(const AUserCallsign : string; out err : string) : boolean; override;
    function PickStation(): integer; override;
    procedure DropStation(id : integer); override;
    function GetCall(id:integer): string; override;  // returns station callsign
    procedure GetExchange(id : integer; station : TDxStation); override;

    function getExch1(id:integer): string;    // returns default RST value
    function getExch2(id:integer): string;    // returns State/Prov (US/Canada) or Power (DX)
    function getUserText(id:integer): string; // returns optional club name
    function IsNum(Num: String): Boolean;
    function FindCallRec(out dxrec: TArrlDxCallRec; const ACall: string): Boolean;
    function GetStationInfo(const ACallsign : string) : string; override;
    function ExtractMultiplier(Qso: PQso) : string; override;
  end;


implementation

uses
  SysUtils, DXCC, CallLst,
  ExchFields,
  ContestFileFormat,
  ContestFileReader,        // for TRecordConsumer<>
  ArrlDx.Reader,
  AppPaths,
  Ini, Main;


constructor TArrlDx.Create;
begin
  inherited Create(etRST, etStateProv,  // US/CA station exchange
                   etRST, etPower);     // DX station exchange
  ArrlDxCallList:= TObjectList<TArrlDxCallRec>.Create;
  Comparer := TComparer<TArrlDxCallRec>.Construct(TArrlDxCallRec.compareCall);
end;


destructor TArrlDx.Destroy;
begin
  FreeAndNil(ArrlDxCallList);
  inherited;
end;


// load call history file iff user's callsign has changed.
// for US/CA calls, load DX callsigns; for DX calls, load US/CA calls.
function TArrlDx.LoadCallHistory(const AUserCallsign: string) : boolean;
var
  Reader: TArrlDxContestFileReader;
  FileName: String;
begin
  Reader := TArrlDxContestFileReader.Create(Self.HomeCallIsLocal);

  try
    ArrlDxCallList.Clear;

    FileName := 'ARRLDXCW_USDX.txt';

    Reader.ReadFile(TAppPaths.ContestDataFile(FileName),
      procedure(rec: TArrlDxCallRec)
      begin
        ArrlDxCallList.Add(rec);
      end);

    ArrlDxCallList.Sort(Self.Comparer);
    Result := True;

  finally
    Reader.Free;
  end;
end;


function TArrlDx.GetCallHistoryCount: Integer;
begin
  Result := Self.ArrlDxCallList.Count;
end;


{
  OnSetMyCall is overriden for ARRL DX Contest to determine whether user's
  callsign is within US/CA. In other words, is the user's station within the
  home region of this contest?

  Sets TDualExchContest.HomeCallIsLocal. Used by GetExchangeTypes() to
  determine sent messages types (US/CA send State/Province; DX sends Power).
}
function TArrlDx.OnSetMyCall(const AUserCallsign : string;
  out err : string) : boolean;
var
  dxcc: TDxCCRec;
begin
  Result:= True;
  err:= '';

  // select calls based on location of user's station (US/CA work only DX)
  if gDxCCList.FindRec(dxcc, AUserCallsign) then
    // Is home call local to contest (i.e. a W/VE Station)?
    HomeCallIsLocal := dxcc.Entity.Equals('United States of America') or
                       dxcc.Entity.Equals('Canada')
  else
    begin
      // report an error
      err := Format('Error: ''%s'' is not recognized as a valid DXCC callsign.',
        [AUserCallsign]);

      // for the error case, make a best-guess effort to determine US/VE
      HomeCallIsLocal := AUserCallsign.StartsWith('A') or
                         AUserCallsign.StartsWith('K') or
                         AUserCallsign.StartsWith('N') or
                         AUserCallsign.StartsWith('W') or
                         AUserCallsign.StartsWith('VE');
      Result := False;
    end;

  // call baseclass to update Me.MyCall and Me.SentExchTypes
  if not inherited OnSetMyCall(AUserCallsign, err) then
    Result:= False;
end;


function TArrlDx.PickStation(): integer;
var
  dxcc: TDxCCRec;
begin
  result := random(ArrlDxCallList.Count);
  while (ArrlDxCallList.Count > 1) do
    begin
      // Keep stations that have a valid DXCC entry
      if gDXCCList.FindRec(dxcc, ArrlDxCallList[result].Call) then
        break;

      // drop this station and try again
      DropStation(result);
      result := random(ArrlDxCallList.Count);
    end;
end;


procedure TArrlDx.DropStation(id : integer);
begin
  ArrlDxCallList.Delete(id)
end;


function TArrlDx.FindCallRec(out dxrec: TArrlDxCallRec; const ACall: string): Boolean;
var
  rec: TArrlDxCallRec;
{$ifdef FPC}
  index: int64;
{$else}
  index: integer;
{$endif}
begin
  rec := TArrlDxCallRec.Create();
  rec.Call := ACall;
  dxrec:= nil;
  try
    if ArrlDxCallList.BinarySearch(rec, index, Comparer) then
      dxrec:= ArrlDxCallList.Items[index];
  finally
    rec.Free;
  end;
  Result:= dxrec <> nil;
end;


// return status bar information string from call history file.
// for DX stations, their Entity and Continent is also included.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - <user text from ArrlDxCallHistoryFile> [- Entity/Continent]'
function TArrlDx.GetStationInfo(const ACallsign: string) : string;
var
  dxrec : TArrlDxCallRec;
  dxccrec : TDXCCRec;
  userText : string;
  dxEntity : string;
begin
  dxrec := nil;
  dxccrec := nil;
  userText := '';
  dxEntity := '';
  result:= '';

  if FindCallRec(dxrec, ACallsign) then
    begin
    userText:= dxrec.UserText;

    // if caller is DX station, include its Continent/Entity
    if Self.HomeCallIsLocal and gDXCCList.FindRec(dxccrec, ACallsign) then
      dxEntity:= dxccrec.Continent + '/' + dxccrec.Entity;
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


function TArrlDx.getCall(id:integer): string;     // returns station callsign
begin
  result := ArrlDxCallList.Items[id].Call;
end;


procedure TArrlDx.GetExchange(id : integer; station : TDxStation);
begin
  station.Exch1 := getExch1(id);
  station.Exch2 := getExch2(id);
  station.UserText := getUserText(id);
end;

function TArrlDx.getExch1(id:integer): string;    // returns default RST value
begin
  result := '599';
end;


function TArrlDx.getExch2(id:integer): string;    // returns State/Prov (US/Canada) or Power (DX)
begin
  result := ArrlDxCallList.Items[id].State +
            ArrlDxCallList.Items[id].Power;
end;


function TArrlDx.getUserText(id:integer): string; // returns optional club name
begin
  result := ArrlDxCallList.Items[id].UserText;
end;


{
  Extract multiplier string for ARRL DX Contest.

  ARRL DX Rules state: "Multiply total QSO points by the number of DXCC
  entities (W/VE stations) or states and provinces (DX stations) contacted
  to get your final score."

  Also sets contest-specific Qso.Points for this QSO.

  return either DXCC Entity string or US state or CA province.
}
function TArrlDx.ExtractMultiplier(Qso: PQso) : string;
var
  dxrec: TDXCCRec;
begin
  dxrec:= nil;
  Result:= '';

  Qso^.Points := 3;
  if Self.HomeCallIsLocal then
    begin
      if gDXCCList.FindRec(dxrec, Qso^.Call) then
        Result:= dxrec.Entity;
    end
  else
    Result:= Qso.Exch2;
end;


function TArrlDx.IsNum(Num: String): Boolean;
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


end.



