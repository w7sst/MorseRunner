//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Test.Arrl10m.Policy;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  [Category('ARRL10M')]
  TArrl10mPolicyTests = class
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    // --- IsCallLocalToContest Tests ---
    [Test(True)]
    [TestCase('USA',     'K1ABC,True')]
    [TestCase('Canada',  'VE3XYZ,True')]
    [TestCase('Mexico',  'XE1AAA,True')]
    [TestCase('Alaska',  'KL7AAA,True')]
    [TestCase('Hawaii',  'KH6AAA,True')]
    [TestCase('Germany', 'DL1ABC,False')]
    [TestCase('Japan',   'JA1XYZ,False')]
    [TestCase('Unknown', 'ZZ9ZZZ,False')]
    procedure IsCallLocalToContest_ReturnsExpected(
      const Callsign: string;
      Expected: Boolean);

    [Test]
    procedure MaritimeMobileProbability_WithinRange;

  end;

implementation

uses
  System.SysUtils,
  Arrl10m.Policy,
  Dxcc;

{ TArrl10mPolicyTests }

procedure TArrl10mPolicyTests.SetupFixture;
begin
  // load DXCC support
  gDXCCList := TDXCC.Create;
end;


procedure TArrl10mPolicyTests.TearDownFixture;
begin
  gDXCCList.Free;
end;


procedure TArrl10mPolicyTests.IsCallLocalToContest_ReturnsExpected(
  const Callsign: string;
  Expected: Boolean);
begin
  Assert.AreEqual(
    Expected,
    TArrl10mPolicy.IsCallLocalToContest(Callsign));
end;

procedure TArrl10mPolicyTests.MaritimeMobileProbability_WithinRange;
begin
  Assert.IsTrue((TArrl10mPolicy.MaritimeMobileProbability >= 0) and
                (TArrl10mPolicy.MaritimeMobileProbability <= 1),
    format('TArrl10mPolicy.MaritimeMobileProbability=%f must be within interval [0.0,1.0]',
           [TArrl10mPolicy.MaritimeMobileProbability]));
end;


initialization
  TDUnitX.RegisterTestFixture(TArrl10mPolicyTests);

end.
