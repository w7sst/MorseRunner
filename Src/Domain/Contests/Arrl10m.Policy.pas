unit Arrl10m.Policy;

interface

uses
  Dxcc,
  Arrl10m.Types;

type
  {
    Contains contest-specific policies shared between the ARRL 10 Meter contest
    implementation and its supporting components (reader, simulator, etc.).
    These include both contest rules and simulation-specific behavior.
  }
  TArrl10mPolicy = class
  public
    const MaritimeMobileProbability = 0.005;
    class function IsEntityLocalToContest(const Rec: TDXCCRec) : boolean;
    class function IsCallLocalToContest(const ACallsign: string) : boolean;
  end;

implementation

uses
  System.StrUtils;

{
  Return whether Station is within the US/CA/XE/AK/HI Contest region.
}
class function TArrl10mPolicy.IsEntityLocalToContest(const Rec: TDXCCRec) : boolean;
const
  LocalEntities: array[0..4] of string = (
    'United States of America', 'Canada', 'Mexico', 'Alaska', 'Hawaii');
begin
  Result := MatchText(Rec.Entity, LocalEntities);
end;


{
  Return whether Station is within the US/CA/XE/AK/HI Contest region.
}
class function TArrl10mPolicy.IsCallLocalToContest(const ACallsign: string) : boolean;
var
  dxrec : TDXCCRec;
begin
  Result := gDXCCList.FindRec(dxrec, ACallsign) and
    IsEntityLocalToContest(dxrec);
end;

end.
