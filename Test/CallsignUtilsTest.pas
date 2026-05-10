unit CallsignUtilsTest;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TestCallsignUtils = class
  var
{$ifdef DEBUG}
    DbgBreak: boolean;
{$endif}

  public
    [SetupFixture]
    procedure SetupFixture;

  public
    // --- ExtractCallsign Tests ---
    [Test(True)]
    [Category('ExtractCallsign')]
    [TestCase('Simple US',            'K1ABC,K1ABC')]
    [TestCase('Simple EU',            'DL2XYZ,DL2XYZ')]
//    [TestCase('Embedded',             'Worked F4ABC on 20m!,F4ABC')]
//    [TestCase('Bracketed',            '[JA1XYZ] logged,JA1XYZ')]
    [TestCase('Invalid_NoDigit',      'ABCDE,')]
    [TestCase('Invalid_NoCall',       'NoCallHere,')]
    [TestCase('Invalid_WeirdInput',   '123ABC,')]
    // International portable format (prefix on left-hand side)
    [TestCase('Portable France',      'F6/W7SST,W7SST')]  // French prefix for U.S. operator
    [TestCase('Portable Germany',     'DL/AA1ZZ,AA1ZZ')]  // German prefix for U.S. operator
    [TestCase('Portable Austria',     'OE/F1ABC,F1ABC')]  // Austrian prefix for French operator
    [TestCase('Portable /P',          'F6/W7SST/P,W7SST')] // '/P' suffix (should be ignored)
    [TestCase('Portable Netherlands', 'PA0/AA1ZZ,AA1ZZ')]  // Netherlands prefix for U.S. operator
    // --- ExtractCallsign edge cases ---
    [TestCase('Empty Callsign',       ',')]         // No callsign provided, should return empty
    [TestCase('No Valid Prefix',      '123ABC,')]   // Invalid callsign format
    [TestCase('Invalid Characters',   '@#CALL,')]   // Callsign contains invalid characters
    [TestCase('Incomplete Portable',  'F6/,')]      // Invalid callsign without proper format
    procedure TestExtractCallsign(const AFullCall, AExpected: string);

    // --- ExtractPrefix Tests (w/ WPX Contest Rules) ---
    [Test(True)]
    [Category('ExtractPrefix-Wpx')]
    [TestCase('US Prefix',          'K1ABC,K1')]
    [TestCase('EU Prefix',          'DL2XYZ,DL2')]
    [TestCase('FR Prefix',          'F4ABC,F4')]
    [TestCase('Lowercase',          'sp4xyz,sp4')]
    //[TestCase('NoPrefix',           '1ABC,')]       // no valid call nor prefix here; 1AA-1ZZ are not allocated, unofficial, disputed
    [TestCase('Empty',              ',')]
    [TestCase('W7SST',              'W7SST,W7')]
    [TestCase('W7SST/7',            'W7SST/7,W7')]
    [TestCase('W7SST/6',            'W7SST/6,W6')]
    [TestCase('N7SST/6',            'N7SST/6,N6')]
    [TestCase('F/W7SST',            'F/W7SST,F0')]
    [TestCase('F6/W7SST',           'F6/W7SST,F6')]
    [TestCase('W7SST/W',            'W7SST/W,W0')]
    [TestCase('F6FVY/W7',           'F6FVY/W7,W7')]
    [TestCase('F6/AB7Q',            'F6/AB7Q,F6')]
    [TestCase('F6/W7SST/P',         'F6/W7SST,F6')]
    [TestCase('W7SST/W/QRP',        'W7SST/W/QRP,W0')]
    [TestCase('F6FVY/W7/MM',        'F6FVY/W7/MM,W7')]
    // Prefix from portable operation
    [TestCase('Portable France',    'F6/W7SST,F6')]       // French prefix for U.S. operator
    [TestCase('Portable Germany',   'DL/AA1ZZ,DL0')]       // German prefix for U.S. operator
    [TestCase('Portable Austria',   'OE/F1ABC,OE0')]       // Austrian prefix for French operator
    [TestCase('Portable /P',        'F6/W7SST/P,F6')]     // '/P' suffix (should be allowed)
    [TestCase('Portable Netherlands', 'PA0/AA1ZZ,PA0')]   // Netherlands prefix for U.S. operator
    // International portable calls from all CallHistory files
    [TestCase('DL/HA5VJ',           'DL/HA5VJ,DL0')]
    [TestCase('DL/KU1CW',           'DL/KU1CW,DL0')]
    [TestCase('ER/UT1ZZ',           'ER/UT1ZZ,ER0')]
    [TestCase('FJ/W2RE',            'FJ/W2RE,FJ0')]
    [TestCase('IZ/9A5K',            'IZ/9A5K,IZ0')]
    [TestCase('OH/M0CFW',           'OH/M0CFW,OH0')]
    [TestCase('EW/R3XA',            'EW/R3XA,EW0')]
    [TestCase('FJ/K2LIO',           'FJ/K2LIO,FJ0')]
    [TestCase('LX/ON4EI',           'LX/ON4EI,LX0')]
    [TestCase('ON/PD5S',            'ON/PD5S,ON0')]
    [TestCase('ON/S58J',            'ON/S58J,ON0')]
    [TestCase('FG/OK6RA',           'FG/OK6RA,FG0')]
    [TestCase('FS/K0CD',            'FS/K0CD,FS0')]
    [TestCase('TF/OU2I',            'TF/OU2I,TF0')]
    [TestCase('DL/YL3GX',           'DL/YL3GX,DL0')]
    [TestCase('F/DJ4MZ',            'F/DJ4MZ,F0')]
    [TestCase('LX/ON9TT',           'LX/ON9TT,LX0')]
    [TestCase('TK/IK1BPL',          'TK/IK1BPL,TK0')]
    [TestCase('YL/DL3GX',           'YL/DL3GX,YL0')]
    [TestCase('EI/N6SN',            'EI/N6SN,EI0')]
    [TestCase('F/OZ1CGQ',           'F/OZ1CGQ,F0')]
    [TestCase('FS/G4HSO',           'FS/G4HSO,FS0')]

    // --- Other test cases suggested by ChatGPT ---
    [TestCase('Monaco Callsign',          '3A/F1ABC,3A0')]     // Monaco prefix
    [TestCase('Contest Callsign',         'I2/AA1ZZ/MM,I2')]  // Italian contest operation with MM suffix
    [TestCase('Rare Prefixes (Andorra)',  'C3/F1ABC,C3')]     // Andorra prefix

    [TestCase('CT3ABC',               'CT3ABC,CT3')]
    [TestCase('SV5ABC',               'SV5ABC,SV5')]
    [TestCase('J49N',                 'J49N,J49')]
    [TestCase('OH0A',                 'OH0A,OH0')]
    [TestCase('JW7ABC',               'JW7ABC,JW7')]
    [TestCase('JX7ABC',               'JX7ABC,JX7')]
    // --- Asia (AS) ---
    [TestCase('VU2ABC',               'VU2ABC,VU2')]
    [TestCase('BY1ABC',               'BY1ABC,BY1')]
    [TestCase('A9AB',                 'A9AB,A9')]
    [TestCase('BS7H',                 'BS7H,BS7')]
    [TestCase('JY3CW',                'JY3CW,JY3')]
    [TestCase('EK2DX',                'EK2DX,EK2')]
    // --- Africa (AF) ---
    [TestCase('CN8CN',                'CN8CN,CN8')]
    [TestCase('ZS6ZS',                'ZS6ZS,ZS6')]

    // Multiple slashes (rare but legal)
    [TestCase('TriplePortable',       'I2/AA1ZZ/MM,I2')]

    // --- ExtractPrefix edge cases ---
    [TestCase('Incomplete Portable',  'F6/,F6')]          // Empty result because no valid callsign
    [TestCase('Multiple Slashes',     'F6/W7SST/MM,F6')]  // Multiple portable suffixes, first prefix only
    [TestCase('Invalid Portable /W',  'F6/W7SST/W,F6')]   // Invalid portable format; `/W` should be ignored
    procedure TestExtractPrefixWpx(const ACallsign, AExpected: string);

    // --- ExtractPrefix Tests (w/ DXCC Rules) ---
    [Test(True)]
    [Category('ExtractPrefixDxcc')]
    [TestCase('US Prefix',          'K1ABC,K1ABC')]
    [TestCase('EU Prefix',          'DL2XYZ,DL2XYZ')]
    [TestCase('FR Prefix',          'F4ABC,F4ABC')]
    [TestCase('Lowercase',          'sp4xyz,sp4xyz')]
    //[TestCase('NoPrefix',           '1ABC,')]       // no valid call nor prefix here; 1AA-1ZZ are not allocated, unofficial, disputed
    [TestCase('Empty',              ',')]
    [TestCase('W7SST',              'W7SST,W7SST')]
    [TestCase('W7SST/7',            'W7SST/7,W7SST')]
    [TestCase('W7SST/6',            'W7SST/6,W7SST')] // not sure about this one; W6SST?
    [TestCase('F/W7SST',            'F/W7SST,F')]
    [TestCase('F6/W7SST',           'F6/W7SST,F6')]
    //[TestCase('W7SST/W',            'W7SST/W,W7SST')] // not a valid call
    [TestCase('F6FVY/W7',           'F6FVY/W7,W7')]
    [TestCase('F6/AB7Q',            'F6/AB7Q,F6')]
    [TestCase('F6/W7SST/P',         'F6/W7SST,F6')]
    [TestCase('W7SST/W/QRP',        'W7SST/W/QRP,W')]
    [TestCase('F6FVY/W7/MM',        'F6FVY/W7/MM,W7')]
    // Prefix from portable operation
    [TestCase('Portable France',    'F6/W7SST,F6')]       // French prefix for U.S. operator
    [TestCase('Portable Germany',   'DL/AA1ZZ,DL')]       // German prefix for U.S. operator
    [TestCase('Portable Austria',   'OE/F1ABC,OE')]       // Austrian prefix for French operator
    [TestCase('Portable /P',        'F6/W7SST/P,F6')]     // '/P' suffix (should be allowed)
    [TestCase('Portable Netherlands', 'PA0/AA1ZZ,PA0')]   // Netherlands prefix for U.S. operator
    // International portable calls from all CallHistory files
    [TestCase('DL/HA5VJ',           'DL/HA5VJ,DL')]
    [TestCase('DL/KU1CW',           'DL/KU1CW,DL')]
    [TestCase('ER/UT1ZZ',           'ER/UT1ZZ,ER')]
    [TestCase('FJ/W2RE',            'FJ/W2RE,FJ')]
    [TestCase('IZ/9A5K',            'IZ/9A5K,IZ')]
    [TestCase('OH/M0CFW',           'OH/M0CFW,OH')]
    [TestCase('EW/R3XA',            'EW/R3XA,EW')]
    [TestCase('FJ/K2LIO',           'FJ/K2LIO,FJ')]
    [TestCase('LX/ON4EI',           'LX/ON4EI,LX')]
    [TestCase('ON/PD5S',            'ON/PD5S,ON')]
    [TestCase('ON/S58J',            'ON/S58J,ON')]
    [TestCase('FG/OK6RA',           'FG/OK6RA,FG')]
    [TestCase('FS/K0CD',            'FS/K0CD,FS')]
    [TestCase('TF/OU2I',            'TF/OU2I,TF')]
    [TestCase('DL/YL3GX',           'DL/YL3GX,DL')]
    [TestCase('F/DJ4MZ',            'F/DJ4MZ,F')]
    [TestCase('LX/ON9TT',           'LX/ON9TT,LX')]
    [TestCase('TK/IK1BPL',          'TK/IK1BPL,TK')]
    [TestCase('YL/DL3GX',           'YL/DL3GX,YL')]
    [TestCase('EI/N6SN',            'EI/N6SN,EI')]
    [TestCase('F/OZ1CGQ',           'F/OZ1CGQ,F')]
    [TestCase('FS/G4HSO',           'FS/G4HSO,FS')]

    [TestCase('CT3ABC',               'CT3ABC,CT3ABC')]
    [TestCase('SV5ABC',               'SV5ABC,SV5ABC')]
    [TestCase('J49N',                 'J49N,J49N')]
    [TestCase('OH0A',                 'OH0A,OH0A')]
    [TestCase('JW7ABC',               'JW7ABC,JW7ABC')]
    [TestCase('JX7ABC',               'JX7ABC,JX7ABC')]
    // --- Asia (AS) ---
    [TestCase('VU2ABC',               'VU2ABC,VU2ABC')]
    [TestCase('BY1ABC',               'BY1ABC,BY1ABC')]
    [TestCase('A9AB',                 'A9AB,A9AB')]
    [TestCase('BS7H',                 'BS7H,BS7H')]
    [TestCase('JY3CW',                'JY3CW,JY3CW')]
    [TestCase('EK2DX',                'EK2DX,EK2DX')]
    // --- Africa (AF) ---
    [TestCase('CN8CN',                'CN8CN,CN8CN')]
    [TestCase('ZS6ZS',                'ZS6ZS,ZS6ZS')]

    // --- Other test cases suggested by ChatGPT ---
    [TestCase('Monaco Callsign',          '3A/F1ABC,3A')]     // Monaco prefix
    [TestCase('Contest Callsign',         'I2/AA1ZZ/MM,I2')]  // Italian contest operation with MM suffix
    [TestCase('Rare Prefixes (Andorra)',  'C3/F1ABC,C3')]     // Andorra prefix

    // Multiple slashes (rare but legal)
    [TestCase('TriplePortable',     'I2/AA1ZZ/MM,I2')]

    // --- ExtractPrefix edge cases ---
    [TestCase('Incomplete Portable',  'F6/,F6')]          // Empty result because no valid callsign
    [TestCase('Multiple Slashes',     'F6/W7SST/MM,F6')]  // Multiple portable suffixes, first prefix only
    [TestCase('Invalid Portable /W',  'F6/W7SST/W,F6')]   // Invalid portable format; `/W` should be ignored
    procedure TestExtractPrefixDxcc(const ACallsign, AExpected: string);

    // --- Original ExtractPrefix Tests ---
    [Test(True)]
    [Category('ExtractPrefix0')]
    //[TestCase('Empty',            ',')]
    [TestCase('W7SST',            'W7SST,W7')]
    [TestCase('W7SST/6',          'W7SST/6,W7')]  // should be 'W6'
    [TestCase('N7SST/6',          'N7SST/6,N7')]  // should be 'N6'
    [TestCase('F6/W7SST',         'F6/W7SST,F6')]
    [TestCase('F6/AB7Q',          'F6/AB7Q,F6')]
    [TestCase('W7SST/W',          'W7SST/W,W7')]  // should be 'W0'
    [TestCase('F6FVY/W7',         'F6FVY/W7,F6')] // should be 'W7'
    procedure TestExtractPrefix0(const AFullCall, AExpected: String);
  end;

implementation

uses
  //TypInfo,          // for typeInfo
  PerlRegEx,
  CallsignUtils,
  System.SysUtils;

procedure TestCallsignUtils.SetupFixture;
begin
{$ifdef DEBUG}
  DbgBreak := False;
{$endif}
end;

procedure TestCallsignUtils.TestExtractCallsign(const AFullCall, AExpected: string);
var
  FullCall, Expected: String;
  S: string;

  procedure RunAlgo(var S: String; const AFullcall, AExpected: String);
  var
    R, T: String;
  begin
    R := ExtractCallsign(AFullcall);
    if R <> AExpected then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := ExtractCallsign(AFullcall);
    {$endif}
        T := format('    %s --> ''%s'', ''%s'' expected.', [Fullcall, R, Expected]);
        S := S + #10 + T;
      end;
  end;
begin
  FullCall := AFullCall.Trim;
  Expected := AExpected.Trim;

  RunAlgo(S, FullCall, Expected);
  if S <> '' then Assert.Fail(S);
end;

procedure TestCallsignUtils.TestExtractPrefixWpx(const ACallsign, AExpected: string);
var
  Callsign, Expected: String;
  S: string;

  procedure RunAlgo(var S: String; const ACallsign, AExpected: String);
  var
    R, T: String;
  begin
    R := ExtractPrefix(ACallsign, {DeleteTrailingLetters=}True);
    if R <> AExpected then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := ExtractPrefix(ACallsign, {DeleteTrailingLetters=}True);
    {$endif}
        T := format('    %s --> ''%s'', ''%s'' expected.', [Callsign, R, Expected]);
        S := S + #10 + T;
      end;
  end;
begin
  Callsign := ACallsign.Trim;
  Expected := AExpected.Trim;

  RunAlgo(S, Callsign, Expected);
  if S <> '' then Assert.Fail(S);
end;

procedure TestCallsignUtils.TestExtractPrefixDxcc(const ACallsign, AExpected: string);
var
  Callsign, Expected: String;
  S: string;

  procedure RunAlgo(var S: String; const ACallsign, AExpected: String);
  var
    R, T: String;
  begin
    R := ExtractPrefix(ACallsign, {DeleteTrailingLetters=}False);
    if R <> AExpected then
      begin
    {$ifdef DEBUG}
        DbgBreak := True;
        //R := ExtractPrefix(ACallsign, {DeleteTrailingLetters=}False);
    {$endif}
        T := format('    %s --> ''%s'', ''%s'' expected.', [Callsign, R, Expected]);
        S := S + #10 + T;
      end;
  end;
begin
  Callsign := ACallsign.Trim;
  Expected := AExpected.Trim;

  RunAlgo(S, Callsign, Expected);
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

procedure TestCallsignUtils.TestExtractPrefix0(const AFullCall, AExpected: String);
begin
  Assert.AreEqual(ExtractPrefix0(AFullCall.Trim), AExpected.Trim);
end;

initialization
  TDUnitX.RegisterTestFixture(TestCallsignUtils);

end.
