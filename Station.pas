//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Station;

{$MODE Delphi}

interface

uses
  SysUtils, Classes, Math, SndTypes, Ini, MorseKey, LazLoggerBase;

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

    NR, RST: integer;
    MyCall, HisCall: string;

    Exch1: string;  // Exchange field 1 (e.g. class, name, etc.)
    Exch2: string;  // Exchange field 2 (e.g. zone, state/prov, section, grid, etc.)
    UserText: string; // club name or description (from fdHistory file)
    Msg: TStationMessages;
    MsgText: string;

    constructor CreateStation;

    procedure Tick;
    function IsLastBlock : boolean;
    function GetBlock: TSingleArray; virtual;
    procedure ProcessEvent(AEvent: TStationEvent); virtual; abstract;

    procedure SendMsg(AMsg: TStationMessage); virtual;
    procedure SendText(AMsg: string); virtual;
    procedure SendMorse(AMorse: string);

    property Pitch: integer read FPitch write SetPitch;
    property Bfo: Single read GetBfo;
  end;

function DbgS(const msg : TStationMessage) : string; overload;
function DbgS(const state : TStationState) : string; overload;
function DbgS(const event : TStationEvent) : string; overload;
function DbgS(const station : TStation)    : string; overload;

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


// return whether the next block is the last block in current Envelope
function TStation.IsLastBlock : boolean;
begin
  Result := ((SendPos + Ini.BufSize) = Length(Envelope)) or
            (Timeout = 1);
end;

function TStation.GetBlock: TSingleArray;
begin
  //DebugLn('TStation(%s).GetBlock', [MyCall]);
  Result := Copy(Envelope, SendPos, Ini.BufSize);

  //advance TX buffer
  Inc(SendPos, Ini.BufSize);
  if SendPos = Length(Envelope) then Envelope := nil;
end;


procedure TStation.SendMsg(AMsg: TStationMessage);
begin
  try
  DebugLnEnter('TStation(%s).SendMsg %s', [MyCall, DbgS(AMsg)]);
  if Envelope = nil then Msg := [];
  if AMsg = msgNone then begin State := stListening; Exit; End;
  Include(Msg, AMsg);
  if Ini.Standalone = True then
  begin
  case AMsg of
    msgCQ:
      begin
        if SimContest = scFieldDay then
          SendText('CQ FD <my>')
        else
          SendText('CQ <my>');
      end;
    msgNR: SendText('<#>');
    msgTU: SendText('TU <my>');
    msgMyCall: SendText('<my>');
    msgHisCall: SendText('<his>');
    msgB4: SendText('QSO B4');
    msgQm: SendText('?');
    msgNil: SendText('NIL');
    msgR_NR: SendText('R <#>');
    msgR_NR2: SendText('R <#> <#>');
    msgDeMyCall1: SendText('DE <my>');
    msgDeMyCall2: SendText('DE <my> <my>');
    msgDeMyCallNr1: SendText('DE <my> <#>');
    msgDeMyCallNr2: SendText('DE <my> <my> <#>');
    msgMyCallNr2: SendText('<my> <my> <#>');
    msgNrQm: SendText('NR?');
    msgLongCQ: SendText('CQ CQ TEST <my> <my>');
    msgQrl: SendText('QRL?');
    msgQrl2: SendText('QRL?   QRL?');
    msqQsy: SendText('<his>  QSY QSY');
    msgAgn: SendText('AGN');
    end;
  end
  else  //controlled by N1MM or DXLog
  begin
  // raise Exception.Create('in Tstation.SendMsg');
  case AMsg of
    msgCQ:
      begin
        if Ini.Messagecq = 'CQ' then
        begin
          if SimContest = scFieldDay then
            Ini.Messagecq := 'CQ FD '+ Ini.Call
          else
            Ini.Messagecq := 'CQ '+ Ini.Call;
        end;
        SendText(Ini.Messagecq);
      end;
    msgNR:
      begin
        if SimContest = scFieldDay then
          SendText('R <#>')
        else
          SendText('<#>');
      end;
    msgTU: SendText(Ini.Messagetu);
    msgMyCall: SendText('<my>');
    msgHisCall: SendText('<his>');
    msgB4: SendText('QSO B4');
    msgQm: SendText('?');
    msgNil: SendText('NIL');
    msgR_NR: SendText('R <#>');
    msgR_NR2: SendText('R <#> <#>');
    msgDeMyCall1: SendText('DE <my>');
    msgDeMyCall2: SendText('DE <my> <my>');
    msgDeMyCallNr1: SendText('DE <my> <#>');
    msgDeMyCallNr2: SendText('DE <my> <my> <#>');
    msgMyCallNr2: SendText('<my> <my> <#>');
    msgNrQm: SendText('NR?');
    msgLongCQ:
      begin
        if SimContest = scFieldDay then
          SendText('CQ CQ FD <my> <my>')
        else
          SendText('CQ CQ TEST <my> <my>');
      end;
    msgQrl: SendText('QRL?');
    msgQrl2: SendText('QRL?   QRL?');
    msqQsy: SendText('<his>  QSY QSY');
    msgAgn: SendText('AGN');
    end;
  end;
  finally
    DebugLnExit([]);
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
  DebugLn('TStation(%s).SendText -> ''%s''', [MyCall, MsgText]);
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
  for i:=0 to High(Envelope) do Envelope[i] := Envelope[i] * Amplitude;

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
  //DebugLn('TStation(%s).Tick: State=%s', [MyCall, DbgS(State)]);
  //just finished sending
  if (State = stSending) and (Envelope = nil) then
    begin
    DebugLnEnter('TStation(%s).Tick: State=%s, finished sending, now stListening',
                 [MyCall, DbgS(State)]);
    MsgText := '';
    State := stListening;
    ProcessEvent(evMsgSent);
    DebugLnExit([]);
    end

  //check timeout
  else if State <> stSending then
    begin
    if TimeOut > -1 then Dec(TimeOut);
    if TimeOut = 0 then
      begin
      DebugLnEnter('TStation(%s).Tick: State=%s, Timeout = 0', [MyCall, DbgS(State)]);
      ProcessEvent(evTimeout);
      DebugLnExit([]);
      end;
    end;
end;


                                                
function TStation.NrAsText: string;
var
  Idx: integer;
begin
  if SimContest = scFieldDay then
      Result := Format('%s %s', [Exch1, Exch2])
  else
      // Result := Format('%d%.2d', [RST, NR]);
      Result := Format('%d%d', [RST, NR]);


  if NrWithError then
    begin
    Idx := Length(Result);
    if not (Result[Idx] in ['2'..'7']) then Dec(Idx);
    if Result[Idx] in ['2'..'7'] then
      begin
      if Random < 0.5 then Dec(Result[Idx]) else Inc(Result[Idx]);
      Result := Result + Format('EEEEE %.3d', [NR]);
      end;
    NrWithError := false;
    end;

  if Ini.ActiveContestExchType1 = etRST then
    Result := StringReplace(Result, '599', '5NN', [rfReplaceAll]);

  if (Ini.RunMode <> rmHst) and (ActiveContestExchType2 in
    [etSerialNr, etCqZone, etItuZone, etAge, etPower]) then
    begin
    Result := StringReplace(Result, '000', 'TTT', [rfReplaceAll]);
    Result := StringReplace(Result, '00', 'TT', [rfReplaceAll]);
//
//    if Random < 0.4
//      then Result := StringReplace(Result, '0', 'O', [rfReplaceAll])
//    else if Random < 0.97
//      then Result := StringReplace(Result, '0', 'T', [rfReplaceAll]);
//
//    if Random < 0.97
//      then Result := StringReplace(Result, '9', 'N', [rfReplaceAll]);
//    end;

    Result := StringReplace(Result, '0', 'T', [rfReplaceAll]);
    Result := StringReplace(Result, '1', 'A', [rfReplaceAll]);
    Result := StringReplace(Result, '9', 'N', [rfReplaceAll]);
    end;
  end;


function DbgS(const msg : TStationMessage) : string; overload;
begin
  WriteStr(Result, msg);
end;

function DbgS(const state : TStationState) : string; overload;
begin
  WriteStr(Result, state);
end;

function DbgS(const event : TStationEvent) : string; overload;
begin
  WriteStr(Result, event);
end;

function DbgS(const station : TStation)    : string; overload;
begin
  Result:= Format('TStation(%s)', [station.MyCall]);
end;


end.

