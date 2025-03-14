unit DxOperTest;

interface

uses
  DUnitX.TestFramework;

type
  TCallCheckResult = (mcNo, mcYes, mcAlmost);
  TIni = record
    LIDs: boolean;
  end;

  [TestFixture]
  TestDxOperIsMyCall = class
  var
    DbgBreak: boolean;
    Penalty: Integer;
    Call: String;
    LastCheckedCall: String;
    LastCallCheck: TCallCheckResult;
    CallConfidence: Integer;  // confidence-level of partial call match (0-100%).
                              // set by IsMyCall.

    Ini: TIni;

  protected
    function IsMyCall(const APattern: string;
      ARandomResult: boolean;
      ACallConfidencePtr: PInteger = nil): TCallCheckResult;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test(True)]
    [Category('Wildcard')]
    [TestCase('Wild.11',  'AA0AA, W?,     N')]
    [TestCase('Wild.11',  'AA0AA, W?,     N')]
    [TestCase('Wild.1',   'AA0AA, AA0?,   P')]
    [TestCase('Wild.2',   'AA0AA, AA0??,  P')]
    [TestCase('Wild.3',   'AA0AA, ??0??,  P')]
    [TestCase('Wild.4',   'AA0AA, ??0AA,  P')]
    [TestCase('Wild.5',   'AA0AA, A?0?A,  P')]
    [TestCase('Wild.6',   'AA0AA, ?A0A?,  P')]
    [TestCase('Wild.7',   'AA0AA, A?0?,   P')]
    [TestCase('Wild.8',   'AA0AA, AA?,    P')]
    [TestCase('Wild.9',   'AA0AA, A?,     P')]
    [TestCase('Wild.10',  'AA0AA, ?,      P')]  // interesting. If '?' is sent, we want all stations to almost match
    [TestCase('Wild.11',  'AA0AA, W?,     N')]
    [TestCase('Wild.12',  'AA0AA, W7?,    N')]
    [TestCase('Wild.13',  'AA0AA, W7S?,   N')]
    [TestCase('Wild.14',  'AA0AA, W7SS?,  N')]
    [TestCase('Wild.15',  'AA0AA, W7SST?, N')]
    [TestCase('Wild.16',  'AA0AA, W7SST?, N')]

    [Test(True)]
    [Category('1x1 Calls')]
    [TestCase('1x1.1',   'W7S,    W7S,    Y')]
    [TestCase('1x1.2',   'W7S,    A0X,    N')]
    [TestCase('1x1.3',   'W7S,    W7,     P')]
    [TestCase('1x1.4',   'W7S,    W7X,    P')]
    [TestCase('1x1.5',   'W7S,    W7XX,   N')]
    [TestCase('1x1.6',   'W7S,    W7XXX,  N')]
    [TestCase('1x1.7',   'W7S,    W6S,    P')]
    [TestCase('1x1.8',   'W7S,    W6X,    N')]
    [TestCase('1x1.9',   'W7S,    A7S,    P')]
    [TestCase('1x1.10',  'W7S,    W7SSS,  N')]
    [TestCase('1x1.11',  'W7S,    W7S,    Y')]
    [TestCase('1x1.12',  'W7S,    W7S,    Y')]

    [Category('1x2 Calls')]
    [TestCase('1x2.1',   'W7SS,   W7SS,   Y')]
    [TestCase('1x2.2',   'W7SS,   W7S,    P')]
    [TestCase('1x2.3',   'W7SS,   W7,     P')]
    [TestCase('1x2.4',   'W7SS,   W7SST,  P')]
    [TestCase('1x2.5',   'W7SS,   A7SS,   P')]
    [TestCase('1x2.6',   'W7SS,   A7SST,  N')]
    [TestCase('1x2.7',   'W7SS,   S,      P')]
    [TestCase('1x2.8',   'W7SS,   SS,     P')]
    [TestCase('1x2.9',   'W7SS,   7SS,    P')]
    [TestCase('1x2.10',  'W7SS,   W7SS,   Y')]
    [TestCase('1x2.11',  'W7AU,   W7AB,   P')]

    [Category('1x3 Calls')]
    [TestCase('1x3.1',   'W7SST,  W7SST,  Y')]
    [TestCase('1x3.1b',  'W7SST,  W7SSTT, P')]
    [TestCase('1x3.2',   'W7SST,  W7,     P')]
    [TestCase('1x3.3',   'W7SST,  W7S,    P')]
    [TestCase('1x3.4',   'W7SST,  W7SS,   P')]
    [TestCase('1x3.5',   'W7SST,  W7SSS,  P')]
    [TestCase('1x3.6',   'W7SST,  A7SST,  P')]
    [TestCase('1x3.7',   'W7SST,  W7ABC,  N')]
    [TestCase('1x3.8',   'W7SST,  T,      P')]
    [TestCase('1x3.8',   'W7SST,  ST,     P')]
    [TestCase('1x3.9',   'W7SST,  SST,    P')]
    [TestCase('1x3.10',  'W7SST,  7SS,    P')]
    [TestCase('1x3.11',  'W7SST,  W7XST,  P')]
    [TestCase('1x3.12',  'W7SST,  W7??T,  P')]

    [Category('1x3/9 Calls')]
    [TestCase('1x3/9.1',   'W7SST/9,  W7SST/9,  Y')]
    [TestCase('1x3/9.1b',  'W7SST/9,  W7SSTT/9, P')]
    [TestCase('1x3/9.1c',  'W7SST/9,  W7SST/8, P')]
    [TestCase('1x3/9.2',   'W7SST/9,  W7,     P')]
    [TestCase('1x3/9.3',   'W7SST/9,  W7S,    P')]
    [TestCase('1x3/9.4',   'W7SST/9,  W7SS,   P')]
    [TestCase('1x3/9.5',   'W7SST/9,  W7SSS,  P')]
    [TestCase('1x3/9.6',   'W7SST/9,  A7SST,  P')]
    [TestCase('1x3/9.7',   'W7SST/9,  W7ABC,  N')]
    [TestCase('1x3/9.8',   'W7SST/9,  T,      P')]
    [TestCase('1x3/9.8',   'W7SST/9,  ST,     P')]
    [TestCase('1x3/9.9',   'W7SST/9,  SST,    P')]
    [TestCase('1x3/9.10',  'W7SST/9,  7SS,    P')]
    [TestCase('1x3/9.11',  'W7SST/9,  W7XST,  P')]
    [TestCase('1x3/9.12',  'W7SST/9,  W7??T,  P')]
    [TestCase('1x3/9.13',  'W7SST/9,  W7??T?, P')]
    [TestCase('1x3/9.14',  'W7SST/9,  W7??T/?,P')]
    [TestCase('1x3/9.15',  'W7SST/9,  W7SST?, P')]
    [TestCase('1x3/9.16',  'W7ABU/9,  W7AB,   P')]

    [Category('2x2 Calls')]
    [TestCase('2x2.1',   'AA0AA,  AA0AA,  Y')]
    [TestCase('2x2.2',   'AA0AA,  AA0A,   P')]
    [TestCase('2x2.3',   'AA0AA,  AA0,    P')]
    [TestCase('2x2.4',   'AA0AA,  AA,     P')]
    [TestCase('2x2.5',   'AA0AA,  A,      P')]
    [TestCase('2x2.6',   'AA0AA,  A0AA,   P')]
    [TestCase('2x2.7',   'AA0AA,  0AA,    P')]
    [TestCase('2x2.8',   'AA0AA,  AA,     P')]
    [TestCase('2x2.9',   'AA0AA,  A,      P')]
    [TestCase('2x2.10',  'AA0AA,  A0A,    P')]
    [TestCase('2x2.11',  'AA0AA,  0A,     P')]
    [TestCase('2x2.12',  'AA0AA,  A0,     P')]
    [TestCase('2x2.13',  'AA0AA,  AA7AA,  P')]
    [TestCase('2x2.14',  'AA0AA,  AA7BB,  N')]
    [TestCase('2x2.15',  'AA0AA,  AA7BBB, N')]
    [TestCase('2x2.16',  'AA0AA,  AB7CD,  N')]
    [TestCase('2x2.17',  'AA0AA,  AA0AA/7,  P')]
    [TestCase('2x2.18',  'AA0AA,     FY/AA0AA, N')]  // 3 extra chars; 2 wrong chars allowed for 5 character call
    [TestCase('2x2.19',  'AA0AA,     FY,       N')]
    [TestCase('2x2.19',  'FY/AA0AA,  FY,       P')]
    [TestCase('2x2.20',  'FY/AA0AA,  FY/,      P')]
    [TestCase('2x2.21',  'FY/AA0AA,  FY/AA,    P')]

    [Category('2x3 Calls')]
    [TestCase('2x3.1',   'WN7SST, WN7SST, Y')]
    [TestCase('2x3.2',   'WN7SST, WN,     P')]
    [TestCase('2x3.3',   'WN7SST, WN7,    P')]
    [TestCase('2x3.4',   'WN7SST, WN7S,   P')]
    [TestCase('2x3.5',   'WN7SST, WN7SS,  P')]
    [TestCase('2x3.6',   'WN7SST, WN7SSS, P')]
    [TestCase('2x3.7',   'WN7SST, AN7SST, P')]
    [TestCase('2x3.8',   'WN7SST, WN7ABC, N')]
    [TestCase('2x3.9',   'WN7SST, T,      P')]
    [TestCase('2x3.10',  'WN7SST, ST,     P')]
    [TestCase('2x3.11',  'WN7SST, SST,    P')]
    [TestCase('2x3.12',  'WN7SST, 7SS,    P')]
    [TestCase('2x3.13',  'WN7SST, WN7XST, P')]
    [TestCase('2x3.14',  'WN7SST, WN7??T, P')]
    [TestCase('2x3.15',  'WN7SST, W7SST,  P')]
    [TestCase('2x3.16',  'WN7SST, W7ST,   P')]
    [TestCase('2x3.17',  'WN7SST, WN7ST,  P')]
    [TestCase('2x3.18',  'WN7SST, W7AB,   N')]
    [TestCase('2x3.19',  'WN7SST, W7ABC,  N')]
    [TestCase('2x3.20',  'WN7SST, 7,      P')]

    [Category('FY/2x3 Calls')]
    [TestCase('FY/2x3.1',   'FY/WN7SST, FY/WN7SST, Y')]
    [TestCase('FY/2x3.1b',  'FY/WN7SST, FY/WN7SST, Y')]
    [TestCase('FY/2x3.2',   'FY/WN7SST, WN,     P')]
    [TestCase('FY/2x3.3',   'FY/WN7SST, WN7,    P')]
    [TestCase('FY/2x3.4',   'FY/WN7SST, WN7S,   P')]
    [TestCase('FY/2x3.5',   'FY/WN7SST, WN7SS,  P')]
    [TestCase('FY/2x3.6',   'FY/WN7SST, WN7SSS, P')]
    [TestCase('FY/2x3.7',   'FY/WN7SST, AN7SST, P')]
    [TestCase('FY/2x3.8',   'FY/WN7SST, WN7ABC, N')]
    [TestCase('FY/2x3.9',   'FY/WN7SST, T,      P')]
    [TestCase('FY/2x3.10',  'FY/WN7SST, ST,     P')]
    [TestCase('FY/2x3.11',  'FY/WN7SST, SST,    P')]
    [TestCase('FY/2x3.12',  'FY/WN7SST, 7SS,    P')]
    [TestCase('FY/2x3.13',  'FY/WN7SST, WN7XST, P')]
    [TestCase('FY/2x3.14',  'FY/WN7SST, WN7??T, P')]
    [TestCase('FY/2x3.15',  'FY/WN7SST, W7SST,  P')]
    [TestCase('FY/2x3.16',  'FY/WN7SST, W7ST,   N')]
    [TestCase('FY/2x3.17',  'FY/WN7SST, WN7ST,  P')]
    [TestCase('FY/2x3.18',  'FY/WN7SST, W7AB,   N')]
    [TestCase('FY/2x3.19',  'FY/WN7SST, W7ABC,  N')]
    [TestCase('FY/2x3.20',  'FY/WN7SST, FY,     P')]
    [TestCase('FY/2x3.21',  'FY/WN7SST, FY?,    P')]
    [TestCase('FY/2x3.22',  'FY/WN7SST, FY/WN7, P')]
    [TestCase('FY/2x3.23',  'FY/WN7SST, FY/,    P')]
    [TestCase('FY/2x3.24',  'FY/WN7SST, FY/W?7, P')]
    [TestCase('FY/2x3.25',  'FY/WN7SST, FX/W7SST, P')]

    [Category('2x3/9 Calls')]
    [TestCase('2x3/9.1',   'WN7SST/9, WN7SST/9, Y')]
    [TestCase('2x3/9.2',   'WN7SST/9, WN,     P')]
    [TestCase('2x3/9.3',   'WN7SST/9, WN7,    P')]
    [TestCase('2x3/9.4',   'WN7SST/9, WN7S,   P')]
    [TestCase('2x3/9.5',   'WN7SST/9, WN7SS,  P')]
    [TestCase('2x3/9.6',   'WN7SST/9, WN7SSS, P')]
    [TestCase('2x3/9.7',   'WN7SST/9, AN7SST, P')]
    [TestCase('2x3/9.8',   'WN7SST/9, WN7ABC, N')]
    [TestCase('2x3/9.9',   'WN7SST/9, T,      P')]
    [TestCase('2x3/9.10',  'WN7SST/9, ST,     P')]
    [TestCase('2x3/9.11',  'WN7SST/9, SST,    P')]
    [TestCase('2x3/9.12',  'WN7SST/9, 7SS,    P')]
    [TestCase('2x3/9.13',  'WN7SST/9, WN7XST, P')]
    [TestCase('2x3/9.14',  'WN7SST/9, WN7??T, P')]
    [TestCase('2x3/9.15',  'WN7SST/9, W7SST,  P')]
    [TestCase('2x3/9.16',  'WN7SST/9, W7ST,   N')]
    [TestCase('2x3/9.17',  'WN7SST/9, WN7ST,  P')]
    [TestCase('2x3/9.18',  'WN7SST/9, W7AB,   N')]
    [TestCase('2x3/9.19',  'WN7SST/9, W7ABC,  N')]
    [TestCase('2x3/9.20',  'WN7SST/9, FY,     N')]
    [TestCase('2x3/9.21',  'WN7SST/9, FY?,    N')]
    [TestCase('2x3/9.22',  'WN7SST/9, /9,     P')]
    [TestCase('2x3/9.23',  'WN7SST/9, 9,      P')]
    [TestCase('2x3/9.23b', 'WN7SST/9, 6,      N')]
    [TestCase('2x3/9.23c', 'WN7SST/9, 7,      P')]
    [TestCase('2x3/9.24',  'WN7SST/9, T/9,    P')]
    [TestCase('2x3/9.25',  'WN7SST/9, SST/9,  P')]
    [TestCase('2x3/9.26',  'WN7SST/9, 7SST/9, P')]
    [TestCase('2x3/9.27',  'WN7SST/9, WN7?/9, N')]
    [TestCase('2x3/9.28',  'WN7SST/9, WN7???/9, P')]

    procedure RunTest(const ADxCall, AEnteredCall, AExpected: string);
  end;

implementation

uses
  Math,             // for MaxIntValue
  TypInfo,          // for typeInfo
  PerlRegEx,        // for regular expression support
  System.SysUtils;

function ToStr(const val : TCallCheckResult) : string; overload;
begin
  Result := GetEnumName(typeInfo(TCallCheckResult), Ord(val));
end;

procedure TestDxOperIsMyCall.SetupFixture;
begin
  LastCheckedCall := '';
  LastCallCheck := mcNo;
  CallConfidence := 0;
  Ini.LIDs := False;
end;

procedure TestDxOperIsMyCall.TearDownFixture;
begin
end;

procedure TestDxOperIsMyCall.RunTest(const ADxCall, AEnteredCall, AExpected: string);
var
  R, Expected: TCallCheckResult;
  EnteredCall: String;
  S, T: string;

  procedure RunAlgo(var S: String; const EnteredCall:string;
    Expected: TCallCheckResult);
  var
    R: TCallCheckResult;
    Confidence: Integer;
    T: String;
  begin
    LastCheckedCall := '';
    LastCallCheck := mcNo;
    CallConfidence := 0;
    T := '';
    R := IsMyCall(EnteredCall, False, @Confidence);
    if R <> Expected then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //LastCheckedCall := '';
        //R := IsMyCall(EnteredCall, False, @Confidence);
        //LastCheckedCall := '';
        //R := IsMyCall(EnteredCall, False, @Confidence);
    {$endif}
        T := format('    %s, Entered: ''%s'' --> %s, %s expected, P=%d.',
          [Self.Call, EnteredCall, ToStr(R), ToStr(Expected), Self.Penalty]);
        S := S + #10 + T;
      end;
  end;
begin
{$ifdef DEBUG}
  DbgBreak := False;
{$endif}
  // TCallCheckResult = (mcNo, mcYes, mcAlmost);
  case AExpected.Trim[1] of
    'N': Expected := mcNo;
    'Y': Expected := mcYes;
    'P': Expected := mcAlmost;
    else Assert.FailFmt('Invalid Expected value: %s; expecting N(mcNo), Y(mcYes), P(mcAlmost)', [AExpected]);
  end;
  Self.Call := ADxCall.Trim;
  EnteredCall := AEnteredCall.Trim;

  RunAlgo(S, EnteredCall, Expected);    // Revised RegEx and DP Algorithm (1.85.2)
  if S <> '' then Assert.Fail(S);
end;


{
  Below is a copy of TDxOperator.IsMyCall().
  (This will be refactored in the future)
}
function TestDxOperIsMyCall.IsMyCall(const APattern: string;
  ARandomResult: boolean;
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
              Self.Penalty := p;
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
          Self.Penalty := M[High(M), High(M[0])];
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
              Self.Penalty := P;
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
//            DebugLn('DxOper.IsMyCall(%s): mcYes->mcAlmost, LID rejects correct call', [Call]);
          end;
        mcAlmost: if Random < 0.04 then
          begin
            // LID accepts a wrong call; doesn't correct a partial call
            Result := mcYes;
            if ACallConfidencePtr <> nil then
              ACallConfidencePtr^ := 100;
//            DebugLn('DxOper.IsMyCall(%s): mcAlmost->mcYes, LID accepts wrong call', [Call]);
          end;
        end;
    end;
end;


initialization
  TDUnitX.RegisterTestFixture(TestDxOperIsMyCall);

end.
