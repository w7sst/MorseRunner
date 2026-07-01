//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.ContestReader.Contracts;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Test.ContestReader.Base,
  ContestFileReader;

type
  {
    Generic reusable contract tests for contest readers.

    Purpose:
      Verify baseline TContestFileReader behavior shared by all
      derived contest readers.

    Derived fixtures provide:
      - concrete reader type
      - concrete record type
      - minimal valid header
      - reader construction

    IMPORTANT:
      This base fixture should test only generic reader behavior.

      Contest-specific semantics such as:
        - KeepRecord logic
        - NormalizeRecord behavior
        - field interpretation
        - contest-specific filtering

      should remain in the derived fixture.
  }
  TContestReaderContractTests<
    TRec: class, constructor;
    TReader: TContestFileReader<TRec>, constructor> =
      class abstract(TContestReaderTestHelper)

  private
    FMinimalValidHeader: string;
    FMinimalValidRow: string;

    procedure CheckFixtureConfigured;

  protected
    property MinimalValidHeader: string read FMinimalValidHeader;
    property MinimalValidRow: string read FMinimalValidRow;

    {
      Construct a new instance of ContestReaderContractTests<>.
      Derived classes provide:
      - AMinimalValidHeader - minimal valid header for the contest reader.
      - AMinimalValidRow    - minimal valid row for the contest reader.

      Example:
        Create('!!Order!!,Call,State', 'K1ABC,MA');
    }
    constructor Create(
      const AMinimalValidHeader: string;
      const AMinimalValidRow: string);

    {
      Create a default valid reader instance.

      Derived fixtures override this to provide any required
      constructor arguments.
    }
    function CreateReader: TReader; virtual;

    {
      Reads all records from the supplied lines and returns
      them in an owning TObjectList<TRec>.
    }
    function ReadAll(
      const Lines: array of string): TObjectList<TRec>;

    { Read all records from the specified file; return TObjectList<TRec>. }
    function ReadAllFromFile(
      const FileName: string): TObjectList<TRec>;

    { Read all records from the specified file and return final count. }
    function ReadCountFromFile(const FileName: string): Integer;

    { Read from specified file and assert that an exception was raised. }
    procedure AssertReadRaises(
      const FileName: string;
      const ExceptionClass: ExceptClass;
      const MsgRegex: string = '');

    public
    {
      Verifies a valid file produces exactly one record.
    }
    [Test]
    procedure Reads_Single_Record;

    {
      Verifies blank lines are ignored.
    }
    [Test]
    procedure Skips_Blank_Lines;

    {
      Verifies comment lines are ignored.
    }
    [Test]
    procedure Skips_Comment_Lines;

    {
      Verifies a header-only file produces no records.
    }
    [Test]
    procedure Header_Only_File_Produces_No_Records;

    {
      Verifies unknown file formats raise exceptions.
    }
    [Test]
    procedure Unknown_Format_Raises_Exception;
  end;

implementation

uses
  AppPaths;

{ TContestReaderContractTests<TRec,TReader> }

constructor TContestReaderContractTests<TRec,TReader>.Create(
  const AMinimalValidHeader: string;
  const AMinimalValidRow: string);
begin
  FMinimalValidHeader := AMinimalValidHeader;
  FMinimalValidRow := AMinimalValidRow;
end;


// Validate that minimal header and row fields have been set by derived class.
procedure TContestReaderContractTests<TRec,TReader>.CheckFixtureConfigured;
begin
  Assert.IsFalse(FMinimalValidHeader.IsEmpty);
  Assert.IsFalse(FMinimalValidRow.IsEmpty);
end;


function TContestReaderContractTests<TRec, TReader>.CreateReader: TReader;
begin
  Result := TReader.Create;
end;


function TContestReaderContractTests<TRec,TReader>.ReadAll(
  const Lines: array of string): TObjectList<TRec>;
var
  Reader: TReader;
  FileName: string;
  Records: TObjectList<TRec>;
begin
  FileName := 'contest-reader-test.csv';

  WriteTestFile(FileName, Lines);

  Records := TObjectList<TRec>.Create(True);

  Reader := CreateReader;
  try
    Reader.ReadFile(TestFile(FileName),
      procedure(Rec: TRec)
      begin
        Records.Add(Rec);
      end);
  finally
    Reader.Free;
  end;

  Result := Records;
end;


function TContestReaderContractTests<TRec, TReader>.ReadAllFromFile(
    const FileName: string): TObjectList<TRec>;
var
  Reader: TReader;
  Records: TObjectList<TRec>;
begin
  Records := TObjectList<TRec>.Create(True);

  Reader := CreateReader;
  try
    Reader.ReadFile(FileName,
      procedure(Rec: TRec)
      begin
        Records.Add(Rec);
      end);
  finally
    Reader.Free;
  end;

  Result := Records;
end;


function TContestReaderContractTests<TRec,TReader>.ReadCountFromFile(
    const FileName: string): Integer;
var
  Reader: TReader;
  Count: integer;
begin
  Count := 0;

  Reader := CreateReader;
  try
    Reader.ReadFile(FileName,
      procedure(Rec: TRec)
      begin
        Inc(Count);
        Rec.Free;
      end);
  finally
    Reader.Free;
  end;

  Result := Count;
end;


procedure TContestReaderContractTests<TRec,TReader>.AssertReadRaises(
  const FileName: string;
  const ExceptionClass: ExceptClass;
  const MsgRegex: string = '');
var
  Reader: TReader;
begin
  Reader := CreateReader;
  try

    if MsgRegex.IsEmpty then
    begin
      Assert.WillRaise(
        procedure
        begin
          Reader.ReadFile(
            FileName,
            procedure(Rec: TRec)
            begin
              Rec.Free;
            end);
        end,
        ExceptionClass);
    end
    else
    begin
      Assert.WillRaiseWithMessageRegex(
        procedure
        begin
          Reader.ReadFile(
            FileName,
            procedure(Rec: TRec)
            begin
              Rec.Free;
            end);
        end,
        ExceptionClass,
        MsgRegex);
    end;

  finally
    Reader.Free;
  end;
end;


procedure TContestReaderContractTests<TRec,TReader>.Reads_Single_Record;
var
  Records: TObjectList<TRec>;
begin
  CheckFixtureConfigured;

  Records := ReadAll([
    MinimalValidHeader,
    MinimalValidRow
  ]);
  try
    Assert.AreEqual(1, Records.Count);
  finally
    Records.Free;
  end;
end;


procedure TContestReaderContractTests<TRec,TReader>.Skips_Blank_Lines;
var
  Records: TObjectList<TRec>;
begin
  Records := ReadAll([
    '',
    '   ',
    MinimalValidHeader,
    '',
    MinimalValidRow,
    ''
  ]);
  try
    Assert.AreEqual(1, Records.Count);
  finally
    Records.Free;
  end;
end;


procedure TContestReaderContractTests<TRec,TReader>.Skips_Comment_Lines;
var
  Records: TObjectList<TRec>;
begin
  Records := ReadAll([
    '# comment',
    '# another comment',
    MinimalValidHeader,
    MinimalValidRow
  ]);
  try
    Assert.AreEqual(1, Records.Count);
  finally
    Records.Free;
  end;
end;


procedure TContestReaderContractTests<TRec,TReader>.Header_Only_File_Produces_No_Records;
var
  Records: TObjectList<TRec>;
begin
  Records := ReadAll([
    MinimalValidHeader
  ]);
  try
    Assert.AreEqual(0, Records.Count);
  finally
    Records.Free;
  end;
end;


procedure TContestReaderContractTests<TRec,TReader>.Unknown_Format_Raises_Exception;
var
  Reader: TReader;
begin
  WriteTestFile('unknown-format.txt', [
    'This is not a valid contest file'
  ]);

  Reader := CreateReader;
  try
    Assert.WillRaiseWithMessageRegex(
      procedure
      begin
        Reader.ReadFile(
          TestFile('unknown-format.txt'),
          procedure(Rec: TRec)
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

end.
