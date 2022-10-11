//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Station;

interface

uses
  SysUtils, Classes, Math, SndTypes, Ini, MorseKey;

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

    // Exchange fields...
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

implementation

{ TStation }

constructor TStation.CreateStation;
begin
  inherited Create(nil);
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


                                                
function TStation.NrAsText: string;
var
  Idx: integer;
begin
  // Adding a contest: TStation.NrAsText(), converts <#> to exchange (usually '<exch1> <exch2>'). Inject LID errors.
  case SimContest of
    scCQWW:
      Result := Format('%d %d', [RST, NR]);
    scCwt:
      Result := Format('%s  %.d', [OpName, NR]);
    scFieldDay:
      Result := Format('%s %s', [Exch1, Exch2]);
    scNaQp:
      Result := Format('%s %s', [Exch1, Exch2]);
    else
      Result := Format('%d%.3d', [RST, NR]);
  end;

  if NrWithError and (ActiveContest.ExchType2 = etSerialNr) then
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

  if Ini.ActiveContest.ExchType1 = etRST then
     Result := StringReplace(Result, '599', '5NN', [rfReplaceAll]);
  if (Ini.RunMode <> rmHst) and (ActiveContest.ExchType2 in
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

