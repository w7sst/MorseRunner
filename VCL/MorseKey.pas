//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit MorseKey;

interface

uses
  SndTypes;


type
  TKeyer = class
  protected
    Morse: array[Char] of string;
    RampLen: integer;
    RampOn, RampOff: TSingleArray;
    FRiseTime: Single;

    // Farnsworth speed s/c (e.g. 5/18). specified as (WpmS/WpmC)
    WpmS: integer;      // sending speed    (set by UI)
    WpmC: integer;      // character speed  (set via .INI file, default=25wpm)

    function GetEnvelope: TSingleArray; virtual;
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

    constructor Create(ARate, ABufSize : integer);
    procedure SetWpm(const AWpmS : integer; const AWpmC : integer = 0);
    function Encode(Txt: string): string; virtual;

    property RiseTime: Single read FRiseTime write SetRiseTime;
    property Envelope: TSingleArray read GetEnvelope;
  end;


procedure MakeKeyer(ARate : integer = 11025; ABufSize : integer = 512);
procedure DestroyKeyer;

var
  Keyer: TKeyer;


implementation

uses
  SysUtils, Classes, MorseTbl, Math;

procedure MakeKeyer(ARate, ABufSize : integer);
begin
  Keyer := TKeyer.Create(ARate, ABufSize);
end;


procedure DestroyKeyer;
begin
  FreeAndNil(Keyer);
end;



{ TKeyer }

constructor TKeyer.Create(ARate, ABufSize : integer);
begin
  LoadMorseTable;
  Rate := ARate;
  BufSize := ABufSize;
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
    Result[Length(Result)] := '~';  // EOM has ~5U spacing
end;


{
  Returns a TSingleArray containing the samples representing the current
  MsgText.

  The following articles discuss the timing equations used in this
  implementation.
    - https://morsecode.world/international/timing.html
    - https://www.arrl.org/files/file/Technology/x9004008.pdf
}
function TKeyer.GetEnvelope: TSingleArray;
var
  UnitCnt, Len, i, p: integer;
  SamplesInUnit: integer;

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

  {
    Add 'Dur' units of 0-value (Off) to the output stream.
    Remember that characters have a trailing ' ' after each character.
    This ' ' emits an additional 2U spacing after each character, resulting
    in 3U spacing after each character is sent. This is the standard 3U
    inter-character spacing.
    Next, an additional space (' ') is included after each word which causes
    an additional 2U spacing to be emitted, resulting in the standard 5U
    inter-word spacing.

    ARampLen is used to subtract the width of the character's trailing
    RampOff samples (of width RampLen samples).
    - When adding the remaining Off samples after the RampOff, the RampOff
      sample width is subtracted.
    - When adding additional Off samples (not immediately following a RampOff
      event, the value 0 is passed used.

    Dur - desired duration in units
    ARampLen - number of samples representing the RampOff length
  }
  procedure AddOff(Dur : integer; ARampLen: integer);
  begin
    Inc(p, Dur * SamplesInUnit - ARampLen);
  end;


begin
  assert(WpmS > 0, 'must init using SetWpm()');

  //count units
  UnitCnt := 0;

  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': Inc(UnitCnt, 2);   // 1 unit dit followed by 1 unit spacing
      '-': Inc(UnitCnt, 4);   // 3 unit dash followed by 1 unit spacing
      ' ': Inc(UnitCnt, 2);   // 3U inter-char space (2U + prior 1U)
    { ' ': subsequent space } // 5U inter-word space (2U + prior 3U)
      '~': Inc(UnitCnt, 3);   // 4U inter-msg space (3U + prior 1U + loop time)
    end;

  //calc buffer size
  SamplesInUnit := Round(60/48 * Rate / WpmS);  // 48U = 1 word w/ 5U inter-word space
  TrueEnvelopeLen := UnitCnt * SamplesInUnit;
  Len := BufSize * Ceil(TrueEnvelopeLen / BufSize);
  Result := nil;
  SetLength(Result, Len);

  //fill buffer
  p := 0;
  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': begin AddRampOn; AddOn(1); AddRampOff; AddOff(1, RampLen); end;
      '-': begin AddRampOn; AddOn(3); AddRampOff; AddOff(1, RampLen); end;
      ' ': AddOff(2, 0);      // 3U inter-char spacing (2U + prior 1U)
    { ' ': subsequent space } // 5U inter-word spacing (2U + prior 3U)
      '~': AddOff(3, 0);      // 4U inter-msg spacing  (3U + prior 1U)
      end;
  assert(p = TrueEnvelopeLen);
end;


end.

