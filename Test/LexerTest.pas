unit LexerTest;

interface

uses
  Lexer,
  System.TypInfo,
  Classes;

type
  {
    TestTLexerBase implements a common test case execution behavior to be
    used by multiple test fixtures, each with a different Lexer Rule table.

    Useful links:
      - https://docwiki.embarcadero.com/RADStudio/Alexandria/en/DUnitX_Overview
      - https://github.com/VSoftTechnologies/DUnitX/wiki
  }
  TestTLexerBase = class(TObject)
    protected
      aLexer: TLexer;
      sl: TStringList;
      Info: PTypeInfo;

      procedure Setup(Lexer: TLexer; ATypeInfo: PTypeInfo);
      procedure Teardown;
      procedure RunTest(const AValue, ExpectedTokens: string);

      function ToStr(const AToken: TExchToken): String; overload;
  end;

implementation

uses
  DUnitX.TestFramework,
  StrUtils,           // ContainsText
  System.SysUtils;

{ TestTLexerBase }

procedure TestTLexerBase.Setup(Lexer: TLexer; ATypeInfo: PTypeInfo);
begin
  aLexer := Lexer;
  sl := TStringList.Create;
  sl.Delimiter := ',';
  sl.StrictDelimiter := True;
  Info := ATypeInfo;
end;

procedure TestTLexerBase.TearDown;
begin
  FreeAndNil(sl);
  FreeAndNil(aLexer);
end;

procedure TestTLexerBase.RunTest(const AValue, ExpectedTokens: string);
var
  token: TExchToken;
  tokenStr, expected: string;
begin
  try
    sl.DelimitedText := ExpectedTokens;

    var I: integer := 0;
    aLexer.Input(AValue);
    try
      while aLexer.NextToken(token) do
      begin
        Assert.IsTrue(I < sl.Count, 'NextToken returned extra tokens');
        tokenStr := ToStr(token);
        expected := Trim(sl[I]);
        Assert.Contains(tokenStr, expected, 'NextToken failure');
        Inc(I);
      end;
    except
      // exception occured, assume last current position
      on E: TLexer.ELexerError do begin
        expected := Trim(sl[I]);
        if not StrUtils.ContainsText(E.Message, expected) then
        begin
          Assert.Contains(E.Message, expected, 'Exception contained wrong message');
          Raise;
        end
        else
          Inc(I);
      end;
    end;
    Assert.AreEqual(sl.Count, I, 'NextToken - token count mismatch');

  finally
    sl.Clear;
  end;
end;


// returns: '<TokenType>(<Value>) at <Pos>' (e.g. 'ttAlpha(ABC) at 3')
function TestTLexerBase.ToStr(const AToken: TExchToken): string;
begin
  var tokName: string := GetEnumName(Info, AToken.TokenType);
  Result := format('%s(%s) at %d', [tokName, AToken.Value, AToken.Pos]);
end;


type
  [TestFixture('Lexer Test', 'Basic tests with three rules')]
  TestTLexer = class(TestTLexerBase)
  private
    type
      TTokenType = (ttAlpha, ttNumeric, ttAlphaNumeric);

    const
      LexerRules: array[0..2] of TTokenRuleDef = (
        (R: '[A-Z]+';               T: Ord(ttAlpha)),
        (R: '\d+';                  T: Ord(ttNumeric)),
        (R: '[A-Z][A-Z\d]*';        T: Ord(ttAlphaNumeric))
      );

  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    [Category('Lexer')]
    [TestCase('Lexer.Empty.1', ';', ';')]  // empty string immediately returns False (no token)
    [TestCase('Lexer.Empty.2', '  ;', ';')]  // whitespace only string, returns False (no token)
    [TestCase('Lexer.Empty.3', '  A;ttAlpha(A) at 3', ';')]  // leading whitespace
    [TestCase('Lexer.Empty.4', 'A  ;ttAlpha(A) at 1', ';')]  // trailing whitespace
    [TestCase('Lexer.Empty.5', ' A ;ttAlpha(A) at 2', ';')]  // leading and trailing whitespace
    [TestCase('Lexer.Alpha.1', 'A;ttAlpha(A) at 1', ';')]
    [TestCase('Lexer.Alpha.2', 'AB;ttAlpha(AB) at 1', ';')]
    [TestCase('Lexer.Alpha.3', 'ABC;ttAlpha(ABC) at 1', ';')]
    [TestCase('Lexer.Alpha.4', 'ABC DEF;ttAlpha(ABC) at 1,ttAlpha(DEF) at 5', ';')]
    [TestCase('Lexer.Numeric.1', '1;ttNumeric(1) at 1', ';')]
    [TestCase('Lexer.Numeric.2', '12;ttNumeric(12) at 1', ';')]
    [TestCase('Lexer.Numeric.3', '123;ttNumeric(123) at 1', ';')]
    [TestCase('Lexer.Numeric.4', '1234;ttNumeric(1234) at 1', ';')]
    [TestCase('Lexer.Numeric.5', '123 456;ttNumeric(123) at 1,ttNumeric(456) at 5', ';')]
    [TestCase('Lexer.Numeric.6', '1234 567 89 0;ttNumeric(1234) at 1,ttNumeric(567) at 6,ttNumeric(89) at 10,ttNumeric(0) at 13', ';')]
    [TestCase('Lexer.AlphaNum.1', 'ABC123;ttAlpha(ABC) at 1,ttNumeric(123) at 4', ';')]
    [TestCase('Lexer.AlphaNum.2', 'ABC123 A1B2C3;ttAlpha(ABC) at 1,ttNumeric(123) at 4,ttAlpha(A) at 8,ttNumeric(1) at 9,ttAlpha(B),ttNumeric(2),ttAlpha(C),ttNumeric(3)', ';')]
    [TestCase('Lexer.AlphaNum.3', 'ABC 123 A1 B2 C3;ttAlpha(ABC) at 1,ttNumeric(123) at 5,ttAlpha(A) at 9,ttNumeric(1) at 10,ttAlpha(B),ttNumeric(2),ttAlpha(C),ttNumeric(3)', ';')]
    [TestCase('Lexer.Mixed.1', '22 A 56 OR;ttNumeric(22) at 1, ttAlpha(A) at 4, ttNumeric(56) at 6, ttAlpha(OR) at 9', ';')]
    [TestCase('Lexer.Mixed.2', '22A 56OR;ttNumeric(22) at 1,ttAlpha(A) at 3, ttNumeric(56) at 5, ttAlpha(OR) at 7', ';')]
    [TestCase('Lexer.Mixed.3', '1 22 333 A OR WWA 4444;ttNumeric, ttNumeric, ttNumeric, ttAlpha(A), ttAlpha(OR), ttAlpha(WWA), ttNumeric(4444)', ';')]
    [TestCase('Lexer.Mixed.4', 'W1AW 22A 56OR;ttAlpha(W),ttNumeric(1) at 2, ttAlpha(AW) at 3, ttNumeric(22), ttAlpha(A), ttNumeric(56), ttAlpha(OR)', ';')]
    [TestCase('Lexer.Mixed.5', '22A XYZZY 72OR;ttNumeric,ttAlpha(A),ttAlpha(XYZZY),ttNumeric(72),ttAlpha(OR)', ';')]
    [TestCase('Lexer.Error.1', '3.2;ttNumeric(3) at 1,Invalid data (.) at position 2', ';')]
    [TestCase('Lexer.Error.2', 'XY+ZZY;ttAlpha(XY) at 1,Invalid data (+) at position 3', ';')]
    procedure LexerTest(const AValue, ExpectedTokens: string);
  end;

{ TestTLexer }

procedure TestTLexer.Setup;
begin
  inherited Setup(
    TLexer.Create(LexerRules, {SkipWhitespace=}True),
    TypeInfo(TTokenType));
end;

procedure TestTLexer.TearDown;
begin
  inherited TearDown;
end;

procedure TestTLexer.LexerTest(const AValue, ExpectedTokens: string);
begin
  RunTest(AValue, ExpectedTokens);
end;


{ TestTLexerWs }

type
  [TestFixture('Lexer Test w/ WS Rules', 'Adds WS rule')]
  TestTLexerWs = class(TestTLexerBase)
  private
    type
      TTokenType = (ttWhitespace, ttNumberPrec, ttCheckSect,
        ttDigits, ttDigit2, ttDigit1, ttCallsign, ttPrec, ttSect);

    const
      RulesWs: array[0..8] of TTokenRuleDef = (
        (R: ' +';                   T: Ord(ttWhitespace)),
        (R: '\d+[QABUMS]';          T: Ord(ttNumberPrec)),
        (R: '\d{2}[A-Z]{2,3}';      T: Ord(ttCheckSect)),
        (R: '\d\d\d+';              T: Ord(ttDigits)),
        (R: '\d\d';                 T: Ord(ttDigit2)),
        (R: '\d';                   T: Ord(ttDigit1)),
        (R: '[A-Z]+\d+[A-Z\d/]+';   T: Ord(ttCallSign)),
        (R: '[QABUMS]';             T: Ord(ttPrec)),
        (R: '[A-Z]{2,3}';           T: Ord(ttSect))
      );

  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    [Category('LexerWs')]
    [TestCase('LexerWs.Digit1', '1;ttDigit1(1) at 1', ';')]
    [TestCase('LexerWs.Digit1ws', '1 ;ttDigit1(1) at 1, ttWhitespace( ) at 2', ';')]
    [TestCase('LexerWs.wsDigit1ws', ' 1 ;ttWhitespace( ) at 1, ttDigit1(1) at 2, ttWhitespace( ) at 3', ';')]
    [TestCase('LexerWs.Digit2', '12;ttDigit2(12) at 1', ';')]
    [TestCase('LexerWs.Digit2.ws', '12 ;ttDigit2(12) at 1, ttWhitespace( ) at 3', ';')]
    [TestCase('LexerWs.wsDigit2.ws', ' 12 ;ttWhitespace( ) at 1, ttDigit2(12) at 2, ttWhitespace( ) at 4', ';')]
    [TestCase('LexerWs.Digits', '123;ttDigits(123) at 1', ';')]
    [TestCase('LexerWs.Digits.ws', '123 ;ttDigits(123) at 1, ttWhitespace( ) at 4', ';')]
    [TestCase('LexerWs.wsDigits.ws', '   123  ;ttWhitespace(   ) at 1, ttDigits(123) at 4, ttWhitespace(  ) at 7', ';')]
    [TestCase('LexerWs.Mixed.1', '22 A 56 OR;ttDigit2(22) at 1, ttWhitespace, ttPrec(A) at 4, ttWhitespace, ttDigit2(56) at 6, ttWhitespace, ttSect(OR) at 9', ';')]
    [TestCase('LexerWs.Mixed.1ws', '22 A 56 OR ;ttDigit2(22) at 1, ttWhitespace, ttPrec(A) at 4, ttWhitespace, ttDigit2(56) at 6, ttWhitespace, ttSect(OR) at 9, ttWhitespace', ';')]
    [TestCase('LexerWs.wsMixed.1ws', '  22 A  56 OR ;ttWhitespace(  ) at 1, ttDigit2(22) at 3, ttWhitespace( ) at 5, ttPrec(A) at 6, ttWhitespace(  ) at 7, ttDigit2(56) at 9, ttWhitespace, ttSect(OR) at 12, ttWhitespace( ) at 14', ';')]
    procedure LexerTest(const AValue, ExpectedTokens: string);
  end;


procedure TestTLexerWs.Setup;
begin
  inherited Setup(
    TLexer.Create(RulesWs, {SkipWhitespace=}False),
    TypeInfo(TTokenType));
end;

procedure TestTLexerWs.TearDown;
begin
  inherited TearDown;
end;

procedure TestTLexerWs.LexerTest(const AValue, ExpectedTokens: string);
begin
  RunTest(AValue, ExpectedTokens);
end;


initialization
  TDUnitX.RegisterTestFixture(TestTLexer);
  TDUnitX.RegisterTestFixture(TestTLexerWs);
end.
