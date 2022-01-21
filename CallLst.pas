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
  Calls: TCallList;




implementation

procedure LoadCallList;
begin
   if Ini.JaMode = False then begin
      Calls.LoadFromMaster();
   end
   else begin
      Calls.LoadFromFile('DIC_ALLJA.DAT');
   end;
end;


function PickCall: string;
var
  Idx: integer;
  O: TCall;
begin
  if Calls.Count = 0 then begin Result := 'P29SX'; Exit; end;

  Idx := Random(Calls.Count);
  O := Calls[Idx];
  Result := O.Callsign;

  if Ini.RunMode = rmHst then Calls.Delete(Idx);
end;

function PickCall2: TCall;
var
  Idx: integer;
  O: TCall;
begin
  if Calls.Count = 0 then begin Result := nil; Exit; end;

  Idx := Random(Calls.Count);
  O := TCall.Create();
  O.Callsign := Calls[Idx].Callsign;
  O.Number := Calls[Idx].Number;

  Result := O;

  if Ini.RunMode = rmHst then Calls.Delete(Idx);
end;

initialization
  Calls := TCallList.Create;

finalization
  Calls.Free;

end.

