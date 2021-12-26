//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit CallLst;

interface

uses
  SysUtils, Classes, Ini, AnsiStrings;

procedure LoadCallList;
function PickCall: string;

var
  Calls: TStringList;




implementation


function CompareCalls(Item1, Item2: Pointer): Integer;
begin
  Result := AnsiStrings.StrComp(PAnsiChar(Item1), PAnsiChar(Item2));
end;

procedure LoadCallList;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/';
  CHRCOUNT = Length(Chars);
  INDEXSIZE = Sqr(CHRCOUNT) + 1;
  INDEXBYTES = INDEXSIZE * SizeOf(Integer);
var
  i: integer;

  FileName: string;
  FFileSize: integer;

  FIndex: array[0..INDEXSIZE-1] of integer;
  Data: AnsiString;
  CL: TStringList;
  S: string;
begin
  Calls.Clear;

  FileName := ExtractFilePath(ParamStr(0)) + 'Master.dta';
  if not FileExists(FileName) then Exit;

  with TFileStream.Create(FileName, fmOpenRead) do
    try
      FFileSize := Size;
      if FFileSize < INDEXBYTES then Exit;
      ReadBuffer(FIndex, INDEXBYTES);

      if (FIndex[0] <> INDEXBYTES) or (FIndex[INDEXSIZE-1] <> FFileSize)
        then Exit;
      SetLength(Data, Size - Position);
      ReadBuffer(Data[1], Length(Data));
    finally
      Free;
    end;

   S := StringReplace(string(Data), #00, #09, [rfReplaceAll]);

   CL := TStringList.Create();
   try
      CL.Delimiter := #09;
      CL.StrictDelimiter := True;
      CL.DelimitedText := S;

      Calls.Duplicates := dupIgnore;
      Calls.Sorted := True;
      for i := 0 to CL.Count - 1 do begin
         S := CL[i];
         Calls.Add(S);
      end;
   finally
      CL.Free();
   end;
end;


function PickCall: string;
var
  Idx: integer;
begin
  if Calls.Count = 0 then begin Result := 'P29SX'; Exit; end;

  Idx := Random(Calls.Count);
  Result := Calls[Idx];

  if Ini.RunMode = rmHst then Calls.Delete(Idx);
end;


initialization
  Calls := TStringList.Create;

finalization
  Calls.Free;

end.

