//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SerNRGen;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Generics.Collections, // for TArray<>
  Ini;                  // for TSerialNumberRange

type
// Used to declare a set of bins containing the number of logs/entries
// for a highest serial number range. An array is formed to create a
// series of bins representing the full sample distribution. An additional
// bin is added to the end of the array.
// See example in CqWpx.pas.
TSerNRSampleBin = record
  B: UInt16;    // starting serial number for this bin
  C: UInt16;    // number of samples (logs/entries) in this bin
end;

{
  SerialNRGen will generate random serial number matching a sample
  distribution representing a prior contest. F6FVY provided data showing
  the last number sent by single-ops according to available public log
  files from the 2023 CQ WPX contest. Please see the discussion at:
  https://github.com/w7sst/MorseRunner/issues/269

  SerialNRGen will organize this data allow easy random generation
  of serial numbers following this same distribution.

  Steps to setup a Serial Number Generator
  1. Create a sample distribution using data from prior contest.
      sampleTbl : array[0..5] of TSerNRSampleBin = (
      //  BeginSN  Count       SN Range    Ratio   Percentage
        (B:    0; C: 344),   // 0-9        344/1030 = 33.4%
        (B:   10; C: 188),   // 10-19      188/1030 = 18.3%
        (B:   20; C: 178),   // 20-29      178/1030 = 17.3%
        (B:   30; C: 164),   // 30-39      164/1030 = 15.9%
        (B:   40; C: 156),   // 40-49      156/1030 = 15.1%
        (B:   50; C:$FFFF);  // end       1030/1030 = 100%
  2. Call TSerialNRGen.AddDistribution(sampleTbl)
      SerialNRGen := TSerialNRGen.Create
      SerialNRGen.AddDistribution(sampleTbl);
  3. Call GetNR as needed
      Result := SerialNRGen.GetNR();

  Details
  The above data will be organized in a new table with a running sample total
  column. This column will be used when searching for a bin instead of using
  a floating-point percentage value. The total, 1030, is used to generate a
  random number when searching for a bin. By searching for a bin in the range
  [0,1030), this data can be stored using 16-bit WORD values (UInt16).
  Once a bin is found using a Random(1030), the value is computed using
  StartingSN + Random(BinWidth).
                         Running
    starting    Bin      Sample   Percent
         SN    Width     Total
        ( 0     10       344 )     33.4%
        (10     10       532 )     51.7%
        (20     10       710 )     68.9%
        (30     10       874 )     84.9%
        (40     10      1030 )    100.0%
                          ^
                          |---- Random (1030) will find the bin

  Finally, TArray<>.BinarySearch has this nifty feature where it will find
  the first occurrance of a bin with the same value. See TSerialNRGen.FindBin().
}
TSerialNRGen = class
public
type
  TSerialNRItem = record
    IdRangeBegin: UInt16;     // serial number range starting value
    IdRangeWidth: UInt16;     // bin width
    CummulativeCnt: UInt16;   // running cummulative total count

    procedure Init(const ABegin, AWidth, ACnt : UInt16);
    function GetNR() : integer;
  end;
  PSerNRItem = ^TSerialNRItem;

var
  SerialNrTbl : TArray<TSerialNRItem>;

  constructor Create;
  destructor Destroy; override;

  procedure AddRange(const aRange : TSerialNRSettings);
  procedure AddDistribution(const aRange : TSerialNRSettings;
    const aSampleTbl : array of TSerNRSampleBin);
  function FindBin(count: UInt16) : integer;
  function GetNR() : integer;

  function GetEntryCount : UInt16;

private
  LowIdx : integer;   // starting index into original sampleTbl
  HighIdx : integer;  // ending index into original sampleTbl
  Sum : UInt16;       // running total of log entries included in distribution

{$ifdef DEBUG}
public
  // starting index into distribution table (used in various asserts)
  property DistRangeLowIdx : integer read LowIdx;

  // ending index into distribution table (used in various asserts)
  property DistRangeHighIdx : integer read HighIdx;
{$endif}
end;

implementation

uses
  Generics.Defaults, System.Math;

constructor TSerialNRGen.Create;
begin

end;


destructor TSerialNRGen.Destroy;
begin
  SerialNRTbl := nil;
end;


// used to add simple user-defined range without a sample distribution table.
procedure TSerialNRGen.AddRange(const aRange : TSerialNRSettings);
begin
  SetLength(SerialNRTbl, 1);
  Sum := 1;
  SerialNRTbl[0].Init(aRange.MinVal, aRange.MaxVal - aRange.MinVal, Sum);
  LowIdx := 0;
  HighIdx := 0;
end;

// add a serial number distribution table to the generator
procedure TSerialNRGen.AddDistribution(const aRange : TSerialNRSettings;
  const aSampleTbl : array of TSerNRSampleBin);
var
  I : integer;
begin
  Sum := 0;
  // note - the following is hardwired. This will replaced in the future
  // with a more general mechanism to allow user-defined ranges to be used.
  case aRange.MinVal of
  50: LowIdx := 5;
  500: LowIdx := 14;
  else
    assert(false);
  end;
  case aRange.MaxVal of
  500: HighIdx := 13;
  5000: HighIdx := 58;
  else
    assert(false);
  end;

  I := HighIdx - LowIdx + 1;
  SetLength(SerialNRTbl, I);
  var pItem : PSerNRItem := @SerialNRTbl[0];
  for I := LowIdx to HighIdx do
    begin
      Inc(Sum, aSampleTbl[I].C);
      assert(pItem = @SerialNRTbl[I-LowIdx]);
      assert(I+1 < Length(aSampleTbl));
      pItem.IdRangeBegin := aSampleTbl[I].B;
      pItem.IdRangeWidth := aSampleTbl[I+1].B - aSampleTbl[I].B;
      pItem.CummulativeCnt := Sum;
      Inc(pItem);
    end;
end;


function TSerialNRGen.GetNR() : integer;
var
  EntryCount : UInt16;
  FoundIdx : integer;
begin
  EntryCount := SerialNRTbl[High(SerialNRTbl)].CummulativeCnt;
  FoundIdx := FindBin(UInt16(Random(EntryCount)+1));  // find bin with this accumulated total
  Result := SerialNRTbl[FoundIdx].GetNR();
end;


function TSerialNRGen.FindBin(count: UInt16) : integer;
var
  Item : TSerialNRItem;
  FoundIdx : integer;
begin
  assert(count <= SerialNRTbl[High(SerialNRTbl)].CummulativeCnt);
  assert(Sum = SerialNRTbl[High(SerialNRTbl)].CummulativeCnt);
  count := Min(count, SerialNRTbl[High(SerialNRTbl)].CummulativeCnt);
  Item.Init(0, 0, count);  // find bin with this accumulated total
  TArray.BinarySearch<TSerialNRItem>(SerialNRTbl, Item, FoundIdx,
    TComparer<TSerialNRItem>.Construct(
      function (const Left, Right: TSerialNRItem): Integer
      begin
        Result := CompareValue(Left.CummulativeCnt, Right.CummulativeCnt);
      end
      ));
  assert(FoundIdx < Length(SerialNRTbl));
  Result := FoundIdx;
end;


function TSerialNRGen.GetEntryCount : UInt16;
begin
  Result := Sum;
end;


procedure TSerialNRGen.TSerialNRItem.Init(const ABegin, AWidth, ACnt : UInt16);
begin
  IdRangeBegin := ABegin;
  IdRangeWidth := AWidth;
  CummulativeCnt := ACnt;
end;


function TSerialNRGen.TSerialNRItem.GetNR() : integer;
begin
  Result := IdRangeBegin + Random(IdRangeWidth);
end;

end.
