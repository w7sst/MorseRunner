unit Test.CallCorrections;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCallCorrectionsTests = class
  private
    function CreateTempFile(
      const FileName: string;
      const Contents: string): string;
  public
    [Test]
    procedure Missing_Call_Returns_False;

    [Test]
    procedure Loads_State_Overrides;

    [Test]
    procedure Multiple_Loads_Accumulate;

    [Test]
    procedure Duplicate_Call_Last_Wins;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  CallCorrections;

function TCallCorrectionsTests.CreateTempFile(
  const FileName: string;
  const Contents: string): string;
var
  Lines: TStringList;
begin
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + FileName;

  Lines := TStringList.Create;
  try
    Lines.Text := Contents;
    Lines.SaveToFile(Result);
  finally
    Lines.Free;
  end;
end;

procedure TCallCorrectionsTests.Missing_Call_Returns_False;
var
  Corrections: TCallCorrections;
  State: string;
begin
  Corrections := TCallCorrections.Create;
  try
    Assert.IsFalse(
      Corrections.TryGetStateOverride(
        'W1AW',
        State));
  finally
    Corrections.Free;
  end;
end;

procedure TCallCorrectionsTests.Loads_State_Overrides;
var
  Corrections: TCallCorrections;
  State: string;
  FileName: string;
begin
  FileName := CreateTempFile(
    'CallCorrectionsTest1.csv',
    '!!Order!!,Call,State' + sLineBreak +
    'K3ABC,DC' + sLineBreak +
    'W1AW,CT');

  Corrections := TCallCorrections.Create;
  try
    Corrections.LoadFromFile(FileName);

    Assert.IsTrue(
      Corrections.TryGetStateOverride(
        'K3ABC',
        State));

    Assert.AreEqual(
      'DC',
      State);

    Assert.IsTrue(
      Corrections.TryGetStateOverride(
        'W1AW',
        State));

    Assert.AreEqual(
      'CT',
      State);
  finally
    Corrections.Free;
    DeleteFile(FileName);
  end;
end;

procedure TCallCorrectionsTests.Multiple_Loads_Accumulate;
var
  Corrections: TCallCorrections;
  State: string;
  File1: string;
  File2: string;
begin
  File1 := CreateTempFile(
    'CallCorrectionsTest2a.csv',
    '!!Order!!,Call,State' + sLineBreak +
    'K3ABC,DC');

  File2 := CreateTempFile(
    'CallCorrectionsTest2b.csv',
    '!!Order!!,Call,State' + sLineBreak +
    'W1AW,CT');

  Corrections := TCallCorrections.Create;
  try
    Corrections.LoadFromFile(File1);
    Corrections.LoadFromFile(File2);

    Assert.IsTrue(
      Corrections.TryGetStateOverride(
        'K3ABC',
        State));

    Assert.AreEqual(
      'DC',
      State);

    Assert.IsTrue(
      Corrections.TryGetStateOverride(
        'W1AW',
        State));

    Assert.AreEqual(
      'CT',
      State);
  finally
    Corrections.Free;
    DeleteFile(File1);
    DeleteFile(File2);
  end;
end;

procedure TCallCorrectionsTests.Duplicate_Call_Last_Wins;
var
  Corrections: TCallCorrections;
  State: string;
  File1: string;
  File2: string;
begin
  File1 := CreateTempFile(
    'CallCorrectionsTest3a.csv',
    '!!Order!!,Call,State' + sLineBreak +
    'K3ABC,MD');

  File2 := CreateTempFile(
    'CallCorrectionsTest3b.csv',
    '!!Order!!,Call,State' + sLineBreak +
    'K3ABC,DC');

  Corrections := TCallCorrections.Create;
  try
    Corrections.LoadFromFile(File1);
    Corrections.LoadFromFile(File2);

    Assert.IsTrue(
      Corrections.TryGetStateOverride(
        'K3ABC',
        State));

    Assert.AreEqual(
      'DC',
      State);
  finally
    Corrections.Free;
    DeleteFile(File1);
    DeleteFile(File2);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCallCorrectionsTests);

end.
