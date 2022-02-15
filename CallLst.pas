//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit CallLst;

interface

uses
  SysUtils, Classes, Ini, Calls;

procedure LoadCallList;
function PickCall: string;
function PickCall2: TCall;

var
  Calls: array[0..2] of TCallList;




implementation

procedure LoadCallList;
begin
   Calls[0].LoadFromMaster();
   Calls[1].LoadFromFile('DIC_ALLJA.DAT');
   Calls[2].LoadFromFile('DIC_ACAG.DAT');
end;


function PickCall: string;
var
  Idx: integer;
  O: TCall;
  N: Integer;
begin
  N := Ini.SimContest;

  if Calls[N].Count = 0 then begin Result := 'P29SX'; Exit; end;

  Idx := Random(Calls[N].Count);
  O := Calls[N][Idx];
  Result := O.Callsign;

  if Ini.RunMode = rmHst then Calls[N].Delete(Idx);
end;

function PickCall2: TCall;
var
  Idx: integer;
  O: TCall;
  N: Integer;
begin
  N := Ini.SimContest;

  if Calls[N].Count = 0 then begin Result := nil; Exit; end;

  Idx := Random(Calls[N].Count);
  O := TCall.Create();
  O.Callsign := Calls[N][Idx].Callsign;
  O.Number := Calls[N][Idx].Number;

  Result := O;

  if Ini.RunMode = rmHst then Calls[N].Delete(Idx);
end;

initialization
  Calls[0] := TCallList.Create;
  Calls[1] := TCallList.Create;
  Calls[2] := TCallList.Create;

finalization
  Calls[0].Free;
  Calls[1].Free;
  Calls[2].Free;

end.

