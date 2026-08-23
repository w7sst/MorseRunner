//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit CallsignUtils;

interface

function ExtractCallsign(const Call: string): string;
function ExtractPrefix(const Call: string; DeleteTrailingLetters: boolean = True): string;

implementation

uses
  SysUtils,
  PerlRegEx;

var
  CallsignRegex: TPerlRegEx;    // Compile the regex ONCE at initialization

// Code by BG4FQD
function ExtractCallsign(const Call: string):string;
var
    bMatch: boolean;
begin
    Result:= '';
    CallsignRegEx.Subject := UTF8Encode(Call);
    bMatch:= CallsignRegEx.Match;
    if bMatch then begin
        if CallsignRegEx.MatchedOffset > 1 then
            bMatch:= (call[CallsignRegEx.MatchedOffset-1] = '/');
        if bMatch then begin
            Result:= String(CallsignRegEx.MatchedText);
        end;
    end;
end;


{
  Extract the prefix from the provided Callsign.

  This function was originally coded for the WPX Contest where the prefix
  is extract and includes its district number (e.g. 'DL8' vs. 'DL').

  Later, this function was used to extract the prefix for DXCC lookup.
  The DeleteTrailingLetters was added for DXCC extraction support by leaving
  all characters after the numeric number to allow the additional prefix
  characters to be used. This is sometimes refered to as the "longest match
  first" rule used in DXCC lookup or cty.dat processing.

  Therefore, this function is called for two different use cases:
  1) WPX Contest - the identifying country prefix along with numeric district
     number is returned. Called with DeleteTrailingLetters = True;
  2) DXCC lookup - the Entity-identifying prefix is extracted and returned
     along with all characters. Called with DeleteTrailingLetters = False.
}
function ExtractPrefix(const Call: string; DeleteTrailingLetters: boolean): string;
const
  DIGITS = ['0'..'9'];
  LETTERS = ['A'..'Z'];
var
  p: integer;
  S1, S2, Dig: string;
  Bare: string;     // Call with modifiers stripped; the parameter stays const
begin
  //kill modifiers
  Bare := Call + '|';
  Bare := StringReplace(Bare, '/QRP|', '', []);
  Bare := StringReplace(Bare, '/MM|', '', []);
  Bare := StringReplace(Bare, '/M|', '', []);
  Bare := StringReplace(Bare, '/P|', '', []);
  Bare := StringReplace(Bare, '|', '', []);
  Bare := StringReplace(Bare, '//', '/', [rfReplaceAll]);
  if Length(Bare) < 2 then
  begin
    Result := '';
    Exit;
  end;

  Dig := '';

  //select shorter piece
  p := Pos('/', Bare);
  if p = 0 then Result := Bare
  else if p = 1 then Result := Copy(Bare, 2, MAXINT)
  else if p = Length(Bare) then Result := Copy(Bare, 1, p-1)
  else
    begin
    S1 := Copy(Bare, 1, p-1);
    S2 := Copy(Bare, p+1, MAXINT);

    if (Length(S1) = 1) and CharInSet(S1[1], DIGITS) then begin
        Dig := S1; Result := S2;
    end
    else
        if (Length(S2) = 1) and CharInSet(S2[1], DIGITS) then begin
            Dig := S2;
            Result := S1;
        end
        else
            if Length(S1) <= Length(S2) then
                Result := S1
            else
                Result := S2;
    end;
  if Pos('/', Result) > 0 then begin
    Result := '';
    Exit;
  end;

  // when DXCC.pas (DXCC support) is extracting the prefix, the trailing letters
  // are NOT removed. This allows longer prefixes to be recognized.
  // (e.g. The call RC2FX has a prefix RC2F, which is Kaliningrad.
  // if the trailing 'F' is removed, the prefix matches European Russia)
  if not DeleteTrailingLetters then
    Exit;

  //delete trailing letters, retain at least 2 chars
  for p:= Length(Result) downto 3 do
    if CharInSet(Result[p], DIGITS) then
      Break
    else
      Delete(Result, p, 1);

  //ensure trailing digit
  if not CharInSet(Result[Length(Result)], DIGITS) then
    Result := Result + '0';
  //replace digit
  if Dig <> '' then
    Result[Length(Result)] := Dig[1];

  Result := Copy(Result, 1, 5);
end;

initialization
  // Compile callsign regex only once at startup; free automatically.
  CallsignRegEx := TPerlRegEx.Create();
  CallsignRegEx.RegEx:= '(([0-9][A-Z])|([A-Z]{1,2}))[0-9][A-Z0-9]*[A-Z]';
  CallsignRegEx.Study;

finalization
  CallsignRegEx.Free;

end.
