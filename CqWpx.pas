unit CQWPX;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Contest, CallLst, DxStn;

type
TCqWpx = class(TContest)
private
  // CQ Wpx Contest uses the global Calls variable (see CallLst.pas)
  CallLst : TCallList;

public
  constructor Create;
  destructor Destroy; override;
  procedure LoadCallHistory(const AUserCallsign : string); override;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id:integer): string; override;     // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;

  function getExch1(id:integer): string;    // returns RST (e.g. 5NN)
  function getExch2(id:integer): string;    // returns section info (e.g. 3)
  {function getZone(id:integer): string;     // returns CQZone (e.g. 3)
  function FindCallRec(out fdrec: TCqWpxCallRec; const ACall: string): Boolean;
  }
  function GetStationInfo(const ACallsign: string) : string; override;
end;

implementation

uses
  SysUtils, Classes, log, ARRL;

procedure TCqWpx.LoadCallHistory(const AUserCallsign : string);
begin
  CallLst.LoadCallList;
end;


constructor TCqWpx.Create;
begin
  inherited Create;
  CallLst := TCallList.Create;
end;


destructor TCqWpx.Destroy;
begin
  CallLst.Free;
  inherited;
end;


function TCqWpx.PickStation(): integer;
begin
  Result := -1;
end;


procedure TCqWpx.DropStation(id : integer);
begin
  // already deleted by GetCall
end;


// return status bar information string from DXCC data file.
// the callsign, Entity and Continent are returned.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - Entity/Continent'
function TCqWpx.GetStationInfo(const ACallsign: string) : string;
var
  dxrec : TDXCCRec;
begin
  dxrec := nil;
  Result := '';

  // find caller's Continent/Entity
  if gDXCCList.FindRec(dxrec, ACallsign) then
    Result := Format('%s - %s/%s', [ACallsign, dxRec.Continent, dxRec.Entity]);
end;


function TCqWpx.GetCall(id : integer): string;     // returns station callsign
begin
  Result := CallLst.PickCall;
end;


procedure TCqWpx.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);  // RST
  station.NR := station.Oper.GetNR;           // serial number
end;



function TCqWpx.getExch1(id:integer): string;    // returns RST (e.g. 5NN)
begin
  result := '599';
end;


function TCqWpx.getExch2(id:integer): string;    // returns serial number (e.g. 3)
begin
  Result := '1';
end;


end.



