unit ArrlSections;

interface

uses
  Generics.Collections;   // for TList<>

type
  TArrlSections = class
    Sections: TList<PCHAR>;
  end;

function SectionToState(const ASection: string): string; overload;
function SectionToState(const ASection: string;
  const ACall: string;
  var DistributionIndex: Integer): string; overload;

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

uses
  CallsignUtils,
  System.StrUtils,  // for MatchStr
  System.SysUtils,
  System.Generics.Collections;

var
  // Map Section to corresponding State
  // Map Callsign Prefix to RAC Province
  GSectionMap: TDictionary<string,string>;

procedure InitSectionMap;
begin
  GSectionMap := TDictionary<string,string>.Create;

  // US subdivisions
  GSectionMap.Add('EMA', 'MA');
  GSectionMap.Add('WMA', 'MA');

  GSectionMap.Add('ENY', 'NY');
  GSectionMap.Add('NLI', 'NY');
  GSectionMap.Add('NNY', 'NY');
  GSectionMap.Add('WNY', 'NY');

  GSectionMap.Add('NNJ', 'NJ');
  GSectionMap.Add('SNJ', 'NJ');

  GSectionMap.Add('EPA', 'PA');
  GSectionMap.Add('WPA', 'PA');

  GSectionMap.Add('NFL', 'FL');
  GSectionMap.Add('SFL', 'FL');
  GSectionMap.Add('WCF', 'FL');

  GSectionMap.Add('NTX', 'TX');
  GSectionMap.Add('STX', 'TX');
  GSectionMap.Add('WTX', 'TX');

  GSectionMap.Add('EWA', 'WA');
  GSectionMap.Add('WWA', 'WA');

  // California sections
  GSectionMap.Add('EB',  'CA');
  GSectionMap.Add('LAX', 'CA');
  GSectionMap.Add('ORG', 'CA');
  GSectionMap.Add('SB',  'CA');
  GSectionMap.Add('SCV', 'CA');
  GSectionMap.Add('SDG', 'CA');
  GSectionMap.Add('SF',  'CA');
  GSectionMap.Add('SJV', 'CA');
  GSectionMap.Add('SV',  'CA');

  // Special MDC (Maryland/DC)
  GSectionMap.Add('MDC', 'MD');

  // Canadian                      RAC Section          Provinces & Territories
  GSectionMap.Add('AB',  'AB'); // Alberta              Alberta           (VE6)
  GSectionMap.Add('BC',  'BC'); // British Columbia     British Columbia  (VE7)
  GSectionMap.Add('GH',  'ON'); // Golden Horseshoe     Ontario           (VE3)
  GSectionMap.Add('MB',  'MB'); // Manitoba             Manitoba          (VE4)
  GSectionMap.Add('NB',  'NB'); // New Brunswick        New Brunswick     (VE9)

  // Special case: Newfoundland and Labrador (NL)
  GSectionMap.Add('NL x VO1', 'NF'); // NL x VO1 -> NF  Newfoundland      (VO1)
  GSectionMap.Add('NL x VO2', 'LB'); // NL x VO2 -> LB  Labrador          (VO2)
  GSectionMap.Add('NL x Def', 'NF'); // NL x Def -> NF  (Default mapping)

  GSectionMap.Add('NS',  'NS'); // Nova Scotia          Nova Scotia       (VE1)
  GSectionMap.Add('ONE', 'ON'); // Ontario East         Ontario           (VE3)
  GSectionMap.Add('ONN', 'ON'); // Ontario North        Ontario           (VE3)
  GSectionMap.Add('ONS', 'ON'); // Ontario South        Ontario           (VE3)
  GSectionMap.Add('PE',  'PE'); // Prince Edward Island Prince Edward Is  (VY2)
  GSectionMap.Add('QC',  'QC'); // Quebec               Quebec            (VE2)
  GSectionMap.Add('SK',  'SK'); // Saskatchewan         Saskatchewan      (VE5)

  // Special case: Territories (TER)
  GSectionMap.Add('TER x VE8', 'NT'); // TER x VE8 -> NT  NW Territories    (VE8)
  GSectionMap.Add('TER x VY0', 'NU'); // TER x VY0 -> NU  Nunavut           (VY0)
  GSectionMap.Add('TER x VY1', 'YT'); // TER x VY1 -> YT  Yukon Territories (VY1)
  GSectionMap.Add('TER x Def', 'NT'); // TER x Def -> NT  (Default mapping)
end;

function SectionToState(
  const ASection: string): string;
var
  S: string;
begin
  S := ASection.ToUpper;

  if GSectionMap.TryGetValue(S, Result) then
    Exit;

  Result := S;
end;

function SectionToState(
  const ASection: string;
  const ACall: string;
  var DistributionIndex: Integer): string;
var
  Section, Prefix: String;
begin
  Section := ASection.ToUpper;

  // special case for MDC - split 50% between 'MD' and 'DC'
  if Section.Equals('MDC') then
  begin
    Inc(DistributionIndex);
    if Odd(DistributionIndex) then
      Exit('MD')
    else
      Exit('DC');
  end
  // special case for Newfoundland & Labrador and Territories
  else if MatchStr(Section, ['NL', 'TER']) then
  begin
    Prefix := CallsignUtils.ExtractPrefix(ACall);
    if GSectionMap.TryGetValue(format('%s x %s', [Section, Prefix]), Result) then
      Exit
    else if GSectionMap.TryGetValue(format('%s x %s', [Section, 'Def']), Result) then
      Exit
    else
      raise Exception.CreateFmt('SectionToState: %s section is missing its default state mapping.',
        [ASection]);
  end;

  Result := SectionToState(ASection);
end;

initialization
  InitSectionMap;

finalization
  GSectionMap.Free;

end.


