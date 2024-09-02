unit CQWPX;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Ini,        // for TSerialNRSettings, TSerialNRTypes
  SerNRGen,   // TSerialNRGen
  Contest, CallLst, DxStn, Log;

type
TCqWpx = class(TContest)
private
  // CQ Wpx Contest uses the global Calls variable (see CallLst.pas)
  CallLst : TCallList;
  SerialNRGen : TSerialNRGen;
  PrevSerialNRType : TSerialNRTypes;
  PrevRangeStr : String;

  function GetNR(const station : TDxStation) : integer;

public
  constructor Create;
  destructor Destroy; override;

  function OnContestPrepareToStart(const AUserCallsign: string;
    const ASentExchange : string) : Boolean; override;
  function LoadCallHistory(const AUserCallsign : string) : boolean; override;
  procedure SerialNrModeChanged; override;
  procedure InitSerialNRGen;

  function PickStation(): integer; override;
  procedure DropStation(id : integer); override;
  function GetCall(id:integer): string; override;     // returns station callsign
  procedure GetExchange(id : integer; out station : TDxStation); override;
  function GetRandomSerialNR: Integer; override;

  function getExch1(id:integer): string;    // returns RST (e.g. 5NN)
  function getExch2(id:integer): string;    // returns section info (e.g. 3)
  function GetStationInfo(const ACallsign: string) : string; override;
  function ExtractMultiplier(Qso: PQso) : string; override;
end;

implementation

uses
  SysUtils, Generics.Defaults, System.Math,
  Main,           // for SetMySerialNR
  Classes, DXCC;

function TCqWpx.OnContestPrepareToStart(const AUserCallsign: string;
  const ASentExchange : string) : Boolean;
begin
  // Refresh Serial NR Generator before calling OnContestPrepareToStart
  InitSerialNRGen;

  Result := inherited OnContestPrepareToStart(AUserCallsign, ASentExchange);

  // reload My Serial Number at start of contest. This allows Mid-Contest and
  // End of Contest modes to set Tst.Me.NR with a realistic random number.
  if Result then
    MainForm.SetMySerialNR;
end;


{
  Overriden for the CQ WPX Contest to allow regeneration of the SerialNRGen
  tables (based on new Ini.SerialNR setting).

  Called after
  - 'Setup | Serial NR' menu pick
  - 'Setup | Serial NR | Custom Range...' menu pick/modification

  This can be called during a Run if the user selects a different
  Serial NR distribution (e.g. Mid-Contest, End of Contest, etc.).
}
procedure TCqWpx.SerialNrModeChanged;
begin
  assert(RunMode <> rmStop);
  InitSerialNRGen;
end;


function TCqWpx.LoadCallHistory(const AUserCallsign : string) : boolean;
begin
  // reload call history if empty
  Result := not CallLst.IsEmpty();
  if Result then
    Exit;

  CallLst.LoadCallList;

  Result := True;
end;


constructor TCqWpx.Create;
begin
  inherited Create;
  CallLst := TCallList.Create;
  SerialNRGen := TSerialNRGen.Create;

  InitSerialNRGen;
end;


destructor TCqWpx.Destroy;
begin
  CallLst.Free;
  SerialNrGen.Free;
  inherited;
end;


procedure TCqWpx.InitSerialNRGen;
const
  { This distribution table contains the number of log entries
    submitted in 2023 as binned by largest serial number sent by single-ops.
    Data provided by Laurent, F6FVY.

    It is used during the simulation to provide a similar distribution
    of serial numbers for the Mid-Contest and End-of-Contest simulations.
  }
  sampleTbl : array[0..59] of TSerNRSampleBin = (
{0} (B:    0; C: 344),   // 0-9
    (B:   10; C: 188),   // 10-19
    (B:   20; C: 178),   // 20-29
    (B:   30; C: 164),   // 30-39
    (B:   40; C: 156),   // 40-49
{5} (B:   50; C: 179),   // 50-59
    (B:   60; C: 149),   // 60-69
    (B:   70; C: 126),   // 70-79
    (B:   80; C: 118),   // 80-89
    (B:   90; C: 124),   // 90-100
{10}(B:  100; C: 957),   // 100-200
    (B:  200; C: 628),   // 200-300
    (B:  300; C: 368),   // 300-400
    (B:  400; C: 257),   // 400-500
    (B:  500; C: 239),   // 500-600
{15}(B:  600; C: 150),   // 600-700
    (B:  700; C: 129),   // 700-800
    (B:  800; C: 100),   // 800-900
    (B:  900; C:  65),   // 900-1000
    (B: 1000; C:  79),   // 1000-1100
{20}(B: 1100; C:  59),   // 1100-1200
    (B: 1200; C:  47),   // 1200-1300
    (B: 1300; C:  44),   // 1300-1400
    (B: 1400; C:  26),   // 1400-1500
    (B: 1500; C:  28),   // 1500-1600
{25}(B: 1600; C:  36),   // 1600-1700
    (B: 1700; C:  23),   // 1700-1800
    (B: 1800; C:  25),   // 1800-1900
    (B: 1900; C:  23),   // 1900-2000
    (B: 2000; C:  17),   // 2000-2100
{30}(B: 2100; C:  24),   // 2100-2200
    (B: 2200; C:  16),   // 2200-2300
    (B: 2300; C:  15),   // 2300-2400
    (B: 2400; C:   7),   // 2400-2500
    (B: 2500; C:  11),   // 2500-2600
{35}(B: 2600; C:   6),   // 2600-2700
    (B: 2700; C:  11),   // 2700-2800
    (B: 2800; C:   4),   // 2800-2900
    (B: 2900; C:   5),   // 2900-3000
    (B: 3000; C:   6),   // 3000-3100
{40}(B: 3100; C:   1),   // 3100-3200
    (B: 3200; C:   4),   // 3200-3300
    (B: 3300; C:   6),   // 3300-3400
    (B: 3400; C:   3),   // 3400-3500
    (B: 3500; C:   1),   // 3500-3600
{45}(B: 3600; C:   2),   // 3600-3700
    (B: 3700; C:   3),   // 3700-3800
    (B: 3800; C:   0),   // 3800-3900
    (B: 3900; C:   1),   // 3900-4000
    (B: 4000; C:   2),   // 4000-4100
{50}(B: 4100; C:   0),   // 4100-4200
    (B: 4200; C:   0),   // 4200-4300
    (B: 4300; C:   0),   // 4300-4400
    (B: 4400; C:   0),   // 4400-4500
    (B: 4500; C:   0),   // 4500-4600
{55}(B: 4600; C:   1),   // 4600-4700
    (B: 4700; C:   0),   // 4700-4800
    (B: 4800; C:   0),   // 4800-4900
    (B: 4900; C:   0),   // 4900-5000
{59}(B: 5000; C:$FFFF)
  );

{$ifdef DEBUG}
var
  EntryCount : UInt16;
  J : integer;
{$endif}
begin
  if (Ini.SerialNR = PrevSerialNRType) and
     (Ini.SerialNRSettings[Ini.SerialNR].RangeStr = PrevRangeStr) then
    exit;

  case Ini.SerialNR of
  snStartContest,   // Start of Contest
  snCustomRange:    // Custom Range (01-99)
    SerialNRGen.AddRange(Ini.SerialNRSettings[Ini.SerialNR]);
  snMidContest,     // Mid-Contest (50-500)
  snEndContest:     // End of Contest (500-5000)
    SerialNRGen.AddDistribution(Ini.SerialNRSettings[Ini.SerialNR], SampleTbl);
  else
    assert(false);
  end;

  PrevSerialNRType := Ini.SerialNR;
  PrevRangeStr := Ini.SerialNRSettings[Ini.SerialNR].RangeStr;

{$ifdef DEBUG}
  EntryCount := SerialNRGen.GetEntryCount;
  case Ini.SerialNR of
  snMidContest:   // Mid-Contest (50-500)
    begin
      assert(SerialNRGen.FindBin(0) = 0);
      assert(SerialNRGen.FindBin(1) = 0);
      assert(SerialNRGen.FindBin(179) = 0);
      assert(SerialNRGen.FindBin(180) = 1);
      assert(SerialNRGen.FindBin(EntryCount-1) = 13-SerialNRGen.DistRangeLowIdx);
      assert(SerialNRGen.FindBin(EntryCount) = 13-SerialNRGen.DistRangeLowIdx);
    end;
  snEndContest:   // End-Contest (500-5000)
    begin
      assert(SerialNRGen.FindBin(0) = 0);
      assert(SerialNRGen.FindBin(1) = 0);
      assert(SerialNRGen.FindBin(239) = 0);
      assert(SerialNRGen.FindBin(240) = 1);
      assert(SerialNRGen.FindBin(239+150-1) = 1);
      assert(SerialNRGen.FindBin(239+150) = 1);
      assert(SerialNRGen.FindBin(239+150+1) = 2);
      assert(SerialNRGen.FindBin(EntryCount-1) = 49-SerialNRGen.DistRangeLowIdx);
      assert(SerialNRGen.FindBin(EntryCount) = 55-SerialNRGen.DistRangeLowIdx);
    end;
  end;

  for J := 1 to EntryCount do
    SerialNRGen.GetNR;
{$endif}
end;


function TCqWpx.PickStation(): integer;
begin
  Result := -1;
end;


procedure TCqWpx.DropStation(id : integer);
begin
  // already deleted by GetCall
end;


function TCqWpx.GetRandomSerialNR: Integer;
begin
  Result := Self.SerialNRGen.GetNR;
end;


// return status bar information string from DXCC data file.
// the callsign, Entity and Continent are returned.
// this string is used in MainForm.sbar.Caption (status bar).
// Format:  '<call> - Entity/Continent'
function TCqWpx.GetStationInfo(const ACallsign: string) : string;
var
  dxrec : TDXCCRec;
begin
  dxrec := nil;
  Result := '';

  // find caller's Continent/Entity
  if gDXCCList.FindRec(dxrec, ACallsign) then
    Result := Format('%s - %s/%s', [ACallsign, dxRec.Continent, dxRec.Entity]);
end;


{
  For CQ Wpx, the multiplier is the sum of unique Wpx prefixes worked.
  Also sets contest-specific Qso.Points for this QSO.
}
function TCqWpx.ExtractMultiplier(Qso: PQso) : string;
begin
  Qso.Points := 1;
  // assumes Log.ExtractPrefix() has already been called.
  Result := Qso.Pfx;
end;


function TCqWpx.GetCall(id : integer): string;     // returns station callsign
begin
  Result := CallLst.PickCall;
end;


procedure TCqWpx.GetExchange(id : integer; out station : TDxStation);
begin
  station.Exch1 := getExch1(station.Operid);  // RST
  station.NR := GetNR(station);               // serial number
  station.Exch2 := IntToStr(station.NR);
end;


{
  Returns the serial number for a DX Station being worked.
  For HST or Start-of-Contest serial NR modes, the serial number is based
  on elapsed time and operator skill. For Mid-Contest and End-of-Contest
  modes, the serial number returned will follow a distribution similar to
  the a WPX Contest. See SerNRGen for more information.
}
function TCqWpx.GetNR(const station : TDxStation) : integer;
begin
  if (RunMode = rmHST) or (Ini.SerialNR = snStartContest) then
    Result := station.Oper.GetNR  // Result = f(elapsed time, operator skill)
  else
    Result := GetRandomSerialNR;  // follows WPX distribution of serial NRs
end;


function TCqWpx.getExch1(id:integer): string;    // returns RST (e.g. 5NN)
begin
  result := '599';
end;


function TCqWpx.getExch2(id:integer): string;    // returns serial number (e.g. 3)
begin
  Result := '1';
end;


end.



