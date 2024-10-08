//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit QrnStn;

interface

uses
  Station;

type
  TQrnStation = class(TStation)
  public
    constructor CreateStation;
    procedure ProcessEvent(AEvent: TStationEvent); override;
  end;

implementation

uses
  Ini, RndFunc,
  ExchFields,
  Math;

constructor TQrnStation.CreateStation;
var
  i: integer;
  Dur: integer;
begin
  inherited Create(nil);

  // QrnStation doesn't send messages, so no call nor exchange types
  SentExchTypes.Exch1:= TExchange1Type(-1);
  SentExchTypes.Exch2:= TExchange2Type(-1);

  Dur := SecondsToBlocks(Random) * Ini.BufSize;
  SetLength(Envelope, Dur);
  Amplitude := 1E5*Power(10, 2*Random);
  for i:=0 to High(Envelope) do
    if Random < 0.01 then Envelope[i] := (Random-0.5) * Amplitude;

  State := stSending;
end;


procedure TQrnStation.ProcessEvent(AEvent: TStationEvent);
begin
  if AEvent = evMsgSent then Free;
end;

end.

