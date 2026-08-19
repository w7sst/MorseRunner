unit Test.Arrl10m.Reader;

interface

uses
  DUnitX.TestFramework,
  Test.ContestReader.Base,
  Test.ContestReader.Contracts,
  Arrl10m.Types,
  Arrl10m.Reader,
  System.Classes;

type
  [Category('ARRL10m')]
  [TestFixture]
  TArrl10mContestFileReaderTests = class(
      TContestReaderContractTests<TArrl10mCallRec,TArrl10mContestFileReader>)
  protected
    function CreateReader: TArrl10mContestFileReader; override;

  public
    constructor Create;

    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    // tests...
    [Test]
    [Category('Schema')]
    procedure Constructor_SetsSupportedFormats;

    [Test]
    [Category('Schema')]
    procedure Missing_Call_Field_Raises;

    [Test]
    [Category('Schema')]
    procedure Reordered_Columns_Are_Supported;

    [Test]
    [Category('File')]
    procedure Test_Load_N1MM_File;

    [Category('File')]
    [TestCase('Official arrl tsv', '6342')]
    procedure Count_Official_Contest_File(Expected: integer);
  end;

implementation

uses
  System.Generics.Collections,  // for TObjectList
  System.SysUtils,
  System.Math,
  ContestFileFormat,
  Arrl10m.Policy,
  DXCC,
  AppPaths;

constructor TArrl10mContestFileReaderTests.Create;
begin
  inherited Create(
    '!!Order!!,Call,State,Section,UserText',
    'K1ABC,MA,EMA,Sample Text');
end;

function TArrl10mContestFileReaderTests.CreateReader: TArrl10mContestFileReader;
begin
  Result := TArrl10mContestFileReader.Create;
end;

procedure TArrl10mContestFileReaderTests.Setup;
begin
  inherited Setup;

  // load DXCC support
  gDXCCList := TDXCC.Create;
end;


procedure TArrl10mContestFileReaderTests.TearDown;
begin
  gDXCCList.Free;
  inherited;
end;


procedure TArrl10mContestFileReaderTests.Missing_Call_Field_Raises;
begin
  WriteTestFile('missing-call.csv', [
      '!!Order!!,State,Section,UserText',
      'MA,EMA,Big Gun'
    ]);

  AssertReadRaises(
    TestFile('missing-call.csv'),
    Exception,
    '.*missing required field "Call".*');
end;


procedure TArrl10mContestFileReaderTests.Reordered_Columns_Are_Supported;
var
  Results: TObjectList<TArrl10mCallRec>;
begin
  WriteTestFile('reordered-columns.csv', [
      '!!Order!!,Section,UserText,State,Call',
      'EMA,Big Gun,MA,K1ABC'
    ]);

  Results := ReadAllFromFile(
    TestFile('reordered-columns.csv'));

  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('K1ABC', Results[0].Call);
    Assert.AreEqual('MA', Results[0].State);
    Assert.AreEqual('Big Gun', Results[0].UserText);
  finally
    Results.Free;
  end;
end;


procedure TArrl10mContestFileReaderTests.Constructor_SetsSupportedFormats;
var
  Reader: TArrl10mContestFileReader;
begin
  Reader := TArrl10mContestFileReader.Create;
  try
    Assert.IsTrue(Reader.SupportedFormats = [cffN1MMCsv, cffARRLTsv]);
  finally
    Reader.Free;
  end;
end;


procedure CalculateLimits(ANotations: Integer; AProbability: Double;
  out ALowerLimit: Integer; out AUpperLimit: Integer);
var
  LSigma, Expected: Double;
  Tolerance: Integer;
begin
  // 1. Calculate Expected Value (Mean)
  Expected := Ceil(ANotations * AProbability);

  // 2. Calculate Standard Deviation for Binomial Distribution
  LSigma := Sqrt(ANotations * AProbability * (1.0 - AProbability));

  // 3. Compute 3-Sigma Tolerance rounded up to the nearest integer
  Tolerance := Ceil(3.0 * LSigma);

  // 4. Compute boundaries for integer comparisons
  ALowerLimit := Floor(Expected - Tolerance);
  AUpperLimit := Ceil(Expected + Tolerance);
end;


procedure TArrl10mContestFileReaderTests.Test_Load_N1MM_File;
const
  ExpectedTotalRows = 11644;
var
  Reader: TArrl10mContestFileReader;
  Count, MaritimeCount: Integer;
  LowerLimit, UpperLimit: Integer;
begin
  Count := 0;
  MaritimeCount := 0;

  Reader := TArrl10mContestFileReader.Create;

  try
    Reader.ReadFile(
      TAppPaths.ContestDataFile('ARRL10M.txt'),

      procedure(Rec: TArrl10mCallRec)
      begin
        Inc(Count);

        Assert.IsNotEmpty(Rec.Call);

        if Rec.Call.EndsWith('/MM') then
          Inc(MaritimeCount)
        else if Rec.Call = '4U1WB' then
          Assert.AreEqual('DC', Rec.State);

        Rec.Free;
      end);

    Assert.AreEqual(ExpectedTotalRows, Count);

    // Calculate 3-sigma limits around expected outcome count
    CalculateLimits(ExpectedTotalRows,
      TArrl10mPolicy.MaritimeMobileProbability,
      LowerLimit, UpperLimit);

    Assert.IsTrue((MaritimeCount >= LowerLimit) and (MaritimeCount <= UpperLimit),
      format('Maritime mobile count %d is not within expected interval [%d,%d]',
        [MaritimeCount, LowerLimit, UpperLimit]));

  finally
    Reader.Free;
  end;
end;


procedure TArrl10mContestFileReaderTests.Count_Official_Contest_File(
  Expected: integer);
var
  Count: Integer;
begin
  Count := ReadCountFromFile(TAppPaths.ContestDataFile('arrl-10-2025.tsv'));
  Assert.AreEqual(Expected, Count);
end;

end.
