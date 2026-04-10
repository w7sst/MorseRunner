unit DxccListTest;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TestDxccList = class
  var
{$ifdef DEBUG}
    DbgBreak: boolean;
{$endif}

  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

  public
    // --- ExtractCallsign Tests ---
    [Test(True)]
    [Category('Dxcc Lookup')]
    [TestCase('Simple US',            'K1ABC,United States of America')]
    [TestCase('Simple EU',            'DL2XYZ,Fed. Rep. of Germany')]

    // International portable format (prefix on left-hand side)
    [TestCase('Portable France',      'F6/W7SST,France')]  // French prefix for U.S. operator
    [TestCase('Portable Germany',     'DL/AA1ZZ,Fed. Rep. of Germany')]  // German prefix for U.S. operator
    [TestCase('Portable Austria',     'OE/F1ABC,Austria')]  // Austrian prefix for French operator
    [TestCase('Portable /P',          'F6/W7SST/P,France')] // '/P' suffix (should be ignored)
    [TestCase('Portable Netherlands', 'PA0/AA1ZZ,Netherlands')]  // Netherlands prefix for U.S. operator

    // --- More simple cases ---
    [TestCase('W7SST',              'W7SST,United States of America')]
    [TestCase('W7SST/7',            'W7SST/7,United States of America')]
    [TestCase('W7SST/6',            'W7SST/6,United States of America')]
    [TestCase('N7SST/6',            'N7SST/6,United States of America')]
    [TestCase('F/W7SST',            'F/W7SST,France')]
    [TestCase('F6/W7SST',           'F6/W7SST,France')]
    [TestCase('W7SST/W/QRP',        'W7SST/W/QRP,United States of America')]
    [TestCase('F6FVY/W7/MM',        'F6FVY/W7/MM,United States of America')]

    // International portable calls from all CallHistory files
    [TestCase('DL/HA5VJ',           'DL/HA5VJ,Fed. Rep. of Germany')]
    [TestCase('DL/KU1CW',           'DL/KU1CW,Fed. Rep. of Germany')]
    [TestCase('ER/UT1ZZ',           'ER/UT1ZZ,Moldova')]
    [TestCase('FJ/W2RE',            'FJ/W2RE,Saint Barthelemy')]
    [TestCase('IZ/9A5K',            'IZ/9A5K,Italy')]
    [TestCase('OH/M0CFW',           'OH/M0CFW,Finland')]
    [TestCase('OH0/M0CFW',          'OH0/M0CFW,Aland Is.')]
    [TestCase('EW/R3XA',            'EW/R3XA,Belarus')]
    [TestCase('FJ/K2LIO',           'FJ/K2LIO,Saint Barthelemy')]
    [TestCase('LX/ON4EI',           'LX/ON4EI,Luxembourg')]
    [TestCase('ON/PD5S',            'ON/PD5S,Belgium')]
    [TestCase('ON/S58J',            'ON/S58J,Belgium')]
    [TestCase('FG/OK6RA',           'FG/OK6RA,Guadeloupe')]
    [TestCase('FS/K0CD',            'FS/K0CD,Saint Martin')]
    [TestCase('TF/OU2I',            'TF/OU2I,Iceland')]
    [TestCase('DL/YL3GX',           'DL/YL3GX,Fed. Rep. of Germany')]
    [TestCase('F/DJ4MZ',            'F/DJ4MZ,France')]
    [TestCase('LX/ON9TT',           'LX/ON9TT,Luxembourg')]
    [TestCase('TK/IK1BPL',          'TK/IK1BPL,Corsica')]
    [TestCase('YL/DL3GX',           'YL/DL3GX,Latvia')]
    [TestCase('EI/N6SN',            'EI/N6SN,Ireland')]
    [TestCase('F/OZ1CGQ',           'F/OZ1CGQ,France')]
    [TestCase('FS/G4HSO',           'FS/G4HSO,Saint Martin')]

    // --- Other test cases suggested by ChatGPT ---
    [TestCase('Monaco Callsign',          '3A/F1ABC,Monaco')]     // Monaco prefix
    [TestCase('Contest Callsign',         'I2/AA1ZZ/MM,Italy')]   // Italian contest operation with MM suffix
    [TestCase('Rare Prefixes (Andorra)',  'C3/F1ABC,Andorra')]    // Andorra prefix

    // --- Some test cases suggest by Google AI ---
    [TestCase('JA1ABC',             'JA1ABC,Japan')]
    [TestCase('VK9ND',              'VK9ND,Norfolk I.')]
    [TestCase('AX9NX',              'AX9NX,Norfolk I.')]
    [TestCase('VK9X',               'VK9X,Christmas I.')]
    [TestCase('KH6IAA',             'KH6IAA,Hawaii')]
    [TestCase('CE0Z',               'CE0Z,Juan Fernandez Is.')]
    [TestCase('CE1ABC',             'CE1ABC,Chile')]
    [TestCase('VP6D',               'VP6D,Ducie I.')]
    [TestCase('VP6R',               'VP6R,Pitcairn I.')]
    [TestCase('3C0DX',              '3C0DX,Annobon I.')]
    [TestCase('3C1DX',              '3C1DX,Equatorial Guinea')]
    [TestCase('3D2HQ',              '3D2HQ,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Mainland Fiji Standard.1',     '3D2AG,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Mainland Fiji Standard.2',     '3D2BT,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Mainland Fiji Standard.3',     '3D2USU,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Specific Rotuma Sub-Entity',   '3D2R,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Specific Conway Reef Sub-Entity (with /)', '3D2X/C,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('Specific Conway Reef Sub-Entity (w/o /)', '3D2CR,Fiji/Conway Reef/Rotuma I.')]
    [TestCase('4X4AAA',             '4X4AAA,Israel')]
    [TestCase('VP9AAA',             'VP9AAA,Bermuda')]
    [TestCase('C6AAA',              'C6AAA,Bahamas')]
    [TestCase('KG4KG',              'KG4KG,Guantanamo Bay')]
    [TestCase('KP4ABC',             'KP4ABC,Puerto Rico')]
    [TestCase('EI9XYZ',             'EI9XYZ,Ireland')]
    [TestCase('OZ1ABC',             'OZ1ABC,Denmark')]
    [TestCase('I1AAA',              'I1AAA,Italy')]

    [TestCase('CT3ABC',             'CT3ABC,Madeira Is.')]
    [TestCase('SV5ABC',             'SV5ABC,Dodecanese')]
    [TestCase('J49N',               'J49N,Crete')]
    [TestCase('OH0A',               'OH0A,Aland Is.')]
    [TestCase('JW7ABC',             'JW7ABC,Svalbard')]
    [TestCase('JX7ABC',             'JX7ABC,Jan Mayen')]

    // --- South America (SA) ---
    [TestCase('VP8AB',              'VP8AB,Falkland Is.')]
    [TestCase('VP0SS',              'VP0SS,South Shetland Is.')]
    [TestCase('HF0SS',              'HF0SS,South Shetland Is.')]
    [TestCase('4K1SS',              '4K1SS,South Shetland Is.')]

    // --- Asia (AS) ---
    [TestCase('VU2ABC',             'VU2ABC,India')]
    [TestCase('BY1ABC',             'BY1ABC,China')]
    [TestCase('A9AB',               'A9AB,Bahrain')]
    [TestCase('BS7H',               'BS7H;Scarborough Reef, China', ';')]
    [TestCase('JY3CW',              'JY3CW,Jordan')]
    [TestCase('EK2DX',              'EK2DX,Armenia')]
    [TestCase('3W0X',               '3W0X,Viet Nam')]
    [TestCase('XV0X',               'XV0X,Viet Nam')]
    [TestCase('AP1C',               'AP1C,Pakistan')]
    [TestCase('AS8FKD',             'AS8FKD,Pakistan')]

    // --- Africa (AF) ---
    [TestCase('CN8CN',              'CN8CN,Morocco')]
    [TestCase('ZS6ZS',              'ZS6ZS,South Africa')]

    // --- Oceania (OC) ---
    [TestCase('VP6PI',              'VP6PI,Pitcairn I.')]
    [TestCase('VP6DCN',             'VP6DCN,Ducie I.')]
    [TestCase('DU6PH',              'DU6PH,Philippines')]
    [TestCase('4I4PH',              '4I4PH,Philippines')]
    [TestCase('ZK1NZ',              'ZK1NZ,New Zealand')]
    [TestCase('ZL50AB',             'ZL50AB,New Zealand')]
    [TestCase('ZK3TI',              'ZK3TI,Tokelau Is.')]

    // Multiple slashes (rare but legal)
    [TestCase('TriplePortable',       'I2/AA1ZZ/MM,Italy')]

    // --- DXCC Lookup edge cases ---
    [TestCase('Empty Callsign',       ',')]         // No callsign provided, should return empty
    [TestCase('No Valid Prefix',      '123ABC,')]   // Invalid callsign format
    [TestCase('Invalid Characters',   '@#CALL,')]   // Callsign contains invalid characters
    [TestCase('Incomplete Portable',  'F6/,France')]    // Incomplete callsign, however prefix is specified
    [TestCase('Lowercase',            'sp4xyz,sp4')]
    //[TestCase('NoPrefix',             '1ABC,')]       // no valid call nor prefix here; 1AA-1ZZ are not allocated, unofficial, disputed
    //[TestCase('Invalid_NoDigit',      'ABCDE,')]
    //[TestCase('Invalid_NoCall',       'NoCallHere,')]
    [TestCase('Invalid_WeirdInput',   '123ABC,')]

    // --- DXCC Lookup edge cases ---
    [TestCase('Incomplete Portable',  'F6/,France')]          // Empty result because no valid callsign
    [TestCase('Multiple Slashes',     'F6/W7SST/MM,France')]  // Multiple portable suffixes, first prefix only
    [TestCase('Invalid Portable /W',  'F6/W7SST/W,France')]   // Invalid portable format; `/W` should be ignored

    procedure TestDxccLookup(const ACallsign, AExpectedEntity: string);

    // --- ExtractCallsign Tests ---
    [Test(True)]
    [Category('Dxcc Lookup 2')]
    [TestCase('Simple.1',   'K1ABC,   United States of America,   Simple US')]
    [TestCase('Simple.2',   'DL2XYZ,  Fed. Rep. of Germany,       Simple EU')]
    procedure TestDxccLookup2(const ACallsign, AExpectedEntity, ANote: string);
  end;

implementation

uses
  //TypInfo,          // for typeInfo
  PerlRegEx,
  DXCC,
  System.SysUtils;

procedure TestDxccList.SetupFixture;
begin
  // load DXCC support
  gDXCCList := TDXCC.Create;

{$ifdef DEBUG}
  DbgBreak := False;
{$endif}
end;


procedure TestDxccList.TearDownFixture;
begin
  gDXCCList.Free;
end;


procedure TestDxccList.TestDxccLookup(const ACallsign, AExpectedEntity: string);
var
  Callsign, ExpectedEntity: String;
  S: string;

  procedure RunAlgo(var S: String; const ACallsign, AExpectedEntity: String);
  var
    T: String;
    R: Boolean;
    dxcc: TDXCCRec;
  begin
    R := gDXCCList.FindRec(dxcc, ACallsign);
    if R and (dxcc.Entity <> AExpectedEntity) then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := gDXCCList.FindRec(dxcc, ACallsign);
    {$endif}
        T := format('    %s --> ''%s'', ''%s'' expected.', [Callsign, dxcc.Entity, AExpectedEntity]);
        S := S + #10 + T;
      end;
  end;
begin
  Callsign := ACallsign.Trim;
  ExpectedEntity := AExpectedEntity.Trim;

  RunAlgo(S, Callsign, ExpectedEntity);
  if S <> '' then Assert.Fail(S);
end;

// This is the original implementation of ExtractPrefix().
function ExtractPrefix0(Call: string): string;
var
    reg: TPerlRegEx;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= '-';
        reg.Subject := UTF8String(Call);
        reg.RegEx:= '(([0-9][A-Z])|([A-Z]{1,2}))[0-9]';
        if reg.Match then
            Result:= UTF8ToUnicodeString(reg.MatchedText);
    finally
        reg.Free;
    end;
end;

procedure TestDxccList.TestDxccLookup2(const ACallsign, AExpectedEntity, ANote: string);
var
  Callsign, ExpectedEntity: String;
  S: string;

  procedure RunAlgo(var S: String; const ACallsign, AExpectedEntity: String);
  var
    T: String;
    R: Boolean;
    dxcc: TDXCCRec;
  begin
    R := gDXCCList.FindRec(dxcc, ACallsign);
    if R and (dxcc.Entity <> AExpectedEntity) then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := gDXCCList.FindRec(dxcc, ACallsign);
    {$endif}
        T := format('    %s --> ''%s'', ''%s'' expected. %s.',
                    [Callsign, dxcc.Entity, AExpectedEntity, ANote.Trim]);
        S := S + #10 + T;
      end;
  end;
begin
  Callsign := ACallsign.Trim;
  ExpectedEntity := AExpectedEntity.Trim;

  RunAlgo(S, Callsign, ExpectedEntity);
  if S <> '' then Assert.Fail(S);
end;

initialization
  TDUnitX.RegisterTestFixture(TestDxccList);

end.
