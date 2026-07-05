program UnitTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  pcre in '..\PerlRegEx\pcre.pas',
  PerlRegEx in '..\PerlRegEx\PerlRegEx.pas',
  Lexer in '..\Util\Lexer.pas',
  SSExchParser in '..\Util\SSExchParser.pas',
  ExchFields in '..\ExchFields.pas',
  ArrlSections in '..\Util\ArrlSections.pas',
  CallsignUtils in '..\Util\CallsignUtils.pas',
  DXCC in '..\DXCC.pas',
  CallsignUtilsTest in 'CallsignUtilsTest.pas',
  LexerTest in 'LexerTest.pas',
  SSLexerTest in 'SSLexerTest.pas',
  MySSExchTest in 'MySSExchTest.pas',
  SSExchParserTest in 'SSExchParserTest.pas',
  DxccListTest in 'DxccListTest.pas',
  AppPaths in '..\Src\Core\AppPaths.pas',
  Flags in '..\Src\Core\Flags.pas',
  Arrl10m.Policy in '..\Src\Domain\Contests\Arrl10m.Policy.pas',
  Arrl10m.Types in '..\Src\Domain\Contests\Arrl10m.Types.pas',
  ArrlDx.Types in '..\Src\Domain\Contests\ArrlDx.Types.pas',
  ContestFileFormat in '..\Src\Persistence\ContestFileFormat.pas',
  ContestFileReader in '..\Src\Persistence\ContestFileReader.pas',
  ArrlDx.Reader in '..\Src\Persistence\Contests\ArrlDx.Reader.pas',
  Test.ArrlSections in 'Test.ArrlSections.pas',
  Test.AppPaths in 'Core\Test.AppPaths.pas',
  Test.Flags in 'Core\Test.Flags.pas',
  Test.Arrl10m.Policy in 'Domain\Test.Arrl10m.Policy.pas',
  Test.ContestFileFormat in 'Persistence\Test.ContestFileFormat.pas',
  Test.ContestFileReader in 'Persistence\Test.ContestFileReader.pas',
  Test.ContestReader.Base in 'Persistence\Test.ContestReader.Base.pas',
  Test.ContestReader.Contracts in 'Persistence\Test.ContestReader.Contracts.pas',
  Test.ArrlDx.Reader in 'Persistence\Contests\Test.ArrlDx.Reader.pas',
  DxOperTest in 'DxOperTest.pas';

{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Keep console window open due to change in version 12.1 (added by w7sst)
    TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;

    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.
