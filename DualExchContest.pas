//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit DualExchContest;

interface

uses
  Contest, Station, Ini;

type
  TDualExchContest = class(TContest)
  private

  protected
    HomeCallIsLocal: boolean; // user's callsign is local to this contest
    LocalTypes: TExchTypes;   // used when station is local-to-contest
    DxTypes: TExchTypes;      // used when station is dx-to-contest

    constructor Create(
      ALocalType1 : TExchange1Type;
      ALocalType2 : TExchange2Type;
      ADxType1 : TExchange1Type;
      ADxType2 : TExchange2Type);

  public
    function GetExchangeTypes(
      const AStationKind : TStationKind;
      const ARequestedMsgType : TRequestedMsgType;
      const ADxCallsign : string) : TExchTypes; override;

  end;

implementation

{ TDualExchContest }

constructor TDualExchContest.Create(
  ALocalType1 : TExchange1Type;
  ALocalType2 : TExchange2Type;
  ADxType1 : TExchange1Type;
  ADxType2 : TExchange2Type);
begin
  inherited Create;
  HomeCallIsLocal:= True;
  LocalTypes.Exch1:= ALocalType1;
  LocalTypes.Exch2:= ALocalType2;
  DxTypes.Exch1:= ADxType1;
  DxTypes.Exch2:= ADxType2;
end;


{
  returns exchange types for this contest. The exchange types are specified
  by the derived class and passed to the constructor.
  Self.HomeCallIsLocal is set by the derived OnSetMyCall.

  There are 3 variables to check:
    1) is user's home callsign on the local-side or DX-side of the contest?
    2) kind of (simulated) station, either MyStation or DxStation?
    3) what message type is requested (sent-type or receive-type)?

  The Karnough Map below shows the logic. Carefull study reveals that the
  'xor' logical operator can be used to implement this logic.

                             \  ARequestedMsgType
  HomeCall, StationKind       \ 0 (mtSendType)  | 1 (mtRecvType)
    00 (W/VE, MyStation)      |   etStateProv   |   etPower
    01 (W/VE, DxStation)      |   etPower       |   etStateProv
    11 (DX,   DxStation)      |   etStateProv   |   etPower
    10 (DX,   MyStation)      |   etPower       |   etStateProv
}
function TDualExchContest.GetExchangeTypes(
  const AStationKind : TStationKind;
  const ARequestedMsgType : TRequestedMsgType;
  const ADxCallsign : string) : TExchTypes;
var
  HomeCallIsDX: Boolean;
  IsSimDxStation: Boolean;
  IsRecvMsgRequest: Boolean;
begin
  HomeCallIsDX:= not Self.HomeCallIsLocal;
  IsSimDxStation:= AStationKind = skDxStation;
  IsRecvMsgRequest:= ARequestedMsgType = mtRecvMsg;
  if HomeCallIsDX xor IsSimDxStation xor IsRecvMsgRequest then
    Result := Self.DxTypes      // e.g. etPower for ARRL DX Contest
  else
    Result := Self.LocalTypes;  // e.g. etStateProv for ARRL DX Contest
end;


end.
