//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit MorseKey;

interface

uses
  SysUtils, Classes, SndTypes, MorseTbl, Math; //, Ini


type
  TKeyer = class
  private
    Morse: array[Char] of string;
    RampLen: integer;
    RampOn, RampOff: TSingleArray;
    FRiseTime: Single;

    // Farnsworth speed s/c (e.g. 5/18). specified as (WpmS/WpmC)
    WpmS: integer;      // sending speed    (set by UI)
    WpmC: integer;      // character speed  (set via .INI file, default=25wpm)

    function GetEnvelope: TSingleArray;
    procedure LoadMorseTable;
    procedure MakeRamp;
    function BlackmanHarrisKernel(x: Single): Single;
    function BlackmanHarrisStepResponse(Len: integer): TSingleArray;
    procedure SetRiseTime(const Value: Single);

public
    BufSize: integer;
    Rate: integer;
    MorseMsg: string;
    TrueEnvelopeLen: integer;

    constructor Create;
    procedure SetWpm(const AWpmS : integer; const AWpmC : integer = 0);
    function Encode(Txt: string): string;

    property RiseTime: Single read FRiseTime write SetRiseTime;
    property Envelope: TSingleArray read GetEnvelope;
  end;


procedure MakeKeyer;
procedure DestroyKeyer;

var
  Keyer: TKeyer;


implementation

procedure MakeKeyer;
begin
  Keyer := TKeyer.Create;
end;


procedure DestroyKeyer;
begin
  Keyer.Free;
end;



{ TKeyer }

constructor TKeyer.Create;
begin
  LoadMorseTable;
  Rate := 11025;
  RiseTime := 0.005;
  //RiseTime := 1.0 / (2.7 * Rate); // debugging with 1 step rise/fall time
  WpmS := 0;
  WpmC := 0;
end;


procedure TKeyer.SetRiseTime(const Value: Single);
begin
  FRiseTime := Value;
  MakeRamp;
end;


procedure TKeyer.SetWpm(const AWpmS : integer; const AWpmC : integer = 0);
begin
  WpmS := AWpmS;
  WpmC := AWpmC;
end;


procedure TKeyer.LoadMorseTable;
var
  i: integer;
  S: string;
  Ch: Char;
begin
  for i:=0 to High(MorseTable) do
  begin
    S := MorseTable[i];
    if S[2] <> '[' then
      Continue;
    Ch := S[1];
    Morse[Ch] := Copy(S, 3, Pos(']', S)-3) + ' ';
  end;
end;


function TKeyer.BlackmanHarrisKernel(x: Single): Single;
const
  a0 = 0.35875;
  a1 = 0.48829;
  a2 = 0.14128;
  a3 = 0.01168;
begin
  Result := a0 - a1*Cos(2*Pi*x) + a2*Cos(4*Pi*x) - a3*Cos(6*Pi*x);
end;


function TKeyer.BlackmanHarrisStepResponse(Len: integer): TSingleArray;
var
  i: integer;
  Scale: Single;
begin
  assert(Len > 0);
  SetLength(Result, Len);
  //generate kernel
  for i:=0 to High(Result) do Result[i] := BlackmanHarrisKernel(i/Len);
  //integrate
  for i:=1 to High(Result) do Result[i] := Result[i-1] + Result[i];
  //normalize
  Scale := 1 / Result[High(Result)];
  for i:=0 to High(Result) do Result[i] := Result[i] * Scale;
end;


procedure TKeyer.MakeRamp;
var
  i: integer;
begin
  RampLen := Round(2.7 * FRiseTime * Rate);
  RampOn := BlackmanHarrisStepResponse(RampLen);

  SetLength(RampOff, RampLen);
  for i:=0 to RampLen-1 do RampOff[High(RampOff)-i] := RampOn[i];
end;


function TKeyer.Encode(Txt: string): string;
var
  i: integer;
begin
  Result := '';
  for i:=1 to Length(Txt) do
    if CharInSet(Txt[i], [' ', '_']) then
        Result := Result + ' '
    else
        Result := Result + Morse[Txt[i]];
  if Result <> '' then
    Result[Length(Result)] := '~';
end;


{
  Returns a TSingleArray containing the samples representing the current
  MsgText. If Farnsworth spacing is enabled, additional inter-character
  and inter-word spacing will be been applied.

  The following articles discuss the timing equations used in this
  implementation.
    - https://morsecode.world/international/timing.html
    - https://www.arrl.org/files/file/Technology/x9004008.pdf
}
function TKeyer.GetEnvelope: TSingleArray;
var
  UnitCnt, Len, i, p: integer;
  Farnsworth: Boolean;
  AdjustCnt: integer;  // units added for inter-character and inter-word spacing
  DelayPerWord: Single;
  SamplesInUnit: integer;
  SamplesPerAdjustUnit: integer; // samples per inter-character and inter-word unit

  procedure AddRampOn;
  begin
    Move(RampOn[0], Result[p], RampLen * SizeOf(Single));
    Inc(p, Length(RampOn));
  end;

  procedure AddRampOff;
  begin
    Move(RampOff[0], Result[p], RampLen * SizeOf(Single));
    Inc(p, Length(RampOff));
  end;

  procedure AddOn(Dur: integer);
  var
    i: integer;
  begin
    for i:=0 to Dur * SamplesInUnit - RampLen - 1 do Result[p+i] := 1;
    Inc(p, Dur * SamplesInUnit - RampLen);
  end;

  // Add 'Dur' units of 0-value (Off) to the output stream, less 'Prior' units
  // of spacing from the last CW character emitted. Remember that characters
  // have a trailing ' ' after each character. When adding additional
  // inter-word spacing, the prior units at character-spacing have to be
  // removed and replaced with 'Dur' units of Farnsworth inter-word spacing.
  //
  // Dur - desired duration in units
  // Prior - number of standard units already applied
  // ARampLen - number of samples representing the RampOff length
  // AFarnsAdj - if enabled, apply additional Farnsworth delay
  procedure AddOff(Dur, Prior: integer; ARampLen: integer = 0; AFarnsAdj : Boolean = false);
  begin
    Inc(p, (Dur-Prior) * SamplesInUnit - ARampLen);
    if AFarnsAdj then
      Inc(p, Dur * (SamplesPerAdjustUnit - SamplesInUnit));
  end;

  // this procedure will adjust any prior UnitCnt (at WpmC) before incrementing
  // the Farnsworth-adjusted AdjustCnt units (at WpmS).
  procedure IncUnitCnt(Dur: integer; Prior: integer = 0);
  begin
    if Farnsworth then
      begin
        Dec(UnitCnt, Prior);
        Inc(AdjustCnt, Dur);
      end
    else
      Inc(UnitCnt, Dur-Prior);
  end;

begin
  assert(WpmS > 0, 'must init using SetWpm()');

  //count units
  UnitCnt := 0;     // intra-character spaces
  AdjustCnt := 0;   // inter-character and inter-word spaces (Farnsworth timing)

  //setup Farnsworth timing adjustments
  DelayPerWord := 0.0;
  SamplesPerAdjustUnit := 0;
  Farnsworth := WpmS < WpmC;
  if Farnsworth then
    begin
      // Farnsworth timing uses a different inter-character and inter-word
      // spacing. Timing equations are discussed in these two articles:
      // - https://morsecode.world/international/timing.html
      // - https://www.arrl.org/files/file/Technology/x9004008.pdf
      //
      // DelayPerWord (19 units of spacing)
      //    = (50 units (1 word) at WpmS) -
      //      (31 character units at WpmC)
      // samples = time * samples/sec
      DelayPerWord := 50*1.2/WpmS - 31*1.2/WpmC;
      SamplesPerAdjustUnit := Round(DelayPerWord * Rate / 19);
    end
  else
    WpmC := WpmS;

  // when adding farnsworth timing, the functions below have been adjusted to
  // compensate for the 1U intra-character space added by the last character.
  // For example, when counting for ' ' (a 3U inter-character space), we will
  // count 3 inter-character units less the 1 unit of intra-character space
  // already streamed by the prior character.
  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': Inc(UnitCnt, 2);     // 1 unit dit followed by 1 unit spacing
      '-': Inc(UnitCnt, 4);     // 3 unit dash followed by 1 unit spacing
      ' ': IncUnitCnt(3, 1);    // inter-character spacing (3U less 1U prior)
      '~': Inc(UnitCnt, 1);
    end;

  //calc buffer size
  SamplesInUnit := Round(0.1 * Rate * 12 / WpmC);
  TrueEnvelopeLen := UnitCnt * SamplesInUnit +            // units at WpmC
                     AdjustCnt * SamplesPerAdjustUnit;    // units at WpmS
  Len := BufSize * Ceil(TrueEnvelopeLen / BufSize);
  Result := nil;
  SetLength(Result, Len);

  //fill buffer
  p := 0;
  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': begin AddRampOn; AddOn(1); AddRampOff; AddOff(1, 0, RampLen); end;
      '-': begin AddRampOn; AddOn(3); AddRampOff; AddOff(1, 0, RampLen); end;
      ' ': AddOff(3, 1, 0, Farnsworth);   // inter-char spacing (3U less 1U applied)
      '~': AddOff(1, 0);                  // one unit of spacing
      end;
  assert(p = TrueEnvelopeLen);
end;


end.

