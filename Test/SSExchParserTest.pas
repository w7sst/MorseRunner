unit SSExchParserTest;

interface

uses
  SSExchParser,
  ExchFields,
  DUnitX.TestFramework;

type
  [TestFixture]
  TestTSSExchParser = class
  var
    parser : TSSExchParser;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test(True)]
    [Category('Simple')]

    [TestCase('Simple.1',   '1,           1...-Missing/Invalid Precedence')]
    [TestCase('Simple.2',   '12,          0..12.-Missing/Invalid Serial Number')]
    [TestCase('Simple.3',   '123,         123...-Missing/Invalid Precedence')]
    [TestCase('Simple.4',   '1234,        1234...-Missing/Invalid Precedence')]
    [TestCase('Simple.5',   '11 22,       11..22.')]    // rotate to NR
    [TestCase('Simple.6',   '11 22 33,    22..33.')]    // rotate to NR
    [TestCase('Simple.7',   '11 22 33 44, 33..44.')]    // rotate to NR
    [TestCase('Simple.8',   '1,           1...-Missing/Invalid Precedence')]
    [TestCase('Simple.9',   '1 2,         2...')]
    [TestCase('Simple.10',  '1 2 3,       3...')]
    [TestCase('Simple.11',  '1 2 3 4,     4...')]

    [TestCase('Zero.1',     '0 01,        0..01.')]
    [TestCase('Zero.2',     '01 0,        1..00.')]
    [TestCase('Zero.3',     '0 01 02,     1..02.')]
    [TestCase('Zero.4',     '01 0 02,     0..02.')]
    [TestCase('Zero.5',     '01 02 0,     2..00.')]
    [TestCase('Zero.6',     '0 01 02 03,  2..03.')]
    [TestCase('Zero.7',     '01 0 02 03,  2..03.')]
    [TestCase('Zero.8',     '01 02 0 03,  0..03.')]
    [TestCase('Zero.9',     '01 02 03 0,  3..00.')]

    [TestCase('Limit.1',    '9999 A 72 OR,  9999.A.72.OR')]
    [TestCase('Limit.2',    '10000 A 72 OR,  10000.A.72.OR')]
    [TestCase('Limit.3',    '10001 A 72 OR,  10000.A.72.OR')]
    [TestCase('Limit.4',    '99999 A 72 OR,  10000.A.72.OR')]
    [TestCase('Limit.5',    '999999 A 72 OR, 10000.A.72.OR')]

    [Category('Prec')]
    [TestCase('Prec.1',   '1 A,        1.A..')]
    [TestCase('Prec.2',   '12 A,       12.A..')]
    [TestCase('Prec.3',   '123 A,      123.A..')]
    [TestCase('Prec.4',   '1234 A,     1234.A..')]
    [TestCase('Prec.5',   '1 X,        1...')]
    [TestCase('Prec.6',   '12 X,       12...')]
    [TestCase('Prec.7',   '123 X,      123...')]
    [TestCase('Prec.8',   '1234 X,     1234...')]
    [TestCase('Prec.9',   '1 A 123 B,  123.B..')]
    [TestCase('Prec.10',  '1 A 123 B M,123.M..')]
    [TestCase('Prec.11',  '1 A B,      1.B..')]
    [TestCase('Prec.12',  '1 A B U M S,1.S..')]

    [Category('Sect')]
    [TestCase('Sect.1',   '12 OR,                 0..12.OR')]   // check reset
    [TestCase('Sect.2',   '12 34 OR,              12..34.OR')]  // rotate to NR
    [TestCase('Sect.3',   '12 34 OR 56,           12..56.OR')]  // check resets
    [TestCase('Sect.4',   '12 34 OR 56 78,        56..78.OR')]  // rotate to NR
    [TestCase('Sect.5',   '12 OR 34,              0..34.OR')]
    [TestCase('Sect.6',   '12 OR 34 56,           34..56.OR')]  // rotate to NR
    [TestCase('Sect.7',   '1 2 3 ID 4,            4..03.ID')]
    [TestCase('Sect.7a',  '1 2 3 ID 4 OR,         2..04.OR')]
    [TestCase('Sect.7b',  '1 2 3 ID 4 OR WWA,     2..04.WWA')]
    [TestCase('Sect.8',   '1 2 3 ID 4 X,          4..03.ID')]
    [TestCase('Sect.9',   '1 2 3 ID 4 XX,         2..04.ID')]
    [TestCase('Sect.10',  '1 2 3 ID 4 XX OR WWA,  2..04.WWA')]
    [TestCase('Sect.11',  '1 2 3 ID 4 XYZ,        2..04.ID')]
    [TestCase('Sect.12',  '1 2 3 ID 4 WXYZ,       4..03.ID')]   // N1MM: 4..03.
    [TestCase('Sect.13',  '11 22 33 ID 44,        22..44.ID')]
    [TestCase('Sect.14',  '11 22 33 ID 44 55,     44..55.ID')]  // rotate to NR
    [TestCase('Sect.15',  '11 22 33 ID 44 55 66,  55..66.ID')]  // rotate to NR
    [TestCase('Sect.16',  '11 12 13 XX,           12..13.')]
    [TestCase('Sect.17',  '11 12 13 XYZ,          12..13.')]
    [TestCase('Sect.18',  '11 12 13 XX OR,        12..13.OR')]
    [TestCase('Sect.19',  '11 22 33 ID 44 X,      44..33.ID')]
    [TestCase('Sect.20',  '11 22 33 ID 44 XX,     22..44.ID')]
    [TestCase('Sect.21',  '11 22 33 ID 44 XYZ,    22..44.ID')]
    [TestCase('Sect.22',  '11 22 33 ID 44 WXYZ,   22..44.ID')]  // N1MM: 22..44.
    [TestCase('Sect.23',  '11 22 33 ID 44 O,      44..33.ID')]
    [TestCase('Sect.24',  '11 22 33 ID 44 OR,     22..44.OR')]
    [TestCase('Sect.31',  '11 12 13 XX,            12..13.')]
    [TestCase('Sect.32',  '11 12 13 XX YY,         12..13.')]
    [TestCase('Sect.33',  '11 12 13 XX YY WWA,     12..13.WWA')]
    [TestCase('Sect.34',  '11 7 13 XX YY WWA,      7..13.WWA')]
    [TestCase('Sect.35',  '7 11 8 XX YY WWA,       7..08.WWA')]

    [TestCase('Mixed.1',  '12 A 34 OR,            12.A.34.OR')]
    [TestCase('Mixed.2',  '1 22 3 ID,             1..03.ID')]
    [TestCase('Mixed.3',  '1 22 3 ID 4,           4..03.ID')]
    [TestCase('Mixed.4',  '1 A 22 3 ID 4,         4.A.03.ID')]
    [TestCase('Mixed.5',  '1 ID 22 3 A 4,         4.A.22.ID')]
    [TestCase('Mixed.6',  '1 A 22 4 ID 3 4,       4.A.04.ID')]
    [TestCase('Mixed.7',  '1 A 22 ID 3 4,         4.A.22.ID')]
    [TestCase('Mixed.8',  '1 A 22 123 ID 4,       4.A.22.')]
    [TestCase('Mixed.9',  '22 ID 1 A,             1.A.22.ID')]
    [TestCase('Mixed.10', '123 11 A ID,           11.A..ID')]
    [TestCase('Mixed.11', '72 OR 73 56 A,         56.A.73.OR')]
    [TestCase('Mixed.12', '72 OR 73 74 56 A,      56.A.74.OR')]
    [TestCase('Mixed.13', '72 OR 73 A 72 73 A,    73.A.72.OR')]
    [TestCase('Mixed.14', '72OR  73 A 72 73A,     73.A.72.OR')]
    [TestCase('Mixed.15', '72 OR 73 A 72 73,      73.A.73.OR')]
    [TestCase('Mixed.16', '72OR 73A 72 73,        73.A.73.OR')]
    [TestCase('Mixed.17', '72 OR 73 A 72 73 74,   73.A.74.OR')]
    [TestCase('Mixed.18', '72 OR 73 72 A 74 75,   72.A.75.OR')]
    [TestCase('Mixed.19', '72OR  73 72A  74 75,   72.A.75.OR')]
    [TestCase('Mixed.20', '1 2 OR 10 11 A,        11.A.10.OR')]
    [TestCase('Mixed.21', '1 2 OR 10 3 11 A,      11.A.10.OR')]
    [TestCase('Mixed.22', '1 2OR  10 3 11A,       11.A.10.OR')]
    [TestCase('Mixed.31',  'XX YY ZZ 1,           1...')]
    [TestCase('Mixed.32',  'XX YY ZZ 1 XX,        0..01.')]
    [TestCase('Mixed.33',  'XX YY ZZ 1 XX YY,     0..01.')]
    [TestCase('Mixed.34',  'XX YY ZZ 1 XX YY B,   0.B.01.')]
    [TestCase('Mixed.35',  'XX YY ZZ 1 XX YY ID,  0..01.ID')]
    [TestCase('Mixed.36',  'XX YY ZZ 1 XX ID B,   0.B.01.ID')]
    [TestCase('Mixed.37',  'XX YY ZZ 1 XX B,      0.B.01.')]
    [TestCase('Mixed.38',  'XX YY ZZ 1 XX B ID,   0.B.01.ID')]
    [TestCase('Mixed.40',  '10A20OR,              10.A.20.OR')]
    [TestCase('Mixed.41',  '20OR10A,              10.A.20.OR')]
    [TestCase('Mixed.42',  '20OR 10A,             10.A.20.OR')]
    [TestCase('Mixed.43',  '10 20OR 30A,          30.A.20.OR')]
    [TestCase('Mixed.44',  '20OR 10 30A,          30.A.10.OR')]
    [TestCase('Mixed.45',  '20OR10A W1AW,         10.A.20.OR.W1AW')]
    [TestCase('Mixed.46',  '10A20OR W1AW,         10.A.20.OR.W1AW')]
    [TestCase('Mixed.47',  'W1AW 20OR10A,         10.A.20.OR.W1AW')]
    [TestCase('Mixed.48',  'W1AW 10A20OR,         10.A.20.OR.W1AW')]
    [TestCase('Mixed.49',  'W1AW10A20OR,          0....W1AW10A20OR')]
    [TestCase('Mixed.50',  '10A20ORW1AW,          10.A.01.')]

    [TestCase('Misc.p04.1',  '98,               0..98.')]
    [TestCase('Misc.p04.2',  '98 WNY,           0..98.WNY')]
    [TestCase('Misc.p04.3',  '98 WNY 1,         1..98.WNY')]
    [TestCase('Misc.p04.4',  '98 WNY 11,        0..11.WNY')]
    [TestCase('Misc.p04.6',  '98 WNY 11 A,      11.A.98.WNY')]
    [TestCase('Misc.p04.7',  '98 WNY N2DC 11 A, 11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.8',  '98 WNY N2DC 11A,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.9',  '98 WNY 11A N2DC,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.10', '98 11A WNY N2DC,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.11', '11A 98 WNY N2DC,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.12', '98 WNY 11A N2DC,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.13', '98 WNY N2DC 11A,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.14', '98 N2DC WNY 11A,  11.A.98.WNY.N2DC')]
    [TestCase('Misc.p04.15', 'N2DC 98 WNY 11A,  11.A.98.WNY.N2DC')]

    [TestCase('Misc.p05.1',  '123 124 11 A UT,      11.A..UT')]
    [TestCase('Misc.p05.2',  '123 124 11 A UT 0,    11.A.00.UT')]
    [TestCase('Misc.p05.3',  '123 124 11 A UT 125,  125.A..UT')]

    // in the following, 'OR' is lost since it bound to an invalid Check value '111'
    [TestCase('Misc.p06.1',   '1 111 OR,        1...')]
    [TestCase('Misc.p06.2',   '12 111 OR,       0..12.')]     // invalid Chk, keep Chk=12
    [TestCase('Misc.p06.3',   '12 111 OR UT,    0..12.UT')]   // reset? Chk is already set.
    [TestCase('Misc.p06.4',   '12 111 OR UT 13, 12..13.UT')]  // rotates NR=12, set Chk=13

    // in the following, 'OR' is lost since it bound to an invalid Check value '111'
    [TestCase('Misc.p07.1',  '12 111 OR UT 13,  12..13.UT')]
    [TestCase('Misc.p07.2',  '12        UT 13,  0..13.UT')]
    [TestCase('Misc.p07.3',  '12 111 OR UT,     0..12.UT')]
    [TestCase('Misc.p07.4',  '12 A OR 133,      133.A..OR')]
    [TestCase('Misc.p07.5',  '12 A OR 13,       12.A.13.OR')]
    [TestCase('Misc.p07.6',  '12 OR 13,         0..13.OR')]
    [TestCase('Misc.p07.7',  '11 12 ORR 133,    133..12.')]

    [TestCase('Misc.p08.1',  '11 12 UT 13,      11..13.UT')]
    [TestCase('Misc.p08.2',  '11 12 XYZ 13,     11..13.')]
    [TestCase('Misc.p08.3',  '11 12 XYZZ 123,   123..12.')]

    [TestCase('Misc.p11.1',  '11 12,            11..12.')]
    [TestCase('Misc.p11.2',  '11 12 A,          12.A.11.')]
    [TestCase('Misc.p11.3',  '11 12 A 1,        1.A.11.')]
    [TestCase('Misc.p11.4',  '11 12 A 13,       12.A.13.')]
    [TestCase('Misc.p11.5',  '11 12 A 134,      134.A.11.')]
    [TestCase('Misc.p11.6',  '11 12 A 1345,     1345.A.11.')]

    [TestCase('Misc.p11b.1',  '11 12,             11..12.')]
    [TestCase('Misc.p11b.2',  '11 12 OR,          11..12.OR')]
    [TestCase('Misc.p11b.3',  '11 12 OR 1,         1..12.OR')]
    [TestCase('Misc.p11b.4',  '11 12 OR 13,       11..13.OR')]
    [TestCase('Misc.p11b.5',  '11 12 OR 134,      134..12.OR')]
    [TestCase('Misc.p11b.6',  '11 12 OR 13 14,    13..14.OR')]   // rotate
    [TestCase('Misc.p11b.7',  '11 12 OR 13 14 15, 14..15.OR')]   // rotate

    [TestCase('Misc.p12.1',   '1 2 OR,            1..02.OR')]
    [TestCase('Misc.p12.2',   '1 OR 2,            2..01.OR')]
    [TestCase('Misc.p12.3',   ',                  0...-Missing/Invalid Serial Number')]
    [TestCase('Misc.p12.4',   '1,                 1...-Missing/Invalid Precedence')]
    [TestCase('Misc.p12.5',   '2 4,               4...')]
    [TestCase('Misc.p12.6',   '2 0,               2..00.')]
    [TestCase('Misc.p12.7',   '2 00,              2..00.')]
    [TestCase('Misc.p12.8',   '2 000,             0...')]
    [TestCase('Misc.p12.9',   '56 A 0,            56.A.00.')]
    [TestCase('Misc.p12.10',  '11 12 ID 134 14,   134..14.ID')]
    [TestCase('Misc.p12.11',  '11 12 ID 134 14 A, 14.A.12.ID')]  // set NR
    [TestCase('Misc.p12.12',  '11 12 ID 134 14 Z, 14..12.ID')]   // set NR
    [TestCase('Misc.p12.13',  '11 A 12 Z,         12.A..')]
    [TestCase('Misc.p12.14',  '11 12 Z,           12..11.')]
    [TestCase('Misc.p12.15',  '11 12 ZZ,          11..12.')]
    [TestCase('Misc.p12.15b', '11 12 ZZZ,         11..12.')]
    [TestCase('Misc.p12.15c', '11 12 ZZZZ,        11..12.')]
    [TestCase('Misc.p12.16',  '0ID,               0..00.ID')]
    [TestCase('Misc.p12.17',  '0 ID,              0..00.ID')]

    [TestCase('Misc.p13.1',   '01 02,             1..02.')]
    [TestCase('Misc.p13.2',   '01 02 A,           2.A.01.')]
    [TestCase('Misc.p13.3',   '01 02 A 03,        2.A.03.')]
    [TestCase('Misc.p13.4',   '01 02 A 3,         3.A.01.')]
    [TestCase('Misc.p13.5',   '01 02 A 57 3,      3.A.57.')]
    [TestCase('Misc.p13.6',   '01 02 A 003,       3.A.01.')]
    [TestCase('Misc.p13.7',   '01 02 A 000,       0.A.01.')]

    [TestCase('Misc.p14.1',   '01,               0..01.-Missing/Invalid Serial Number')]
    [TestCase('Misc.p14.2',   '01 02,            1..02.')]
    [TestCase('Misc.p14.3',   '01 02 A,          2.A.01.')]   // 'A' binds NR=2, rotate back to Chk=01
    [TestCase('Misc.p14.4',   '01 02 A 5,        5.A.01.')]   // Set NR=5
    [TestCase('Misc.p14.5',   '01 02 A 57,       2.A.57.')]   // 2 digit, set Chk=57, no change to NR=2
    [TestCase('Misc.p14.6',   '01 02 A 57 7,     7.A.57.')]   // 1 digit, set NR=7
    [TestCase('Misc.p14.7',   '01 02 A 57 72,    2.A.72.')]   // set Chk=72, no shift?
    [TestCase('Misc.p14.8',   '01 02 A 57 72 8,  8.A.72.')]   // set NR=8
    [TestCase('Misc.p14.9',   '01 02 A 57 72 83, 2.A.83.')]   // set Chk, no rotate due to 'A'
    [TestCase('Misc.p14.10',  '1,                1...-Missing/Invalid Precedence')]
    [TestCase('Misc.p14.11',  '1 2,              2...')]
    [TestCase('Misc.p14.12',  '1 2 3,            3...')]
    [TestCase('Misc.p14.13',  '1 2 3 ID,         2..03.ID')]
    [TestCase('Misc.p14.14',  '1 2 3 ID 4,       4..03.ID')]
    [TestCase('Misc.p14.15b', '1 2 3 ID 4 X,     4..03.ID')]
    [TestCase('Misc.p14.15',  '1 2 3 ID 4 XX,    2..04.ID')]
    [TestCase('Misc.p14.15c', '1 2 3 ID 4 XXX,   2..04.ID')]
    [TestCase('Misc.p14.15d', '1 2 3 ID 4 XXXX,  4..03.ID')]
    [TestCase('Misc.p14.15e', '1 2 3 ID 4 WWA,   2..04.WWA')]

    [TestCase('Misc.p15.1',   '10,                    0..10.-Missing/Invalid Serial Number')]     // set Chk, reset
    [TestCase('Misc.p15.2',   '10 20,                 10..20.')]    // rotate
    [TestCase('Misc.p15.3',   '10 20 30,              20..30.')]    // rotate
    [TestCase('Misc.p15.4',   '10 20 30 X,            30..20.')]    // 'X' binds NR=30, shift back to Chk=20
    [TestCase('Misc.p15.5',   '10 20 30 X 40,         30..40.')]    // set Chk
    [TestCase('Misc.p15.6',   '10 20 30 X 40 50,      30..50.')]    // set Chk, no rotate
    [TestCase('Misc.p15.7',   '10 20 30 X 40 50 A,    50.A.40.')]   // 'A' binds NR=50, shift back to Chk=40
    [TestCase('Misc.p15.8',   '10 20 30 X 40 50 60,   30..60.')]    // set Chk, no rotate
    [TestCase('Misc.p15.9',   '10 20 30 X 40 50 60 A, 60.A.50.')]   // 'A' binds NR=60, shift back to Chk=50

    [TestCase('Misc.p16.1',   '11 22 33 ID 44 X,    44..33.ID')]
    [TestCase('Misc.p16.2',   '11 0 33 ID,          0..33.ID')]
    [TestCase('Misc.p16.3',   '11 0 33 ID X,        0..33.ID')]
    [TestCase('Misc.p16.4',   '11 0 33 ID A,        0.A.33.ID')]

    // in the following, 'OR' is lost since it bound to an invalid Check value '111'
    [TestCase('Misc.4',   '1 111 OR 66,             1..66.')]
    [TestCase('Misc.5',   '1 111 OR 66 A,           66.A..')]
    [TestCase('Misc.6',   '10 20 111 OR,            10..20.')]
    [TestCase('Misc.7',   '10 20 111 OR A,          10.A.20.')]
    [TestCase('Misc.8',   '10 20 111 222 OR,        111..20.')]
    [TestCase('Misc.9',   '10 20 111 222 OR ID,     111..20.ID')]
    [TestCase('Misc.10',  '10 20 111 222 OR A ID,   111.A.20.ID')]
    [TestCase('Misc.11',  '10 20 111 222 OR ID A,   111.A.20.ID')]
    [TestCase('Misc.12',  '1 10 2,                  2..10.')]
    [TestCase('Misc.13',  '1 10 2 OR,               1..02.OR')]
    [TestCase('Misc.14',  '1 10 2 OR 20,            1..20.OR')]
    [TestCase('Misc.15',  '1 10 2 20,               2..20.')]
    [TestCase('Misc.16',  '1 10 2 20 3,             3..20.')]
    [TestCase('Misc.17',  '1 10 2 20 3 30,          3..30.')]
    [TestCase('Misc.18',  '1 10 2 20 3 OR,          2..03.OR')]
    [TestCase('Misc.19',  '1 10 2 20 3 OR 30,       2..30.OR')]
    [TestCase('Misc.20',  '1 10 2 OR 20 3,          3..20.OR')]
    [TestCase('Misc.21',  '1 10 2 OR 20 3 30,       3..30.OR')]
    [TestCase('Misc.22',  '1 10 2 20 OR 3 30,       3..30.OR')]
    [TestCase('Misc.23',  '1 10 2 20 3 OR 30,       2..30.OR')]
    [TestCase('Misc.24',  '10 1 20 2 OR 30 3,       3..30.OR')]
    [TestCase('Misc.25',  'OR 1 10 2 20 ID 3 30,    3..30.ID')]
    [TestCase('Misc.26',  '10 1 20 2 A 30 3,        3.A.30.')]
    [TestCase('Misc.27',  'OR 1 10 2 20 A 3 30,     3.A.30.OR')]
    [TestCase('Misc.28',  '1 10 2 20 OR A 3 30,     3.A.30.OR')]
    [TestCase('Misc.29',  '1 10 2 20 3 OR 30 A,     30.A.03.OR')]

    [TestCase('Misc.31',  'A,             0.A..-Missing/Invalid Serial Number')]
    [TestCase('Misc.32',  'A 10,          0.A.10.')]
    [TestCase('Misc.33',  'A 10 20,       10.A.20.')]
    [TestCase('Misc.34',  'A 10 B 20,     10.B.20.')]
    [TestCase('Misc.35',  'A 10 20 B,     20.B.10.')]

    [TestCase('Misc.40',  'ID,            0...ID-Missing/Invalid Serial Number')]
    [TestCase('Misc.41',  'ID 10,         0..10.ID')]
    [TestCase('Misc.42',  'ID 10 20,      10..20.ID')]
    [TestCase('Misc.43',  'ID 10 A 20,    10.A.20.ID')]
    [TestCase('Misc.44',  'ID 10 20 A,    20.A.10.ID')]

    [TestCase('Misc.50',  '  ,            0...-Missing/Invalid Serial Number')]
    [TestCase('Misc.51',  '20 ID 10 A  ,  10.A.20.ID')]
    [TestCase('Misc.52',  '  20 ID 10 A,  10.A.20.ID')]
    [TestCase('Misc.53',  '  20 ID 10 A  ,10.A.20.ID')]
    [TestCase('Misc.54',  '12 111 OR,     0..12.')]

    [TestCase('Misc.60',  'W7SST ID 10 A 20,    10.A.20.ID.W7SST')]
    [TestCase('Misc.61',  'ID W7SST 10 A 20,    10.A.20.ID.W7SST')]
    [TestCase('Misc.62',  'ID 10 W7SST A 20,    10.A.20.ID.W7SST')]
    [TestCase('Misc.63',  'ID 10 A W7SST 20,    10.A.20.ID.W7SST')]
    [TestCase('Misc.64',  'ID 10 A 20 W7SST,    10.A.20.ID.W7SST')]
    [TestCase('Misc.65',  'W7SST OR 1 10 2 20 ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.66',  'OR W7SST 1 10 2 20 ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.67',  'OR 1 W7SST 10 2 20 ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.68',  'OR 1 10 W7SST 2 20 ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.69',  'OR 1 10 2 W7SST 20 ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.70',  'OR 1 10 2 20 W7SST ID 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.71',  'OR 1 10 2 20 ID W7SST 3 30,  3..30.ID.W7SST')]
    [TestCase('Misc.72',  'OR 1 10 2 20 ID 3 W7SST 30,  3..30.ID.W7SST')]
    [TestCase('Misc.73',  'OR 1 10 2 20 ID 3 30 W7SST,  3..30.ID.W7SST')]

    procedure RunTest(const AEnteredExchange, AExpected: string);

    [Test(False)]
    [Category('ErrorChecks')]
    [TestCase('MyExch.Error.Invalid.01', ',Invalid exchange')]

    [TestCase('MyExch.Error.Extra.01', 'A 72 OR EX,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.02', 'A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.03', '123 A 72 OR EX,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.04', '123 A 72 OR WWA,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.05', '123 A 72 OR 56,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.06', '123 A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.07', 'A B 72 OR,Invalid exchange')]
    [TestCase('MyExch.Error.Extra.08', 'A B 72 OR ID,Invalid exchange')]

    [TestCase('MyExch.Error.Missing.01', 'OR,missing Precedence')]
    [TestCase('MyExch.Error.Missing.02', '72 OR,missing Precedence')]

    [TestCase('MyExch.Error.Missing.11', 'A,missing Check')]
    [TestCase('MyExch.Error.Missing.12', 'A OR,missing Check')]
    [TestCase('MyExch.Error.Missing.13', '123 A OR,missing Check')]
    [TestCase('MyExch.Error.Missing.14', '123 A,missing Check')]

    [TestCase('MyExch.Error.Missing.21', 'A 72,missing Section')]
    [TestCase('MyExch.Error.Missing.22', '123 A 72,missing Section')]

    [TestCase('MyExch.Error.Invalid.11', 'NN A 123 OR,invalid Number')]

    [TestCase('MyExch.Error.Invalid.21', 'C 1 OR,invalid Precedence')]
    [TestCase('MyExch.Error.Invalid.22', '123 C 123 OR,invalid Precedence')]
    [TestCase('MyExch.Error.Invalid.23', '123 xxA 123 OR,invalid Precedence')]

    [TestCase('MyExch.Error.Invalid.31', 'A 1 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.32', 'A 1 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.33', 'A 123 OR,invalid Check')]
    [TestCase('MyExch.Error.Invalid.33', 'A 2024 OR,invalid Check')]

    [TestCase('MyExch.Error.Invalid.41', 'A 72 OR1,invalid Section')]
    [TestCase('MyExch.Error.Invalid.42', '123 A 72 1OR,invalid Section')]
    [TestCase('MyExch.Error.Invalid.43', 'A 72 222,invalid Section')]
    [TestCase('MyExch.Error.Invalid.44', '123 A 72 222,invalid Section')]
    [TestCase('MyExch.Error.Invalid.44', 'A 72 XYZZY,invalid Section')]
    procedure ErrorCheck(const AEnteredExchange, AExpected: string);

    [Test(True)]
    [TestCase('Parser.Test3','')]
    procedure Test3();

    [Test(True)]
    [TestCase('Lexer.PerlRegExList','')]
    procedure Test4();

  end;

implementation

uses
  PerlRegEx,
  System.SysUtils;

{
  TSSExchParser is created once for the TestFixture, not with each Test.
  This matches usage model in MRCE where it's lifetime is controlled by
  TSweepstakes.
}
procedure TestTSSExchParser.SetupFixture;
begin
  parser := TSSExchParser.Create;
end;

procedure TestTSSExchParser.TearDownFixture;
begin
  FreeAndNil(parser);
end;

procedure TestTSSExchParser.RunTest(const AEnteredExchange, AExpected: string);
var
  R: boolean;
  S, ExchError: string;

  // summary: <NR>.<Prec>.<Check>.<Section>[.<Call>]
  function Summary: String;
  begin
    Result := format('%d.%s.%s.%s', [parser.NR, parser.Precedence, parser.Check, parser.Section]);
    if not parser.Call.IsEmpty then
      Result := Result + '.' + parser.Call;
  end;
begin
{$ifdef DEBUG}
  DbgBreak := False;
{$endif}
  R := parser.ValidateEnteredExchange('', '', AEnteredExchange, ExchError);
  S := Summary;

  if R then
    begin
      if AExpected.Trim <> S then begin
  {$ifdef DEBUG}
        // a few retries for easy debugging with debugger
        DbgBreak := True;
        R := parser.ValidateEnteredExchange('', '', AEnteredExchange, ExchError);
        S := Summary;
        R := parser.ValidateEnteredExchange('', '', AEnteredExchange, ExchError);
        S := Summary;
  {$endif}
        Assert.AreEqual(AExpected.Trim, S, format(' <-- (%s)', [AEnteredExchange]));
      end;
    end
  else
    begin
  {$ifdef DEBUG}
      DbgBreak := True;
      R := parser.ValidateEnteredExchange('', '', AEnteredExchange, ExchError);
  {$endif}
      S := Summary + '-' + ExchError;
      Assert.Contains(S, AExpected.Trim, format(' <-- (%s)', [AEnteredExchange]));
    end;
end;

procedure TestTSSExchParser.ErrorCheck(const AEnteredExchange, AExpected : string);
var
  R: boolean;
  S, ExchError: string;
begin
  R:= parser.ValidateEnteredExchange('', '', AEnteredExchange, ExchError);
  Assert.IsFalse(R, format('expecting ''%s'' to fail', [AEnteredExchange]));
  if not R then
    Assert.Contains(ExchError, AExpected.Trim);
end;

procedure TestTSSExchParser.Test3;
var
  Reg: TPerlRegEx;
  S: string;
begin
  Reg := TPerlRegEx.Create;

  try
  //  RegEx.RegEx := UTF8Encode('^' + ARegexpr + '$');
    Reg.RegEx := UTF8Encode('(A|B|C)');
    Reg.Compile;
    Reg.Subject := 'B';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(PCREString('B'), Reg.Groups[0]);

    Reg.RegEx := UTF8Encode('((A)|(B)|(?P<c>C))');
    Reg.Subject := 'A';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(2, Reg.GroupCount);
    Assert.AreEqual(PCREString('A'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('A'), Reg.Groups[1]);

    Reg.Subject := 'ABC';
    Assert.IsTrue(Reg.Match);
    Assert.AreEqual(2, Reg.GroupCount);
    Assert.AreEqual(PCREString('A'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('A'), Reg.Groups[1]);

    Assert.IsTrue(Reg.MatchAgain);
    Assert.AreEqual(3, Reg.GroupCount);
    Assert.AreEqual(PCREString('B'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('B'), Reg.Groups[1]);
    Assert.IsEmpty(Reg.Groups[2]);
    Assert.AreEqual(PCREString('B'), Reg.Groups[3]);
    Assert.IsEmpty(Reg.Groups[4]);
    Assert.IsEmpty(Reg.Groups[Reg.NamedGroup('c')]);  // index = 4

    Assert.IsTrue(Reg.MatchAgain);
    Assert.AreEqual(4, Reg.GroupCount);
    Assert.AreEqual(PCREString('C'), Reg.Groups[0]);
    Assert.AreEqual(PCREString('C'), Reg.Groups[1]);
    Assert.IsEmpty(Reg.Groups[2]);
    Assert.IsEmpty(Reg.Groups[3]);
    Assert.AreEqual(PCREString('C'), Reg.Groups[4]);

    Assert.IsFalse(Reg.MatchAgain, 'final MatchAgain should fail');
  finally
    Reg.Free;
  end;
end;

procedure TestTSSExchParser.Test4;
var
  Reg1, Reg2, Reg3: TPerlRegEx;
  MatchedReg: TPerlRegEx;
  RegList: TPerlRegExList;
  R: boolean;
begin
  MatchedReg := nil;
  RegList := TPerlRegExList.Create;

  try
    Reg1 := TPerlRegEx.Create;
    Reg2 := TPerlRegEx.Create;
    Reg3 := TPerlRegEx.Create;
    Reg1.RegEx := 'A'; Reg1.Study;
    Reg2.RegEx := 'B'; Reg2.Study;
    Reg3.RegEx := 'C'; Reg3.Study;
    RegList.Add(Reg1);
    RegList.Add(Reg2);
    RegList.Add(Reg3);

    RegList.Subject := 'ABC';
    Assert.IsTrue(RegList.Match, 'a');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'A');
    Assert.AreEqual(0, RegList.IndexOf(MatchedReg));

    Assert.IsTrue(RegList.MatchAgain, 'b');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'B');
    Assert.AreEqual(1, RegList.IndexOf(MatchedReg));

    Assert.IsTrue(RegList.MatchAgain, 'c');
    MatchedReg := RegList.MatchedRegEx;
    Assert.Contains(MatchedReg.MatchedText, 'C');
    Assert.AreEqual(2, RegList.IndexOf(MatchedReg));

    Assert.IsFalse(RegList.MatchAgain, 'final MatchAgain should fail');

  finally
    MatchedReg := nil;
{
    RegList.GetRegEx(2).Free;
    RegList.GetRegEx(1).Free;
    RegList.GetRegEx(0).Free;
}
    RegList.Clear;
    RegList.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TestTSSExchParser);

end.
