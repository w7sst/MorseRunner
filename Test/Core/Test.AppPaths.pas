unit Test.AppPaths;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAppPathsTests = class
  public
    [Test]
    procedure RepositoryRootDir_Is_Not_Empty;

    [Test]
    procedure All_Directories_Have_Trailing_Delimiter;

    [Test]
    procedure ContestDataDir_Is_Under_AppRoot;

    [Test]
    procedure ContestDataFile_Appends_FileName;

    [Test]
    procedure ContestDataFile_Does_Not_Duplicate_Separators;

    [Test]
    procedure TestDataDir_Is_Under_AppRoot;

    [Test]
    procedure TestDataFile_Appends_FileName;

    [Test]
    procedure TempTestDir_Is_Created;

    [Test]
    procedure TempTestDir_Is_Writable;

    [Test]
    procedure TempTestDir_Is_Under_AppRoot;

    [Test]
    procedure TempTestFile_Appends_FileName;

    [Test]
    procedure TempTestFile_Empty_FileName_Creates_Unique_File;

    [Test]
    procedure CreateTempTestFile_Is_Empty_File;

  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  AppPaths;

procedure TAppPathsTests.RepositoryRootDir_Is_Not_Empty;
begin
  Assert.IsFalse(TAppPaths.RepositoryRootDir.IsEmpty);
end;

procedure TAppPathsTests.All_Directories_Have_Trailing_Delimiter;
begin
  Assert.IsTrue(TAppPaths.RepositoryRootDir.EndsWith(PathDelim));
  Assert.IsTrue(TAppPaths.ContestDataDir.EndsWith(PathDelim));
  Assert.IsTrue(TAppPaths.TestDataDir.EndsWith(PathDelim));
  Assert.IsTrue(TAppPaths.TempTestDir.EndsWith(PathDelim));
end;

procedure TAppPathsTests.ContestDataDir_Is_Under_AppRoot;
begin
  Assert.IsTrue(TAppPaths.ContestDataDir.StartsWith(TAppPaths.ExecutableDir));

{$IFDEF FUTURE_CONTEST_DATA_SUBDIR}
  Assert.IsTrue(TAppPaths.ContestDataDir.Contains('ContestData'));
{$ELSE}
  Assert.AreEqual(TAppPaths.ExecutableDir, TAppPaths.ContestDataDir);
{$ENDIF}
end;

procedure TAppPathsTests.ContestDataFile_Appends_FileName;
var
  Path: string;
begin
  Path := TAppPaths.ContestDataFile('FDGOTA.txt');

  Assert.IsTrue(Path.EndsWith('FDGOTA.txt'));
end;

procedure TAppPathsTests.ContestDataFile_Does_Not_Duplicate_Separators;
var
  Path: string;
begin
  Path := TAppPaths.ContestDataFile('sample.txt');

  Assert.IsFalse(Path.Contains('\\'),
    'Path should not contain duplicate separators.');
end;

procedure TAppPathsTests.TestDataDir_Is_Under_AppRoot;
var
  Path, ExpectedTail: string;
begin
  Path := TAppPaths.TestDataDir;

  Assert.IsTrue(Path.StartsWith(TAppPaths.RepositoryRootDir),
    format('%s: should start with RepositoryRootDir',[Path]));

  ExpectedTail := IncludeTrailingPathDelimiter(TPath.Combine('Test', 'Data'));
  Assert.IsTrue(Path.EndsWith(ExpectedTail),
    format('%s: should end with %s', [Path, ExpectedTail]));
end;

procedure TAppPathsTests.TestDataFile_Appends_FileName;
var
  Path: string;
begin
  Path := TAppPaths.TestDataFile('sample.csv');

  Assert.IsTrue(Path.EndsWith('sample.csv'));
end;

procedure TAppPathsTests.TempTestDir_Is_Created;
var
  Dir: string;
begin
  Dir := TPath.Combine([TAppPaths.RepositoryRootDir, 'Test', 'Temp']);

  if TDirectory.Exists(Dir) then
    TDirectory.Delete(Dir, True);

  Assert.IsFalse(TDirectory.Exists(Dir));

  Dir := TAppPaths.TempTestDir;

  Assert.IsTrue(
    TDirectory.Exists(Dir),
    'Temp test directory should be auto-created.');
end;

procedure TAppPathsTests.TempTestDir_Is_Writable;
var
  Dir: string;
  FileName: string;
begin
  Dir := TAppPaths.TempTestDir;

  FileName := TPath.Combine(Dir, 'write-test.tmp');

  try
    TFile.WriteAllText(FileName, 'test');

    Assert.IsTrue(TFile.Exists(FileName));
  finally
    DeleteFile(FileName);
  end;
end;

procedure TAppPathsTests.TempTestDir_Is_Under_AppRoot;
var
  Path, ExpectedTail: string;
begin
  Path := TAppPaths.TempTestDir;

  ExpectedTail := IncludeTrailingPathDelimiter(TPath.Combine('Test', 'Temp'));
  Assert.IsTrue(Path.StartsWith(TAppPaths.RepositoryRootDir));
  Assert.IsTrue(Path.EndsWith(ExpectedTail),
    format('%s: should end with %s', [Path, ExpectedTail]));
end;

procedure TAppPathsTests.TempTestFile_Appends_FileName;
var
  Path: string;
begin
  Path := TAppPaths.TempTestFile('temp.csv');

  Assert.IsTrue(Path.EndsWith('temp.csv'));
end;

procedure TAppPathsTests.TempTestFile_Empty_FileName_Creates_Unique_File;
var
  FileName1: string;
  FileName2: string;
begin
  FileName1 := TAppPaths.TempTestFile('');
  FileName2 := TAppPaths.TempTestFile('');

  try
    Assert.IsFalse(FileName1.IsEmpty);
    Assert.IsFalse(FileName2.IsEmpty);

    Assert.AreNotEqual(FileName1, FileName2);

    Assert.IsTrue(FileName1.StartsWith(TAppPaths.TempTestDir));
    Assert.IsTrue(FileName2.StartsWith(TAppPaths.TempTestDir));

  finally
    DeleteFile(FileName1);
    DeleteFile(FileName2);
  end;
end;

procedure TAppPathsTests.CreateTempTestFile_Is_Empty_File;
var
  FileName: string;
  Contents: string;
begin
  FileName := TAppPaths.CreateTempTestFile('txt');

  try
    Assert.IsTrue(
      TFile.Exists(FileName),
      'Temporary file should exist.');

    Contents := TFile.ReadAllText(FileName);

    Assert.AreEqual(
      '',
      Contents,
      'Temporary file should initially be empty.');
  finally
    DeleteFile(FileName);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAppPathsTests);

end.
