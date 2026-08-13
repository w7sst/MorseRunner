//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.ContestReader.Base;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections;

type
  {
    Base helper fixture for contest reader tests.

    Responsibilities:
      - Temporary file creation
      - Test data path
      - Writing test input files
      - Reading all records into TObjectList<T>
      - Common parsing helpers
      - Shared assertions
      - Cleanup

    This class is intentionally NON-generic so helper methods remain
    simple and reusable across all reader test fixtures.
  }
  TContestReaderTestHelper = class
  protected
    FTempFiles: TList<string>;

    function TempTestFile(
      const FileName: string = ''): string;

    function CreateTempFileName(const FileName: string = ''): string;
    function CreateTempTestFile(const Extension: string = ''): string;

    procedure WriteTestFile(
      const FileName: string;
      const Lines: array of string);

    function TestFile(const FileName: string): string;

    function ContestDataFile(
      const FileName: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;
  end;

implementation

uses
  AppPaths;

{ ==================================================================== }
{ TContestReaderTestHelper                                             }
{ ==================================================================== }

procedure TContestReaderTestHelper.Setup;
begin
  FTempFiles := TList<string>.Create;
end;

procedure TContestReaderTestHelper.TearDown;
var
  FileName: string;
begin
  for FileName in FTempFiles do
  begin
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;

  FTempFiles.Free;
end;


// generates path, does NOT create file, registers cleanup
function TContestReaderTestHelper.CreateTempFileName(const FileName: string = ''): string;
begin
  Result := TAppPaths.TempTestFile(FileName);
  FTempFiles.Add(Result);
end;


// generates path, creates the file, registers cleanup
function TContestReaderTestHelper.CreateTempTestFile(
  const Extension: string = ''): string;
begin
  Result := TAppPaths.CreateTempTestFile(Extension);
  FTempFiles.Add(Result);
end;


function TContestReaderTestHelper.TempTestFile(
  const FileName: string): string;
begin
  Result := TAppPaths.TempTestFile(FileName);
end;


function TContestReaderTestHelper.ContestDataFile(
  const FileName: string): string;
begin
  Result := TAppPaths.ContestDataFile(FileName);
end;


procedure TContestReaderTestHelper.WriteTestFile(
  const FileName: string;
  const Lines: array of string);
var
  SL: TStringList;
  Path: string;
  S: string;
begin
  Path := CreateTempFileName(FileName);

  SL := TStringList.Create;
  try
    for S in Lines do
      SL.Add(S);

    SL.SaveToFile(Path);

  finally
    SL.Free;
  end;
end;

function TContestReaderTestHelper.TestFile(
  const FileName: string): string;
begin
  Result := TAppPaths.TempTestFile(FileName);
end;

end.
