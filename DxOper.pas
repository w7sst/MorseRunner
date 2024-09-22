//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit DxOper;

interface

uses
  Station;

const
  FULL_PATIENCE = 5;

type
  {
    TOperatorState represents the various states of an independent DxStation/
    DxOperator object. During a pile-up, multiple DxStation objects will exist.
    These states represent the operational state of each unique station within
    a simulated QSO.

    Each state follows the back and forth transmissions between the user and
    an indiviual DxOperator. Remember that DxStation and DxOperator objects
    are the simulated stations within the MR simulation.

    State           Description
    NORMAL FLOW...
    osNeedPrevEnd   Starting point. This is the initial operator state for a
                    newly created DxStation. The station will wait for the
                    completion of any prior QSO's as indicated by either
                    the user's next CQ call or a 'TU' message.
    osNeedQso       The DxOperator is waiting for their Dx callsign to be sent
                    by user. This state begins after the user has either called
                    CQ or finished the prior QSO by sending a 'TU' message.
                    For RunMode rmSingle, the CQ message is assumed and
                    the DxOperator immediately goes into this state
                    (expecting their callsign to be sent by user).
                    Typical response msg: send DxStation's callsign.
    osNeedNr        DxOperator is waiting for user's exchange.
                    DxOperator has received the user's callsign and is now
                    waiting to receive the user's exchange.
                    Typical response: send DxStation's exchange.
    osNeedEnd       DxStation is waiting for 'TU' from user.
                    User's call and exchange have been received.
                    Typical response msg: send DxStation's exchange.
    osDone          DxOperator has received a 'TU' from the user.
                    This QSO is now considered complete and can be logged.

    SPECIAL CASES (timeouts, call/exchange copy errors, random events)...
    osFailed        This QSO has failed. Reasons for failure include:
                    - DxStation is created and waits for the User to call their
                      callsign. If the user does not call them within a given
                      timeframe, the DxOperator will loose Patience and stop
                      sending their callsign. This is a form of caller ghosting
                      where the DxOperator gives up due to lack of patience
                      (occurs whenever Patience decrements to zero).
                    - user sends a msgNIL, which forces the QSO to fail.
                    - user sends a msgB4, stating that they had a prior QSO.
    osNeedCall      DxStation is expecting their call to be corrected by the
                    user. This state is entered when user sends a partially-
                    correct callsign. This DxOperator will wait for the correct
                    call to be sent before sending its Exchange.
                    The logic also appears to support the fact the user's
                    exchange (NR) has already been copied by this DxStation.
                    Once corrected, we should send 'R <exch>'.
                    Typical response msg: send DxStation's callsign
    osNeedCallNr    DxStation is expecting both their callsign and Exchange
                    to be sent by user.
                    This state is entered when the DxStation receives a
                    partially-correct callsign from the user. In this case,
                    the QSO advances from osNeedQso to osNeedCallNr.
                    Once the correct callsign is received, the next state will
                    be osNeedNr.
                    Typical response msg: DxStation's callsign
  }
  TOperatorState = (osNeedPrevEnd, osNeedQso, osNeedNr, osNeedCall,
    osNeedCallNr, osNeedEnd, osDone, osFailed);

  TCallCheckResult = (mcNo, mcYes, mcAlmost);


  TDxOperator = class
  private
    R1: Single;         // holds a Random number; used in IsMyCall
    R2: Single;         // holds a Random number; used in MsgReceived, GetReply
    procedure DecPatience;
    procedure MorePatience(AValue: integer = 0);
  public
    Call: string;
    Skills: integer;
    Patience: integer;  // Number of times operator will retry before leaving.
                        // Decremented to zero upon each evTimeout.
                        // When it reaches zero, the operator will ghost and its
			// TDxOperator.State set to osFailed.
			// Patience is increased with calls to MorePatience.
    RepeatCnt: integer;
    State: TOperatorState;
    constructor Create(const ACall: string; AState: TOperatorState);
    function IsGhosting: boolean;
    function GetSendDelay: integer;
    function GetReplyTimeout: integer;
    function GetWpm(out AWpmC : integer) : integer;
    function GetNR: integer;
    function GetName: string;
    procedure MsgReceived(AMsg: TStationMessages);
    procedure SetState(AState: TOperatorState);
    function GetReply: TStationMessage;
    function IsMyCall(const ACall: string; ARandomResult: boolean): TCallCheckResult;
  end;


implementation

uses
  SysUtils, Ini, Math, RndFunc, Contest, Log, Main;

{ TDxOperator }


constructor TDxOperator.Create(const ACall: string; AState: TOperatorState);
begin
  R1 := Random;     // a random value assigned at creation provides consistency
  R2 := Random;     // assigned at creation for consistent responses
  Call := ACall;
  Skills := 1 + Random(3); //1..3
  Patience := 0;
  RepeatCnt := 1;
  SetState(AState);
end;


{
  The notion of ghosting refers to a DxOperator who has run out of
  Patience and is leaving the QSO because the User has failed to respond.
  This will occur if the User does not respond or continue to interact with
  this DxOperator. A station is considered ghosting whenever Patience = 0.

  When a DxStation is ghosting, it will:
  - leaving the QSO because User did not complete QSO
  - will not send additional transmissions to the user
  - will retain in set of active stations so it can still receive messages
    from the user. Most often, it is waiting for the final 'TU' message.
  - if 'TU' is received, then the station can be added to the log.
}
function TDxOperator.IsGhosting: boolean;
begin
  Result := Patience = 0;
end;


//Delay before reply, keying speed and exchange number are functions
//of the operator's skills

function TDxOperator.GetSendDelay: integer;
begin
//  Result := Max(1, SecondsToBlocks(1 / Sqr(4*Skills)));
//  Result := Round(RndGaussLim(Result, 0.7 * Result));

  if State = osNeedPrevEnd then
    Result := NEVER
  else if RunMode = rmHst then
    Result := SecondsToBlocks(0.05 + 0.5*Random * 10/Ini.Wpm)
  else
    Result := SecondsToBlocks(0.1 + 0.5*Random);
end;

function TDxOperator.GetWpm(out AWpmC : integer): integer;
var
  mean, limit: Single;
begin
  if RunMode = rmHst then
    Result := Ini.Wpm
  else if (MaxRxWpm = -1) or (MinRxWpm = -1) then { use original algorithm }
    Result := Round(Ini.Wpm * 0.5 * (1 + Random))
  else if Ini.GetWpmUsesGaussian then  { use Gaussian w/ limit, [Wpm-Min, Wpm+Max] }
    begin                           // assume Wpm=30,  MinRxWpm=6, MaxRxWpm=2
    mean := Ini.Wpm + (-MinRxWpm + MaxRxWpm)/2; // 30+(-6+2)/2 = 30-4/2 = 28
    limit := (MinRxWpm + MaxRxWpm)/2;           // (6+2)/2 = 4 wpm
    Result := Round(RndGaussLim(mean, limit));  // [28-4, 28+4] -> wpm [24,32]
    end
  else                      { use Random value, [Wpm-Min,Wpm+Max] }
    Result := Round(Ini.Wpm - MinRxWpm + (MinRxWpm + MaxRxWpm) * Random);

  // optionally force all stations to use same speed (debugging and timing)
  if Ini.AllStationsWpmS > 10 then
    Result := Ini.AllStationsWpmS;

  // Allow Farnsworth timing for certain contests
  if Tst.IsFarnsworthAllowed() and (Result < Ini.FarnsworthCharRate) then
    AWpmC := Ini.FarnsworthCharRate
  else
    AWpmC := Result;
end;

function TDxOperator.GetNR: integer;
begin
  assert((RunMode = rmHST) or (Ini.SerialNR = snStartContest));
  Result := 1 + Round(Random * Tst.Minute * Skills)
end;


function TDxOperator.GetName: string;
begin
  Result := 'ALEX';
end;


{
  Returns the amount of time to wait for a reply after sending a transmission.
  This is in units of block counts. A new block is fetched by the audio
  system as needed to keep the audio stream full (See TContest.GetAudio).
}
function TDxOperator.GetReplyTimeout: integer;
begin
  if RunMode = rmHst then
    Result := SecondsToBlocks(60/Ini.Wpm)
  else
    Result := SecondsToBlocks(6-Skills);
  Result := Round(RndGaussLim(Result, Result/2));
end;


{
  DecPatience is typically called after an evTimeout event.
  The TDxOperator.Patience value is decremented down to zero.
  When this count reaches zero, the DxStation will start "ghosting" and
  stop transmitting. The ghosting station will remain active so it can
  receive final messages from user, logged and deleted from the simulation.
}
procedure TDxOperator.DecPatience;
begin
  if State = osDone then Exit;

  if Patience > 0 then
    Dec(Patience);

  // starting in v1.85, caller ghosting will occur when a QSO has started, but
  // has not yet completed. If the QSO has not yet started, set State=osFailed.
  if (Patience < 1) and (State in [osNeedPrevEnd, osNeedQso]) then
    State := osFailed;
end;


{
  MorePatience is called to add additional patience while remaining in the
  current state. This will happen when a message is received from the user
  without an associated state change. Without adding additional patience,
  the DxStation will timeout and disappear from the user in the middle of
  an ongoing QSO.

  Parameter AValue is an optional Patience value.
  If AValue > 0, Patience is set to this value;
  else if RunMode = rmSingle, Patience is set to 4;
  otherwise Patience is incremented by 2 (up to maximum of 4).
}
procedure TDxOperator.MorePatience(AValue: integer);
begin
  if State = osDone then Exit;

  if AValue > 0 then
    Patience := Min(AValue, FULL_PATIENCE)
  else if RunMode = rmSingle then
    Patience := 4
  else
    Patience := Min(Patience + 2, 4);
end;


{
  Calling this function will set the new State and compute a new Patience
  value to represent how patient this operator will be while waiting for
  a subsequent transmission from the user.

  SetState will:
    - set the operator State - See TOperatorState.
    - set Patience value - represents operator patience while waiting
      for response from user.
      - For osNeedQso, Patience is set to a random value using a
        Rayleigh distribution within the range of [1, 14] retries,
        with a Mean value of 4.
      - For all other states, Patience is set to 5.

  This function is typically called by TDxOperator.MsgReceived() whenever
  new TStationMessages are being sent to this DxStation/DxOperator by the
  simulation engine.
}
procedure TDxOperator.SetState(AState: TOperatorState);
begin
  State := AState;

  {
    Patience, set below, represents how long a station will stay around to
    complete a QSO with the user. FULL_PATIENCE = 5. Patience is the number of
    TimeOut events to occur before this station will disappear.
    A TimeOut is typically in the range of 3-6 seconds (See GetReplyTimeout).

    When entering the osNeedQso state, the original code was setting a Patience
    value which would cause a station to disappear quickly after its first
    transmission (i.e. sending its callsign). This was caused by the original
    RndRayleigh(4) distribution below having a result in the range [0,2] about
    6% of the time.

    In May 2024, this was changed to '3 + RndRayleigh(3)' to keep the
    station around long enough for the user to respond to a call.
    This fixes the so-called ghosting-problem where stations would disappear
    almost immediately after sending their callsign for the first time.
    See Issue #200 for additional information.

    0 + RndRayleigh(4)   0+([1,14], mean 4); value 0|1|2 occurs 6% (ghosting)
    3 + RndRayleigh(3)   3+([1,11], mean 3); [4,14], mean 6; value 4 occurs 2.6%
    3 + RndRayleigh(2)   3+([1, 7], mean 2); [4,10], mean 5; value 4 occurs 11%
  }
  if AState = osNeedQso
    then Patience := 3 + Round(RndRayleigh(3))
    else Patience := FULL_PATIENCE;

  if (AState = osNeedQso) and (not (RunMode in [rmSingle, RmHst])) and (Random < 0.1)
    then RepeatCnt := 2
    else RepeatCnt := 1;
end;


function TDxOperator.IsMyCall(const ACall: string;
  ARandomResult: boolean): TCallCheckResult;
const
  W_X = 1; W_Y = 1; W_D = 1;
var
  C, C0: string;
  M: array of array of integer;
  x, y: integer;
  T, L, D: integer;

  P: integer;
begin
  C0 := Call;
  C := ACall;

  SetLength(M, Length(C)+1, Length(C0)+1);

  //dynamic programming algorithm

  for y:=0 to High(M[0]) do
    M[0,y] := 0;
  for x:=1 to High(M) do
    M[x,0] := M[x-1,0] + W_X;

  for x:=1 to High(M) do
    for y:=1 to High(M[0]) do begin
      T := M[x,y-1];
      //'?' can match more than one char
      //end may be missing
      if (x < High(M)) and (C[x] <> '?') then
        Inc(T, W_Y);

      L := M[x-1,y];
      //'?' can match no chars
      if C[x] <> '?' then Inc(L, W_X);

      D := M[x-1,y-1];
      //'?' matches any char
      //if not (C[x] in [C0[y], '?']) then Inc(D, W_D);
      if not (CharInSet(C[x], [C0[y], '?'])) then Inc(D, W_D);

      M[x,y] := MinIntValue([T,D,L]);
    end;

  P := M[High(M), High(M[0])];

  if (P = 0) then
    Result := mcYes
  else if (((Length(C0) <= 4) and (Length(C0) - P >= 3)) or
       ((Length(C0) > 4) and (Length(C0) - P >= 4))) then
    Result := mcAlmost
  else
    Result := mcNo;

  //callsign-specific corrections

  if (not Ini.Lids) and (Length(C) = 2) and (Result = mcAlmost) then Result := mcNo;

  //partial and wildcard match result in 0 penalty but are not exact matches
  if (Result = mcYes) then
    if (Length(C) <> Length(C0)) or (Pos('?', C) > 0)
      then Result := mcAlmost;

  //partial match too short
  if Length(StringReplace(C, '?', '', [rfReplaceAll])) < 2 then Result := mcNo;

  //accept a wrong call, or reject the correct one
  if ARandomResult and Ini.Lids and (Length(C) > 3) then
    case Result of
      mcYes: if R1 < 0.01 then Result := mcAlmost;
      mcAlmost: if R1 < 0.04 then Result := mcYes;
      end;
end;


procedure TDxOperator.MsgReceived(AMsg: TStationMessages);
begin

  //if CQ received, we can call no matter what else was sent
  if msgCQ in AMsg then
    begin
    case State of
      osNeedPrevEnd: SetState(osNeedQso);
      osNeedQso: DecPatience;
      osNeedNr, osNeedCall, osNeedCallNr: State := osFailed;
      osNeedEnd: State := osDone;
      end;
    Exit;
    end;

  if msgNil in AMsg then
    begin
    case State of
      osNeedPrevEnd: SetState(osNeedQso);
      osNeedQso: DecPatience;
      osNeedNr, osNeedCall, osNeedCallNr, osNeedEnd: State := osFailed;
     end;
    Exit;
    end;  

  if msgHisCall in AMsg then
    case IsMyCall(Tst.Me.HisCall, True) of
      mcYes:
        if State in [osNeedPrevEnd, osNeedQso] then SetState(osNeedNr)
        else if State = osNeedCallNr then SetState(osNeedNr)
        else if State in [osNeedNr, osNeedEnd] then MorePatience
        else if State = osNeedCall then SetState(osNeedEnd);

      mcAlmost:
        if State in [osNeedPrevEnd, osNeedQso] then SetState(osNeedCallNr)
        else if State = osNeedCallNr then MorePatience
        else if State = osNeedNr then SetState(osNeedCallNr)
        else if State = osNeedEnd then SetState(osNeedCall);

      mcNo:
        if State = osNeedQso then State := osNeedPrevEnd
        else if State in [osNeedNr, osNeedCall, osNeedCallNr] then State := osFailed
        else if State = osNeedEnd then State := osDone;
     end;

  if msgB4 in AMsg then
    case State of
      osNeedPrevEnd, osNeedQso: SetState(osNeedQso);
      osNeedNr, osNeedEnd: State := osFailed;
      osNeedCall, osNeedCallNr: ; //same state: correct the call
      end;

  if msgNR in AMsg then
    case State of
      osNeedPrevEnd: ;
      osNeedQso: State := osNeedPrevEnd;
      osNeedNr: if (Random < 0.9) or (RunMode in [rmHst, rmSingle]) then
          SetState(osNeedEnd)
        else
          MorePatience;
      osNeedCall: MorePatience;
      osNeedCallNr: if (Random < 0.9) or (RunMode in [rmHst, rmSingle]) then
          SetState(osNeedCall)
        else
          MorePatience;
      osNeedEnd: MorePatience;
      end;

  if msgTU in AMsg then
    case State of
      osNeedPrevEnd: SetState(osNeedQso);
      osNeedQso: SetState(osNeedQso);
      osNeedNr: State := osDone;          // may have exchange (NR) error
      osNeedCall: State := osDone;        // possible partial call match
      osNeedCallNr: SetState(osNeedQso);  // start over with new QSO
      osNeedEnd: State := osDone;
      end;

  if msgQm in AMsg then
  begin
    case State of
      osNeedPrevEnd: if Mainform.Edit1.Text = '' then SetState(osNeedQso);
      osNeedQso: ;
      osNeedNr: MorePatience;
      osNeedCall: MorePatience;
      osNeedCallNr: MorePatience;
      osNeedEnd: MorePatience;
    end;
  end;

  if (not Ini.Lids) and (AMsg = [msgGarbage]) then State := osNeedPrevEnd;


  if State <> osNeedPrevEnd then DecPatience;
end;


function TDxOperator.GetReply: TStationMessage;
begin
  // A ghosting station (Patience=0) will not send any additional messages
  assert(not IsGhosting, 'this should not be called when ghosting');
  if IsGhosting then
    Result := msgNone
  else
  case State of
    osNeedPrevEnd, osDone, osFailed: Result := msgNone;
    osNeedQso: Result := msgMyCall;
    osNeedNr:
      if (Patience = (FULL_PATIENCE-1)) or (Random < 0.3)
        then Result := msgNrQm
        else Result := msgAgn;

    // osNeedCall - I have their Exch (NR), but need user to correct my call.
    osNeedCall:
      if (RunMode = rmHst) then
        Result := msgDeMyCallNr1
      else if (SimContest in [scArrlSS]) then
        case Trunc(R2*3) of
          0: Result := msgDeMyCallNr1;  // DE <my> <exch>
          1,2: Result := msgMyCallNr1;  // <my> <exch>
        end
      else
        case Trunc(R2*6) of
          0: Result := msgDeMyCallNr1;  // DE <my> <exch>
          1: Result := msgDeMyCallNr2;  // DE <my> <my> <exch>
          2,3: Result := msgMyCallNr2;  // <my> <my> <exch>
          4,5: Result := msgMyCallNr1;  // <my> <exch>
        end;

    // osNeedCallNr - They have sent an almost-correct callsign.
    osNeedCallNr:
      if (RunMode = rmHst) then
        Result := msgDeMyCall1
      else if (SimContest in [scArrlSS]) then
        case Trunc(R2*5) of
          0: Result := msgDeMyCall1;    // DE <my>
          1: Result := msgDeMyCall2;    // DE <my> <my>
          2: Result := msgMyCall2;      // <my> <my>
          3,4: Result := msgMyCallNr1;  // <my> <exch>
        end
      else
        case Trunc(R2*6) of
          0: Result := msgDeMyCall1;    // DE <my>
          1: Result := msgDeMyCall2;    // DE <my> <my>
          2: Result := msgMyCall2;      // <my> <my>
          3: Result := msgMyCallNr2;    // <my> <my> <exch>
          4,5: Result := msgMyCallNr1;  // <my> <exch>
        end
    else //osNeedEnd:
      if Patience < (FULL_PATIENCE-1) then Result := msgNR
      else if (RunMode = rmHst) or (SimContest in [scArrlSS]) or
              (Random < 0.9) then
        Result := msgR_NR
      else Result := msgR_NR2;
    end;
end;

end.

