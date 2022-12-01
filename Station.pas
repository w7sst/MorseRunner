//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Station;

interface

uses
  Classes, SndTypes, Ini;

const
  NEVER = MAXINT;

type
  TStationMessage =  (msgNone, msgCQ, msgNR, msgTU, msgMyCall, msgHisCall,
    msgB4, msgQm, msgNil, msgGarbage, msgR_NR, msgR_NR2, msgDeMyCall1, msgDeMyCall2,
    msgDeMyCallNr1, msgDeMyCallNr2, msgNrQm, msgLongCQ, msgMyCallNr2,
    msgQrl, msgQrl2, msqQsy, msgAgn);

  TStationMessages = set of TStationMessage;
  TStationState = (stListening, stCopying, stPreparingToSend, stSending);
  TStationEvent = (evTimeout, evMsgSent, evMeStarted, evMeFinished);

  // TStationKind identifies whether the station is the simulated home
  // station or a remote DX station within the context of the simulation.
  TStationKind = (skMyStation, skDxStation);

  // Requested message type used to query sent or received dynamic message types.
  // Used in TContest.GetSentExchTypes() and TContest.GetRecvExchTypes().
  TRequestedMsgType = (mtSendMsg, mtRecvMsg);

  // Exchange Field types
  TExchTypes = record
    Exch1: TExchange1Type;  // Exchange field 1 type
    Exch2: TExchange2Type;  // Exchange field 2 type

    class operator Equal(const a,b: TExchTypes) : Boolean;
  end;

  TStation = class (TCollectionItem)
  private
    FBfo: Single;
    dPhi: Single;
    FPitch: integer;
    function GetBfo: Single;
    procedure SetPitch(const Value: integer);
  protected
    SendPos: integer;
    TimeOut: integer;
    NrWithError: boolean;
    function NrAsText: string;
  public
    Amplitude: Single;
    Wpm: integer;
    Envelope: TSingleArray;
    State: TStationState;

    // Sent Exchange field types...
    // Sent Exchange information is contest-specific and depends on contest,
    // user's QTH/location (based on callsign & prefix), and whether the user's
    // station is local/DX relative to the contest.
    // This value is set by calling the virtual TContest.GetSentExchTypes()
    // function. See TArrlDx.GetExchangeTypes() for additional information.
    SentExchTypes : TExchTypes;

    // Sent Exchange fields...
    // Adding a contest: try to use the generalized Exch1 and Exch2 instead of new fields.
    // TODO - continue to generalize the notion of Exch1 and Exch2 for all contests.
    NR, RST: integer;
    MyCall, HisCall: string;
    OpName: string;
    CWOPSNR: integer;
    Exch1: string;  // Exchange field 1 (e.g. class, name, etc.)
    Exch2: string;  // Exchange field 2 (e.g. zone, state/prov, section, grid, etc.)
    UserText: string; // club name or description (from fdHistory file)

    Msg: TStationMessages;
    MsgText: string;

    constructor CreateStation;

    procedure Tick;
    function GetBlock: TSingleArray; virtual;
    procedure ProcessEvent(AEvent: TStationEvent); virtual; abstract;

    procedure SendMsg(AMsg: TStationMessage); virtual;
    procedure SendText(AMsg: string); virtual;
    procedure SendMorse(AMorse: string);

    property Pitch: integer read FPitch write SetPitch;
    property Bfo: Single read GetBfo;
  end;

const
  ExchTypesUndef : TExchTypes = (
    Exch1: TExchange1Type(-1);
    Exch2: TExchange2Type(-1);
  );

implementation

uses
  SysUtils, Math, MorseKey, Contest;


{ TExchTypes }

class operator TExchTypes.Equal(const a,b: TExchTypes) : Boolean;
begin
  Result:= (a.Exch1 = b.Exch1) and (a.Exch2 = b.Exch2);
end;


{ TStation }

constructor TStation.CreateStation;
begin
  inherited Create(nil);

  SentExchTypes:= ExchTypesUndef;
end;


function TStation.GetBfo: Single;
begin
  Result := FBfo;
  FBfo := FBfo + dPhi;
  if FBfo > TWO_PI then FBfo := FBfo - TWO_PI;
end;


function TStation.GetBlock: TSingleArray;
begin
  Result := Copy(Envelope, SendPos, Ini.BufSize);

  //advance TX buffer
  Inc(SendPos, Ini.BufSize);
  if SendPos = Length(Envelope) then Envelope := nil;
end;


procedure TStation.SendMsg(AMsg: TStationMessage);
begin
  if Envelope = nil then Msg := [];
  if AMsg = msgNone then begin State := stListening; Exit; End;
  Include(Msg, AMsg);

  case AMsg of
    msgCQ: begin
      // Adding a contest: TStation.SendMsg(msgCQ): send CQ message (e.g. CQ FD <my>)
      case SimContest of
        scCwt: SendText('CQ CWT <my>');
        scFieldDay: SendText('CQ FD <my>');
        else SendText('CQ <my> TEST');
      end;
    end;
    msgNR: SendText('<#>');
    msgTU: SendText('TU');
    msgMyCall: SendText('<my>');
    msgHisCall: SendText('<his>');
    msgB4: SendText('QSO B4');
    msgQm: SendText('?');
    msgNil: SendText('NIL');
    msgR_NR: begin
      // Adding a contest: TStation.SendMsg(msgR_NR): send 'R <#>' message, where # is exch (e.g. 3A OR)
      case SimContest of
        scCwt: SendText('<#>')
      else
        SendText('R <#>');
      end;
    end;
    msgR_NR2: begin
      // Adding a contest: TStation.SendMsg(msgR_NR2): send 'R <#> <#>' message, where # is exch (e.g. 3A OR)
      case SimContest of
        scCwt: SendText('<#>')
      else
        SendText('R <#> <#>');
      end;
    end;
    msgDeMyCall1: SendText('DE <my>');
    msgDeMyCall2: SendText('DE <my> <my>');
    msgDeMyCallNr1: SendText('DE <my> <#>');
    msgDeMyCallNr2: SendText('DE <my> <my> <#>');
    msgMyCallNr2: SendText('<my> <my> <#>');
    msgNrQm: SendText('NR?');
    msgLongCQ:
      begin
        case SimContest of
          scFieldDay: SendText('CQ CQ FD <my> <my>')
        else
          SendText('CQ CQ TEST <my> <my> TEST');
        end;
      end;
    msgQrl: SendText('QRL?');
    msgQrl2: SendText('QRL?   QRL?');
    msqQsy: SendText('<his>  QSY QSY');
    msgAgn: SendText('AGN');
    end;
end;

procedure TStation.SendText(AMsg: string);
begin
  if Pos('<#>', AMsg) > 0 then
    begin
    //with error
    AMsg := StringReplace(AMsg, '<#>', NrAsText, []);
    //error cleared
    AMsg := StringReplace(AMsg, '<#>', NrAsText, [rfReplaceAll]);
    end;

  AMsg := StringReplace(AMsg, '<my>', MyCall, [rfReplaceAll]);

{
  if CallsFromKeyer
     then AMsg := StringReplace(AMsg, '<his>', ' ', [rfReplaceAll])
     else AMsg := StringReplace(AMsg, '<his>', HisCall, [rfReplaceAll]);
}

  if MsgText <> ''
    then MsgText := MsgText + ' ' + AMsg
    else MsgText := AMsg;
  SendMorse(Keyer.Encode(MsgText));
end;


procedure TStation.SendMorse(AMorse: string);
var
  i: integer;
begin
  if Envelope = nil then
    begin
    SendPos := 0;
    FBfo := 0;
    end;
    
  Keyer.Wpm := Wpm;
  Keyer.MorseMsg := AMorse;
  Envelope := Keyer.Envelope;
  for i:=0 to High(Envelope) do
    Envelope[i] := Envelope[i] * Amplitude;

  State := stSending;
  TimeOut := NEVER;
end;



procedure TStation.SetPitch(const Value: integer);
begin
  FPitch := Value;
  dPhi := TWO_PI * FPitch / DEFAULTRATE;
end;


procedure TStation.Tick;
begin
  //just finished sending
  if (State = stSending) and (Envelope = nil) then
    begin
    MsgText := '';
    State := stListening;
    ProcessEvent(evMsgSent);
    end

  //check timeout
  else if State <> stSending then
    begin
    if TimeOut > -1 then Dec(TimeOut);
    if TimeOut = 0 then ProcessEvent(evTimeout);
    end;
end;


                                                
{
  This function formats the exchange string to be sent by this station
  by combining exchange fields 1 and 2.
}
function TStation.NrAsText: string;
var
  Idx: integer;
begin
  // Adding a contest: TStation.NrAsText(), converts <#> to exchange (usually '<exch1> <exch2>'). Inject LID errors.
  case SimContest of
    scCQWW:
      Result := Format('%s %d', [Exch1, NR]);     // <RST> <serial#>
    scCwt:
      Result := Format('%s  %.d', [OpName, NR]);
    scFieldDay:
      Result := Format('%s %s', [Exch1, Exch2]);
    scNaQp, scArrlDx:
      Result := Format('%s %s', [Exch1, Exch2]);
    else
      Result := Format('%d%.3d', [RST, NR]);
  end;

  if NrWithError and (SentExchTypes.Exch2 = etSerialNr) then
    begin
    Idx := Length(Result);
    if not CharInSet(Result[Idx], ['2'..'7']) then
      Dec(Idx);
    if CharInSet(Result[Idx], ['2'..'7']) then begin
      if Random < 0.5 then
        Dec(Result[Idx])
      else
        Inc(Result[Idx]);
      Result := Result + Format('EEEEE %.3d', [NR]);
    end;
    NrWithError := false;
    end;

  if SentExchTypes.Exch1 = etRST then
     begin
     if (Ini.RunMode <> rmHST) and (Random < 0.05) then
       Result := StringReplace(Result, '599', 'ENN', [rfReplaceAll]);
     Result := StringReplace(Result, '599', '5NN', [rfReplaceAll]);
     end;
  if (Ini.RunMode <> rmHst) and (SentExchTypes.Exch2 in
    [etSerialNr, etCqZone, etItuZone, etAge, etPower]) then
    begin
    Result := StringReplace(Result, '000', 'TTT', [rfReplaceAll]);
    Result := StringReplace(Result, '00', 'TT', [rfReplaceAll]);

    if Random < 0.4
      then Result := StringReplace(Result, '0', 'O', [rfReplaceAll])
    else if Random < 0.97
      then Result := StringReplace(Result, '0', 'T', [rfReplaceAll]);

    if Random < 0.97
      then Result := StringReplace(Result, '9', 'N', [rfReplaceAll]);
    end;
end;

end.

