//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit FarnsKeyer;

interface

uses
  SndTypes, MorseKey;


type
  TFarnsKeyer = class(TKeyer)
  protected
    function GetEnvelope: TSingleArray; override;
    procedure LoadMorseTable;

  public
    constructor Create(ARate, ABufSize : integer);
    function Encode(Txt: string): string; override;
  end;


implementation

uses
  SysUtils, Classes, MorseTbl, Math;


{ TFarnsKeyer }

constructor TFarnsKeyer.Create(ARate, ABufSize : integer);
begin
  inherited Create(ARate, ABufSize);
  LoadMorseTable;
end;


{
  Load MorseTable with the dit/dash representation of each character
  followed by a trailing intra-character marker ('^').
    A: '.-^'
    B: '-...^'
    C: '-.-.^'
    ...
    Z: '--..^'
}
procedure TFarnsKeyer.LoadMorseTable;
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
    Morse[Ch] := Copy(S, 3, Pos(']', S)-3) + '^';
  end;
end;


{
  Encode()

  In order to correct apply the Farnsworth timing, we need to clearly
  distinguish inter-character, inter-word, and inter-message markers.
  Each of these markers will require special treatment while generating
  the CW samples.

  The approach will be to insert special characters to represent each marker.
  We will add '^' as inter-character marker and convert all occurances of
  '^ ' to '_' for inter-word marker.

  Approach:
  - add '^' as the inter-character marker when creating the Morse lookup table.
      A: '.-^'
      B: '-...^'
      C: '-.-.^'
      ...
      Z: '--..^'
    As an example, 'CQ CQ' becomes:
      'CQ CQ' -> '-.-.^--.-^ -.-.^--.-^'
  - convert all '^ ' occurances to '_'.
      'CQ CQ' -> '-.-.^--.-_-.-.^--.-^'
  - replace trailing '^$' with '~' to end of each encoded message.
      'CQ CQ' -> '-.-.^--.-_-.-.^--.-~'

  Timing:
      '^' - 3U @ Farnsworth adjusted inter-char/word rate
      '_' - 5U or 7U @ Farnsworth adjusted inter-char/word rate
      '~' - 5U or 7U @ Farnsworth adjusted inter-char/word rate
    Example (continued)
      'CQ CQ' -> '-.-.^--.-_-.-.^--.-~'
                      3    7    3    7
    Our implementation is using 5U inter-word and inter-message spacing, thus:
      'CQ CQ' -> '-.-.^--.-_-.-.^--.-~'
                      3    5    3    5

  Subsequent messages:
  - when subsequent messages are appended (by independent SendMsg() calls),
    the new message is appended to to the existing MsgText string using
    a space (' ').
  - callsigns sent by the current MR user are handled by TMyStation.SendText()
    by breaking up the callsign in a separate so-called Pieces. These pieces
    are then sent sequentially and not appended into a single message string.
    Thus '<his>;<#>' (sent by successive function keys) becomes:
    'K7S;5NN TT1' -> '-.-^--...^...~' ; '.....^-.^-.^ -^-^.----^'
                  -> '-.-^--...^...~' ; '.....^-.^-._-^-^.----~'
                         3     3   7     3  3  7 3 3     7
    '?';'?' -> '..--..^' ; '..--..^'
            -> '..--..~' ; '..--..~'
            -> '..--..~' ; '..--..~'
                      7      7

  Timing summary:
  - all '^' occurances - inter-character spacing with 3U @ Farns adjusted time
  - all '_' occurances - inter-word      spacing with 5U @ Farns adjusted time
  - all ' ' occurances - additional inter-word spacing with 5U spacing
  - all '~' occurances - inter-word      spacing with 5U @ Farns adjusted time
}
function TFarnsKeyer.Encode(Txt: string): string;
var
  i: integer;
begin
  Result := '';
  for i:=1 to Length(Txt) do
    if CharInSet(Txt[i], [' ', '_']) then
        Result := Result + ' '
    else
        Result := Result + Morse[Txt[i]];

  // apply rules
  Result := Result.Replace('^ ', '_', [rfReplaceAll]); // inter-word marker ('_')
  {while true do begin
    i := Result.IndexOf('~');
    if (i = 0) or (i = Length(Result)) then break;
    Result[i] := '_';
  end;}
  if Result.EndsWith('^') then
    Result[Length(Result)] := '~';    // inter-message marker ('~')
end;


{
  GetEnvelope()

  Returns a TSingleArray containing the samples representing the current
  MsgText. If Farnsworth spacing is enabled, additional inter-character
  and inter-word spacing will be been applied.

  The following articles discuss the timing equations used in this
  implementation.
    - https://morsecode.world/international/timing.html
    - https://www.arrl.org/files/file/Technology/x9004008.pdf
}
function TFarnsKeyer.GetEnvelope: TSingleArray;
const
  InterCharSpacing : integer = 3;   // 3U inter-char, 5U inter-word spacing
  InterWordSpacing : integer = 5;   // 5U inter-word spacing (matches original)
  InterMsgSpacing  : integer = 4;   // 4U inter-message spacing (plus loop time)
var
  UnitCnt, Len, i, p: integer;
  Farnsworth: Boolean;
  AdjustCnt: integer;  // units added for inter-character and inter-word spacing
  DelayPerWord: Single;
  SamplesInUnit: integer;
  SamplesInAdjustUnit: integer; // samples per inter-character and inter-word unit

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

  { Add "Dur" units of standard-width 1-value (On) to the output stream. }
  procedure AddOn(Dur: integer);
  var
    i: integer;
  begin
    for i:=0 to Dur * SamplesInUnit - RampLen - 1 do Result[p+i] := 1;
    Inc(p, Dur * SamplesInUnit - RampLen);
  end;

  {
    Add 'Dur' units of standard-width 0-value (Off) to the output stream.
    The argument ARampLen allows the RampLen width of the prior RampOff()
    to be subtracted while advancing the pointer 'Dur' units.

    Dur - desired duration in units
    ARampLen - number of samples representing the RampOff length
  }
  procedure AddOff(Dur: integer; ARampLen: integer = 0);
  begin
    Inc(p, Dur * SamplesInUnit - ARampLen);
  end;

  {
    AdjustSpace() will convert a trailing standard-width intra-character space
    with a Farnsworth-width inter-character space.

    This is called for one of inter-character ('^'), inter-word ('_'), or
    inter-message spacing '(~)'.
    This should only be called after a character is streamed with AddOff().
    Remember that the last character has advanced the pointer, p, by RampLen
    samples and was counted at WpmC (character speed).
  }
  procedure AdjustSpace(Dur : Integer);
  begin
    Inc(p, (Dur-1) * SamplesInUnit);
    if Farnsworth then
      Inc(p, Dur * (SamplesInAdjustUnit - SamplesInUnit));
  end;

  {
    Add additional space between characters (' ') without compensating
    for a prior space being sent.
  }
  procedure AddSpace(Dur: integer);
  begin
    if Farnsworth then
      Inc(p, Dur * SamplesInAdjustUnit)
    else
      Inc(p, Dur * SamplesInUnit);
  end;

  // this procedure will increment both the standard-width UnitCnt and the
  // Farnsworth-adjusted AdjustCnt units.
  procedure IncAdjust(Dur: integer; Prior: integer = 0);
  begin
    assert(Prior <= 0);   // Prior is an optional negative value
    if Farnsworth then
      begin
        Inc(UnitCnt, Prior);
        Inc(AdjustCnt, Dur);  // consider SpaceCnt instead of AdjustCnt?
      end
    else
      Inc(UnitCnt, Dur+Prior);
  end;

begin
  assert(WpmS > 0, 'must init using SetWpm()');

  UnitCnt := 0;     // intra-character spaces
  AdjustCnt := 0;   // inter-character and inter-word spaces (Farnsworth timing)

  //setup Farnsworth timing adjustments
  DelayPerWord := 0.0;
  SamplesInAdjustUnit := 0;
  Farnsworth := WpmS <= WpmC;
  if Farnsworth then
    begin
      {
        Farnsworth timing uses a different inter-character and inter-word
        spacing. Timing equations are discussed in these two articles:
          - https://morsecode.world/international/timing.html
          - https://www.arrl.org/files/file/Technology/x9004008.pdf

        The delay equation is based on the word 'PARIS ', there are 19U of
        Farnsworth spacing, including 7 units representing the trailing space.
        Based on the above papers, the time of the farnsworth spacing for these
        19 units of inter-character spacing is defined as:
            DelayPerWord (19 units of spacing)
               = (50 units (1 word) at WpmS) - (31 character units at WpmC)
            DelayPerWord := 50*(60/50)/WpmS - 31*60/WpmC/50;
            DelayPerWord := 60/WpmS - 31*60/WpmC/50;

        However, since we are using inter-word spacing of 5U instead of 7U,
        these equations must be modified by changing the number of spacing
        units being sent. To change the 19U of Farnsworth delay spacing to 17U,
        we will reduce the total 50U to 48U as represented by
        (43+InterWordSpacing). With this substitution, the delay timing
        equation becomes:
            DelayPerWord ((12+InterWordSpacing) units of spacing)
               = (1 word at WpmS) - (31 character units at WpmC)
            DelayPerWord := 60/WpmS - 31*60/WpmC/50;
            DelayPerWord := 60/WpmS - 31*60/WpmC/48;
            DelayPerWord := 60/WpmS - 31*60/WpmC/(43+InterWordSpacing);

        samples = time * samples/sec
      }
      DelayPerWord := 60/WpmS - 31*60/WpmC/(43+InterWordSpacing);
      SamplesInAdjustUnit := Round(DelayPerWord * Rate / (12+InterWordSpacing));
    end
  else
    WpmC := WpmS;

  //count standard and delay units
  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': Inc(UnitCnt, 2);     // 1 unit dit followed by 1 unit spacing
      '-': Inc(UnitCnt, 4);     // 3 unit dash followed by 1 unit spacing
      '^': IncAdjust(InterCharSpacing, -1);  // inter-char spacing (3U - 1U prior)
      ' ': IncAdjust(InterWordSpacing,  0);  // inter-word spacing (5U)
      '_': IncAdjust(InterWordSpacing, -1);  // inter-word spacing (5U - 1U prior)
      '~': IncAdjust(InterMsgSpacing,  -1);  // inter-msg  spacing (4U - 1U prior)
    end;

  //calc buffer size
  SamplesInUnit := Round(60 * Rate / WpmC / (43+InterWordSpacing));
  TrueEnvelopeLen := UnitCnt * SamplesInUnit +          // units at WpmC
                     AdjustCnt * SamplesInAdjustUnit;   // units at WpmS
  Len := BufSize * Ceil(TrueEnvelopeLen / BufSize);
  Result := nil;
  SetLength(Result, Len);

  //fill buffer
  p := 0;
  for i:=1 to Length(MorseMsg) do
    case MorseMsg[i] of
      '.': begin AddRampOn; AddOn(1); AddRampOff; AddOff(1, RampLen); end;
      '-': begin AddRampOn; AddOn(3); AddRampOff; AddOff(1, RampLen); end;
      '^': AdjustSpace(InterCharSpacing); // inter-char spacing (3U less 1U applied)
      ' ': AddSpace(InterWordSpacing);    // inter-word spacing (5U)
      '_': AdjustSpace(InterWordSpacing); // inter-word spacing (5U less 1U applied)
      '~': AdjustSpace(InterMsgSpacing);  // inter-msg  spacing (4U less 1U applied)
      end;
  assert(p = TrueEnvelopeLen);
end;


end.

