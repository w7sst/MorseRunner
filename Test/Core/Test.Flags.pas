//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.Flags;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TFlags16Tests = class
  public

    [Test]
    procedure Constructor_Initializes_Value;

    [Test]
    procedure SetFlag_Sets_Bit;

    [Test]
    procedure ClearFlag_Clears_Bit;

    [Test]
    procedure ToggleFlag_Toggles_Bit;

    [Test]
    procedure TestFlag_Returns_True_When_Set;

    [Test]
    procedure TestFlag_Returns_False_When_Clear;

    [Test]
    procedure SetFlag_With_Boolean_True_Sets_Flag;

    [Test]
    procedure SetFlag_With_Boolean_False_Clears_Flag;

  end;

implementation

uses
  Flags;

const
  FLAG_A = $0001;
  FLAG_B = $0002;

{ TFlags16Tests }

procedure TFlags16Tests.Constructor_Initializes_Value;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create($1234);

  Assert.AreEqual(UInt16($1234), Flags.GetValue);
end;


procedure TFlags16Tests.SetFlag_Sets_Bit;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(0);

  Flags.SetFlag(FLAG_A);

  Assert.IsTrue(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.ClearFlag_Clears_Bit;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create($FFFF);

  Flags.ClearFlag(FLAG_A);

  Assert.IsFalse(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.ToggleFlag_Toggles_Bit;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(0);

  Flags.ToggleFlag(FLAG_A);
  Assert.IsTrue(Flags.TestFlag(FLAG_A));

  Flags.ToggleFlag(FLAG_A);
  Assert.IsFalse(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.TestFlag_Returns_True_When_Set;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(FLAG_A);

  Assert.IsTrue(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.TestFlag_Returns_False_When_Clear;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(0);

  Assert.IsFalse(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.SetFlag_With_Boolean_True_Sets_Flag;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(0);

  Flags.SetFlag(FLAG_A, True);

  Assert.IsTrue(Flags.TestFlag(FLAG_A));
end;


procedure TFlags16Tests.SetFlag_With_Boolean_False_Clears_Flag;
var
  Flags: TFlags16;
begin
  Flags := TFlags16.Create(FLAG_A);

  Flags.SetFlag(FLAG_A, False);

  Assert.IsFalse(Flags.TestFlag(FLAG_A));
end;

initialization
  TDUnitX.RegisterTestFixture(TFlags16Tests);

end.

