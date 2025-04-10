//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit StnColl;

interface

uses
  SysUtils, Classes, Station, DxStn, QrnStn, QrmStn;

type
  TStations = class(TCollection)
  private
    function GetItem(Index: Integer): TStation;
    function CallsignExists(const ACall: String) : Boolean;
  public
    constructor Create;
    //destructor Destroy; override;
    function AddCaller: TStation;
    function AddQrn: TStation;
    function AddQrm: TStation;
    property Items[Index: Integer]: TStation read GetItem; default;
  end;

implementation

{ TCallerCollection }


{ TStations }

constructor TStations.Create;
begin
  inherited Create(TStation);
end;


function TStations.GetItem(Index: Integer): TStation;
begin
  Result := (inherited GetItem(Index)) as TStation;
end;


function TStations.CallsignExists(const ACall: String) : Boolean;
var
  i: integer;
begin
  Result := False;
  for i:=Self.Count-1 downto 0 do begin
    Result := Self[i].MyCall = ACall;
    if Result then
      Break;
  end;
end;


{
  When adding a DxStation, make sure that we do not add a station whose
  callsign already exists in the TStations collection. This can be very
  confusing during debugging and during operation.
}
function TStations.AddCaller: TStation;
var
  cnt: integer;
begin
  cnt := 10;
  Result := nil;
  while Result = nil do
    begin
      Result := TDxStation.CreateStation;
      Dec(cnt);
      if Cnt = 0 then break;
      if CallsignExists(Result.MyCall) then
        FreeAndNil(Result);
    end;
  Result.Collection := Self;
end;


function TStations.AddQrn: TStation;
begin
  Result := TQrnStation.CreateStation;
  Result.Collection := Self;
end;


function TStations.AddQrm: TStation;
begin
  Result := TQrmStation.CreateStation;
  Result.Collection := Self;
end;




end.

