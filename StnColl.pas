//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit StnColl;

{$MODE Delphi}

interface

uses
  SysUtils, Classes, Station, DxStn, QrnStn, QrmStn;

type
  TStations = class(TCollection)
  private
    function GetItem(Index: Integer): TStation;
  public
    constructor Create;
    //destructor Destroy; override;
    function AddCaller: TStation;
    function AddQrn: TStation;
    function AddQrm: TStation;
    property Items[Index: Integer]: TStation read GetItem; default;
    function AnyLastBlock: Boolean;
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


function TStations.AddCaller: TStation;
begin
  Result := TDxStation.CreateStation;
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


function TStations.AnyLastBlock: Boolean;
var
  i : integer;
begin
  Result:= False;
  for i:=Count-1 downto 0 do
    if GetItem(i).IsLastBlock then
    begin
      Result:= True;
      Break;
    end;
end;

end.

