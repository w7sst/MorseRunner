unit AppPaths;

interface

type
  {
    TAppPaths centralizes all filesystem paths used by the application
    and test infrastructure.

    Responsibilities
    ----------------
    - Detect development vs installed runtime layout
    - Provide canonical application directories
    - Provide contest data file locations
    - Provide shared test data locations
    - Provide writable temporary test file locations
    - Cache resolved paths for efficiency and consistency

    Directory Conventions
    ---------------------
    Development Layout
      RepositoryRoot\
        Src\
        Test\
        ...

      Contest data files:
        Src\Domain\Contests\Data\

      Test data files:
        Test\Data\

      Temporary test files:
        Test\Temp\

    Installed Layout
      ApplicationDirectory\
        Executable.exe
        ContestData\

    Notes
    -----
    - All directory paths returned by TAppPaths include a trailing path delimiter.
    - File-returning functions return fully-qualified file paths.
    - Temporary test directories are automatically created on demand.
    - TempTestFile('') creates a (potential) unique temporary file name.

    Design Notes
    ------------
    TAppPaths is intended to be application-wide infrastructure and should
    remain independent of contest-specific logic.

    The class caches resolved filesystem locations after first initialization
    to avoid repeated filesystem probing during runtime and unit testing.

    Developed with the assistance of OpenAI/ChatGPT.
  }
  TAppPaths = record
  private
    class var
      FInitialized: Boolean;
      FExecutableDir: string;
      FRepositoryRootDir: string;
      FContestDataDir: string;
      FTestDataDir: string;
      FTempTestDir: string;
      FIsInstalledLayout: Boolean;

    class procedure Initialize; static;

  public
    class function IsInstalledLayout: Boolean; static;

    class function ExecutableDir: string; static;
    class function RepositoryRootDir: string; static;

    class function ContestDataDir: string; static;
    class function ContestDataFile(const FileName: string): string; static;

    class function TestDataDir: string; static;
    class function TestDataFile(const FileName: string): string; static;

    class function TempTestDir: string; static;
    class function TempTestFile(const FileName: string = ''): string; static;
    class function CreateTempTestFile(const Extension: string = '.tmp'): string; static;

    class procedure ResetForTesting; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

class procedure TAppPaths.Initialize;
begin
  if FInitialized then
    Exit;

  Randomize;

  // Executable location
  TAppPaths.FExecutableDir := IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0)));

  // Detect repository layout
  if TDirectory.Exists(TPath.Combine(FExecutableDir, '.git')) and
     TDirectory.Exists(TPath.Combine(FExecutableDir, 'VCL')) and
     TDirectory.Exists(TPath.Combine(FExecutableDir, 'Util')) and
     TFile.Exists(TPath.Combine(FExecutableDir, 'Main.pas')) then
    TAppPaths.FRepositoryRootDir := FExecutableDir
  else
    TAppPaths.FRepositoryRootDir := '';

  // Detect installed layout
  if TDirectory.Exists(TPath.Combine(FExecutableDir, 'ContestData')) then
    TAppPaths.FIsInstalledLayout := True
{$IFDEF FUTURE_CONTEST_DATA_SUBDIR}
  else if TDirectory.Exists(
    TPath.Combine([FRepositoryRootDir, 'Src', 'Domain', 'Contests', 'Data'])) then
    TAppPaths.FIsInstalledLayout := False
{$ELSE}
  else if not FRepositoryRootDir.IsEmpty then
    TAppPaths.FIsInstalledLayout := False
{$ENDIF}
  else
    raise Exception.Create('Invalid configuration');

  // location of contest history files
{$IFDEF FUTURE_CONTEST_DATA_SUBDIR}
  if FIsInstalledLayout then
    FContestDataDir := IncludeTrailingPathDelimiter(
      TPath.Combine(FExecutableDir, 'ContestData'))
  else
    FContestDataDir := IncludeTrailingPathDelimiter(
      TPath.Combine(
        [FRepositoryRootDir, 'Src', 'Domain', 'Contests', 'Data']));
  FContestDataDir := IncludeTrailingPathDelimiter(FContestDataDir);
{$ELSE}
  TAppPaths.FContestDataDir := TAppPaths.FExecutableDir;
{$ENDIF}

  TAppPaths.FInitialized := True;
end;

class procedure TAppPaths.ResetForTesting;
begin
  TAppPaths.FInitialized := False;
end;

class function TAppPaths.IsInstalledLayout: Boolean;
begin
  Initialize;
  Result := FIsInstalledLayout;
end;

class function TAppPaths.ExecutableDir: string;
begin
  Initialize;
  Result := FExecutableDir;
end;

class function TAppPaths.RepositoryRootDir: string;
begin
  Initialize;
  Result := FRepositoryRootDir;
end;

class function TAppPaths.ContestDataDir: string;
begin
  Initialize;
  Result := FContestDataDir;
end;

class function TAppPaths.ContestDataFile(const FileName: string): string;
begin
  Result := TPath.Combine(ContestDataDir, FileName);
end;

class function TAppPaths.TestDataDir: string;
begin
  if FTestDataDir.IsEmpty then
    FTestDataDir := IncludeTrailingPathDelimiter(
      TPath.Combine([RepositoryRootDir,'Test', 'Data']));

  Result := FTestDataDir;
end;

class function TAppPaths.TestDataFile(const FileName: string): string;
begin
  Result := TPath.Combine(TestDataDir, FileName);
end;

class function TAppPaths.TempTestDir: string;
begin
  if FTempTestDir.IsEmpty then
    FTempTestDir := IncludeTrailingPathDelimiter(
      TPath.Combine([RepositoryRootDir, 'Test', 'Temp']));

  ForceDirectories(FTempTestDir);

  Result := FTempTestDir;
end;

{
  Returns a writable temporary test file path.

  If FileName is empty, a potentially unique temporary file path
  is contructed under TempTestDir, but the file is not created.
  Since regression tests are not threaded, name collisions are very unlikely.

  If FileName is supplied, the path is constructed under
  TempTestDir but the file is not created.
}
class function TAppPaths.TempTestFile(const FileName: string = ''): string;
begin
  if FileName.IsEmpty then
  begin
    repeat
      Result := TPath.Combine(
        TempTestDir,
        Format('tmp%.4x.tmp', [Random($10000)]));
    until not TFile.Exists(Result);
  end
  else
    Result := TPath.Combine(TempTestDir, FileName);
end;

class function TAppPaths.CreateTempTestFile(
  const Extension: string): string;
var
  Ext: string;
begin
  Ext := Extension;
  if (not Ext.IsEmpty) and (Ext[1] <> '.') then
    Ext := '.' + Ext;

  repeat
    Result := TPath.Combine(
      TempTestDir,
      ChangeFileExt(Format('tmp%.4x.tmp', [Random($10000)]), Ext));
  until not TFile.Exists(Result);

  TFile.WriteAllText(Result, '');
end;

end.
