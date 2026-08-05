//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// FPC/Lazarus console runner for the MorseRunner unit tests -- the counterpart
// to the Delphi Test/UnitTests.dpr.
//
// The test units under gen/ are generated from Test/*.pas by
// tools/gen-fpc-tests.py (run it before building; see Test/fpc/README.md).
// Exit code is 0 when every test passes, 1 otherwise.
//
program UnitTests;

{$MODE DELPHI}
{$H+}

uses
  SysUtils,
  DUnitX.TestFramework in 'DUnitX.TestFramework.pas',
  pcre in '../../PerlRegEx/pcre.pas',
  PerlRegEx in '../../PerlRegEx/PerlRegEx.pas',
  Lexer in '../../Util/Lexer.pas',
  SSExchParser in '../../Util/SSExchParser.pas',
  ExchFields in '../../ExchFields.pas',
  ArrlSections in '../../Util/ArrlSections.pas',
  CallsignUtils in '../../Util/CallsignUtils.pas',
  DXCC in '../../DXCC.pas',
  CallsignUtilsTest in 'gen/CallsignUtilsTest.pas',
  LexerTest in 'gen/LexerTest.pas',
  SSLexerTest in 'gen/SSLexerTest.pas',
  MySSExchTest in 'gen/MySSExchTest.pas',
  SSExchParserTest in 'gen/SSExchParserTest.pas',
  DxccListTest in 'gen/DxccListTest.pas',
  DxOperTest in 'gen/DxOperTest.pas',
  GeneratedTests in 'gen/GeneratedTests.pas';

var
  Failures: integer;
begin
  try
    RegisterAllTests;
    Failures := RunRegisteredTests;
    if Failures > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
