//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit DxStn;

{$MODE Delphi}

interface

uses
  SysUtils, Classes, Station, RndFunc, Ini, ARRLFD,
  LazLoggerBase,
  CallLst, Qsb, DxOper, Log, SndTypes;

type
  TDxStation = class(TStation)
  private
    Qsb: TQsb;
  public
    Oper: TDxOperator;
    constructor CreateStation;
    destructor Destroy; override;
    procedure ProcessEvent(AEvent: TStationEvent); override;
    procedure SendMsg(AMsg: TStationMessage); override;
    procedure DataToLastQso;
    function GetBlock: TSingleArray; override;
  var
     Operid: integer;
  end;

function DbgS(const station : TDxStation)    : string; overload;

implementation

uses
  Contest;

{ TDxStation }

var callzone: string;
    stringlist: TStringList;

constructor TDxStation.CreateStation;
begin
  inherited Create(nil);
  stringlist := TStringList.Create;
  stringlist.Delimiter := ';';
try
  HisCall := Ini.Call;

  if Ini.ContestName = 'arrlfd' then
  begin
    Operid := gARRLFD.pickStation();
    MyCall := gARRLFD.getCall(Operid);
  end
  else
  begin
    callzone := PickCallAndZone;
    stringlist.DelimitedText := callzone;  // Pick one Callsign from Calllist
    MyCall := stringlist[0];
  end;

  Oper := TDxOperator.Create;
  Oper.Call := MyCall;
  Oper.Skills := 1 + Random(3); //1..3
  Oper.SetState(osNeedPrevEnd);
  NrWithError := Ini.Lids and (Random < 0.1);

  Wpm := Oper.GetWpm;
  If Ini.ContestName = 'cqwpx' then
  begin
      NR := Oper.GetNR;
  end
  else if Ini.ContestName = 'arrlfd' then
  begin
    Exch1 := gARRLFD.getExch1(Operid);
    Exch2 := gARRLFD.getExch2(Operid);
    UserText := gARRLFD.getUserText(Operid);
  end
  else
  begin
       NR := StrToInt(stringlist[1]);  // store Zone in Station.NR
  end;
  //if LeftStr(Oper.Call, 1) = 'K' then
  //begin
  //NR := Random(3) + 3;
  //end
  //else if LeftStr(Oper.Call, 1) = 'W' then
  //begin
  //NR := Random(3) + 3;
  //end
  //else if LeftStr(Oper.Call, 1) = 'N' then
  //begin
  //NR := Random(3) + 3;
  //end
  //else if LeftStr(Oper.Call, 1) = 'A' then
  //begin
  //NR := Random(3) + 3;
  //end;

  if Ini.Lids and (Random < 0.03)
    then RST := 559 + 10*Random(4)
    else RST := 599;

  Qsb := TQsb.Create;

  Qsb.Bandwidth := 0.1 + Random / 2;
  if Ini.Flutter and (Random < 0.3) then Qsb.Bandwidth := 3 + Random * 30;

  Amplitude := 9000 + 18000 * (1 + RndUShaped);
  Pitch := Round(RndGaussLim(0, 300));

  //the MeSent event will follow immediately
  TimeOut := NEVER;
  State := stCopying;

  DebugLn('TDxStation.CreateStation -> %s, amplitude %f, pitch %d', [MyCall, Amplitude, Pitch]);
finally
  FreeAndNil(stringlist);
end;
end;


destructor TDxStation.Destroy;
begin
  Oper.Free;
  Qsb.Free;
  inherited;
end;


procedure TDxStation.ProcessEvent(AEvent: TStationEvent);
var
  i: integer;
begin
try
  DebugLnEnter('TDxStation(%s).ProcessEvent: %s, %s',
               [MyCall, DbgS(AEvent), DbgS(State)]);

  if Oper.State = osDone then Exit;

  case AEvent of
    evMsgSent:
      //we finished sending and started listening
      if Tst.Me.State = stSending
        then TimeOut := NEVER
        else TimeOut := Oper.GetReplyTimeout;

    evTimeout:
      begin
      //he did not reply, quit or try again
      if State = stListening then
        begin
        Oper.MsgReceived([msgNone]);
        if Oper.State = osFailed then begin Free; Exit; end;
        State := stPreparingToSend;
        end;
      //preparations to send are done, now send
      if State = stPreparingToSend then
         begin
         if Oper.RepeatCnt>1 then DebugLn('repeat %d msgs...', [Oper.RepeatCnt]);
         for i:=1 to Oper.RepeatCnt do
             SendMsg(Oper.GetReply);
         end;
      end;

    evMeFinished: //he finished sending
      //we notice the message only if we are not sending ourselves
      if State <> stSending then
        begin
        //interpret the message
        case State of
          stCopying:
            Oper.MsgReceived(Tst.Me.Msg);

          stListening, stPreparingToSend:
           //these messages can be copied even if partially received
            if (msgCQ in Tst.Me.Msg) or (msgTU in Tst.Me.Msg) or (msgNil in Tst.Me.Msg)
              then Oper.MsgReceived(Tst.Me.Msg)
              else Oper.MsgReceived([msgGarbage]);
          end;

          //react to the message
          if Oper.State = osFailed
            then begin Free; Exit; end         //give up
            else TimeOut := Oper.GetSendDelay; //reply or switch to standby
          State := stPreparingToSend;
        end;

    evMeStarted:
      //If we are not sending, we can start copying
      //Cancel timeout, he is replying
      begin
      if State <> stSending then State := stCopying;
      TimeOut := NEVER;
      end;
    end;
finally
  //DebugLnExit('  --> new State = %s', [DbgS(State)]);
  DebugLnExit([]);
  end;
end;


// override SendMsg to allow Dx Stations to send alternate field day messages
// (SECT?, CLASS?, CL?) whenever a 'NR?' message (msgNrQm) is sent.
procedure TDxStation.SendMsg(AMsg: TStationMessage);
begin
  if (SimContest = scFieldDay) and
    (AMsg = msgNrQm) then
    begin
      DebugLnEnter('TDxStation(%s).SendMsg %s', [MyCall, DbgS(AMsg)]);
      case Random(5) of
        0,1: SendText('NR?');
        2: SendText('SECT?');
        3: SendText('CLASS?');
        4: SendText('CL?');
      end;
      DebugLnExit([]);
    end
  else
    inherited SendMsg(AMsg);
end;


// copies data from this DxStation to top of QsoList[].
// removes Self from Stations[] container array.
procedure TDxStation.DataToLastQso;
begin
  DebugLn('TxDxStation.DataToLastQso: ', DbgS(Self));
  with QsoList[High(QsoList)] do
    begin
    TrueCall := Self.MyCall;
    TrueRst := Self.Rst;
    TrueNR := Self.NR;
    TrueStnClass := Self.Exch1; //StnClass; // mikeb - todo
    TrueSection := Self.Exch2;  //Section;
    end;

  Free; // removes Self from Stations[] container
end;




function TDxStation.GetBlock: TSingleArray;
begin
  if IsLastBlock then DebugLn('TDxStation(%s).GetBlock', [MyCall]);
  Result := inherited GetBlock;
  if Ini.Qsb then Qsb.ApplyTo(Result);
end;


function DbgS(const station : TDxStation)    : string; overload;
begin
  Result:= Format('TDxStation(%s)', [station.MyCall]);
end;

end.

