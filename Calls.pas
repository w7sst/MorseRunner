unit Calls;

interface

uses
  SysUtils, Windows, Classes,
  Generics.Collections, Generics.Defaults;

type
  TCall = class(TObject)
    Callsign: string;
    Number: string;
  public
    constructor Create();
  end;

  TCallList = class(TObjectList<TCall>)
  public
    constructor Create(OwnsObjects: Boolean = True);
    procedure LoadFromFile(filename: string);
    procedure LoadFromMaster();
  end;


implementation

constructor TCall.Create();
begin
   Callsign := '';
   Number := '';
end;

constructor TCallList.Create(OwnsObjects: Boolean);
begin
   Inherited Create(OwnsObjects);
end;

procedure TCallList.LoadFromFile(filename: string);
var
   i: Integer;
   slFile: TStringList;
   slLine: TStringList;
   O: TCall;
begin
   slFile := TStringList.Create();
   slLine := TStringList.Create();
   slLine.Delimiter := #09;
   slLine.StrictDelimiter := True;
   try
      Clear();

      filename := ExtractFilePath(ParamStr(0)) + filename;
      slFile.LoadFromFile(filename);
      slFile.Sort();

      for i := 0 to slFile.Count - 1 do begin
         slLine.DelimitedText := slFile[i];

         O := TCall.Create();
         O.Callsign := slLine[0];
         O.Number := slLine[1];
         Add(O);
      end;

   finally
      slFile.Free();
      slLIne.Free();
   end;
end;

procedure TCallList.LoadFromMaster();
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
  O: TCall;
begin
  Clear;

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
      CL.Sort();

      for i := 0 to CL.Count - 1 do begin
         S := CL[i];

         O := TCall.Create();
         O.Callsign := S;
         Add(O);
      end;
   finally
      CL.Free();
   end;
end;

end.
