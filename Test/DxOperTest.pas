unit DxOperTest;

interface

uses
  DUnitX.TestFramework;

type
  TUseAlgorithm = (uaOriginal, uaCurrent, uaHybrid);
  TCallCheckResult = (mcNo, mcYes, mcAlmost);
  TIni = record
    LIDs: boolean;
  end;

  [TestFixture]
  TestDxOperIsMyCall = class
  var
    DbgBreak: boolean;
    UseAlgorithm: TUseAlgorithm;
    Penalty: Integer;
    Call: String;
    Ini: TIni;

  protected
    function IsMyCall(const ACall: string;
      ARandomResult: boolean): TCallCheckResult;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test(True)]
    [Category('1x1 Calls')]
    [TestCase('FY/2x3.19',  'FY/WN7SST, W7ABC,  0')]
    [TestCase('FY/2x3.19',  'FY/WN7SST, W7ABC,  0')]
    [TestCase('FY/2x3.19',  'FY/WN7SST, W7ABC,  0')]
    [TestCase('1x1.1',   'W7S,    W7S,    1')]
    [TestCase('1x1.2',   'W7S,    A0X,    0')]
    [TestCase('1x1.3',   'W7S,    W7,     2')]
    [TestCase('1x1.4',   'W7S,    W7X,    2')]
    [TestCase('1x1.5',   'W7S,    W7XX,   0')]
    [TestCase('1x1.6',   'W7S,    W7XXX,  0')]
    [TestCase('1x1.7',   'W7S,    W6S,    2')]
    [TestCase('1x1.8',   'W7S,    W6X,    0')]
    [TestCase('1x1.9',   'W7S,    A7S,    2')]
    [TestCase('1x1.10',  'W7S,    W7SSS,  0')]
    [TestCase('1x1.11',  'W7S,    W7S,    1')]
    [TestCase('1x1.12',  'W7S,    W7S,    1')]

    [Category('1x2 Calls')]
    [TestCase('1x2.1',   'W7SS,   W7SS,   1')]
    [TestCase('1x2.2',   'W7SS,   W7S,    2')]
    [TestCase('1x2.3',   'W7SS,   W7,     2')]
    [TestCase('1x2.4',   'W7SS,   W7SST,  2')]
    [TestCase('1x2.5',   'W7SS,   A7SS,   2')]
    [TestCase('1x2.6',   'W7SS,   A7SST,  0')]
    [TestCase('1x2.7',   'W7SS,   S,      0')]
    [TestCase('1x2.7',   'W7SS,   SS,     2')]
    [TestCase('1x2.8',   'W7SS,   7SS,    2')]
    [TestCase('1x2.9',   'W7SS,   W7SS,   1')]

    [Category('1x3 Calls')]
    [TestCase('1x3.1',   'W7SST,  W7SST,  1')]
    [TestCase('1x3.1b',  'W7SST,  W7SSTT, 2')]
    [TestCase('1x3.2',   'W7SST,  W7,     2')]
    [TestCase('1x3.3',   'W7SST,  W7S,    2')]
    [TestCase('1x3.4',   'W7SST,  W7SS,   2')]
    [TestCase('1x3.5',   'W7SST,  W7SSS,  2')]
    [TestCase('1x3.6',   'W7SST,  A7SST,  2')]
    [TestCase('1x3.7',   'W7SST,  W7ABC,  0')]
    [TestCase('1x3.8',   'W7SST,  T,      0')]
    [TestCase('1x3.8',   'W7SST,  ST,     2')]
    [TestCase('1x3.9',   'W7SST,  SST,    2')]
    [TestCase('1x3.10',  'W7SST,  7SS,    2')]
    [TestCase('1x3.11',  'W7SST,  W7XST,  2')]
    [TestCase('1x3.12',  'W7SST,  W7??T,  2')]

    [Category('2x3 Calls')]
    [TestCase('2x3.1',   'WN7SST, WN7SST, 1')]
    [TestCase('2x3.2',   'WN7SST, WN,     2')]
    [TestCase('2x3.3',   'WN7SST, WN7,    2')]
    [TestCase('2x3.4',   'WN7SST, WN7S,   2')]
    [TestCase('2x3.5',   'WN7SST, WN7SS,  2')]
    [TestCase('2x3.6',   'WN7SST, WN7SSS, 2')]
    [TestCase('2x3.7',   'WN7SST, AN7SST, 2')]
    [TestCase('2x3.8',   'WN7SST, WN7ABC, 0')]
    [TestCase('2x3.9',   'WN7SST, T,      0')]
    [TestCase('2x3.10',  'WN7SST, ST,     2')]
    [TestCase('2x3.11',  'WN7SST, SST,    2')]
    [TestCase('2x3.12',  'WN7SST, 7SS,    2')]
    [TestCase('2x3.13',  'WN7SST, WN7XST, 2')]
    [TestCase('2x3.14',  'WN7SST, WN7??T, 2')]
    [TestCase('2x3.15',  'WN7SST, W7SST,  2')]
    [TestCase('2x3.16',  'WN7SST, W7ST,   2')]
    [TestCase('2x3.17',  'WN7SST, WN7ST,  2')]
    [TestCase('2x3.18',  'WN7SST, W7AB,   0')]
    [TestCase('2x3.19',  'WN7SST, W7ABC,  0')]
    [TestCase('2x3.20',  'WN7SST, 7,      0')]

    [Category('FY/2x3 Calls')]
    [TestCase('FY/2x3.1',   'FY/WN7SST, FY/WN7SST, 1')]
    [TestCase('FY/2x3.2',   'FY/WN7SST, WN,     2')]
    [TestCase('FY/2x3.3',   'FY/WN7SST, WN7,    2')]
    [TestCase('FY/2x3.4',   'FY/WN7SST, WN7S,   2')]
    [TestCase('FY/2x3.5',   'FY/WN7SST, WN7SS,  2')]
    [TestCase('FY/2x3.6',   'FY/WN7SST, WN7SSS, 2')]
    [TestCase('FY/2x3.7',   'FY/WN7SST, AN7SST, 2')]
    [TestCase('FY/2x3.8',   'FY/WN7SST, WN7ABC, 0')]
    [TestCase('FY/2x3.9',   'FY/WN7SST, T,      0')]
    [TestCase('FY/2x3.10',  'FY/WN7SST, ST,     2')]
    [TestCase('FY/2x3.11',  'FY/WN7SST, SST,    2')]
    [TestCase('FY/2x3.12',  'FY/WN7SST, 7SS,    2')]
    [TestCase('FY/2x3.13',  'FY/WN7SST, WN7XST, 2')]
    [TestCase('FY/2x3.14',  'FY/WN7SST, WN7??T, 2')]
    [TestCase('FY/2x3.15',  'FY/WN7SST, W7SST,  2')]
    [TestCase('FY/2x3.16',  'FY/WN7SST, W7ST,   0')]
    [TestCase('FY/2x3.17',  'FY/WN7SST, WN7ST,  2')]
    [TestCase('FY/2x3.18',  'FY/WN7SST, W7AB,   0')]
    [TestCase('FY/2x3.19',  'FY/WN7SST, W7ABC,  0')]
    [TestCase('FY/2x3.20',  'FY/WN7SST, FY,     2')]
    [TestCase('FY/2x3.21',  'FY/WN7SST, FY?,    2')]

    [Category('2x3/9 Calls')]
    [TestCase('2x3/9.1',   'WN7SST/9, WN7SST/9, 1')]
    [TestCase('2x3/9.2',   'WN7SST/9, WN,     2')]
    [TestCase('2x3/9.3',   'WN7SST/9, WN7,    2')]
    [TestCase('2x3/9.4',   'WN7SST/9, WN7S,   2')]
    [TestCase('2x3/9.5',   'WN7SST/9, WN7SS,  2')]
    [TestCase('2x3/9.6',   'WN7SST/9, WN7SSS, 2')]
    [TestCase('2x3/9.7',   'WN7SST/9, AN7SST, 2')]
    [TestCase('2x3/9.8',   'WN7SST/9, WN7ABC, 0')]
    [TestCase('2x3/9.9',   'WN7SST/9, T,      0')]
    [TestCase('2x3/9.10',  'WN7SST/9, ST,     2')]
    [TestCase('2x3/9.11',  'WN7SST/9, SST,    2')]
    [TestCase('2x3/9.12',  'WN7SST/9, 7SS,    2')]
    [TestCase('2x3/9.13',  'WN7SST/9, WN7XST, 2')]
    [TestCase('2x3/9.14',  'WN7SST/9, WN7??T, 2')]
    [TestCase('2x3/9.15',  'WN7SST/9, W7SST,  2')]
    [TestCase('2x3/9.16',  'WN7SST/9, W7ST,   2')]
    [TestCase('2x3/9.17',  'WN7SST/9, WN7ST,  2')]
    [TestCase('2x3/9.18',  'WN7SST/9, W7AB,   0')]
    [TestCase('2x3/9.19',  'WN7SST/9, W7ABC,  0')]
    [TestCase('2x3/9.20',  'WN7SST/9, FY,     0')]
    [TestCase('2x3/9.21',  'WN7SST/9, FY?,    0')]
    [TestCase('2x3/9.22',  'WN7SST/9, /9,     2')]
    [TestCase('2x3/9.23',  'WN7SST/9, 9,      2')]
    [TestCase('2x3/9.24',  'WN7SST/9, T/9,    2')]
    [TestCase('2x3/9.25',  'WN7SST/9, SST/9,  2')]
    [TestCase('2x3/9.26',  'WN7SST/9, 7SST/9, 2')]

    procedure RunTest(const ADxCall, AEnteredCall: string; AExpected: integer);
  end;

implementation

uses
  Math,             // for MaxIntValue
  TypInfo,          // for typeInfo
  System.SysUtils;

function ToStr(const val : TUseAlgorithm) : string; overload;
begin
  Result := GetEnumName(typeInfo(TUseAlgorithm), Ord(val));
end;

function ToStr(const val : TCallCheckResult) : string; overload;
begin
  Result := GetEnumName(typeInfo(TCallCheckResult), Ord(val));
end;

procedure TestDxOperIsMyCall.SetupFixture;
begin
  Ini.LIDs := False;
end;

procedure TestDxOperIsMyCall.TearDownFixture;
begin
end;

procedure TestDxOperIsMyCall.RunTest(const ADxCall, AEnteredCall: string; AExpected: integer);
var
  R, Expected: TCallCheckResult;
  EnteredCall: String;
  S, T: string;

  procedure RunAlgo(var S: String; Algorithm: TUseAlgorithm; const EnteredCall:string;
    Expected: TCallCheckResult);
  const
    VersionTbl: array[TUseAlgorithm] of PCHAR = (
      'v1.68', 'v1.68.2+', 'v1.85.2');
  var
    R: TCallCheckResult;
    T: String;
  begin
    T := '';
    UseAlgorithm := Algorithm;
    R := IsMyCall(EnteredCall, False);
    if R <> Expected then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := IsMyCall(EnteredCall, False);
        //R := IsMyCall(EnteredCall, False);
    {$endif}
        T := format('%s, Entered: ''%s'' --> %s.  %s expected, P=%d, %s (%s)',
          [Self.Call, EnteredCall, ToStr(R), ToStr(Expected),
           Self.Penalty, ToStr(UseAlgorithm), VersionTbl[UseAlgorithm]]);
        S := S + #10 + T;
      end;
  end;
begin
{$ifdef DEBUG}
  DbgBreak := False;
{$endif}
  // TCallCheckResult = (mcNo, mcYes, mcAlmost);
  case AExpected of
    0: Expected := mcNo;
    1: Expected := mcYes;
    2: Expected := mcAlmost;
    else Assert.FailFmt('Invalid Expected value: %s; expecting 0(mcNo), 1(mcYes), 2(mcAlmost)', [AExpected]);
  end;
  Self.Call := ADxCall.Trim;
  EnteredCall := AEnteredCall.Trim;

  // run this test case with all three algorithms
  RunAlgo(S, uaOriginal, EnteredCall, Expected); // Original Algorithm (1.68)
  RunAlgo(S, uaCurrent, EnteredCall, Expected);  // Current Algorithm (1.68.1+)
  RunAlgo(S, uaHybrid, EnteredCall, Expected);   // Hybrid Algorithm (1.85.2)
  if S <> '' then Assert.Fail(S);
end;


function TestDxOperIsMyCall.IsMyCall(const ACall: string;
  ARandomResult: boolean): TCallCheckResult;
var
  C, C0: string;
  M: array of array of integer;
  x, y: integer;
  T, L, D: integer;
  W_X, W_Y, W_D: integer;
  NewerAlgorithm: Boolean;
begin
  C0 := Call;
  C := ACall;

  SetLength(M, Length(C)+1, Length(C0)+1);

  case UseAlgorithm of
    uaOriginal: NewerAlgorithm := False;
    uaCurrent:  NewerAlgorithm := True;
    uaHybrid:   NewerAlgorithm := C0.Length > 4;
  end;

  if NewerAlgorithm then
    begin W_X := 1; W_Y := 1; W_D := 1; end
    //begin W_X := 2; W_Y := 2; W_D := 2; end
  else
    begin W_X := 2; W_Y := 2; W_D := 2; end;
    //begin W_X := 1; W_Y := 1; W_D := 1; end;

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
      if (C[x] <> '?') then
        Inc(L, W_X);

      D := M[x-1,y-1];
      //'?' matches any char
      //if not (C[x] in [C0[y], '?']) then Inc(D, W_D);
      if not (CharInSet(C[x], [C0[y], '?'])) then
        Inc(D, W_D);

      M[x,y] := MinIntValue([T,D,L]);
    end;

  //classify by penalty
  Self.Penalty := M[High(M), High(M[0])];
  if NewerAlgorithm then
    begin
    var P: Integer := M[High(M), High(M[0])];
    if (P = 0) then
      Result := mcYes
    else if ((C0.length <= 4) and (C0.length - P >= 3)) then
      Result := mcAlmost
    else if ((C0.length > 4) and (C0.length - P >= 4)) then
      Result := mcAlmost
    else if (((Length(C0) <= 4) and (Length(C0) - P >= 3)) or
         ((Length(C0) > 4) and (Length(C0) - P >= 4))) then
      Result := mcAlmost
    else
      Result := mcNo;
    end
  else
    case M[High(M), High(M[0])] of
      0:   Result := mcYes;
      1,2: Result := mcAlmost;
      else Result := mcNo;
    end;

  //callsign-specific corrections

  if (not Ini.Lids) and (Length(C) = 2) {and
     (C0.Length > 4)} and (Result = mcAlmost) then
    Result := mcNo;

  //partial and wildcard match result in 0 penalty but are not exact matches
  if (Result = mcYes) then
    if (Length(C) <> Length(C0)) or (Pos('?', C) > 0)
      then Result := mcAlmost;

  //partial match too short
  if Length(StringReplace(C, '?', '', [rfReplaceAll])) < 2 then Result := mcNo;

{  //partial match for starting/ending character match
  if (Result = mcNo) and (C0.StartsWith(C) or C0.EndsWith(C)) then
    Result := mcAlmost;
}
  //accept a wrong call, or reject the correct one
  if ARandomResult and Ini.Lids and (Length(C) > 3) then
    case Result of
      mcYes: if Random < 0.01 then Result := mcAlmost;   // LID rejects correct call; sends <HisCall>
      mcAlmost: if Random < 0.04 then Result := mcYes;   // LID accepts a wrong call; doesn't correct a partial call
      end;
end;

initialization
  TDUnitX.RegisterTestFixture(TestDxOperIsMyCall);

end.
