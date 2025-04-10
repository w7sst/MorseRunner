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
    osNeedCall      DxStation has received a partially correct callsign from
                    the user along with the user's exchange. At this point, the
                    DxStation is expecting their call to be corrected by the
                    user. This station responds with either "DE <call>" or
                    "DE <call> <exch>".
                    Once corrected, the State becomes osNeedEnd and sends
                    'R <exch>'.
    osNeedCallNr    DxStation is expecting both their callsign and Exchange
                    to be sent by user.
                    This state is entered when the DxStation receives a
                    partially-correct callsign from the user. In this case,
                    the QSO advances from osNeedQso to osNeedCallNr.
                    Once the correct callsign is received, the next state will
                    be osNeedNr.
                    Typical DxStation response messages include:
                      - [DE] <callsign>
                      - [DE] <callsign> <callsign>
                      -      <callsign> <exch>
  }
  TOperatorState = (osNeedPrevEnd, osNeedQso, osNeedNr, osNeedCall,
    osNeedCallNr, osNeedEnd, osDone, osFailed);

  TCallCheckResult = (mcNo, mcYes, mcAlmost);


  TDxOperator = class
  private
    R2: Single;         // holds a Random number; used in MsgReceived, GetReply
    LastCheckedCall: String;            // last call passed to IsMyCall()
    LastCallCheck: TCallCheckResult;    // IsMyCall()'s last result
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
    CallConfidence: Integer;  // confidence-level of partial call match (0-100%).
                              // set by IsMyCall.
    CorrectedCallAndExchSent: Boolean;  // DxOper has sent callsign correction
                                        // and exchange in one message.
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
    function IsMyCall(const APattern: string; ARandomResult: boolean;
      ACallConfidencePtr: PInteger = nil): TCallCheckResult;
    function CallConfidenceCheck(const ACall: string;
      ARandomResult: boolean): TCallCheckResult;
    function IsActiveInQso: Boolean;
  end;


implementation

uses
  PerlRegEx,        // for regular expression support
  SysUtils, Ini, Math, RndFunc, Contest, Log, Main;

{ TDxOperator }


constructor TDxOperator.Create(const ACall: string; AState: TOperatorState);
begin
  R2 := Random;     // assigned at creation for consistent responses
  Call := ACall;
  Skills := 1 + Random(3); //1..3
  Patience := 0;
  RepeatCnt := 1;
  SetState(AState);
  LastCheckedCall := '';
  LastCallCheck := mcNo;
  CallConfidence := 0;
  CorrectedCallAndExchSent := false;
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
  else if Patience=FULL_PATIENCE, no changes;
  else if RunMode = rmSingle, Patience is set to 4;
  otherwise Patience is incremented by 2 (up to maximum of 4).

  Note: When MorePatience was introduced in May 2024, a bug (Issue #370) was
  introduced causing the DxStation to not send an 'R' after the user corrected
  a callsign. The case involved the user sending a corrected callsign using
  the Enter key while leaving the exchange fields blank (user sends
  '<his incorrect call> ?'. In this case, the DxOperator.MsgReceived function
  would call MorePatience for the '?' and the Patience value was set to 4.
  This caused DxOperator.GetReply() to send the wrong response:
      DxOperator.GetReply(osNeedEnd, Patience=5) --> 'R <HisCall>'
      DxOperator.GetReply(osNeedEnd, Patience=4) --> '<HisCall>'
  To fix this problem, MorePatience will maintain an existing Patience value
  of 5 (FULL_PATIENCE) and not set it to 4. Resolved in October 2024.
}
procedure TDxOperator.MorePatience(AValue: integer);
begin
  if State = osDone then Exit;

  if AValue > 0 then
    Patience := Min(AValue, FULL_PATIENCE)
  else if Patience < FULL_PATIENCE then
    begin
      if RunMode = rmSingle then
        Patience := 4
      else if Patience = 0 then
        Patience := 3   // this is immediately decremented, leaving 2 retries
      else
        Patience := Min(Patience + 2, 4);
    end;
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

  if AState = osNeedQso
    then CorrectedCallAndExchSent := False;
end;


{
  IsMyCall() will compare the user-entered callsign (APattern) against this
  operator's callsign. It supports wildcard search using '?' or substring
  matches, including the starting, ending, or any substring within the call.
  This will allow the user to partially match a received callsign using any
  copied portion of the call, including a single character.

  The algorithm uses several steps:
  1. if the enter-call contains '?', then regular expression searching is used.
     Each '?' will match a single character and a trailing '?' will match zero
     or more characters at the end of the callsign.
  2a. next, a dynamic programming algorithm called "edit distance" is used to
      compute the number of wrong or missing characters.
  2b. If no match is found, we search for the user-entered string to exist
      anywhere within the callsign.
  3. Finally, a call match Confidence value is computed to represent how
     close the entered-string matches the operator's callsign. When multiple
     callsigns partially match the entered string, the call(s) with the
     highest confidence is used.

  Confidence is defined as:
      Confidence = 100 * (# matching characters) / callsign_length

    Examples:
      1. Call W7SST, searching with 'SST' has confidence = 60%.
      2. Call K7OK, searching with 'OK', has confidence = 50%.
      3. Given 4 calls, with entered search string 'W7AB'
            W7ABC - confidence = 100*4/5 = 80%
            W7ABX - confidence = 100*4/5 = 80%
            W7AU  - confidence = 100*3/4 = 75%
            W7ABU/6 - confidence = 100*4/7 = 57%
         The first two calls with the highest confidence will respond
         to the partial call match.
}
function TDxOperator.IsMyCall(const APattern: string; ARandomResult: boolean;
  ACallConfidencePtr: PInteger): TCallCheckResult;
var
  C0: string;
  M: array of array of integer;
  x, y: integer;
  P: integer;
  reg: TPerlRegEx;
begin
  C0 := Call;
  reg := NIL;

  Result := mcNo;

  if LastCheckedCall = APattern then
    begin
      Result := LastCallCheck;
      if ACallConfidencePtr <> nil then ACallConfidencePtr^ := CallConfidence;
    end
  else
    begin
      LastCheckedCall := APattern;

      if APattern.Contains('?') then
        try
          reg := TPerlRegEx.Create();
          if APattern.EndsWith('?') then
            reg.RegEx := APattern.Replace('?','.') + '*'
          else
            reg.RegEx := APattern.Replace('?','.');
          reg.Subject := C0;
          if reg.Match then
            begin
              Result := mcAlmost;
              // count incorrect characters
              P := C0.Length - APattern.Replace('?', '', [rfReplaceAll]).Length;
              // confidence = 100 * correct chars / total length
              CallConfidence := (100 * (C0.Length - P)) div C0.Length;
            end
          else
            begin
              Result := mcNo;
              CallConfidence := 0;
            end;
        finally
          FreeAndNil(reg);
        end
      else
        begin
          //dynamic programming algorithm to determine "Edit Distance", which is
          //the number of character edits needed for the two strings to match.
          SetLength(M, Length(APattern)+1, Length(C0)+1);
          for x:=0 to High(M) do
            M[x,0] := x;
          for y:=0 to High(M[0]) do
            M[0,y] := y;

          for x:=1 to High(M) do
            for y:=1 to High(M[0]) do begin
              if APattern[x] = C0[y] then
                M[x][y] := M[x - 1][y - 1]
              else
                M[x][y] := 1 + MinIntValue([M[x    ][y - 1],
                                            M[x - 1][y    ],
                                            M[x - 1][y - 1]]);
            end;

          //classify by penalty
          //Penalty is the Edit Distance (# of missing or invalid characters)
          P := M[High(M), High(M[0])];
          if (P = 0) then
            Result := mcYes
          else if P <= (C0.Length-1)/2 then
            Result := mcAlmost
          else
            Result := mcNo;

          //partial match for matching any substring within the call
          if (Result = mcNo) and C0.Contains(APattern) then
            begin
              Result := mcAlmost;
              P := C0.Length - APattern.Length;
            end;

          // confidence = 100 * correct chars / total length
          case Result of
            mcYes: CallConfidence := 100;
            mcAlmost: CallConfidence := 100 * (C0.Length - P) div C0.Length;
            mcNo: CallConfidence := 0;
          end;
        end;

      LastCallCheck := Result;
      if ACallConfidencePtr <> nil then ACallConfidencePtr^ := CallConfidence;
    end;

  //accept a wrong call, or reject the correct one
  if ARandomResult and Ini.Lids and (Length(APattern) > 3) then
    begin
      case Result of
        mcYes: if Random < 0.01 then
          begin
            // LID rejects correct call; sends <HisCall>
            Result := mcAlmost;
            if ACallConfidencePtr <> nil then
              ACallConfidencePtr^ := 100 * (C0.Length-1) div C0.Length;
          end;
        mcAlmost: if Random < 0.04 then
          begin
            // LID accepts a wrong call; doesn't correct a partial call
            Result := mcYes;
            if ACallConfidencePtr <> nil then
              ACallConfidencePtr^ := 100;
          end;
        end;
    end;
end;


{
  For the case where there are two callers, K7AA and K7AB, and the user enters
  K7AA to work the first one, the first call is a full match (mcYes) and the
  second call is a partial match (mcAlmost). In this case, we want the full
  match to take precidence and subsequent callers should wait their turn.
}
function TDxOperator.CallConfidenceCheck(const ACall: string;
  ARandomResult: boolean): TCallCheckResult;
begin
  Result := IsMyCall(ACall, ARandomResult);
  if (Result = mcAlmost) and
    (Self.CallConfidence < Tst.Stations.BestMatchConfidence) then
    Result := mcNo;
end;


{
  A TDxOperator is considered active in the QSO if it's CallConfidence value
  meets or exceeds TContest.Stations.BestMatchConfidence.
}
function TDxOperator.IsActiveInQso: Boolean;
begin
  Result := (CallConfidence >= Tst.Stations.BestMatchConfidence) or
            (Tst.Stations.BestMatchCallsign = Self.Call);
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
    case CallConfidenceCheck(Tst.Me.HisCall, True) of
      mcYes:
        if State in [osNeedPrevEnd, osNeedQso] then SetState(osNeedNr)
        else if State = osNeedCallNr then SetState(osNeedNr)
        else if State in [osNeedNr, osNeedEnd] then MorePatience
        else if State = osNeedCall then SetState(osNeedEnd);

      mcAlmost:
        if State in [osNeedPrevEnd, osNeedQso] then SetState(osNeedCallNr)
        else if State = osNeedCallNr then MorePatience
        else if State = osNeedCall then MorePatience
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
      osNeedNr: if IsActiveInQso
        then State := osDone              // may have exchange (NR) error
        else SetState(osNeedQso);         // start over with new QSO
      osNeedCall: if IsActiveInQso
        then State := osDone              // possible partial call match
        else SetState(osNeedQso);         // start over with new QSO
      osNeedCallNr: if IsActiveInQso and CorrectedCallAndExchSent
        then State := osDone              // we are done
        else SetState(osNeedQso);         // start over with new QSO
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
          2,3: Result := msgMyCallNr1;  // <my> <exch>
          4: Result := msgMyCallNr2;    // <my> <my> <exch>
          5: Result := msgMyCall;       // <my>
        end;

    // osNeedCallNr - They have sent an almost-correct callsign.
    osNeedCallNr:
      if (RunMode = rmHst) then
        Result := msgDeMyCall1
      else
        case Trunc(R2*6) of
          0: Result := msgDeMyCall1;    // DE <my>
          1: Result := msgDeMyCall2;    // DE <my> <my>
          2,3: Result := msgMyCall;     // <my>
          4: Result := msgMyCall2;      // <my> <my>
          5: begin
              Result := msgMyCallNr1;   // <my> <exch>
              CorrectedCallAndExchSent := true;
             end;
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

