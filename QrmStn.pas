//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit QrmStn;

interface

uses
  Station;

type
  TQrmStation = class(TStation)
  private
    Patience: integer;
  public
    constructor CreateStation;
    procedure ProcessEvent(AEvent: TStationEvent); override;
  end;

implementation

uses
  SysUtils, Classes, RndFunc, Ini, CallLst,
  Contest;

constructor TQrmStation.CreateStation;
begin
  inherited Create(nil);
  inherited Init;

  Patience := 1 + Random(5);
  MyCall := Tst.PickCallOnly;
  HisCall := Ini.Call;
  Amplitude := 5000 + 25000 * Random;
  Pitch := Round(RndGaussLim(0, 300));
  WpmS := 30 + Random(20);
  WpmC := WpmS;

  // DX's sent exchange types depends on kind-of-station and their callsign
  SentExchTypes:= Tst.GetSentExchTypes(skDxStation, MyCall);

  case Random(7) of
    0: SendMsg(MsgQrl);
    1,2: SendMsg(MsgQrl2);
    3,4,5: SendMsg(msgLongCQ);
    6: SendMsg(MsqQsy);
    end;
end;


procedure TQrmStation.ProcessEvent(AEvent: TStationEvent);
begin
  case AEvent of
    evMsgSent:
      begin
      Dec(Patience);
      if Patience = 0
        then Free
        else Timeout := Round(RndGaussLim(SecondsToBlocks(4), 2));
      end;
    evTimeout:
      SendMsg(msgLongCQ);
    end;
end;

end.

