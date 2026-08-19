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
  System.SysUtils,
  System.Generics.Collections;

var
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

  // Canadian subdivisions
  GSectionMap.Add('ONE', 'ON');
  GSectionMap.Add('ONN', 'ON');
  GSectionMap.Add('ONS', 'ON');
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
  var DistributionIndex: Integer): string;
begin
  // special case for MDC - split 50% between 'MD' and 'DC'
  if ASection.ToUpper = 'MDC' then
  begin
    Inc(DistributionIndex);
    if Odd(DistributionIndex) then
      Exit('MD')
    else
      Exit('DC');
  end;

  Result := SectionToState(ASection);
end;

initialization
  InitSectionMap;

finalization
  GSectionMap.Free;

end.


