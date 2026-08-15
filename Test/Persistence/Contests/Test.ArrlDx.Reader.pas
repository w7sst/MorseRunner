//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.ArrlDx.Reader;

interface

uses
  DUnitX.TestFramework,
  Test.ContestReader.Base,
  Test.ContestReader.Contracts,
  ArrlDx.Types,
  ArrlDx.Reader,
  System.Classes;

type
  {
    Derived Reader Verification...
      Derived Reader Configuration
        which fields are required
        which are optional
        which normalization rules apply
        which filters apply
        without duplicating infrastructure testing.

      Contest Semantics
        KeepRecord logic
        official file counts
        DX/local semantics
        contest-specific normalization
  }
  [Category('ARRLDX')]
  [TestFixture]
  TArrlDxContestFileReaderTests = class(
      TContestReaderContractTests<TArrlDxCallRec,TArrlDxContestFileReader>)
  private
    FLocalToContest: Boolean;

  protected
    function CreateReader: TArrlDxContestFileReader; override;

  public
    constructor Create;

    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    // tests...
    [Test]
    [Category('Schema')]
    procedure Missing_Call_Field_Raises;

    [Test]
    [Category('Schema')]
    procedure Reordered_Columns_Are_Supported;

    [Test]
    [Category('Normalization')]
    procedure State_Field_Normalized_to_Uppercase;

    [Test]
    [Category('Normalization')]
    procedure Power_Field_Normalized_to_Uppercase;

    [Test]
    [Category('Normalization')]
    procedure UserText_Preserved;

    [Category('Semantics')]
    [TestCase('KeepRecord.1', 'True,     ,     ,False')]
    [TestCase('KeepRecord.2', 'True,   MA,     ,False')]
    [TestCase('KeepRecord.3', 'True,     ,  KW ,True')]
    [TestCase('KeepRecord.4', 'True,   MA,  KW ,True')]

    [TestCase('KeepRecord.5', 'False,    ,     ,False')]
    [TestCase('KeepRecord.6', 'False,  MA,     ,True')]
    [TestCase('KeepRecord.7', 'False,    ,  KW ,False')]
    [TestCase('KeepRecord.8', 'False,  MA,  KW ,True')]
    procedure KeepRecord_Matrix(
      HomeCallLocal: Boolean;
      State: string;
      Power: string;
      Expected: Boolean);

    [Test]
    [Category('File')]
    procedure Load_N1MM_File_Local;

    [Test]
    [Category('File')]
    procedure Load_N1MM_File_Dx;

    [Category('File')]
    [TestCase('Local', 'True,  3781')]
    [TestCase('DX',    'False, 4576')]
    procedure Count_Official_Contest_File(LocalToContest: boolean; Expected: integer);
end;

implementation

uses
  System.IOUtils,               // for TFile
  System.SysUtils,
  System.Generics.Collections,  // for TObjectList
  ContestFileFormat,
  AppPaths;

constructor TArrlDxContestFileReaderTests.Create;
begin
  inherited Create('!!Order!!,Call,State,Power', 'K1ABC,MA,100');
  FLocalToContest := True;
end;

function TArrlDxContestFileReaderTests.CreateReader: TArrlDxContestFileReader;
begin
  Result := TArrlDxContestFileReader.Create(FLocalToContest);
end;

procedure TArrlDxContestFileReaderTests.Setup;
begin
  inherited Setup;

  FLocalToContest := True;
end;


procedure TArrlDxContestFileReaderTests.TearDown;
begin
  inherited;
end;


procedure TArrlDxContestFileReaderTests.Missing_Call_Field_Raises;
begin
  Self.FLocalToContest := False;

  WriteTestFile('dx-missing-call.csv', [
      '!!Order!!,State,Power',
      'MA,KW'
    ]);

  AssertReadRaises(
    TestFile('dx-missing-call.csv'),
    Exception,
    '.*missing required field "Call".*');
end;


procedure TArrlDxContestFileReaderTests.Reordered_Columns_Are_Supported;
var
  Results: TObjectList<TArrlDxCallRec>;
begin
  FLocalToContest := False;

  WriteTestFile('reordered-columns.csv', [
      '!!Order!!,Power,UserText,State,Call',
      'KW,Big Gun,MA,K1ABC'
    ]);

  Results := ReadAllFromFile(
    TestFile('reordered-columns.csv'));

  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('K1ABC', Results[0].Call);
    Assert.AreEqual('MA', Results[0].State);
    Assert.AreEqual('KW', Results[0].Power);
    Assert.AreEqual('Big Gun', Results[0].UserText);
  finally
    Results.Free;
  end;
end;


procedure TArrlDxContestFileReaderTests.State_Field_Normalized_to_Uppercase;
var
  Results: TObjectList<TArrlDxCallRec>;
begin
  // DX Station will work states. Set FLocalToContest to False.
  Self.FLocalToContest := False;

  WriteTestFile('dx-state-uppercase.csv', [
      '!!Order!!,Call,State',
      'K1ABC,ma'
    ]);

  Results := Self.ReadAllFromFile(TestFile('dx-state-uppercase.csv'));
  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('MA', Results[0].State);
  finally
    Results.Free;
  end;
end;


procedure TArrlDxContestFileReaderTests.Power_Field_Normalized_to_Uppercase;
var
  Results: TObjectList<TArrlDxCallRec>;
begin
  WriteTestFile('dx-power-uppercase.csv', [
      '!!Order!!,Call,Power',
      'DL1ABC,kw'
    ]);

  Results := ReadAllFromFile(TestFile('dx-power-uppercase.csv'));
  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('KW', Results[0].Power);
  finally
    Results.Free;
  end;
end;


procedure TArrlDxContestFileReaderTests.UserText_Preserved;
var
  Results: TObjectList<TArrlDxCallRec>;
begin
  // DX Station will work states. Set FLocalToContest to False.
  Self.FLocalToContest := False;

  WriteTestFile('dx-usertext.csv', [
      '!!Order!!,Call,State,UserText',
      'K1abc,Ma,Big Gun Station'
    ]);

  Results := ReadAllFromFile(TestFile('dx-usertext.csv'));
  try
    Assert.AreEqual(1, Results.Count);
    Assert.AreEqual('K1ABC', Results[0].Call);
    Assert.AreEqual('MA', Results[0].State);
    Assert.IsEmpty(Results[0].Power);
    Assert.AreEqual('Big Gun Station', Results[0].UserText);
  finally
    Results.Free;
  end;
end;


procedure TArrlDxContestFileReaderTests.KeepRecord_Matrix(
  HomeCallLocal: Boolean;
  State: string;
  Power: string;
  Expected: Boolean);
var
  TempFile: string;
  Count: Integer;
begin
  TempFile := TAppPaths.TempTestFile(
    Format('keep-record.%s.%s.txt', [State.Trim, Power.Trim]));
  TFile.WriteAllLines(TempFile, TArray<string>.Create(
    '!!Order!!,Call,State,Power',
    Format('K1ABC,%s,%s', [State.Trim, Power.Trim])
  ));

  FLocalToContest := HomeCallLocal;
  Count := Self.ReadCountFromFile(TempFile);

  Assert.AreEqual(Integer(Ord(Expected)), Count);
end;


procedure TArrlDxContestFileReaderTests.Load_N1MM_File_Local;
var
  Reader: TArrlDxContestFileReader;
begin
  Reader := TArrlDxContestFileReader.Create({HomeCallIsLocal=}True);

  try
    Reader.ReadFile(
      TAppPaths.ContestDataFile('ARRLDXCW_USDX.txt'),
      procedure(Rec: TArrlDxCallRec)
      begin
        // Local to contest (W/VE) will work DX
        // DX sends Call,Power
        // W/VE sends Call,State
        Assert.IsNotEmpty(Rec.Call);
        Assert.IsEmpty(Rec.State);
        Assert.IsNotEmpty(Rec.Power);

        Rec.Free;
      end);

  finally
    Reader.Free;
  end;
end;

procedure TArrlDxContestFileReaderTests.Load_N1MM_File_Dx;
var
  Reader: TArrlDxContestFileReader;
begin
  Reader := TArrlDxContestFileReader.Create({HomeCallIsLocal=}False);

  try
    Reader.ReadFile(
      TAppPaths.ContestDataFile('ARRLDXCW_USDX.txt'),
      procedure(Rec: TArrlDxCallRec)
      begin
        // Not Local to contest (DX) will work W/VE
        // DX sends Call,Power
        // W/VE sends Call,State
        Assert.IsNotEmpty(Rec.Call);
        Assert.IsNotEmpty(Rec.State);
        Assert.IsEmpty(Rec.Power);

        Rec.Free;
      end);

  finally
    Reader.Free;
  end;
end;


procedure TArrlDxContestFileReaderTests.Count_Official_Contest_File(
  LocalToContest: boolean; Expected: integer);
var
  Count: Integer;
begin
  FLocalToContest := LocalToContest;
  Count := ReadCountFromFile(TAppPaths.ContestDataFile('ARRLDXCW_USDX.txt'));
  Assert.AreEqual(Expected, Count);
end;

end.
