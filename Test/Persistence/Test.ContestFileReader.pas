//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.ContestFileReader;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  ContestFileFormat,
  ContestFileReader,
  Test.ContestReader.Base;

type
  TFakeRec = class
  public
    Call: string;
    State: string;
    Power: string;
    UserText: string;
  end;

  TColumnMap = record
    CallInx: Integer;
    StateInx: Integer;
    PowerInx: Integer;
    UserTextInx: Integer;
  end;

type
  TFakeReader = class(TContestFileReader<TFakeRec>)
  protected
    FCols: TColumnMap;
    FHeaderCount: Integer;

    procedure ParseSectionHeader(
      const Format: TContestFileFormat;
      const Fields: TStrings); override;

    procedure ParseRow(
      const Fields: TStrings;
      Rec: TFakeRec); override;

    property HeaderCount: Integer read FHeaderCount;

  public
    constructor Create;
    destructor Destroy; override;
  end;

type
  TFakeBindingRow = class
  public
    Call: string;
    Name: string;
    Age: Integer;
  end;

  TFakeBindingReader = class(TContestFileReader<TFakeBindingRow>)
  protected
    function IsHeaderDirective(
      const Format: TContestFileFormat;
      const Fields: TStrings): Boolean; override;

    procedure ConfigureBindings; override;
  end;

  [TestFixture]
  TContestFileReaderTests = class(TContestReaderTestHelper)
  public
    [Test]
    procedure Visits_All_Rows;

    [Test]
    procedure Skips_Blank_Lines;

    [Test]
    procedure Skips_Comment_Lines;

    [Test]
    procedure Header_Is_Not_Visited;

    [Test]
    procedure Reads_Multiple_Files;

    [Test]
    procedure KeepRow_Can_Filter_Rows;

    [Test]
    procedure Multiple_Headers_Are_Supported;

    [Test]
    procedure Reordered_Columns_Are_Supported;

    [Test]
    procedure Missing_Optional_Field_Returns_Empty_String;

    [Test]
    procedure Unknown_Columns_Are_Ignored;

    [Test]
    procedure Missing_Required_Field_Raises;

    [Test]
    procedure Unknown_Format_Raises_Exception;

    [Test]
    procedure Unsupported_Format_Raises_Exception;

    [Test]
    procedure Empty_File_Raises_Unknown_Format;

    [Test]
    procedure Default_CreateRecord_Is_Used;

    [Test]
    procedure NormalizeRecord_Is_Called;

    [Test]
    procedure NormalizeRecord_Before_KeepRow;

    [Test]
    procedure StopReading_Ends_Read_Loop;

    [Test]
    procedure HandleLine_Can_Consume_Line;

    [Test]
    procedure Consumer_Can_Apply_Correction_File;

    [Test]
    procedure Default_Bindings_Are_Applied;

    [Test]
    procedure Default_Bindings_Recompile_When_Header_Changes;

    [Test]
    procedure Consumer_Owns_Record;

    [Test]
    procedure Header_Only_File_Produces_No_Records;

    [Test]
    procedure FileName_Is_Available_During_Parsing;

    [Test]
    procedure LineNumber_Is_Available_During_Parsing;

    [Test]
    procedure ReadFiles_Preserves_Order;

    [Test]
    procedure ReadFiles_Continues_Across_Multiple_Files;
  end;

  [TestFixture]
  TTestCallHistoryBindings = class(TContestReaderTestHelper)
  public
    [Test]
    procedure Binds_Required_Field;

    [Test]
    procedure Binds_Optional_Field;

    [Test]
    procedure Missing_Optional_Field_Uses_Default;

    [Test]
    procedure Missing_Required_Field_Raises_Exception;

    [Test]
    procedure Recompiles_Bindings_When_Header_Changes;
  end;

  [TestFixture]
  TTestCallHistoryHybrid = class(TContestReaderTestHelper)
  public
    [Test]
    procedure Hybrid_ParseRow_Can_Extend_Bindings;
  end;

implementation

uses
  System.Generics.Collections,  // for TObjectDictionary
  System.SysUtils;

constructor TFakeReader.Create;
begin
  inherited Create([cffN1MMCsv]);
  FCols.CallInx := -1;
  FCols.StateInx := -1;
  FCols.PowerInx := -1;
  FCols.UserTextInx := -1;
  FHeaderCount := 0;
end;

destructor TFakeReader.Destroy;
begin
  inherited;
end;

procedure TFakeReader.ParseSectionHeader(
  const Format: TContestFileFormat;
  const Fields: TStrings);
begin
  inherited;
  Inc(FHeaderCount);

  Assert.IsFalse(FColumnMap.Contains('!!Order!!'));

  FCols.CallInx := RequireField('Call');
  FCols.StateInx := OptionalField('State');
  FCols.PowerInx := OptionalField('Power');
  FCols.UserTextInx := OptionalField('UserText');
end;

procedure TFakeReader.ParseRow(
  const Fields: TStrings;
  Rec: TFakeRec);
begin
  Rec.Call := GetValue(Fields, FCols.CallInx);
  Rec.State := GetValue(Fields, FCols.StateInx);
  Rec.Power := GetValue(Fields, FCols.PowerInx);
  Rec.UserText := GetValue(Fields, FCols.UserTextInx);
end;

function TFakeBindingReader.IsHeaderDirective(
  const Format: TContestFileFormat;
  const Fields: TStrings): Boolean;
begin
  Result := (Fields.Count > 0) and SameText(Fields[0], '!!Order!!');
end;

procedure TFakeBindingReader.ConfigureBindings;
begin
  AddBinding(
    'CALL',
    True,
    procedure(const Value: string; Rec: TFakeBindingRow)
    begin
      Rec.Call := Value.ToUpper;
    end);

  AddBinding(
    'NAME',
    False,
    procedure(const Value: string; Rec: TFakeBindingRow)
    begin
      Rec.Name := Value;
    end);

  AddBinding(
    'AGE',
    False,
    procedure(const Value: string; Rec: TFakeBindingRow)
    begin
      Rec.Age := StrToIntDef(Value, 0);
    end);
end;

procedure TContestFileReaderTests.Visits_All_Rows;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  WriteTestFile('multi-calls.txt', [
    '!!Order!!,CALL',
    'AA0A',
    'AA0AA',
    'AA0AW'
  ]);

  Reader := TFakeReader.Create;
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('multi-calls.txt'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(3, Count);
  finally
    Reader.Free;
  end;
end;

[Test]
procedure TContestFileReaderTests.Skips_Blank_Lines;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  WriteTestFile('skip-blanks.txt', [
    '!!Order!!,CALL',
    '',
    'AA0A',
    '',
    'AA0AA'
  ]);

  Reader := TFakeReader.Create;
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('skip-blanks.txt'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;

[Test]
procedure TContestFileReaderTests.Skips_Comment_Lines;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  WriteTestFile('skip-comments.txt', [
    '# comment',
    '!!Order!!,CALL',
    '# another comment',
    'AA0A'
  ]);

  Reader := TFakeReader.Create;
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('skip-comments.txt'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(1, Count);
  finally
    Reader.Free;
  end;
end;

[Test]
procedure TContestFileReaderTests.Header_Is_Not_Visited;
var
  Reader: TFakeReader;
  Calls: TStringList;
begin
  WriteTestFile('single.csv', [
    '!!Order!!,CALL',
    'AA0A'
  ]);

  Calls := TStringList.Create;
  Reader := TFakeReader.Create;
  try
    Reader.ReadFile(
      TestFile('single.csv'),
      procedure(Rec: TFakeRec)
      begin
        Calls.Add(Rec.Call);
        Rec.Free;
      end);

    Assert.AreEqual(1, Calls.Count);
    Assert.AreEqual('AA0A', Calls[0]);
  finally
    Reader.Free;
    Calls.Free;
  end;
end;

procedure TContestFileReaderTests.Multiple_Headers_Are_Supported;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  WriteTestFile('multiple-headers.csv', [
    '!!Order!!,CALL',
    'AA0A',
    'AA0AA',
    '!!Order!!,CALL',
    'AA0AW'
  ]);

  Reader := TFakeReader.Create;
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('multiple-headers.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

  	Assert.AreEqual(2, Reader.HeaderCount);
    Assert.AreEqual(3, Count);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.Reordered_Columns_Are_Supported;
var
  Reader: TFakeReader;
begin
  WriteTestFile('reorder-columns.txt', [
    '!!Order!!,State,Call,Power',
    'MA,K1ABC,KW'
  ]);

  Reader := TFakeReader.Create;
  try
    Reader.ReadFile(
      TestFile('reorder-columns.txt'),
      procedure(Rec: TFakeRec)
      begin
        Assert.AreEqual('K1ABC', Rec.Call);
        Assert.AreEqual('MA', Rec.State);
        Assert.AreEqual('KW', Rec.Power);
        Rec.Free;
      end);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.Missing_Optional_Field_Returns_Empty_String;
var
  Reader: TFakeReader;
begin
  WriteTestFile('opt-field.txt', [
    '!!Order!!,Call',
    'K1ABC'
  ]);

  Reader := TFakeReader.Create;
  try
    Reader.ReadFile(
      TestFile('opt-field.txt'),
      procedure(Rec: TFakeRec)
      begin
        Assert.AreEqual('K1ABC', Rec.Call);
        Assert.AreEqual('', Rec.State);
        Assert.AreEqual('', Rec.Power);
        Assert.AreEqual('', Rec.UserText);
        Rec.Free;
      end);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.Unknown_Columns_Are_Ignored;
var
  Reader: TFakeReader;
  Records: TObjectList<TFakeRec>;
begin
  WriteTestFile('unknown-cols.txt', [
    '!!Order!!,Foo,Call,Bar,State,Baz',
    'XXX,AA0A,YYY,MA,ZZZ'
  ]);

  Reader := TFakeReader.Create;
  Records := TObjectList<TFakeRec>.Create(True);

  try
    Reader.ReadFile(
      TestFile('unknown-cols.txt'),
      procedure(Rec: TFakeRec)
      begin
        Records.Add(Rec);
      end);

    Assert.AreEqual(1, Records.Count, 'expecting 1 record');

    Assert.AreEqual('AA0A', Records[0].Call);
    Assert.AreEqual('MA', Records[0].State);

  finally
    Records.Free;
    Reader.Free;
  end;
end;

procedure TContestFileReaderTests.Missing_Required_Field_Raises;
var
  Reader: TFakeReader;
begin
  WriteTestFile('missing-call.csv', [
    '!!Order!!,State,Power',
    'MA,KW'
  ]);

  Reader := TFakeReader.Create;
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        Reader.ReadFile(
          TestFile('missing-call.csv'),
          procedure(Rec: TFakeRec)
          begin
            Rec.Free;
          end);
      end,
      Exception,
      '.*missing required field "Call".*');
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.Reads_Multiple_Files;
var
  Reader: TFakeReader;
  File1: string;
  File2: string;
  Count: Integer;
begin
  File1 := 'multi-files1.csv';
  File2 := 'multi-files2.csv';

  WriteTestFile(File1, [
    '!!Order!!,CALL',
    'AA0A'
  ]);

  WriteTestFile(File2, [
    '!!Order!!,CALL',
    'AA0AA'
  ]);

  Reader := TFakeReader.Create;
  try
    Count := 0;

    Reader.ReadFiles(
      [TestFile(File1), TestFile(File2)],
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;

type
  TFilteringReader = class(TFakeReader)
  protected
    function KeepRecord(const Rec: TFakeRec): Boolean; override;
  end;

function TFilteringReader.KeepRecord(const Rec: TFakeRec): Boolean;
begin
  Result := Rec.Call <> 'AA0AA';
end;

[Test]
procedure TContestFileReaderTests.KeepRow_Can_Filter_Rows;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  WriteTestFile('keep-row-filter.csv', [
    '!!Order!!,CALL',
    'AA0A',
    'AA0AA',
    'AA0AW'
  ]);

  Reader := TFilteringReader.Create;
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('keep-row-filter.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.Unknown_Format_Raises_Exception;
var
  Reader: TFakeReader;
begin
  WriteTestFile('invalid-header.csv', [
    'not a valid header'
  ]);

  Reader := TFakeReader.Create;
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        Reader.ReadFile(
          TestFile('invalid-header.csv'),
          procedure(Rec: TFakeRec)
          begin
            Rec.Free;
          end);
      end,
      Exception,
      'Unknown call history file format: ".*"');
  finally
    Reader.Free;
  end;
end;

procedure TContestFileReaderTests.Unsupported_Format_Raises_Exception;
var
  Reader: TFakeReader;
begin
  // TFakeReader is expecting N1MM-format files
  Reader := TFakeReader.Create;

  // Reading an ARRL-format file raises unsupported format exception
  WriteTestFile('arrl-format.csv', [
    'cabrillo_id'#9'CALL',
    'AA0A',
    'AA0AA',
    'AA0AW'
  ]);

  Assert.WillRaiseWithMessageRegex(
    procedure
    begin
      Reader.ReadFile(TestFile('arrl-format.csv'),
          procedure(Rec: TFakeRec)
          begin
            Rec.Free;
          end)
    end,
    Exception,
    'File ".*" is in ARRL Score Summary format, which is not supported by TFakeReader.');
end;

[Test]
procedure TContestFileReaderTests.Empty_File_Raises_Unknown_Format;
var
  Reader: TFakeReader;
begin
  // create an empty file
  WriteTestFile('empty-file.csv', [
    ''
  ]);

  Reader := TFakeReader.Create;
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        Reader.ReadFile(
          TestFile('empty-file.csv'),
          procedure(Rec: TFakeRec)
          begin
            Rec.Free;
          end);
      end,
      Exception,
      'Unknown call history file format: ".*"');
  finally
    Reader.Free;
  end;
end;


type
  TLineNumberReader = class(TFakeReader)
  public
    LastLineNumber: Integer;

  protected
    procedure ParseRow(
      const Fields: TStrings;
      Rec: TFakeRec); override;
  end;

procedure TLineNumberReader.ParseRow(
  const Fields: TStrings;
  Rec: TFakeRec);
begin
  inherited;

  LastLineNumber := LineNumber;
end;


type
  TFileNameReader = class(TFakeReader)
  public
    LastFileName: string;

  protected
    procedure ParseRow(
      const Fields: TStrings;
      Rec: TFakeRec); override;
  end;

procedure TFileNameReader.ParseRow(
  const Fields: TStrings;
  Rec: TFakeRec);
begin
  inherited;

  LastFileName := FileName;
end;


procedure TContestFileReaderTests.Consumer_Owns_Record;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  Count := 0;

  WriteTestFile(TestFile('simple.csv'), [
    '!!Order!!,Call',
    'K1ABC'
  ]);

  Reader := TFakeReader.Create;
  try
    Reader.ReadFile(TestFile('simple.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Assert.IsNotNull(Rec);
        Rec.Free;
      end);

    Assert.AreEqual(1, Count);
  finally
    Reader.Free;
  end;
end;

[Test]
procedure TContestFileReaderTests.Header_Only_File_Produces_No_Records;
var
  Reader: TFakeReader;
  Count: Integer;
begin
  Count := 0;

  // create a header-only file
  WriteTestFile('header-only.csv', [
    '!!Order!!,Call,State'
  ]);

  Reader := TFakeReader.Create;
  try
    Reader.ReadFile(TestFile('header-only.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(0, Count);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.FileName_Is_Available_During_Parsing;
var
  Reader: TFileNameReader;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,Call',
    'K1ABC'
  ]);

  Reader := TFileNameReader.Create;
  try
    Reader.ReadFile(TestFile('simple.csv'),
      procedure(Rec: TFakeRec)
      begin
        Rec.Free;
      end);

    Assert.AreEqual(TestFile('simple.csv'), Reader.LastFileName);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.LineNumber_Is_Available_During_Parsing;
var
  Reader: TLineNumberReader;
begin
  Reader := TLineNumberReader.Create;
  try
    WriteTestFile('simple.csv', [
      '!!Order!!,Call',
      'K1ABC'
    ]);

    Reader.ReadFile(TestFile('simple.csv'),
      procedure(Rec: TFakeRec)
      begin
        Rec.Free;
      end);

    Assert.AreEqual(2, Reader.LastLineNumber);
  finally
    Reader.Free;
  end;
end;


procedure TContestFileReaderTests.ReadFiles_Preserves_Order;
var
  Reader: TFakeReader;
  Calls: TStringList;
  File1, File2: string;
begin
  Calls := TStringList.Create;
  Reader := TFakeReader.Create;
  try
    File1 := 'simple1.csv';
    WriteTestfile(File1, [
      '!!Order!!,Call',
      'K1AAA'
    ]);

    File2 := 'simple2.csv';
    WriteTestfile(File2, [
      '!!Order!!,Call',
      'K1BBB'
    ]);

    Reader.ReadFiles(
      [TestFile(File1), TestFile(File2)],
      procedure(Rec: TFakeRec)
      begin
        Calls.Add(Rec.Call);
        Rec.Free;
      end);

    Assert.AreEqual('K1AAA', Calls[0]);
    Assert.AreEqual('K1BBB', Calls[1]);
  finally
    Calls.Free;
    Reader.Free;
  end;
end;


[Test]
procedure TContestFileReaderTests.ReadFiles_Continues_Across_Multiple_Files;
var
  Reader: TFakeReader;
  Count: Integer;
  File1, File2: string;
begin
  Count := 0;

  Reader := TFakeReader.Create;
  try
    File1 := 'simple1.csv';
    WriteTestfile(File1, [
      '!!Order!!,Call',
      'K1AAA'
    ]);

    File2 := 'simple2.csv';
    WriteTestfile(File2, [
      '!!Order!!,Call',
      'K1BBB'
    ]);

    Reader.ReadFiles(
      [TestFile(File1), TestFile(File2)],
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;

type
  TDefaultCreateRec = class
  public
    Call: string;
  end;

  TDefaultCreateReader = class(TContestFileReader<TDefaultCreateRec>)
  protected
    procedure ParseRow(
      const Fields: TStrings;
      Rec: TDefaultCreateRec); override;
  end;

procedure TDefaultCreateReader.ParseRow(
  const Fields: TStrings;
  Rec: TDefaultCreateRec);
begin
  Rec.Call := Fields[0];
end;


[Test]
procedure TContestFileReaderTests.Default_CreateRecord_Is_Used;
var
  Reader: TDefaultCreateReader;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL',
    'AA0A'
  ]);

  Reader := TDefaultCreateReader.Create([cffN1MMCsv]);
  try
    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(Rec: TDefaultCreateRec)
      begin
        Assert.IsNotNull(Rec);
        Assert.AreEqual('AA0A', Rec.Call);
        Rec.Free;
      end);
  finally
    Reader.Free;
  end;
end;


type
  TNormalizingReader = class(TFakeReader)
  protected
    procedure NormalizeRecord(Rec: TFakeRec); override;
  end;

  procedure TNormalizingReader.NormalizeRecord(Rec: TFakeRec);
  begin
    inherited;
    Rec.Call := UpperCase(Rec.Call);
  end;

[Test]
procedure TContestFileReaderTests.NormalizeRecord_Is_Called;
var
  Reader: TNormalizingReader;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL',
    'aa0a'
  ]);

  Reader := TNormalizingReader.Create;
  try
    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(Rec: TFakeRec)
      begin
        Assert.AreEqual('AA0A', Rec.Call);
        Rec.Free;
      end);
  finally
    Reader.Free;
  end;
end;


type
  TNormalizeThenKeepReader = class(TFakeReader)
  protected
    procedure NormalizeRecord(Rec: TFakeRec); override;
    function KeepRecord(const Rec: TFakeRec): Boolean; override;
  end;

procedure TNormalizeThenKeepReader.NormalizeRecord(Rec: TFakeRec);
begin
  Rec.Call := UpperCase(Rec.Call);
end;

function TNormalizeThenKeepReader.KeepRecord(const Rec: TFakeRec): Boolean;
begin
  Result := Rec.Call = 'AA0A';
end;

[Test]
procedure TContestFileReaderTests.NormalizeRecord_Before_KeepRow;
var
  Reader: TNormalizeThenKeepReader;
  Count: Integer;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL',
    'aa0a'
  ]);

  Reader := TNormalizeThenKeepReader.Create;
  try
    Assert.IsTrue(Reader.SupportedFormats = [cffN1MMCsv]);

    Count := 0;
    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);
    Assert.AreEqual(1, Count);
  finally
    Reader.Free;
  end;
end;


type
  THandleLineReader = class(TFakeReader)
  protected
    function HandleLine(const Line: string): Boolean; override;
  end;

function THandleLineReader.HandleLine(
  const Line: string): Boolean;
begin
  Result := SameText(Line, 'SPECIAL');
end;


[Test]
procedure TContestFileReaderTests.HandleLine_Can_Consume_Line;
var
  Reader: THandleLineReader;
  Count: Integer;
begin
  WriteTestFile('special.csv', [
    '!!Order!!,CALL',
    'AA0A',
    'SPECIAL',
    'AA0AA'
  ]);

  Reader := THandleLineReader.Create;
  try
    Count := 0;
    Reader.ReadFile(
      TestFile('special.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);
    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;


[Test]
{
  This test is based on the need to apply corrections to an original data set.
  This is true for the Arrl 10m Contest where the ARRL score data file
  contains sections, not States. The ARRL 10m Contest requires States to be
  sent from US/CA/XE stations. This data file uses 'MDC' for Maryland/DC
  section, but the contest requires the state. Either 'MD' or 'DC', not 'MDC'

  The idea of using a second correction file allows records from the first
  file to be correct using data from the second file. This unit test
  captures the basic idea of this proposed algorithm.

  What this test proves:
  - The reader produces records immediately.
  - The consumer may store records.
  - The consumer may later apply corrections.
  - Unknown corrections are ignored.
  - The reader itself performs no merge logic.
}
procedure TContestFileReaderTests.Consumer_Can_Apply_Correction_File;
var
  Reader: TFakeReader;
  PrimaryFile: string;
  CorrectionFile: string;
  Dict: TObjectDictionary<string, TFakeRec>;
  Rec: TFakeRec;
begin
  PrimaryFile := 'primary.txt';
  CorrectionFile := 'corrections.txt';

  WriteTestFile(PrimaryFile, [
    '!!Order!!,CALL,STATE',
    'AA0A,MD',
    'AA0B,MD'
  ]);

  WriteTestFile(CorrectionFile, [
    '!!Order!!,CALL,STATE',
    'AA0B,DC',
    'AA0C,DC'
  ]);

  Reader := TFakeReader.Create;
  Dict := TObjectDictionary<string, TFakeRec>.Create([doOwnsValues]);
  try

    // Load primary records.
    Reader.ReadFile(
      TestFile(PrimaryFile),

      procedure(Rec: TFakeRec)
      begin
        Dict.Add(Rec.Call, Rec);
      end);

    // Apply corrections.
    Reader.ReadFile(
      TestFile(CorrectionFile),

      procedure(Rec: TFakeRec)
      var
        Existing: TFakeRec;
      begin
        if Dict.TryGetValue(Rec.Call, Existing) then
          Existing.State := Rec.State;

        Rec.Free;
      end);

    Assert.AreEqual(2, Dict.Count);

    Assert.IsTrue(Dict.TryGetValue('AA0A', Rec));
    Assert.AreEqual('MD', Rec.State);

    Assert.IsTrue(Dict.TryGetValue('AA0B', Rec));
    Assert.AreEqual('DC', Rec.State);

    Assert.IsFalse(Dict.ContainsKey('AA0C'));

  finally
    Dict.Free;
    Reader.Free;
  end;
end;

type
  TSimpleRec = class
  public
    Call: string;
    State: string;
  end;

type
  TSimpleReader = class(TContestFileReader<TSimpleRec>)
  end;

[Test]
procedure TContestFileReaderTests.Default_Bindings_Are_Applied;
var
  Reader: TSimpleReader;
  Rec: TSimpleRec;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL,STATE',
    'AA0A,TX'
  ]);

  Reader := TSimpleReader.Create([cffN1MMCsv]);
  try
    Reader.AddDefaultBinding('CALL', True,
      procedure(const Value: string; Row: TSimpleRec) begin
        Row.Call := Value;
      end);

    Reader.AddDefaultBinding('STATE', True,
      procedure(const Value: string; Row: TSimpleRec) begin
        Row.State := Value;
      end);

    Rec := nil;

    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(Row: TSimpleRec)
      begin
        Rec := Row;
      end);

    Assert.IsNotNull(Rec);
    Assert.AreEqual('AA0A', Rec.Call);
    Assert.AreEqual('TX', Rec.State);

    Rec.Free;
  finally
    Reader.Free;
  end;
end;

[Test]
procedure TContestFileReaderTests.Default_Bindings_Recompile_When_Header_Changes;
var
  Reader: TSimpleReader;
  Count: Integer;
begin
  WriteTestFile('multiple-bindings.csv', [
    '!!Order!!,CALL',
    'AA0A',

    '!!Order!!,CALL,STATE',
    'AA0B,CA'
  ]);

  Reader := TSimpleReader.Create([cffN1MMCsv]);
  try
    Reader.AddDefaultBinding('CALL', True,
      procedure(const Value: string; Row: TSimpleRec)
      begin
        Row.Call := Value;
      end);

    Reader.AddDefaultBinding('STATE', False,
      procedure(const Value: string; Row: TSimpleRec)
      begin
        Row.State := Value;
      end);

    Count := 0;

    Reader.ReadFile(
      TestFile('multiple-bindings.csv'),
      procedure(Row: TSimpleRec)
      begin
        Inc(Count);

        if Count = 1 then
        begin
          Assert.AreEqual('AA0A', Row.Call);
          Assert.AreEqual('', Row.State);
        end;

        if Count = 2 then
        begin
          Assert.AreEqual('AA0B', Row.Call);
          Assert.AreEqual('CA', Row.State);
        end;

        Row.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;


type
  TStopReader = class(TFakeReader)
  protected
    function HandleLine(const Line: string): Boolean; override;
  end;

function TStopReader.HandleLine(
  const Line: string): Boolean;
begin
  Result := SameText(Line, 'BREAK');
  if Result then
    StopReading;
end;


[Test]
procedure TContestFileReaderTests.StopReading_Ends_Read_Loop;
var
  Reader: TStopReader;
  Count: Integer;
begin
  WriteTestFile('file-with-break.csv', [
    '!!Order!!,CALL',
    'AA0A',
    'BREAK',
    'AA0AA'
  ]);

  Reader := TStopReader.Create;
  try
    Count := 0;
    Reader.ReadFile(
      TestFile('file-with-break.csv'),
      procedure(Rec: TFakeRec)
      begin
        Inc(Count);
        Rec.Free;
      end);
    Assert.AreEqual(1, Count);
  finally
    Reader.Free;
  end;
end;


procedure TTestCallHistoryBindings.Binds_Required_Field;
var
  Reader: TFakeBindingReader;
  Rec: TFakeBindingRow;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL',
    'AA0A'
  ]);

  Reader := TFakeBindingReader.Create([cffN1MMCsv]);
  try
    Rec := nil;

    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(R: TFakeBindingRow)
      begin
        Rec := R;
      end);

    Assert.IsNotNull(Rec);
    Assert.AreEqual('AA0A', Rec.Call);

    Rec.Free;
  finally
    Reader.Free;
  end;
end;

procedure TTestCallHistoryBindings.Binds_Optional_Field;
var
  Reader: TFakeBindingReader;
  Rec: TFakeBindingRow;
begin
  WriteTestFile('name-age.txt', [
    '!!Order!!,CALL,NAME,AGE',
    'AA0A,Mike,42'
  ]);

  Reader := TFakeBindingReader.Create([cffN1MMCsv]);
  try
    Rec := nil;

    Reader.ReadFile(
      TestFile('name-age.txt'),
      procedure(R: TFakeBindingRow)
      begin
        Rec := R;
      end);

    Assert.AreEqual('AA0A', Rec.Call);
    Assert.AreEqual('Mike', Rec.Name);
    Assert.AreEqual(42, Rec.Age);

    Rec.Free;
  finally
    Reader.Free;
  end;
end;

procedure TTestCallHistoryBindings.Missing_Optional_Field_Uses_Default;
var
  Reader: TFakeBindingReader;
  Rec: TFakeBindingRow;
begin
  WriteTestFile('simple.csv', [
    '!!Order!!,CALL',
    'AA0A'
  ]);

  Reader := TFakeBindingReader.Create([cffN1MMCsv]);
  try
    Rec := nil;

    Reader.ReadFile(
      TestFile('simple.csv'),
      procedure(R: TFakeBindingRow)
      begin
        Rec := R;
      end);

    Assert.AreEqual('AA0A', Rec.Call);
    Assert.AreEqual('', Rec.Name);
    Assert.AreEqual(0, Rec.Age);

    Rec.Free;
  finally
    Reader.Free;
  end;
end;

procedure TTestCallHistoryBindings.Missing_Required_Field_Raises_Exception;
var
  Reader: TFakeBindingReader;
begin
  WriteTestFile('missing-call.txt', [
    '!!Order!!,NAME',
    'Mike'
  ]);

  Reader := TFakeBindingReader.Create([cffN1MMCsv]);
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        Reader.ReadFile(
          TestFile('missing-call.txt'),
          procedure(Rec: TFakeBindingRow)
          begin
            Rec.Free;
          end);
      end,
      Exception,
      'Missing required field "CALL". Line 1, File ".*"');
  finally
    Reader.Free;
  end;
end;

procedure TTestCallHistoryBindings.Recompiles_Bindings_When_Header_Changes;
var
  Reader: TFakeBindingReader;
  Count: Integer;
begin
  WriteTestFile('header-change.txt', [
    '!!Order!!,CALL',
    'AA0A',

    '!!Order!!,CALL,NAME',
    'AA0B,Mike'
  ]);

  Reader := TFakeBindingReader.Create([cffN1MMCsv]);
  try
    Count := 0;

    Reader.ReadFile(
      TestFile('header-change.txt'),
      procedure(Rec: TFakeBindingRow)
      begin
        Inc(Count);

        if Count = 1 then
        begin
          Assert.AreEqual('AA0A', Rec.Call);
          Assert.AreEqual('', Rec.Name);
        end;

        if Count = 2 then
        begin
          Assert.AreEqual('AA0B', Rec.Call);
          Assert.AreEqual('Mike', Rec.Name);
        end;

        Rec.Free;
      end);

    Assert.AreEqual(2, Count);
  finally
    Reader.Free;
  end;
end;

{ ---- Hybrid Reader ---- }

type
  THybridRow = class
  public
    Call: string;
    State: string;
    DisplayText: string;
  end;

  THybridReader = class(TContestFileReader<THybridRow>)
  protected
    function IsHeaderDirective(
      const Format: TContestFileFormat;
      const Fields: TStrings): Boolean; override;

    procedure ConfigureBindings; override;

    procedure ParseRow(
      const Fields: TStrings;
      Rec: THybridRow); override;
  end;

function THybridReader.IsHeaderDirective(
  const Format: TContestFileFormat;
  const Fields: TStrings): Boolean;
begin
  Result := inherited IsHeaderDirective(Format, Fields);
end;

procedure THybridReader.ConfigureBindings;
begin
  AddBinding(
    'CALL',
    True,
    procedure(const Value: string; Rec: THybridRow)
    begin
      Rec.Call := Value.ToUpper;
    end);

  AddBinding(
    'STATE',
    False,
    procedure(const Value: string; Rec: THybridRow)
    begin
      Rec.State := Value.ToUpper;
    end);
end;

procedure THybridReader.ParseRow(
  const Fields: TStrings;
  Rec: THybridRow);
begin
  inherited;

  Rec.DisplayText :=
    Rec.Call + ' (' + Rec.State + ')';
end;

[Test]
procedure TTestCallHistoryHybrid.Hybrid_ParseRow_Can_Extend_Bindings;
var
  Reader: THybridReader;
begin
  WriteTestFile('call-state.txt', [
    '!!Order!!,CALL,STATE',
    'aa0a,tx'
  ]);

  Reader := THybridReader.Create([cffN1MMCsv]);
  try
    Reader.ReadFile(
      TestFile('call-state.txt'),
      procedure(Rec: THybridRow)
      begin
        Assert.AreEqual('AA0A', Rec.Call);
        Assert.AreEqual('TX', Rec.State);
        Assert.AreEqual('AA0A (TX)', Rec.DisplayText);

        Rec.Free;
      end);
  finally
    Reader.Free;
  end;
end;


initialization
  TDUnitX.RegisterTestFixture(TContestFileReaderTests);
  TDUnitX.RegisterTestFixture(TTestCallHistoryBindings);
  TDUnitX.RegisterTestFixture(TTestCallHistoryHybrid);

end.
