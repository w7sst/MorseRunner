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
    procedure Init;
    function NrAsText: string;
  public
    Amplitude: Single;
    WpmS: integer;          // Words per minute, sending speed (set by UI)
    WpmC: integer;          // Words per minute, character speed (set via .INI)
    Envelope: TSingleArray; // this station's digitized Envelope being sent
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
    Exch1: string;  // Exchange field 1 (e.g. class, name, etc.)
    Exch2: string;  // Exchange field 2 (e.g. zone, state/prov, section, grid, etc.)
    UserText: string; // club name or description (from fdHistory file)
    MsgTemp: string;  // hold a portion of the message (randomly generated once)

    Msg: TStationMessages;
    MsgText: string;  // this station's current message being sent

    constructor CreateStation;

    procedure Tick;
    function GetBlock: TSingleArray; virtual;
    procedure ProcessEvent(AEvent: TStationEvent); virtual; abstract;

    procedure SendMsg(AMsg: TStationMessage); virtual;
    procedure SendText(AMsg: string); virtual;
    procedure SendMorse(AMorse: string);

    function WpmAsText : string;

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
  Main,     // for Mainform.sbar.Caption, BDebugCwDecoder
  QrmStn,   // for TQrmStation.ClassType
  Contest,  // for Tst (TContest), Tst.Me.OpName
  StrUtils, // for PosEx
  SysUtils, Math, MorseKey;


{ TExchTypes }

class operator TExchTypes.Equal(const a,b: TExchTypes) : Boolean;
begin
  Result:= (a.Exch1 = b.Exch1) and (a.Exch2 = b.Exch2);
end;


{ TStation }

constructor TStation.CreateStation;
begin
  inherited Create(nil);

  Init;
end;


procedure TStation.Init;
begin
  SentExchTypes:= ExchTypesUndef;
  MsgTemp := 'undef';
end;


function TStation.GetBfo: Single;
begin
  Result := FBfo;
  FBfo := FBfo + dPhi;
  if FBfo > TWO_PI then FBfo := FBfo - TWO_PI;
end;


// returns the next block of 512 samples from this station's current Envelope.
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

  // during debug, use status bar to show CW stream
  if (AMsg = msgTU) and BDebugCwDecoder and not (self is TQrmStation) then
    Mainform.sbar.Caption:= '';

  // Create contest-specific messages...
  Tst.SendMsg(self, AMsg);
end;

{
  Handle station-specific messaging by replacing message tokens with
  their respective values. The resulting message is then passed to
  Keyer.Encode() and SendMorse().
}
procedure TStation.SendText(AMsg: string);
var
  P : integer;

  // Modifies AMsg by replacing AToken at position P with ANewText and
  // advances the token offset P to the start of the next token.
  // Successive occurances of the same token are replaced in one call.
  // Returns true when no additional tokens are available.
  function ReplaceTokenAt(
    var AMsg : string;      // in/out: message to be modified
    var P : integer;        // in/out: current token offset; advanced to next
    const AToken : string;  // token to be replaced
    const ANewText : string // NewText to replace token
    ) : boolean;            // return true when no additional tokens available
  begin
    // loop with valid token and look for successive matches of current token
    while (P > 0) and (PosEx(AToken, AMsg, P) = P) do
      begin
        AMsg := StuffString(AMsg, P, AToken.Length, ANewText);
        P := PosEx('<', AMsg, P);
      end;

    // return whether no additional tokens are present in string.
    Result := (P = 0);
  end;

begin
  if Pos('<#>', AMsg) > 0 then
    begin
    //with error
    AMsg := StringReplace(AMsg, '<#>', NrAsText, []);
    //error cleared
    AMsg := StringReplace(AMsg, '<#>', NrAsText, [rfReplaceAll]);
    end;

  // replace tokens with actual values
  P := Pos('<', AMsg);
  while (P > 0) do
    begin
      if ReplaceTokenAt(AMsg, P, '<my>', MyCall) then Break;
      if ReplaceTokenAt(AMsg, P, '<exch1>', Exch1) then Break;
      if ReplaceTokenAt(AMsg, P, '<exch2>', Exch2) then Break;
      if ReplaceTokenAt(AMsg, P, '<HisName>', MainForm.Edit2.Text) then Break;
      if ReplaceTokenAt(AMsg, P, '<MyName>', Tst.Me.OpName) then Break;
    end;

{
  if CallsFromKeyer
     then AMsg := StringReplace(AMsg, '<his>', ' ', [rfReplaceAll])
     else AMsg := StringReplace(AMsg, '<his>', HisCall, [rfReplaceAll]);
}

  if MsgText <> ''
    then MsgText := MsgText + ' ' + AMsg
    else MsgText := AMsg;

  // during debug, use status bar to show CW stream
  if BDebugCwDecoder and not (self is TQrmStation) then
    Mainform.sbar.Caption := (MsgText + '; ' + Mainform.sbar.Caption).Substring(0, 80);

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

  Keyer.SetWpm(Self.WpmS, Self.WpmC);
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
      Result := Format('%s  %s', [Exch1, Exch2]); // <Name> <NR|State|Prov|Prefix>
    scSst:
      Result := Format('%s %s', [Exch1, Exch2]); // <Name> <State|Prov|DX>
    scFieldDay:
      Result := Format('%s %s', [Exch1, Exch2]);
    scNaQp, scArrlDx, scIaruHf:
      Result := Format('%s %s', [Exch1, Exch2]);
    scAllJa, scAcag:
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


function TStation.WpmAsText : string;
begin
  if WpmS < WpmC then
    Result:= Format('%d/%d', [WpmS, WpmC])
  else
    Result:= Format('%3d', [WpmS]);
end;

end.

