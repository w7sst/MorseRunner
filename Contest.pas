//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Contest;

interface

uses
  SndTypes, Station, StnColl, MyStn, Ini, Log, System.Classes,
  ExchFields,
  MovAvg, Mixers, VolumCtl, DxStn;

type
  TContest = class
  private
    LastLoadCallsign : String;  // used to minimize call history file reloads

    function DxCount: integer;
    procedure SwapFilters;

  protected
  const
    STATION_ID_RATE = 3;  // send Station ID after 3 consecutive QSOs

  var
    QsoCountSinceStationID: Integer;  // QSOs since last CQ or Station ID
    BFarnsworthEnabled : Boolean; // enables Farnsworth timing (e.g. SST Contest)

    constructor Create;
    function IsReloadRequired(const AUserCallsign : String) : boolean;
    procedure SetLastLoadCallsign(const AUserCallsign : String);
    function ValidateExchField(const FieldDef: PFieldDefinition;
      const Avalue: string) : Boolean;

  public
    BlockNumber: integer;
    Me: TMyStation;
    Stations: TStations;
    Agc: TVolumeControl;
    Filt, Filt2: TMovingAverage;
    Modul: TModulator;
    RitPhase: Single;
    FStopPressed: boolean;

    destructor Destroy; override;
    procedure Init;
    function LoadCallHistory(const AUserCallsign : string) : boolean; virtual; abstract;

    function PickStation : integer; virtual; abstract;
    procedure DropStation(id : integer); virtual; abstract;
    function GetCall(id : integer) : string; virtual; abstract;
    procedure GetExchange(id : integer; out station : TDxStation); virtual; abstract;
    function GetRandomSerialNR: Integer; virtual;
    function GetStationInfo(const ACallsign : string) : string; virtual;
    function PickCallOnly : string;

    function OnSetMyCall(const AUserCallsign : string; out err : string) : boolean; virtual;
    function ValidateMyExchange(const AExchange: string;
      ATokens: TStringList;
      out AExchError: string): boolean; virtual;
    function OnContestPrepareToStart(const AUserCallsign: string;
      const ASentExchange : string) : Boolean; virtual;
    procedure SerialNrModeChanged; virtual;
    function IsFarnsworthAllowed : Boolean;
    function GetSentExchTypes(
      const AStationKind : TStationKind;
      const AMyCallsign : string) : TExchTypes;
    function GetRecvExchTypes(
      const AStationKind : TStationKind;
      const AMyCallsign : string;
      const ADxCallsign : string) : TExchTypes;
    function GetExchangeTypes(
      const AStationKind : TStationKind;
      const ARequestedMsgType : TRequestedMsgType;
      const AStationCallsign : String;
      const ARemoteCallsign : String) : TExchTypes; virtual;
    procedure SendMsg(const AStn: TStation; const AMsg: TStationMessage); virtual;
    procedure SendText(const AStn: TStation; const AMsg: string); virtual;
    procedure ResetQsoState;
    procedure OnWipeBoxes; virtual;
    function OnExchangeEdit(const ACall, AExch1, AExch2: string;
       out AExchSummary: string; out AExchError: string) : Boolean; virtual;
    procedure OnExchangeEditComplete; virtual;
    procedure SetHisCall(const ACall: string); virtual;

    function CheckEnteredCallLength(const ACall: string;
      out AExchError: String) : boolean; virtual;
    function ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
      out AExchError: String) : boolean; virtual;
    procedure SaveEnteredExchToQso(var Qso: TQso; const AExch1, AExch2: string); virtual;
    procedure FindQsoErrors(var Qso: TQso; var ACorrections: TStringList);
    function ExtractMultiplier(Qso: PQso) : string; virtual;
    function Minute: Single;
    function GetAudio: TSingleArray;
    procedure OnMeFinishedSending;
    procedure OnMeStartedSending;
    procedure OnSaveQsoComplete;
    procedure OnStationIDSent;
  end;

var
  Tst: TContest;


implementation

uses
  SysUtils, RndFunc, Math, DxOper,
  PerlRegEx,
  VCL.Graphics,       // clDefault
  Main, CallLst, DXCC;

{ TContest }

constructor TContest.Create;
begin
  Me := TMyStation.CreateStation;
  Stations := TStations.Create;
  Filt := TMovingAverage.Create(nil);
  Modul := TModulator.Create;
  Agc := TVolumeControl.Create(nil);

  Filt.Points := Round(0.7 * DEFAULTRATE / Ini.BandWidth);
  Filt.Passes := 3;
  Filt.SamplesInInput := Ini.BufSize;
  Filt.GainDb := 10 * Log10(500/Ini.Bandwidth);

  Filt2 := TMovingAverage.Create(nil);
  Filt2.Passes := Filt.Passes;
  Filt2.SamplesInInput := Filt.SamplesInInput;
  Filt2.GainDb := Filt.GainDb;

  Modul.SamplesPerSec := DEFAULTRATE;
  Modul.CarrierFreq := Ini.Pitch;

  Agc.NoiseInDb := 76;
  Agc.NoiseOutDb := 76;
  Agc.AttackSamples := 155;   //AGC attack 5 ms
  Agc.HoldSamples := 155;
  Agc.AgcEnabled := true;
  NoActivityCnt :=0;
  LastLoadCallsign := '';
  QsoCountSinceStationID := 0;
  BFarnsworthEnabled := false;

  Init;
end;


destructor TContest.Destroy;
begin
  Me.Free;
  FreeAndNil(Stations);
  Filt.Free;
  Filt2.Free;
  Modul.Free;
  FreeAndNil(Agc);
  inherited;
end;


procedure TContest.Init;
begin
  Me.Init;
  Stations.Clear;
  BlockNumber := 0;
  LastLoadCallsign := '';
  QsoCountSinceStationID := 0;
  BFarnsworthEnabled := false;
end;


{
  user's home callsign is required when loading some contests
  (don't load if user callsign is empty or is the same as last time).

  return whether the call history file is valid. This varies by contest.
}
function TContest.IsReloadRequired(const AUserCallsign : string) : boolean;
begin
  Result := not (AUserCallsign.IsEmpty or (LastLoadCallsign = AUserCallsign));
end;


// called by LoadCallHistory after loading the call history file.
procedure TContest.SetLastLoadCallsign(const AUserCallsign : String);
begin
  LastLoadCallsign := AUserCallsign;
end;


{
  Farnsworth timing is supported by certain contests only (initially the
  K1USN SST Contest). Derived contests will set BFarnworthEnabled in their
  TContest.Create() method.
}
function TContest.IsFarnsworthAllowed : Boolean;
begin
  Result := BFarnsworthEnabled;
end;


{
  Return a random serial number for the currently selected Serial NR mode
  (a menu pick).
}
function TContest.GetRandomSerialNR: Integer;
begin
  Result := Ini.SerialNRSettings[Ini.SerialNR].GetNR;
end;


{
  GetStationInfo() returns station's DXCC information.

  Adding a contest: SbarUpdateStationInfo - update status bar with station info (e.g. FD shows UserText)
  Override as needed for each contest.
}
function TContest.GetStationInfo(const ACallsign : string) : string;
begin
  Result := gDXCCList.Search(ACallsign);
end;


// helper function to return only a callsign (used by QrnStation)
function TContest.PickCallOnly : string;
var
  id : integer;
begin
  id := PickStation;
  Result := GetCall(id);
end;


{
  OnSetMyCall() is called whenever the user's callsign is set.
  Can be overriden by derived classes as needed to update contest-specific
  settings. Note that derived classes should update contest-specific
  settings before calling this function since the Sent Exchange settings
  may depend upon this contest-specific information.

  Returns whether the call was successful.
}
function TContest.OnSetMyCall(const AUserCallsign : string; out err : string) : boolean;
begin
  Me.MyCall:= AUserCallsign;

  // update my sent exchange field types
  Me.SentExchTypes:= GetSentExchTypes(skMyStation, AUserCallsign);

  Result:= True;
end;


{
  Parse into two strings [Exch1, Exch2].
  Validate each string and set error string in AExchError.
  Return True upon success; False otherwise.
}
function TContest.ValidateMyExchange(const AExchange: string;
  ATokens: TStringList;
  out AExchError: string): boolean;
var
  SentExchTypes : TExchTypes;
  Field1Def: PFieldDefinition;
  Field2Def: PFieldDefinition;
begin
  SentExchTypes := Self.Me.SentExchTypes;
  Field1Def := @Exchange1Settings[SentExchTypes.Exch1];
  Field2Def := @Exchange2Settings[SentExchTypes.Exch2];

  // parse into two strings [Exch1, Exch2]
  ATokens.Clear;
  ExtractStrings([' '], [], PChar(AExchange), ATokens);
  if ATokens.Count = 0 then
    ATokens.AddStrings(['', '']);
  if ATokens.Count = 1 then
    ATokens.AddStrings(['']);

  // validate sent exchange strings
  Result := ValidateExchField(Field1Def, ATokens[0]) and
            ValidateExchField(Field2Def, ATokens[1]);

  if not Result then
    AExchError := Format('Invalid exchange: ''%s'' - expecting %s.',
          [AExchange, ActiveContest.Msg]);
end;

function TContest.ValidateExchField(const FieldDef: PFieldDefinition;
  const Avalue: string) : Boolean;
var
  reg: TPerlRegEx;
  s: string;
begin
  if SimContest = scNaQp then begin
    // special case - I can't figure out how to match an empty string,
    // so manually check for an optional string.
    s := FieldDef.R;
    Result := s.StartsWith('()|(') and Avalue.IsEmpty;
    if Result then Exit;
  end;

  reg := TPerlRegEx.Create();
  try
    reg.Subject := UTF8Encode(Avalue);
    s:= '^(' + FieldDef.R + ')$';
    reg.RegEx:= UTF8Encode(s);
    Result:= Reg.Match;
  finally
    reg.Free;
  end;
end;


{
  OnContestPrepareToStart() event is called whenever a contest is started.
  Some contests will override this method to provide additional contest-specfic
  behaviors. When overriding this function, be sure to call this base-class
  function.

  Current behavior is to load the call history file. This action has been
  deferred until now since some contests use the user's callsign to determine
  which stations can work other stations in the contest. For example, in the
  ARRL DX Contest, US/CA Stations work DX (non-US/CA) stations.

  Returns whether the operation was successfull.
}
function TContest.OnContestPrepareToStart(const AUserCallsign: string;
  const ASentExchange : string) : Boolean;
begin
  // reload call history iff user's callsign has changed.
  if IsReloadRequired(AUserCallsign) then
    begin
      // load contest-specific call history file
      Result:= LoadCallHistory(AUserCallsign);

      // retain user's callsign after successful load
      if Result then
        SetLastLoadCallsign(AUserCallsign);
    end
  else
    Result:= True;
end;


{
  Called after
  - 'Setup | Serial NR' menu pick
  - 'Setup | Serial NR | Custom Range...' menu pick/modification

  The base class implementation does nothing. Other derived classes can
  update cached information based on the serial NR menu pick (e.g. CQ WPX).
}
procedure TContest.SerialNrModeChanged;
begin
  assert(RunMode <> rmStop);
end;


{
  Return sent dynamic exchange types for the given kind-of-station and callsign.
  AStationKind represents either the user's station (representing current
  simulation) or the DxStn represented a simulated station calling the user.
}
function TContest.GetSentExchTypes(
  const AStationKind : TStationKind;
  const AMyCallsign : string) : TExchTypes;
begin
  Result:= Self.GetExchangeTypes(AStationKind, mtSendMsg, AMyCallsign, '');
end;


{
  Return received dynamic exchange types for the given kind-of-station,
  user's (simulation callsign) and the dx station's callsign.
  Different contests will use either user's callsign or dx station's callsign.
}
function TContest.GetRecvExchTypes(
  const AStationKind : TStationKind;
  const AMyCallsign : string;
  const ADxCallsign : string) : TExchTypes;
begin
  if AStationKind = skMyStation then
    Result:= Self.GetExchangeTypes(AStationKind, mtRecvMsg, AMyCallsign, ADxCallsign)
  else
    Result:= Self.GetExchangeTypes(AStationKind, mtRecvMsg, ADxCallsign, AMyCallsign);
end;


function TContest.GetExchangeTypes(
  const AStationKind : TStationKind;
  const ARequestedMsgType : TRequestedMsgType;
  const AStationCallsign : String;
  const ARemoteCallsign : String) : TExchTypes;
begin
  Result.Exch1 := ActiveContest.ExchType1;
  Result.Exch2 := ActiveContest.ExchType2;
end;


{
  This virtual procedure allows contest-specific messages to be implemented
  in derived Contest classes.

  When overridden by derived classes, if a message is not handled then this
  base-class procedure should be called.
  Please see ARRLFD.SendMsg for an example.
}
procedure TContest.SendMsg(const AStn: TStation; const AMsg: TStationMessage);
begin
  case AMsg of
    msgCQ: SendText(AStn, 'CQ <my> TEST');
    msgNR: SendText(AStn, '<#>');
    msgTU:
      // send station ID after 3 consecutive QSOs (the comparison below uses
      // 2 since the counter is incremented after 'TU <my>' has been sent).
      if (RunMode <> rmHST) and (QsoCountSinceStationID >= (STATION_ID_RATE-1))
        then SendText(AStn, 'TU <my>')
        else SendText(AStn, 'TU');
    msgMyCall: SendText(AStn, '<my>');
    msgHisCall: SendText(AStn, '<his>');
    msgB4: SendText(AStn, 'QSO B4');
    msgQm: SendText(AStn, '?');
    msgNil: if Ini.F8.IsEmpty then SendText(AStn, 'NIL')
                              else SendText(Astn, Ini.F8);
    msgR_NR: SendText(AStn, 'R <#>');
    msgR_NR2: SendText(AStn, 'R <#> <#>');
    msgDeMyCall1: SendText(AStn, 'DE <my>');
    msgDeMyCall2: SendText(AStn, 'DE <my> <my>');
    msgDeMyCallNr1: SendText(AStn, 'DE <my> <#>');
    msgDeMyCallNr2: SendText(AStn, 'DE <my> <my> <#>');
    msgMyCall2: SendText(AStn, '<my> <my>');
    msgMyCallNr1: SendText(AStn, '<my> <#>');
    msgMyCallNr2: SendText(AStn, '<my> <my> <#>');
    msgNrQm: SendText(AStn, 'NR?');
    msgLongCQ: SendText(AStn, 'CQ CQ TEST <my> <my> TEST');
    msgQrl: SendText(AStn, 'QRL?');
    msgQrl2: SendText(AStn, 'QRL?   QRL?');
    msqQsy: SendText(AStn, '<his>  QSY QSY');                // QrmStation only
    msgAgn: SendText(AStn, 'AGN');
  end;
end;


{
  This virtual procedure is provided to allow a derived contest the ability
  to perform additional processing on the message, including token replacement,
  before being passed to the Encoder and Keyer.
}
procedure TContest.SendText(const AStn: TStation; const AMsg: string);
begin
  AStn.SendText(AMsg);  // virtual
end;


{
  Called after each QSO is completed to reset internal QSO-tracking state logic.

  TContest.Me.HisCall is used by TDxOperator.MsgReceived to determine if the
  user's call matches the DxStation's assigned callsign. TContest.Me.HisCall
  is a copy of the call as entered by the user during each QSO.
}
procedure TContest.ResetQsoState;
begin
  Me.HisCall := '';
end;


{
  Called at end of each QSO or by user's Cntl-W (Wipe Boxes) keystroke.
}
procedure TContest.OnWipeBoxes;
begin
  Log.NrSent := False;
  Log.DisplayError('', clDefault);
end;


{
  Called after each keystroke of the Exch2 field (Edit3).
}
function TContest.OnExchangeEdit(const ACall, AExch1, AExch2: string;
  out AExchSummary: string; out AExchError: string) : Boolean;
begin
  AExchSummary := '';
  Result := False;
end;


{
  Called at the start of each action/command after user has finished typing
  in the Exchange fields. Can be overriden as needed for complex exchange
  behaviors (e.g. ARRL SS).
}
procedure TContest.OnExchangeEditComplete;
begin
  Log.CallSent := (Mainform.Edit1.Text <> '') and
    (Mainform.Edit1.Text = Self.Me.HisCall);
end;


{
  SetHisCall will:
  - sets TContest.Me.HisCall to the supplied callsign, ACall.
  - sets Log.CallSent to False if the callsign should be sent.

  Override as needed to provide more complex callsign behaviors (e.g. ARRL
  Sweepstakes allows callsign corrections in the exchange).
}
procedure TContest.SetHisCall(const ACall: string);
begin
  if ACall <> '' then Self.Me.HisCall := ACall;
  Log.CallSent := ACall <> '';
end;


{
  Find exchange errors in the current Qso.
  Called at end of each Qso during Qso validaiton.
  This virtual procedure can be overriden to perform special exchange
  validation behaviors.

  Side Effects:
  - sets Qso.Exch1Error and Qso.Exch2Error
  - add exchange corrections to ACorrection
}
procedure TContest.FindQsoErrors(var Qso: TQso; var ACorrections: TStringList);
begin
  Qso.CheckExch1(ACorrections);
  Qso.CheckExch2(ACorrections);
end;


{
  Performs simple length check on a callsign.
  Returns true for callsigns with 3 or more characters; false otherwise.
  Upon error, AExchError will contain a simple error message.
}
function TContest.CheckEnteredCallLength(const ACall: string;
  out AExchError: String) : boolean;
begin
  Result := StringReplace(ACall, '?', '', [rfReplaceAll]).Length >= 3;
  if not Result then
    AExchError := 'Invalid callsign';
end;


{
  ValidateEnteredExchange is called prior to sending the final 'TU' and calling
  SaveQSO (see Log.pas). The basic validation is a length test where each
  exchange is checked against a minimum length requirement.
  This is consistent with original 1.68 behaviors.

  This virtual function can be overriden for complex exchange information
  (e.g. ARRL Sweepstakes).
}
function TContest.ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
  out AExchError: String) : boolean;
  // Adding a contest: validate contest-specific exchange fields
  //validate Exchange 1 (Edit2) field lengths
  function ValidateExchField1(const text: string): Boolean;
  begin
    Result := false;
    case Mainform.RecvExchTypes.Exch1 of
      etRST:     Result := Length(text) = 3;
      etOpName:  Result := Length(text) > 1;
      etFdClass: Result := Length(text) > 1;
      else
        assert(false, 'missing case');
    end;
  end;

  //validate Exchange 2 (Edit3) field lengths
  function ValidateExchField2(const text: string): Boolean;
  begin
    Result := false;
    case Mainform.RecvExchTypes.Exch2 of
      etSerialNr:    Result := Length(text) > 0;
      etGenericField:Result := Length(text) > 0;
      etArrlSection: Result := Length(text) > 1;
      etStateProv:   Result := Length(text) > 1;
      etCqZone:      Result := Length(text) > 0;
      etItuZone:     Result := Length(text) > 0;
      //etAge:
      etPower:       Result := Length(text) > 0;
      etJaPref:      Result := Length(text) > 2;
      etJaCity:      Result := Length(text) > 3;
      etNaQpExch2:   Result := Length(text) > 0;
      etNaQpNonNaExch2: Result := Length(text) >= 0;
      else
        assert(false, 'missing case');
    end;
  end;

begin
  if not ValidateExchField1(AExch1) then
    AExchError := format('Missing/Invalid %s',
      [Exchange1Settings[Mainform.RecvExchTypes.Exch1].C])
  else if not ValidateExchField2(AExch2) then
    AExchError := format('Missing/Invalid %s',
      [Exchange2Settings[Mainform.RecvExchTypes.Exch2].C])
  else
    AExchError := '';
  Result := AExchError.IsEmpty;
end;


{
  SaveEnteredExchToQso will save contest-specific exchange values into a QSO.
  This is called by SaveQSO while saving the completed QSO into the log.
  This virtual function can be overriden by specialized contests as needed
  (see ARRL Sweepstakes).
}
procedure TContest.SaveEnteredExchToQso(var Qso: TQso; const AExch1, AExch2: string);
begin
    // Adding a contest: save contest-specific exchange values into QsoList
    //save Exchange 1 (Edit2)
    case Mainform.RecvExchTypes.Exch1 of
      etRST:     Qso.Rst := StrToIntDef(AExch1, 0);
      etOpName:  Qso.Exch1 := AExch1;
      etFdClass: Qso.Exch1 := AExch1;
      else
        assert(false, 'missing case');
    end;

    //save Exchange2 (Edit3)
    case Mainform.RecvExchTypes.Exch2 of
      etSerialNr:    Qso.Nr := StrToIntDef(AExch2, 0);
      etGenericField:Qso.Exch2 := AExch2;
      etArrlSection: Qso.Exch2 := AExch2;
      etStateProv:   Qso.Exch2 := AExch2;
      etCqZone:      Qso.Exch2 := AExch2;
      etItuZone:     Qso.Exch2 := AExch2;
      //etAge:
      etPower:       Qso.Exch2 := AExch2;
      etJaPref:      Qso.Exch2 := AExch2;
      etJaCity:      Qso.Exch2 := AExch2;
      etNaQpExch2:   Qso.Exch2 := AExch2;
      etNaQpNonNaExch2:
        if AExch2 = '' then
          Qso.Exch2 := 'DX'
        else
          Qso.Exch2 := AExch2;
      else
        assert(false, 'missing case');
    end;

  if Qso.Exch1.IsEmpty then Qso.Exch1 := '?';
  if Qso.Exch2.IsEmpty and (Mainform.RecvExchTypes.Exch2 <> etNaQpNonNaExch2) then
    Qso.Exch2 := '?';
end;


{
  Extract multiplier string for a given contest. Default behavior will
  return the QSO.Pfx string (which implies this method must be called
  after ExtractPrefix.
  Also sets contest-specific Qso.Points for this QSO.

  Derived contests will override this method when contest rules require
  different multiplier rules or QSO points.

  For example, ARRL DX Rules state: "Multiply total QSO points by the number
  of DXCC entities (W/VE stations) or states and provinces (DX stations)
  contacted to get your final score."

  Return the multiplier string used by this contest. This string is accumlated
  in the Log.RawMultList and Log.VerifiedMultList to count the multiplier value.
}
function TContest.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso.Points := 1;
  // assumes Log.ExtractPrefix() has already been called.
  Result := Qso.Pfx;
end;


function TContest.GetAudio: TSingleArray;
const
  NOISEAMP = 6000;
var
  ReIm: TReImArrays;
  Blk: TSingleArray;
  i, Stn: integer;
  Bfo: Single;
  Smg, Rfg: Single;
begin
  //minimize audio output delay
  SetLength(Result, 1);
  Inc(BlockNumber);
  if BlockNumber < 6 then Exit;

  //complex noise
  SetLengthReIm(ReIm, Ini.BufSize);
  for i:=0 to High(ReIm.Re) do
    begin
    ReIm.Re[i] := 3 * NOISEAMP * (Random-0.5);
    ReIm.Im[i] := 3 * NOISEAMP * (Random-0.5);
    end;

  //QRN
  if Ini.Qrn then
    begin
    //background
    for i:=0 to High(ReIm.Re) do
      if Random < 0.01 then ReIm.Re[i] := 60 * NOISEAMP * (Random-0.5);
    //burst
    if Random < 0.01 then Stations.AddQrn;
    end;

  //QRM
  if Ini.Qrm and (Random < 0.0002) then Stations.AddQrm;


  //audio from stations
  Blk := nil;
  for Stn:=0 to Stations.Count-1 do
    if Stations[Stn].State = stSending then
      begin
      Blk := Stations[Stn].GetBlock;
      for i:=0 to High(Blk) do
        begin
        Bfo := Stations[Stn].Bfo - RitPhase - i * TWO_PI * Ini.Rit / DEFAULTRATE;
        ReIm.Re[i] := ReIm.Re[i] + Blk[i] * Cos(Bfo);
        ReIm.Im[i] := ReIm.Im[i] - Blk[i] * Sin(Bfo);
        end;
      end;               

  //Rit
  RitPhase := RitPhase + Ini.BufSize * TWO_PI * Ini.Rit / DEFAULTRATE;
  while RitPhase > TWO_PI do RitPhase := RitPhase - TWO_PI;
  while RitPhase < -TWO_PI do RitPhase := RitPhase + TWO_PI;
  

  //my audio
  if Me.State = stSending then
    begin
    Blk := Me.GetBlock;
    //self-mon. gain
    Smg := Power(10, (MainForm.VolumeSlider1.Value - 1) * 3);

    // apply linear rolloff towards zero between -57 and -60db (i.e. Smg=0 @ -60db)
    if MainForm.VolumeSlider1.Value < 0.05 then       // @ -57db, value = 3/60 = 0.05
      Smg := Smg * MainForm.VolumeSlider1.Value * 60; // 60 dB steps in [-60,0dB]

    Rfg := 1;
    if Ini.Qsk
      then
        for i:=0 to High(Blk) do
           begin
           if Rfg > (1 - Smg*Blk[i]/Me.Amplitude)
             then Rfg := (1 - Smg*Blk[i]/Me.Amplitude)
             else Rfg := Rfg * 0.997 + 0.003;
           ReIm.Re[i] := Smg * Blk[i] + Rfg * ReIm.Re[i];
           ReIm.Im[i] := Smg * Blk[i] + Rfg * ReIm.Im[i];
           end
      else
        for i:=0 to High(Blk) do
          begin
          ReIm.Re[i] := Smg * (Blk[i]);
          ReIm.Im[i] := Smg * (Blk[i]);
          end;
    end;


  //LPF
  Filt2.Filter(ReIm);
  ReIm := Filt.Filter(ReIm);
  if (BlockNumber mod 10) = 0 then SwapFilters;

  //mix up to Pitch frequency
  Result := Modul.Modulate(ReIm);
  //AGC
  Result := Agc.Process(Result);
  //save
  with MainForm.AlWavFile1 do
   if IsOpen then WriteFrom(@Result[0], nil, Ini.BufSize);

  //timer tick
  Me.Tick;
  for Stn:=Stations.Count-1 downto 0 do Stations[Stn].Tick;


  //if DX is done, write to log and kill
    for i:=Stations.Count-1 downto 0 do
      if Stations[i] is TDxStation then
        with Stations[i] as TDxStation do
          if (Oper.State = osDone) and (QsoList <> nil) and
            ((MyCall = QsoList[High(QsoList)].Call) or
             (Oper.IsMyCall(QsoList[High(QsoList)].Call, False) = mcAlmost)) then begin
              // grab Qso's "True" data (e.g. TrueCall, TrueExch1, TrueExch2)
              DataToLastQso; // deletes this TDxStation from Stations[]

              // Tst.Me.HisCall can be cleared now in preparation for the next
              // QSO. It was last used by TDxOperator.MsgReceived when comparing
              // the user-entered callsign against the DxStation's callsign.
              Tst.ResetQsoState;

              // rerun error check and update Err string on screen log
              Log.CheckErr;
              Log.ScoreTableUpdateCheck;

              { TODO -omikeb -cfeature : Clean up status bar code. }
              if SimContest = scHst then
                Log.UpdateStatsHst
              else
                Log.UpdateStats({AVerifyResults=}True);

{
              This code can be used to clear QSO info after 'TU' is sent.
              However, this may be a multi-threading issue here because
              this audio thread will be changing things being manipulated
              by the GUI thread. Need more time to think through this one.
              --> There is no threading issue. The Audio thread is synchronized
                  with the main thread using a call to TThread.Synchonize() in
                  the audio thread execute function. See TWaitThread.Execute()
                  in VCL/SndCustm.pas for more details.

              // clear any errors/status from last QSO
              Log.DisplayError('', clDefault);
              Log.SBarUpdateSummary('');
}
          end;

  //show info
  ShowRate;
  MainForm.Panel2.Caption := FormatDateTime('hh:nn:ss', BlocksToSeconds(BlockNumber) /  86400);
  if Ini.RunMode = rmPileUp then
    MainForm.Panel4.Caption := Format('Pile-Up:  %d', [DxCount]);

  if (RunMode = rmSingle) and (DxCount = 0) then begin
     Me.Msg := [msgCq]; //no need to send cq in this mode
     Stations.AddCaller.ProcessEvent(evMeFinished);

{$ifdef DEBUG}
     if Main.BDebugExchSettings then
     begin
         MainForm.Edit1.Text := DxStn.LastDxCallsign;
         MainForm.Edit2.Text := '';
         MainForm.Edit3.Text := '';
         Log.CallSent := False; // my Call hasn't been sent to this new station
         Log.NrSent := False;   // my Exch hasn't been sent to this new station
     end;
{$endif}
  end
  else
    if (RunMode = rmHst) and (DxCount < Activity) then begin
      Me.Msg := [msgCq];
      for i:=DxCount+1 to Activity do
        Stations.AddCaller.ProcessEvent(evMeFinished);
    end;


  if (BlocksToSeconds(BlockNumber) >= (Duration * 60)) or FStopPressed then
    begin
    if RunMode = rmHst then
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      MainForm.PopupScoreHst;
      end
    else if (SimContest = scWpx) and
      (RunMode in [rmHst, rmWpx]) and
      not FStopPressed then
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      MainForm.PopupScoreWpx;
      end
    else
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      end;
{
    if (RunMode in [rmWpx, rmHst]) and not FStopPressed
      then begin MainForm.Run(rmStop); MainForm.PopupScore; end
      else MainForm.Run(rmStop);
}
    end;
end;


function TContest.DxCount: integer;
var
  i: integer;
begin
  Result := 0;
  for i:=Stations.Count-1 downto 0 do
    if (Stations[i] is TDxStation) and
       (TDxStation(Stations[i]).Oper.State <> osDone)
      then Inc(Result);
end;


function TContest.Minute: Single;
begin
  Result := BlocksToSeconds(BlockNumber) / 60;
end;


procedure TContest.OnMeFinishedSending;
var
  i: integer;
  z: integer;
  Dx : integer;
begin
  // reset Station ID counter after sending a CQ or 3 consecutive QSOs
  if (msgCQ in Me.Msg) or
     ((msgTU in Me.Msg) and (QsoCountSinceStationID >= STATION_ID_RATE)) then
    OnStationIDSent;

  //the stations heard my CQ and want to call
  if (not (RunMode in [rmSingle, RmHst])) then
    if (msgCQ in Me.Msg) or
       ((QsoList <> nil) and ((msgTU in Me.Msg) or (msgMyCall in Me.Msg))) then
       begin
          z := 0;
          Dx := DxCount;
          if not (msgCQ in Me.Msg) then
             if Dx > 0 then Dec(Dx);  // The just finished Q has to be deducted
          for i:=1 to RndPoisson(Activity / 2) - Dx do
             begin
                 Stations.AddCaller;
                 z := 1;
             end;
          if z=0 then begin
             // No maximo fica 3 cq sem contesters
             // (At most 3 cq without contesters)
             inc(NoActivityCnt);
             if ((NoActivityCnt > 2) or (NoStopActivity > 0) )  then begin
                 Stations.AddCaller;
                 NoActivityCnt := 0;
             end;
          end;
       end;
  //tell callers that I finished sending
  for i:=Stations.Count-1 downto 0 do
    Stations[i].ProcessEvent(evMeFinished);
end;


procedure TContest.OnMeStartedSending;
var
  i: integer;
begin
  //tell callers that I started sending
  for i:=Stations.Count-1 downto 0 do
    Stations[i].ProcessEvent(evMeStarted);
end;


// Called by Log.SaveQso after saving a QSO into the log.
procedure TContest.OnSaveQsoComplete;
begin
  // send station ID after 3 consecutive QSOs
  Inc(QsoCountSinceStationID);
end;


// Called by TContest.OnMeFinishedSending after sending 'CQ <my>' or 'TU <my>'.
procedure TContest.OnStationIDSent;
begin
  QsoCountSinceStationID := 0;
end;


procedure TContest.SwapFilters;
var
  F: TMovingAverage;
begin
  F := Filt;
  Filt := Filt2;
  Filt2 := F;
  Filt2.Reset;
end;



end.

