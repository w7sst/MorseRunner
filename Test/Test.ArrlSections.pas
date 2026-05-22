unit Test.ArrlSections;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestArrlSections = class
  public

    [Test]
    procedure SectionToState_MapsMassachusettsSections;

    [Test]
    procedure SectionToState_MapsNewYorkSections;

    [Test]
    procedure SectionToState_MapsNewJerseySections;

    [Test]
    procedure SectionToState_MapsPennsylvaniaSections;

    [Test]
    procedure SectionToState_MapsFloridaSections;

    [Test]
    procedure SectionToState_MapsTexasSections;

    [Test]
    procedure SectionToState_MapsWashingtonSections;

    [Test]
    procedure SectionToState_MapsCaliforniaSections;

    [Test]
    procedure SectionToState_MapsMarylandDCSections;

    [Test]
    procedure SectionToState_MapsOntarioSections;

    [Test]
    procedure SectionToState_PreservesSimpleSections;

    [Test]
    procedure SectionToState_IsCaseInsensitive;

    [Test]
    procedure SectionToState_EmptySectionReturnsInput;

    [Test]
    procedure SectionToState_UnknownSectionReturnsInput;

    [Test]
    procedure SectionToState_NonMdc_IgnoresDistributionIndex;

    [Test]
    procedure SectionToState_Mdc_AlternatesStates;

    [Test]
    procedure SectionToState_CounterIncrementedOnlyForMdc;

    [Test]
    procedure SectionToState_Mdc_InitialDistribution;
  end;

implementation

uses
  ArrlSections;

procedure TTestArrlSections.SectionToState_MapsMassachusettsSections;
begin
  Assert.AreEqual('MA', SectionToState('EMA'));
  Assert.AreEqual('MA', SectionToState('WMA'));
end;

procedure TTestArrlSections.SectionToState_MapsNewYorkSections;
begin
  Assert.AreEqual('NY', SectionToState('ENY'));
  Assert.AreEqual('NY', SectionToState('NLI'));
  Assert.AreEqual('NY', SectionToState('NNY'));
  Assert.AreEqual('NY', SectionToState('WNY'));
end;

procedure TTestArrlSections.SectionToState_MapsNewJerseySections;
begin
  Assert.AreEqual('NJ', SectionToState('NNJ'));
  Assert.AreEqual('NJ', SectionToState('SNJ'));
end;

procedure TTestArrlSections.SectionToState_MapsPennsylvaniaSections;
begin
  Assert.AreEqual('PA', SectionToState('EPA'));
  Assert.AreEqual('PA', SectionToState('WPA'));
end;

procedure TTestArrlSections.SectionToState_MapsFloridaSections;
begin
  Assert.AreEqual('FL', SectionToState('NFL'));
  Assert.AreEqual('FL', SectionToState('SFL'));
  Assert.AreEqual('FL', SectionToState('WCF'));
end;

procedure TTestArrlSections.SectionToState_MapsTexasSections;
begin
  Assert.AreEqual('TX', SectionToState('STX'));
  Assert.AreEqual('TX', SectionToState('NTX'));
  Assert.AreEqual('TX', SectionToState('WTX'));
end;

procedure TTestArrlSections.SectionToState_MapsWashingtonSections;
begin
  Assert.AreEqual('WA', SectionToState('EWA'));
  Assert.AreEqual('WA', SectionToState('WWA'));
end;

procedure TTestArrlSections.SectionToState_MapsCaliforniaSections;
begin
  Assert.AreEqual('CA', SectionToState('EB'));
  Assert.AreEqual('CA', SectionToState('LAX'));
  Assert.AreEqual('CA', SectionToState('ORG'));
  Assert.AreEqual('CA', SectionToState('SB'));
  Assert.AreEqual('CA', SectionToState('SCV'));
  Assert.AreEqual('CA', SectionToState('SDG'));
  Assert.AreEqual('CA', SectionToState('SF'));
  Assert.AreEqual('CA', SectionToState('SJV'));
  Assert.AreEqual('CA', SectionToState('SV'));
end;

procedure TTestArrlSections.SectionToState_MapsMarylandDCSections;
var
  MdcCounter: Integer;
begin
  // Special MDC (Maryland/DC) processing alternates between MD & DC
  MdcCounter := 0;

  // Special MDC (Maryland/DC) processing alternates between MD & DC
  Assert.AreEqual('MD', SectionToState('MDC', MdcCounter));
  Assert.AreEqual('DC', SectionToState('MDC', MdcCounter));

  // Without distribution counter, 'MD' is returned
  Assert.AreEqual('MD', SectionToState('MDC'));
  Assert.AreEqual('MD', SectionToState('MDC'));
  Assert.AreEqual('MD', SectionToState('MDC'));

  Assert.AreEqual('MD', SectionToState('Mdc', MdcCounter));
  Assert.AreEqual('DC', SectionToState('Mdc', MdcCounter));
  Assert.AreEqual(4, MdcCounter);
end;

procedure TTestArrlSections.SectionToState_MapsOntarioSections;
begin
  Assert.AreEqual('ON', SectionToState('ONE'));
  Assert.AreEqual('ON', SectionToState('ONN'));
  Assert.AreEqual('ON', SectionToState('ONS'));
end;

procedure TTestArrlSections.SectionToState_PreservesSimpleSections;
begin
  Assert.AreEqual('AZ', SectionToState('AZ'));
  Assert.AreEqual('CO', SectionToState('CO'));
  Assert.AreEqual('QC', SectionToState('QC'));
end;

procedure TTestArrlSections.SectionToState_IsCaseInsensitive;
var
  MdcCounter: Integer;
begin
  MdcCounter := 0;
  Assert.AreEqual('TX', SectionToState('stx'));
  Assert.AreEqual('CA', SectionToState('scv'));
  Assert.AreEqual('ON', SectionToState('one'));
  Assert.AreEqual('MD', SectionToState('mdc'));
  Assert.AreEqual('MD', SectionToState('mdc', MdcCounter));
  Assert.AreEqual('DC', SectionToState('mdc', MdcCounter));
end;

procedure TTestArrlSections.SectionToState_EmptySectionReturnsInput;
begin
  Assert.AreEqual('', SectionToState(''));
end;

procedure TTestArrlSections.SectionToState_UnknownSectionReturnsInput;
begin
  Assert.AreEqual('XYZ', SectionToState('XYZ'));
end;

procedure TTestArrlSections.SectionToState_NonMdc_IgnoresDistributionIndex;
var
  Index: Integer;
begin
  Index := 42;

  Assert.AreEqual('MA', SectionToState('EMA', Index));
  Assert.AreEqual(42, Index);
end;

procedure TTestArrlSections.SectionToState_Mdc_AlternatesStates;
var
  Index: Integer;
begin
  Index := 0;

  Assert.AreEqual('MD', SectionToState('MDC', Index));
  Assert.AreEqual('DC', SectionToState('MDC', Index));
  Assert.AreEqual('MD', SectionToState('MDC', Index));
  Assert.AreEqual('DC', SectionToState('MDC', Index));
end;

procedure TTestArrlSections.SectionToState_CounterIncrementedOnlyForMdc;
var
  Index: Integer;
begin
  Index := 0;

  SectionToState('EMA', Index);
  Assert.AreEqual(0, Index);

  SectionToState('MDC', Index);
  Assert.AreEqual(1, Index);

  SectionToState('SCV', Index);
  Assert.AreEqual(1, Index);
end;

procedure TTestArrlSections.SectionToState_Mdc_InitialDistribution;
var
  Index: Integer;
begin
  Index := 0;
  Assert.AreEqual('MD', SectionToState('MDC', Index));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestArrlSections);

end.
