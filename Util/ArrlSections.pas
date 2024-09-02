unit ArrlSections;

interface

uses
  Generics.Collections;   // for TList<>

type
  TArrlSections = class
    Sections: TList<PCHAR>;
  end;

const
  // https://contests.arrl.org/contestmultipliers.php?a=wve
  SectionsTbl: array[0..84] of PCHAR = (
    // Call Area 0
    'CO', 'IA', 'KS', 'MN', 'MO',
    'ND', 'NE', 'SD',

    // Call Area 1
    'CT', 'EMA', 'ME', 'NH', 'RI',
    'VT', 'WMA',

    // Call Area 2
    'ENY', 'NLI', 'NNJ', 'NNY', 'SNJ',
    'WNY',

    // Call Area 3
    'DE', 'EPA', 'MDC', 'WPA',

    // Call Area 4
    'AL', 'GA', 'KY', 'NC', 'NFL',
    'SC', 'SFL', 'TN', 'VA', 'WCF',
    'PR', 'VI',

    // Call Area 5
    'AR', 'LA', 'MS', 'NM', 'NTX',
    'OK', 'STX', 'WTX',

    // Call Area 6
    'EB', 'LAX', 'ORG', 'SB', 'SCV',
    'SDG', 'SF', 'SJV', 'SV', 'PAC',

    // Call Area 7
    'AK', 'AZ', 'EWA', 'ID', 'MT',
    'NV', 'OR', 'UT', 'WWA', 'WY',

    // Call Area 8
    'MI', 'OH', 'WV',

    // Call Area 9
    'IL', 'IN', 'WI',

    // RAC Sections
    'AB', 'BC', 'GH', 'MB', 'NB',
    'NL', 'NS', 'ONE', 'ONN', 'ONS',
    'PE', 'QC', 'SK', 'TER'
  );

implementation


end.


