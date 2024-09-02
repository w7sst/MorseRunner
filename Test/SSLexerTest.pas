unit SSLexerTest;

interface

uses
  DUnitX.TestFramework;

implementation

uses
  LexerTest,          // for TestTLexerBase
  Lexer,              // for TLexer
  SSExchParser,       // for SSLexerRules, TSSLexer
  Math,
  System.Classes,     // TStringList
  System.TypInfo,     // GetEnumName
  System.SysUtils;

type
  [TestFixture('SSRules', 'Tests using SSLexerRules')]
  TestSSRules = class(TestTLexerBase)
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test(True)]
    [Category('SSRules')]
{//Original from a few days ago...}
    [TestCase('Empty.1', ';', ';')]  // empty string immediately returns False (no token)
    [TestCase('Alpha.1',  'ABC;ttAlpha(ABC) at 1', ';')]
    [TestCase('Alpha.2',  'ABC DEF;ttAlpha(ABC) at 1,ttAlpha(DEF) at 5', ';')]
    [TestCase('Digit1',   '1;ttDigit1(1) at 1', ';')]
    [TestCase('Digit2',   '12;ttDigit2(12) at 1', ';')]
    [TestCase('Digits.3', '123;ttDigits(123) at 1', ';')]
    [TestCase('Digits.4', '1234;ttDigits(1234) at 1', ';')]
    [TestCase('Digits.5', '123 456;ttDigits(123) at 1,ttDigits(456) at 5', ';')]
    [TestCase('Digits.6', '1234 567 89 0;ttDigits(1234) at 1,ttDigits(567) at 6,ttDigit2(89) at 10,ttDigit1(0) at 13', ';')]

//      (R: '\d+[QABUMS]\b';          T: Ord(ttNumberPrec)),
//    [TestCase('NumPrec.1', '1A;ttNumberPrec(1A) at 1', ';')]
//    [TestCase('NumPrec.1', '1A;ttDigit1(1) at 1,ttAlpha(A) at 2', ';')]
//    [TestCase('NumPrec.2', '12B;ttNumberPrec(12B) at 1', ';')]
//    [TestCase('NumPrec.3', '123Q;ttNumberPrec(123Q) at 1', ';')]
//    [TestCase('NumPrec.4', '1234U;ttNumberPrec(1234U) at 1', ';')]
//    [TestCase('NumPrec.5', '1234M;ttNumberPrec(1234M) at 1', ';')]
//    [TestCase('NumPrec.6', '1234S;ttNumberPrec(1234S) at 1', ';')]
//    [TestCase('NumPrec.7', '1234X;ttNumericAlpha(1234X) at 1', ';')]

    [TestCase('NumPrec.1', '1A;ttDigit1(1) at 1,ttAlpha(A) at 2', ';')]
    [TestCase('NumPrec.3', '123Q;ttDigits(123) at 1,ttAlpha(Q) at 4', ';')]
    [TestCase('NumPrec.7', '1234X;ttDigits(1234) at 1,ttAlpha(X) at 5', ';')]

//      (R: '\d+[A-Z]+';            T: Ord(ttNumericAlpha)),
    [TestCase('NumAlpha.1', '123A;ttDigits(123) at 1,ttAlpha(A) at 4', ';')]
    [TestCase('NumAlpha.2', '123AB;ttDigits(123) at 1,ttAlpha(AB) at 4', ';')]
    [TestCase('NumAlpha.3', '123ABC;ttDigits(123) at 1,ttAlpha(ABC) at 4', ';')]
    [TestCase('NumAlpha.4', '72OR;ttDigit2(72) at 1,ttAlpha(OR) at 3', ';')]
    [TestCase('NumAlpha.5', '72 OR;ttDigit2(72),ttAlpha(OR) at 4', ';')]
    [TestCase('NumAlpha.6', '7 WWA;ttDigit1(7),ttAlpha(WWA) at 3', ';')]
    [TestCase('NumAlpha.7', '7 W;ttDigit1(7),ttAlpha(W) at 3', ';')]
    [TestCase('NumAlpha.8', '7 A;ttDigit1(7),ttAlpha(A) at 3', ';')]
    [TestCase('NumAlpha.9', '7A;ttDigit1(7) at 1,ttAlpha(A) at 2', ';')]

//      (R: '[A-Z]+\d+\b';          T: Ord(ttAlphaNumeric)), // alpha followed by numeric
    [TestCase('AlphaNum.1', 'ABC123;ttAlpha(ABC) at 1,ttDigits(123) at 4', ';')]
    [TestCase('AlphaNum.2', 'ABC123 A1B2C3;ttAlpha(ABC),ttDigits(123),ttAlpha(A),ttDigit1(1),ttAlpha(B),ttDigit1(2),ttAlpha(C),ttDigit1(3) at 13', ';')]
    [TestCase('AlphaNum.3', 'ABC 123 A1 B2 C3;ttAlpha(ABC) at 1,ttDigits(123) at 5,ttAlpha(A),ttDigit1(1),ttAlpha(B),ttDigit1(2),ttAlpha(C),ttDigit1(3) at 16', ';')]

//      (R: '([A-Z\d]{2,}\/)?([A-Z]{1,2}|\d[A-Z]|[A-Z]\d|\d[A-Z]{2})([0-9])([A-Z\d]*[A-Z])(\/[A-Z\d]+)?(\/[A-Z\d]+)?\b';
    [TestCase('Callsign.1', 'W7SST;ttCallsign(W7SST) at 1', ';')]
    [TestCase('Callsign.2', 'W7SST/5;ttCallsign(W7SST/5) at 1', ';')]
    [TestCase('Callsign.3', 'W7SST/QRP;ttCallsign(W7SST/QRP) at 1', ';')]
    [TestCase('Callsign.4', 'KP4/W7SST;ttCallsign(KP4/W7SST) at 1', ';')]
    [TestCase('Callsign.5', 'KP4/W7SST/QRP;ttCallsign(KP4/W7SST/QRP) at 1', ';')]
    [TestCase('Callsign.6', 'W7S;ttCallsign(W7S) at 1', ';')]
    [TestCase('Callsign.7', 'W7SS;ttCallsign(W7SS) at 1', ';')]
    [TestCase('Callsign.8', 'WN7SST;ttCallsign(WN7SST) at 1', ';')]
    [TestCase('Callsign.9', 'WA7S;ttCallsign(WA7S) at 1', ';')]
    [TestCase('Callsign.10', 'WA7SS;ttCallsign(WA7SS) at 1', ';')]
//    [TestCase('Callsign.20', 'WAA7SST;ttAlphaNumericMixed(WAA7SST) at 1', ';')]     // an invalid callsign

    [TestCase('Mixed.1', '22 A 56 OR;ttDigit2(22) at 1, ttAlpha(A) at 4, ttDigit2(56) at 6, ttAlpha(OR) at 9', ';')]
    [TestCase('Mixed.2', '22A 56OR;ttDigit2(22), ttAlpha(A) at 3, ttDigit2(56), ttAlpha(OR) at 7', ';')]
    [TestCase('Mixed.3', '1 22 333 A OR WWA 4444;ttDigit1, ttDigit2, ttDigits(333), ttAlpha(A), ttAlpha(OR), ttAlpha(WWA), ttDigits', ';')]
    [TestCase('Mixed.4', 'W1AW 22A 56OR;ttCallsign(W1AW), ttDigit2, ttAlpha, ttDigit2, ttAlpha', ';')]
    [TestCase('Mixed.5', '22A W1AW/7 56OR;ttDigit2, ttAlpha, ttCallsign(W1AW/7), ttDigit2, ttAlpha', ';')]
    [TestCase('Mixed.6', '22A 56OR KP4/W1AW; ttDigit2(22), ttAlpha(A), ttDigit2(56), ttAlpha(OR), ttCallsign(KP4/W1AW)', ';')]
//    [TestCase('Error.1', '3.2;LexError', ';')]
    procedure LexerTest(const AValue, ExpectedTokens: string);
  end;

procedure TestSSRules.Setup;
begin
  // SSLexerRules is defined in SSExchParser and is used by TSSLexer
  inherited Setup(
    TLexer.Create(SSLexerRules, {SkipWhitespace=}True),
    TypeInfo(TExchTokenType));
end;

procedure TestSSRules.TearDown;
begin
  inherited TearDown;
end;

procedure TestSSRules.LexerTest(const AValue, ExpectedTokens: string);
begin
  RunTest(AValue, ExpectedTokens);
end;

type
  [TestFixture('TestSSLexer', 'Tests using SSLexer')]
  TestTSSLexer = class(TestTLexerBase)
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test(True)]
    [Category('SSLexer')]
    [TestCase('Empty.1', ';', ';')]  // empty string immediately returns False (no token)
    [TestCase('Empty.2', ' ;', ';')]  // whitespace-only string immediately returns False (no token)
    [TestCase('Empty.3', '   ;', ';')]  // whitespace-only string immediately returns False (no token)
    [TestCase('Empty.4', '  A;ttPrec(A) at 3', ';')]  // leading whitespace
    [TestCase('Empty.5', 'A  ;ttPrec(A) at 1', ';')]  // trailing whitespace
    [TestCase('Empty.6', ' A ;ttPrec(A) at 2', ';')]  // leading and trailing whitespace
    [TestCase('Alpha.1', 'ABC;ttAlpha(ABC) at 1', ';')]
    [TestCase('Alpha.2', 'ABC DEF;ttAlpha(ABC) at 1,ttAlpha(DEF) at 5', ';')]
    [TestCase('Digit1', '1;ttDigit1(1) at 1', ';')]
    [TestCase('Digit2', '12;ttDigit2(12) at 1', ';')]
    [TestCase('Digits.3', '123;ttDigits(123) at 1', ';')]
    [TestCase('Digits.4', '1234;ttDigits(1234) at 1', ';')]
    [TestCase('Digits.5', '123 456;ttDigits(123) at 1,ttDigits(456) at 5', ';')]
    [TestCase('Digits.6', '1234 567 89 0;ttDigits(1234) at 1,ttDigits(567) at 6,ttDigit2(89) at 10,ttDigit2(00) at 13', ';')]

//      (R: '\d+[QABUMS]\b';          T: Ord(ttNumberPrec)),
//    [TestCase('NumPrec.1', '1A;ttNumberPrec(1A) at 1', ';')]
//    [TestCase('NumPrec.2', '12B;ttNumberPrec(12B) at 1', ';')]
//    [TestCase('NumPrec.3', '123Q;ttNumberPrec(123Q) at 1', ';')]
//    [TestCase('NumPrec.4', '1234U;ttNumberPrec(1234U) at 1', ';')]
//    [TestCase('NumPrec.5', '1234M;ttNumberPrec(1234M) at 1', ';')]
//    [TestCase('NumPrec.6', '1234S;ttNumberPrec(1234S) at 1', ';')]
//    [TestCase('NumPrec.7', '1234X;ttNumericAlpha(1234X) at 1', ';')]
//    [TestCase('NumPrec.8', '1X;ttNumericAlpha(1X) at 1', ';')]

    [TestCase('NumPrec.1', '1A;ttDigit1(1) at 1,ttPrec(A) at 2', ';')]
    [TestCase('NumPrec.3', '123Q;ttDigits(123) at 1,ttPrec(Q) at 4', ';')]
    [TestCase('NumPrec.7', '1234X;ttDigits(1234) at 1,ttAlpha(X) at 5', ';')]

//      (R: '\d+[A-Z]+';            T: Ord(ttNumericAlpha)),
    [TestCase('NumAlpha.1', '123A;ttDigits(123) at 1,ttPrec(A) at 4', ';')]
    [TestCase('NumAlpha.2', '123AB;ttDigits(123) at 1,ttSect(AB) at 4', ';')]
    [TestCase('NumAlpha.3', '123ABC;ttDigits(123) at 1,ttAlpha(ABC) at 4', ';')]
    [TestCase('NumAlpha.4', '72OR;ttDigit2(72) at 1,ttSect(OR)', ';')]
    [TestCase('NumAlpha.5', '72 OR;ttDigit2(72),ttSect(OR) at 4', ';')]
    [TestCase('NumAlpha.6', '7 WWA;ttDigit1(7),ttSect(WWA) at 3', ';')]
    [TestCase('NumAlpha.7', '7 W;ttDigit1(7),ttAlpha(W) at 3', ';')]
    [TestCase('NumAlpha.8', '7 A;ttDigit1(7),ttPrec(A) at 3', ';')]
    [TestCase('NumAlpha.9', '7A;ttDigit1(7) at 1,ttPrec(A) at 2', ';')]
    [TestCase('NumAlpha.10', '0Z;ttDigit2(00) at 1,ttAlpha(Z) at 2', ';')]
    [TestCase('NumAlpha.11','14Z;ttDigit2(14) at 1, ttAlpha(Z) at 3', ';')]

//      (R: '[A-Z]+\d+\b';          T: Ord(ttAlphaNumeric)), // alpha followed by numeric
    [TestCase('AlphaNum.1', 'ABC123;ttAlpha(ABC) at 1,ttDigits(123) at 4', ';')]
    [TestCase('AlphaNum.2', 'ABC123 A1B2C3;ttAlpha(ABC) at 1,ttDigits(123) at 4,ttPrec(A),ttDigit1(1),ttPrec(B),ttDigit1(2),ttAlpha(C),ttDigit1(3) at 13', ';')]
    [TestCase('AlphaNum.3', 'ABC 123 A1 B2 C3;ttAlpha(ABC) at 1,ttDigits(123) at 5,ttPrec(A) at 9,ttDigit1(1),ttPrec(B) at 12,ttDigit1(2),ttAlpha(C) at 15,ttDigit1(3) at 16', ';')]

//      (R: '([A-Z\d]{2,}\/)?([A-Z]{1,2}|\d[A-Z]|[A-Z]\d|\d[A-Z]{2})([0-9])([A-Z\d]*[A-Z])(\/[A-Z\d]+)?(\/[A-Z\d]+)?\b';
    [TestCase('Callsign.1', 'W7SST;ttCallsign(W7SST) at 1', ';')]
    [TestCase('Callsign.2', 'W7SST/5;ttCallsign(W7SST/5) at 1', ';')]
    [TestCase('Callsign.3', 'W7SST/QRP;ttCallsign(W7SST/QRP) at 1', ';')]
    [TestCase('Callsign.4', 'KP4/W7SST;ttCallsign(KP4/W7SST) at 1', ';')]
    [TestCase('Callsign.5', 'KP4/W7SST/QRP;ttCallsign(KP4/W7SST/QRP) at 1', ';')]
    [TestCase('Callsign.6', 'W7S;ttCallsign(W7S) at 1', ';')]
    [TestCase('Callsign.7', 'W7SS;ttCallsign(W7SS) at 1', ';')]
    [TestCase('Callsign.8', 'WN7SST;ttCallsign(WN7SST) at 1', ';')]
    [TestCase('Callsign.9', 'WA7S;ttCallsign(WA7S) at 1', ';')]
    [TestCase('Callsign.10', 'WA7SS;ttCallsign(WA7SS) at 1', ';')]
    [TestCase('Callsign.20', 'WAA7SST;ttAlpha(WAA),ttDigit1(7),ttAlpha(SST) at 5', ';')]     // an invalid callsign
    [TestCase('Callsign.21', 'WA7SSST;ttCallsign(WA7SSST) at 1', ';')]
    [TestCase('Callsign.22', ';', ';')]  // empty callsign immediately returns False (no token)
    [TestCase('Callsign.23', 'TO973FY;ttCallsign(TO973FY) at 1', ';')]

    [TestCase('Mixed.1',  '22 A 56 OR;ttDigit2(22) at 1, ttPrec(A) at 4, ttDigit2(56) at 6, ttSect(OR) at 9', ';')]
    [TestCase('Mixed.2',  '22A 56OR;ttDigit2(22) at 1,ttPrec(A) at 3, ttDigit2(56) at 5,ttSect(OR) at 7', ';')]
    [TestCase('Mixed.3',  '1 22 333 A OR WWA 4444;ttDigit1, ttDigit2, ttDigits(333), ttPrec(A), ttSect(OR), ttSect(WWA), ttDigits', ';')]
    [TestCase('Mixed.4',  'W1AW 22A 56OR;ttCallsign(W1AW), ttDigit2(22), ttPrec(A), ttDigit2(56), ttSect(OR)', ';')]
    [TestCase('Mixed.5',  '22A W1AW/7 56OR;ttDigit2(22), ttPrec(A), ttCallsign(W1AW/7), ttDigit2(56), ttSect(OR)', ';')]
    [TestCase('Mixed.6',  '22A 56OR KP4/W1AW; ttDigit2(22), ttPrec(A), ttDigit2(56), ttSect(OR), ttCallsign(KP4/W1AW)', ';')]
    [TestCase('Mixed.10', '10A20OR;      ttDigit2(10), ttPrec(A),    ttDigit2(20), ttSect(OR)', ';')]
    [TestCase('Mixed.11', '20OR10A;      ttDigit2(20), ttSect(OR),   ttDigit2(10), ttPrec(A)', ';')]
    [TestCase('Mixed.12', '20OR 10A;     ttDigit2(20), ttSect(OR),   ttDigit2(10), ttPrec(A)', ';')]
    [TestCase('Mixed.13', '10 20OR 30A;  ttDigit2(10), ttDigit2(20), ttSect(OR),   ttDigit2(30), ttPrec(A)', ';')]
    [TestCase('Mixed.14', '20OR 10 30A;  ttDigit2(20), ttSect(OR),   ttDigit2(10), ttDigit2(30), ttPrec(A)', ';')]
    [TestCase('Mixed.15', '10A20ORW1AW;  ttDigit2(10), ttPrec(A),    ttDigit2(20), ttAlpha(ORW), ttDigit1(1), ttAlpha(AW)', ';')]
    [TestCase('Mixed.16', '10A20OR W1AW; ttDigit2(10), ttPrec(A),    ttDigit2(20), ttSect(OR), ttCallsign(W1AW)', ';')]
    [TestCase('Mixed.17', 'W1AW 10A20OR; ttCallsign(W1AW), ttDigit2(10), ttPrec(A),    ttDigit2(20), ttSect(OR)', ';')]
    [TestCase('Mixed.18', 'W1AW10A20OR;  ttCallsign(W1AW10A20OR)', ';')]
    procedure SSLexerTest(const AValue, ExpectedTokens: string);

    [Test(True)]
    [TestCase('SSExchToken.Init','')]
    procedure InitTokenTest;

    [Test(True)]
    [Category('CallHistory')]
    // Validate all callsigns contained in all call history files;
    // exceptions (known bad callsigns) are included for each file.
    [TestCase('SSCW', 'SSCW.txt;', ';')]
    [TestCase('IARU_HF', 'IARU_HF.txt;F/DJ4MZ,K5,KM5', ';')]
    [TestCase('ARRLDXCW_USDX', 'ARRLDXCW_USDX.txt;F/SQ6MS,KI30,VYIJA', ';')]
    [TestCase('JARL_ACAG', 'JARL_ACAG.TXT;', ';')]
    [TestCase('JARL_ALLJA', 'JARL_ALLJA.TXT;', ';')]
    [TestCase('CQWW', 'CQWWCW.txt;4L8,EA5,IO1', ';')]
    [TestCase('NAQP', 'NAQPCW.txt;KI30,VYIJA', ';')]
    [TestCase('K1USNSST', 'K1USNSST.txt;F/OZ1CGQ,KI30,VYIJA', ';')]
    procedure ApplyCallHistory(const FileName, Exceptions: string);
  end;

procedure TestTSSLexer.Setup;
begin
  inherited Setup(TSSLexer.Create, TypeInfo(TExchTokenType));
end;

procedure TestTSSLexer.TearDown;
begin
  inherited TearDown;
end;

procedure TestTSSLexer.SSLexerTest(const AValue, ExpectedTokens: string);
begin
  RunTest(AValue, ExpectedTokens);
end;

procedure TestTSSLexer.InitTokenTest;
begin
  var token: TSSExchToken := TSSExchToken.Create;
  try
    Assert.IsFalse(token.IsValid);
    token.TokenType := ttEOS;
    token.Pos := 0;
    Assert.IsTrue(token.IsValid);
  finally
    FreeAndNil(token);
  end;
end;

procedure TestTSSLexer.ApplyCallHistory(const FileName, Exceptions: string);
var
  slst, tl, badCalls: TStringList;
  i: integer;
  M: Boolean;
  Call, Section: String;
  Token: TExchToken;
  CallInx, SectInx, MinColumnCount, Index: integer;
begin
  slst:= TStringList.Create;
  tl:= TStringList.Create;
  badCalls:=TStringList.Create;

  tl.Delimiter := ',';
  tl.StrictDelimiter := True;
  badCalls.Delimiter := ',';
  badCalls.StrictDelimiter := True;
  badCalls.DelimitedText := Exceptions;

  CallInx := -1;
  SectInx := -1;
  MinColumnCount := MaxInt;
  Call := '';
  Section := '';

  try
    slst.LoadFromFile('C:\Users\mikeb\Documents\Code\w7sst\MorseRunnerCE\' + FileName);

    for i:= 0 to slst.Count-1 do begin
      if (slst.Strings[i].StartsWith('#')) then continue;
      tl.DelimitedText := slst.Strings[i];
      if tl.Count = 0 then continue;

      // note - !!Order!! can occur multiple time in the file
      if (tl.Strings[0] = '!!Order!!') then begin
        // !!Order!!,Call,Sect,UserText,
        tl.Delete(0); // shifts others down by one
        CallInx := tl.IndexOf('Call');
        Assert.IsTrue(CallInx > -1, 'missing Call column');
        if CompareText(FileName, 'SSCW.TXT') = 0 then
          SectInx := tl.IndexOf('Sect')
        else
          SectInx := -1;
        MinColumnCount := Max(CallInx, SectInx)+1;
        continue;
      end;
      if tl.Count < MinColumnCount then
        continue;

      try
        Call := tl.Strings[CallInx].ToUpper.Trim;
        if Call='' then continue;
        aLexer.Input(Call);
        M := aLexer.NextToken(token) and (token.TokenType = Integer(ttCallsign));
        if not M and not BadCalls.Find(Call, Index) then
          Assert.FailFmt('%s(%d): ''%s'' is a bad callsign and fails regex test', [FileName, i+1, Call]);
      except
        // exception occured, assume last current position
        on E: TLexer.ELexerError do begin
          Assert.FailFmt('%s(%d): %s', [FileName, i+1, E.Message]);
        end;
      end;

      if SectInx <> -1 then
        begin
          Section := tl.Strings[SectInx].ToUpper.Trim;
          if Section = '' then continue;
          aLexer.Input(Section);
          M := aLexer.NextToken(token) and (token.TokenType = Integer(ttSect));
          if not M then
            Assert.FailFmt('%s(%d): ''%s'' has bad Section (%s)', [FileName, i+1, slst.Strings[i], Section]);
        end;
    end;

  finally
    slst.Free;
    tl.Free;
  end;
end;


type
  [TestFixture]
  TestSweepExch = class(TObject)
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test(False)]
    [TestCase('Parser.Test2.1','1,2')]
    [TestCase('Parser.Test2.2','3,4')]
    procedure Test2(const AValue1 : Integer;const AValue2 : Integer);
    [Test(False)]
    [TestCase('Parser.Test3.1','1,2')]
    [TestCase('Parser.Test3.2','3,4')]
    procedure Test3(const AValue1 : Integer;const AValue2 : Integer);
  end;

procedure TestSweepExch.Setup;
begin
  // xx := TSweepExchParser.Create(AOwner: TComponent); override;
  // xx.Call = 'Call';
end;

procedure TestSweepExch.TearDown;
begin
end;

procedure TestSweepExch.Test2(const AValue1 : Integer;const AValue2 : Integer);
begin
end;

procedure TestSweepExch.Test3(const AValue1 : Integer;const AValue2 : Integer);
begin
end;

initialization
  TDUnitX.RegisterTestFixture(TestSSRules);
  TDUnitX.RegisterTestFixture(TestTSSLexer);
//  TDUnitX.RegisterTestFixture(TestSweepExch);

end.
