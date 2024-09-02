unit MySSExchTest;

interface

uses
  SSExchParser,
  ExchFields,
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestMySSExch = class
  var
    parser : TMyExchParser;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test(True)]
    [Category('General')]
    [TestCase('MyExch.General.1', 'A 72 OR,A 72 OR')]
    [TestCase('MyExch.General.2', '123 A 72 OR,123 A 72 OR')]
    [TestCase('MyExch.General.3', '22A 72OR,22A 72 OR')]
    [TestCase('MyExch.General.4', '22 A 72OR,22A 72 OR')]
    [TestCase('MyExch.General.5', '# A 72 OR,# A 72 OR')]
    [TestCase('MyExch.General.6', '#A 72 OR,#A 72 OR')]
    procedure Test1(const AExchange, AExpected: string);

    [Test(False)]
    [Category('ErrorChecks')]
    [TestCase('MyExch.Error.Invalid.01', ',Invalid exchange')]

    [TestCase('MyExch.Error.Extra.01', 'A 72 OR EX,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.02', 'A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.03', '123 A 72 OR EX,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.04', '123 A 72 OR WWA,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.05', '123 A 72 OR 56,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.06', '123 A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.07', 'A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.08', 'A B 72 OR ID,Invalid exchange')]

    [TestCase('MyExch.Error.Missing.01', 'OR,missing Precedence')]
    [TestCase('MyExch.Error.Missing.02', '72 OR,missing Precedence')]

    [TestCase('MyExch.Error.Missing.11', 'A,missing Check')]
    [TestCase('MyExch.Error.Missing.12', 'A OR,missing Check')]
    [TestCase('MyExch.Error.Missing.13', '123 A OR,missing Check')]
    [TestCase('MyExch.Error.Missing.14', '123 A,missing Check')]

    [TestCase('MyExch.Error.Missing.21', 'A 72,missing Section')]
    [TestCase('MyExch.Error.Missing.22', '123 A 72,missing Section')]

    [TestCase('MyExch.Error.Invalid.11', 'NN A 123 OR,invalid Number')]

    [TestCase('MyExch.Error.Invalid.21', 'C 1 OR,invalid Precedence')]
    [TestCase('MyExch.Error.Invalid.22', '123 C 123 OR,invalid Precedence')]
    [TestCase('MyExch.Error.Invalid.23', '123 xxA 123 OR,invalid Precedence')]

    [TestCase('MyExch.Error.Invalid.31', 'A 1 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.32', 'A 1 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.33', 'A 123 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.33', 'A 2024 OR,invalid Check')]

    [TestCase('MyExch.Error.Invalid.41', 'A 72 OR1,invalid Section')]
    [TestCase('MyExch.Error.Invalid.42', '123 A 72 1OR,invalid Section')]
    [TestCase('MyExch.Error.Invalid.43', 'A 72 222,invalid Section')]
    [TestCase('MyExch.Error.Invalid.44', '123 A 72 222,invalid Section')]
    [TestCase('MyExch.Error.Invalid.44', 'A 72 XYZZY,invalid Section')]
    procedure ErrorCheck(const AMyExchange, AExpected: string);

    [Test(True)]
    [TestCase('Parser.Test3','')]
    procedure Test3();

    [Test(True)]
    [TestCase('Lexer.PerlRegExList','')]
    procedure Test4();

  end;

implementation

uses
  PerlRegEx,
  System.SysUtils;

procedure TTestMySSExch.Setup;
begin
  parser := TMyExchParser.Create;
end;

procedure TTestMySSExch.TearDown;
begin
  parser := nil;
end;

procedure TTestMySSExch.Test1(const AExchange, AExpected: string);
var
  R: boolean;
  S: string;
begin
  R:= parser.ParseMyExch(AExchange);
  // todo - can't reach the parser.ErrorStr below if this assert fails.
  Assert.IsTrue(R, format('''%s'', expecting ''%s''', [AExchange, AExpected]));
  if not R then
    begin
      S := parser.ErrorStr;
      Assert.Contains(S, AExpected);
    end;
end;

procedure TTestMySSExch.ErrorCheck(const AMyExchange, AExpected : string);
var
  R: boolean;
  S: string;
begin
  R:= parser.ParseMyExch(AMyExchange);
  Assert.IsFalse(R, 'expecting regex.Match to fail');
  if not R then
    begin
      S := parser.ErrorStr;
      Assert.Contains(S, AExpected);
    end;
end;

procedure TTestMySSExch.Test3;
var
  Reg: TPerlRegEx;
  S: string;
begin
  Reg := TPerlRegEx.Create;

  try
  //  RegEx.RegEx := UTF8Encode('^' + ARegexpr + '$');
    Reg.RegEx := UTF8Encode('(A|B|C)');
    Reg.Compile;
    Reg.Subject := 'B';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(PCREString('B'), Reg.Groups[0]);

    Reg.RegEx := UTF8Encode('((A)|(B)|(?P<c>C))');
    Reg.Subject := 'A';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(2, Reg.GroupCount);
    Assert.AreEqual(PCREString('A'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('A'), Reg.Groups[1]);

    Reg.Subject := 'ABC';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(2, Reg.GroupCount);
    Assert.AreEqual(PCREString('A'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('A'), Reg.Groups[1]);

    Assert.IsTrue(Reg.MatchAgain);
    Assert.AreEqual(3, Reg.GroupCount);
    Assert.AreEqual(PCREString('B'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('B'), Reg.Groups[1]);
    Assert.IsEmpty(Reg.Groups[2]);
    Assert.AreEqual(PCREString('B'), Reg.Groups[3]);
    Assert.IsEmpty(Reg.Groups[4]);
    Assert.IsEmpty(Reg.Groups[Reg.NamedGroup('c')]);  // index = 4

    Assert.IsTrue(Reg.MatchAgain);
    Assert.AreEqual(4, Reg.GroupCount);
    Assert.AreEqual(PCREString('C'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('C'), Reg.Groups[1]);
    Assert.IsEmpty(Reg.Groups[2]);
    Assert.IsEmpty(Reg.Groups[3]);
    Assert.AreEqual(PCREString('C'), Reg.Groups[4]);

    Assert.IsFalse(Reg.MatchAgain, 'final MatchAgain should fail');
  finally
    Reg.Free;
  end;
end;

procedure TTestMySSExch.Test4;
var
  Reg1, Reg2, Reg3: TPerlRegEx;
  MatchedReg: TPerlRegEx;
  RegList: TPerlRegExList;
  R: boolean;
  S: string;
begin
  MatchedReg := nil;
  RegList := TPerlRegExList.Create;

  try
    Reg1 := TPerlRegEx.Create;
    Reg2 := TPerlRegEx.Create;
    Reg3 := TPerlRegEx.Create;
    Reg1.RegEx := 'A'; Reg1.Study;
    Reg2.RegEx := 'B'; Reg2.Study;
    Reg3.RegEx := 'C'; Reg3.Study;
    RegList.Add(Reg1);
    RegList.Add(Reg2);
    RegList.Add(Reg3);

    RegList.Subject := 'ABC';
    Assert.IsTrue(RegList.Match, 'a');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'A');
    Assert.AreEqual(0, RegList.IndexOf(MatchedReg));

    Assert.IsTrue(RegList.MatchAgain, 'b');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'B');
    Assert.AreEqual(1, RegList.IndexOf(MatchedReg));

    Assert.IsTrue(RegList.MatchAgain, 'c');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'C');
    Assert.AreEqual(2, RegList.IndexOf(MatchedReg));

    Assert.IsFalse(RegList.MatchAgain, 'final MatchAgain should fail');

  finally
    MatchedReg := nil;
{
    RegList.GetRegEx(2).Free;
    RegList.GetRegEx(1).Free;
    RegList.GetRegEx(0).Free;
}
    RegList.Clear;
    RegList.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMySSExch);

end.
