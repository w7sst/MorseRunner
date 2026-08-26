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

    [Test]
    procedure SectionToState_RAC_BasicMapping;

    [Test]
    procedure SectionToState_RAC_SpecialCase;
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
  Assert.AreEqual('MD', SectionToState('MDC', '', MdcCounter));
  Assert.AreEqual('DC', SectionToState('MDC', 'K1ABC', MdcCounter));

  // Without distribution counter, 'MD' is returned
  Assert.AreEqual('MD', SectionToState('MDC'));
  Assert.AreEqual('MD', SectionToState('MDC'));
  Assert.AreEqual('MD', SectionToState('MDC'));

  Assert.AreEqual('MD', SectionToState('Mdc', 'W1AW', MdcCounter));
  Assert.AreEqual('DC', SectionToState('Mdc', 'W1/VY0ABC', MdcCounter));
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
  Assert.AreEqual('MD', SectionToState('mdc', '', MdcCounter));
  Assert.AreEqual('DC', SectionToState('mdc', '', MdcCounter));
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

  Assert.AreEqual('MA', SectionToState('EMA', '', Index));
  Assert.AreEqual(42, Index);
end;

procedure TTestArrlSections.SectionToState_Mdc_AlternatesStates;
var
  Index: Integer;
begin
  Index := 0;

  Assert.AreEqual('MD', SectionToState('MDC', '', Index));
  Assert.AreEqual('DC', SectionToState('MDC', '', Index));
  Assert.AreEqual('MD', SectionToState('MDC', '', Index));
  Assert.AreEqual('DC', SectionToState('MDC', '', Index));
end;

procedure TTestArrlSections.SectionToState_CounterIncrementedOnlyForMdc;
var
  Index: Integer;
begin
  Index := 0;

  SectionToState('EMA', '', Index);
  Assert.AreEqual(0, Index);

  SectionToState('MDC', '', Index);
  Assert.AreEqual(1, Index);

  SectionToState('SCV', '', Index);
  Assert.AreEqual(1, Index);
end;

procedure TTestArrlSections.SectionToState_Mdc_InitialDistribution;
var
  Index: Integer;
begin
  Index := 0;
  Assert.AreEqual('MD', SectionToState('MDC', '', Index));
end;

procedure TTestArrlSections.SectionToState_RAC_BasicMapping;
var
  Index: Integer;
begin
  Index := 0;

  Assert.AreEqual('AB', SectionToSTate('AB', '', Index));
  Assert.AreEqual('BC', SectionToSTate('BC', '', Index));
  Assert.AreEqual('ON', SectionToSTate('GH', '', Index));
  Assert.AreEqual('MB', SectionToSTate('MB', '', Index));
  Assert.AreEqual('NB', SectionToSTate('NB', '', Index));

  Assert.AreEqual('NS', SectionToSTate('NS',  '', Index));
  Assert.AreEqual('ON', SectionToSTate('ONE', '', Index));
  Assert.AreEqual('ON', SectionToSTate('ONN', '', Index));
  Assert.AreEqual('ON', SectionToSTate('ONS', '', Index));
  Assert.AreEqual('PE', SectionToSTate('PE', '', Index));
  Assert.AreEqual('QC', SectionToSTate('QC', '', Index));
  Assert.AreEqual('SK', SectionToSTate('SK', '', Index));

  Assert.AreEqual(0, Index);
end;

procedure TTestArrlSections.SectionToState_RAC_SpecialCase;
var
  Index: Integer;
begin
  Index := 0;

  // Special case: Newfoundland and Labrador (NL)
  Assert.AreEqual('NF', SectionToSTate('NL', 'VO1ABC', Index), 'NL x VO1 -> NF');
  Assert.AreEqual('LB', SectionToSTate('NL', 'VO2ABC', Index), 'NL x VO2 -> LB');
  Assert.AreEqual('NF', SectionToSTate('NL', 'VE8ABC', Index), 'NL x VE8 -> NF');   // default mapping
  Assert.AreEqual('NF', SectionToSTate('NL', 'VE7ABC', Index), 'NL x VE7 -> NF');   // default mapping

  // Special case: Territories (TER)
  Assert.AreEqual('NT', SectionToSTate('TER', 'VE8ABC', Index), 'TER x VE8 -> NT');
  Assert.AreEqual('NU', SectionToSTate('TER', 'VY0ABC', Index), 'TER x VY0 -> NU');
  Assert.AreEqual('YT', SectionToSTate('TER', 'VY1ABC', Index), 'TER x VY1 -> YT');
  Assert.AreEqual('NT', SectionToSTate('TER', 'VE7ABC', Index), 'TER x VE7 -> NT');   // default mapping

  Assert.AreEqual(0, Index);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestArrlSections);

end.
