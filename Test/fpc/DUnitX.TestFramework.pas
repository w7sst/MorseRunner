//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// Minimal DUnitX-compatible test framework for FPC/Lazarus.
//
// The MorseRunner test suite is written against DUnitX, which discovers
// fixtures and test cases from custom attributes ([TestFixture], [Test],
// [TestCase], ...) via extended RTTI. FPC 3.2.x cannot even *parse* custom
// attributes, let alone reflect over them, so the attributes are instead read
// at build time by tools/gen-fpc-tests.py, which emits:
//
//   - attribute-stripped copies of the test units, and
//   - a GeneratedTests unit that registers each fixture together with a
//     type-safe invoker that calls the test methods directly.
//
// This unit supplies the pieces the test sources themselves reference --
// the Assert class and TDUnitX -- plus the runner that executes the
// generated registrations.
//
unit DUnitX.TestFramework;

{$MODE DELPHI}
{$H+}

interface

uses
  SysUtils, Classes;

type
  ETestFailure = class(Exception);

  TTestArgs = array of string;

  { Calls AMethod on AInstance with AArgs. Generated per fixture, because FPC
    cannot invoke a method by name with arbitrary parameters at runtime. }
  TTestInvoker = procedure(AInstance: TObject; const AMethod: string;
    const AArgs: TTestArgs);

  { Assert -- only the subset the MorseRunner suite actually uses. Failures
    raise ETestFailure, which the runner catches and reports. }
  Assert = class
  public
    class procedure AreEqual(const AExpected, AActual: string); overload;
    class procedure AreEqual(const AExpected, AActual: string;
      const AMessage: string); overload;
    class procedure AreEqual(const AExpected, AActual: integer); overload;
    class procedure AreEqual(const AExpected, AActual: integer;
      const AMessage: string); overload;
    class procedure IsTrue(const ACondition: boolean; const AMessage: string = '');
    class procedure IsFalse(const ACondition: boolean; const AMessage: string = '');
    class procedure IsEmpty(const AValue: string; const AMessage: string = '');
    class procedure Contains(const AValue, ASubstring: string;
      const AMessage: string = '');
    class procedure Fail(const AMessage: string = '');
    class procedure FailFmt(const AFormat: string; const AArgs: array of const);
  end;

  TDUnitX = class
  public
    { The test units call this from their initialization sections. The
      generated registration carries the authoritative fixture list, so this
      only records the class for a consistency check. }
    class procedure RegisterTestFixture(const AClass: TClass);
  end;

{ Registration API used by the generated unit. }
procedure BeginFixture(AClass: TClass; const AName: string;
  AInvoker: TTestInvoker; const ASetupFixture, ATearDownFixture,
  ASetup, ATearDown: string);
procedure AddTestCase(const AMethod, ACaseName: string; const AArgs: TTestArgs;
  AEnabled: boolean);

{ Runs every registered fixture. Returns the number of failed tests. }
function RunRegisteredTests: integer;

implementation

type
  TCaseInfo = class
    MethodName: string;
    CaseName: string;
    Args: TTestArgs;
    Enabled: boolean;
  end;

  TFixtureInfo = class
    FixtureClass: TClass;
    Name: string;
    Invoker: TTestInvoker;
    SetupFixture: string;
    TearDownFixture: string;
    Setup: string;
    TearDown: string;
    Cases: TList;
    constructor Create;
    destructor Destroy; override;
  end;

var
  Fixtures: TList = nil;
  SelfRegistered: TList = nil;

constructor TFixtureInfo.Create;
begin
  inherited Create;
  Cases := TList.Create;
end;

destructor TFixtureInfo.Destroy;
var
  I: integer;
begin
  for I := 0 to Cases.Count - 1 do
    TCaseInfo(Cases[I]).Free;
  Cases.Free;
  inherited Destroy;
end;

{ ---------------------------------------------------------------- Assert --- }

class procedure Assert.AreEqual(const AExpected, AActual: string);
begin
  AreEqual(AExpected, AActual, '');
end;

class procedure Assert.AreEqual(const AExpected, AActual: string;
  const AMessage: string);
begin
  if AExpected <> AActual then
    raise ETestFailure.CreateFmt('expected ''%s'' but got ''%s''%s',
      [AExpected, AActual, AMessage]);
end;

class procedure Assert.AreEqual(const AExpected, AActual: integer);
begin
  AreEqual(AExpected, AActual, '');
end;

class procedure Assert.AreEqual(const AExpected, AActual: integer;
  const AMessage: string);
begin
  if AExpected <> AActual then
    raise ETestFailure.CreateFmt('expected %d but got %d%s',
      [AExpected, AActual, AMessage]);
end;

class procedure Assert.IsTrue(const ACondition: boolean; const AMessage: string);
begin
  if not ACondition then
    if AMessage = '' then
      raise ETestFailure.Create('expected True but got False')
    else
      raise ETestFailure.Create(AMessage);
end;

class procedure Assert.IsFalse(const ACondition: boolean; const AMessage: string);
begin
  if ACondition then
    if AMessage = '' then
      raise ETestFailure.Create('expected False but got True')
    else
      raise ETestFailure.Create(AMessage);
end;

class procedure Assert.IsEmpty(const AValue: string; const AMessage: string);
begin
  if AValue <> '' then
    if AMessage = '' then
      raise ETestFailure.CreateFmt('expected empty but got ''%s''', [AValue])
    else
      raise ETestFailure.Create(AMessage);
end;

class procedure Assert.Contains(const AValue, ASubstring: string;
  const AMessage: string);
begin
  if Pos(ASubstring, AValue) = 0 then
    raise ETestFailure.CreateFmt('''%s'' does not contain ''%s''%s',
      [AValue, ASubstring, AMessage]);
end;

class procedure Assert.Fail(const AMessage: string);
begin
  if AMessage = '' then
    raise ETestFailure.Create('test failed')
  else
    raise ETestFailure.Create(AMessage);
end;

class procedure Assert.FailFmt(const AFormat: string; const AArgs: array of const);
begin
  raise ETestFailure.Create(Format(AFormat, AArgs));
end;

{ --------------------------------------------------------------- TDUnitX --- }

class procedure TDUnitX.RegisterTestFixture(const AClass: TClass);
begin
  if SelfRegistered = nil then
    SelfRegistered := TList.Create;
  SelfRegistered.Add(Pointer(AClass));
end;

{ ---------------------------------------------------------- Registration --- }

procedure BeginFixture(AClass: TClass; const AName: string;
  AInvoker: TTestInvoker; const ASetupFixture, ATearDownFixture,
  ASetup, ATearDown: string);
var
  F: TFixtureInfo;
begin
  if Fixtures = nil then
    Fixtures := TList.Create;
  F := TFixtureInfo.Create;
  F.FixtureClass := AClass;
  F.Name := AName;
  F.Invoker := AInvoker;
  F.SetupFixture := ASetupFixture;
  F.TearDownFixture := ATearDownFixture;
  F.Setup := ASetup;
  F.TearDown := ATearDown;
  Fixtures.Add(F);
end;

procedure AddTestCase(const AMethod, ACaseName: string; const AArgs: TTestArgs;
  AEnabled: boolean);
var
  C: TCaseInfo;
begin
  if (Fixtures = nil) or (Fixtures.Count = 0) then
    raise Exception.Create('AddTestCase called before BeginFixture');
  C := TCaseInfo.Create;
  C.MethodName := AMethod;
  C.CaseName := ACaseName;
  C.Args := AArgs;
  C.Enabled := AEnabled;
  TFixtureInfo(Fixtures[Fixtures.Count - 1]).Cases.Add(C);
end;

{ ---------------------------------------------------------------- Runner --- }

procedure InvokeNoArgs(F: TFixtureInfo; Inst: TObject; const AMethod: string);
var
  Empty: TTestArgs;
begin
  if AMethod = '' then
    Exit;
  SetLength(Empty, 0);
  F.Invoker(Inst, AMethod, Empty);
end;

function RunRegisteredTests: integer;
var
  I, J: integer;
  F: TFixtureInfo;
  C: TCaseInfo;
  Inst: TObject;
  Passed, Failed, Skipped: integer;
  Label_: string;
begin
  Passed := 0;
  Failed := 0;
  Skipped := 0;

  if Fixtures <> nil then
    for I := 0 to Fixtures.Count - 1 do
    begin
      F := TFixtureInfo(Fixtures[I]);
      WriteLn;
      WriteLn('== ', F.Name, ' ==');

      Inst := nil;
      try
        try
          Inst := F.FixtureClass.Create;
          InvokeNoArgs(F, Inst, F.SetupFixture);
        except
          on E: Exception do
          begin
            WriteLn('  FIXTURE SETUP FAILED: ', E.ClassName, ': ', E.Message);
            Inc(Failed);
            FreeAndNil(Inst);
            Continue;
          end;
        end;

        for J := 0 to F.Cases.Count - 1 do
        begin
          C := TCaseInfo(F.Cases[J]);
          if C.CaseName = '' then
            Label_ := C.MethodName
          else
            Label_ := C.MethodName + '.' + C.CaseName;

          if not C.Enabled then
          begin
            Inc(Skipped);
            Continue;
          end;

          try
            InvokeNoArgs(F, Inst, F.Setup);
            try
              F.Invoker(Inst, C.MethodName, C.Args);
              Inc(Passed);
            finally
              InvokeNoArgs(F, Inst, F.TearDown);
            end;
          except
            on E: Exception do
            begin
              Inc(Failed);
              WriteLn('  FAIL ', Label_, ': ', E.ClassName, ': ', E.Message);
            end;
          end;
        end;

        try
          InvokeNoArgs(F, Inst, F.TearDownFixture);
        except
          on E: Exception do
            WriteLn('  FIXTURE TEARDOWN FAILED: ', E.ClassName, ': ', E.Message);
        end;
      finally
        Inst.Free;
      end;
    end;

  WriteLn;
  WriteLn(Format('Passed: %d  Failed: %d  Skipped: %d', [Passed, Failed, Skipped]));
  Result := Failed;
end;

initialization

finalization
  if Fixtures <> nil then
  begin
    while Fixtures.Count > 0 do
    begin
      TFixtureInfo(Fixtures[0]).Free;
      Fixtures.Delete(0);
    end;
    FreeAndNil(Fixtures);
  end;
  FreeAndNil(SelfRegistered);

end.
