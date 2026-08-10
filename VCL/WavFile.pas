//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit WavFile;

//TSingleArray input and output buffers are normalized: Abs() <= 32767

//to do: direct read/write mmio buffer like in lowpass.c MS demo (sdk_Graphics_AUDIO_lowpass.exe)
//to do: access buffers by pointer, not by index
//to do: read non-PCM files, convert from different sampling rates via ACM


interface

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF MSWINDOWS}
  Windows, Messages, MMSystem,
  {$ENDIF}
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  SndTypes;

type
  TByteArray = array of byte;

  {$IFNDEF MSWINDOWS}
  //the 16-byte PCM header as it is laid out in a RIFF 'fmt ' chunk; stands in
  //for MMSystem's TPcmWaveFormat, whose fields are referenced the same way
  TWaveFormatPCM = packed record
    wf: packed record
      wFormatTag:      Word;
      nChannels:       Word;
      nSamplesPerSec:  LongWord;
      nAvgBytesPerSec: LongWord;
      nBlockAlign:     Word;
      end;
    wBitsPerSample: Word;
    end;

  TFourCC = array[0..3] of AnsiChar;
  {$ENDIF}

  TAlWavFile = class(TComponent)
  private
    {$IFDEF MSWINDOWS}
    ckInfoRIFF, ckInfo: TMmckInfo;
    WaveFmt: TPcmWaveFormat;
    rc: HMMIO;
    FHandle: HMMIO;
    {$ELSE}
    WaveFmt: TWaveFormatPCM;
    FStream: TFileStream;
    FDataOffset: Int64;   //file offset of the 'data' chunk payload
    FDataSize: LongWord;  //size of the 'data' chunk payload, in bytes
    FDataSizePos: Int64;  //file offset of the 'data' chunk size field
    FRiffSizePos: Int64;  //file offset of the 'RIFF' chunk size field
    {$ENDIF}

    FFileName: TFileName;
    FIsOpen: boolean;
    FStereo: boolean;
    FSamplesPerSec: LongWord;
    FBytesPerSample: LongWord;
    FAlignBits: integer;
    FSampleCnt: LongWord;
    FLData: TSingleArray;
    FRData: TSingleArray;
    FWriteMode: boolean;
    FInfo: TStrings;
    FCurrentSample: LongWord;

    procedure SetBytesPerSample(const Value: LongWord);
    procedure SetSamplesPerSec(const Value: LongWord);
    procedure SetStereo(const Value: boolean);
    procedure InfoChanging(Sender: TObject);
    procedure SetInfo(const Value: TStrings);
    procedure SetFileName(const Value: TFileName);
    {$IFNDEF MSWINDOWS}
    procedure ParseInfo(Data: AnsiString);
    {$ENDIF}
  protected
    procedure ChkErr;
    procedure ErrIf(IsErr: boolean; Msg: string);
    procedure ChkNotOpen;
    procedure ReadInfo;
    procedure WriteInfo;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenRead;
    procedure OpenWrite;
    procedure Seek(SampleNo: LongWord);
    procedure Read(ASampleCnt: LongWord);
    function  ReadTo(ALData, ARData: PSingle; ASampleCnt: LongWord): LongWord;
    procedure Write;
    procedure WriteFrom(ALData, ARData: PSingle; ASampleCnt: LongWord);
    procedure NormalizeData;
    procedure Close;

    property SampleCnt: LongWord read FSampleCnt;
    property CurrentSample: LongWord read FCurrentSample;
    property IsOpen: boolean read FIsOpen;
    property LData: TSingleArray read FLData write FLData;
    property RData: TSingleArray read FRData write FRData;
  published
    property FileName : TFileName read FFileName write SetFileName;
    property Stereo: boolean read FStereo write SetStereo default false;
    property SamplesPerSec: LongWord read FSamplesPerSec write SetSamplesPerSec default 11025;
    property BytesPerSample: LongWord read FBytesPerSample write SetBytesPerSample default 2;
    property Info: TStrings read FInfo write SetInfo;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Snd', [TAlWavFile]);
end;

{ TAlWavFile }

//------------------------------------------------------------------------------
//                             create/destroy
//------------------------------------------------------------------------------

constructor TAlWavFile.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FBytesPerSample := 2;
  FSamplesPerSec := 11025;
  Stereo := false;

  FInfo := TStringList.Create;
  TStringList(FInfo).OnChanging := InfoChanging;
end;

destructor TAlWavFile.Destroy;
begin
  FInfo.Free;
  inherited Destroy;
end;






//------------------------------------------------------------------------------
//                               Open/Close/Seek
//------------------------------------------------------------------------------

{$IFDEF MSWINDOWS}
//==============================================================================
//                        Win32 mmio implementation
//==============================================================================

procedure TAlWavFile.OpenRead;
begin
  ErrIf(FIsOpen, 'File already open');

  FWriteMode := false;
  FCurrentSample := 0;

  //open
  FHandle := mmioOpen(pchar(FFileName), nil, MMIO_READ or MMIO_ALLOCBUF or MMIO_DENYWRITE);
  ErrIf(FHandle = 0, 'Unable to open file');
  try
    //go to wav section
    ckInfoRiff.fccType := mmioStringToFOURCCA('WAVE', 0);
    rc := mmioDescend(FHandle, @ckInfoRIFF, nil, MMIO_FINDRIFF);
    ChkErr;

    //read Info strings
    ReadInfo;

    //go to format header
    ckInfo.ckid := mmioStringToFOURCCA('fmt ', 0);
    rc := mmioDescend(FHandle, @ckInfo, @ckInfoRIFF, MMIO_FINDCHUNK);
    ChkErr;
    ErrIf(ckInfo.cksize < SizeOf(TPcmWaveFormat), 'Invalid header size');
    //read header
    rc := mmioRead(FHandle, @WaveFmt, SizeOf(TPcmWaveFormat));
    ErrIf(rc <> SizeOf(TPcmWaveFormat), 'Unable to read header');
    ErrIf(WaveFmt.wf.wFormatTag <> WAVE_FORMAT_PCM, 'Unsupported compression method');
    //store parameters
    FStereo := WaveFmt.wf.nChannels = 2;
    FSamplesPerSec := WaveFmt.wf.nSamplesPerSec;
    FBytesPerSample := WaveFmt.wBitsPerSample shr 3;

    case WaveFmt.wf.nBlockAlign of
      1: FAlignBits := 0;
      2: FAlignBits := 1;
      4: FAlignBits := 2;
      end;

    //go to data
    rc := mmioAscend(FHandle, @ckInfo, 0);
    ChkErr;
    ckInfo.ckid := mmioStringToFOURCCA('data', 0);
    rc := mmioDescend(FHandle, @ckInfo, @ckInfoRiff, MMIO_FINDCHUNK);
    ChkErr;

    FSampleCnt := ckInfo.ckSize shr FAlignBits;
  except
    mmioClose(FHandle, 0);
    raise;
  end;

  FIsOpen := true;
end;


procedure TAlWavFile.OpenWrite;
begin
  ErrIf(FIsOpen, 'File already open');

  FWriteMode := true;
  FCurrentSample := 0;

  //open
  FHandle := mmioOpen(pchar(FFileName), nil, MMIO_CREATE or MMIO_ALLOCBUF or MMIO_WRITE or MMIO_DENYWRITE);
  ErrIf(FHandle = 0, 'Unable to open file');
  try
    //fill WaveFmt
    with WaveFmt.wf do
      begin
      wFormatTag := WAVE_FORMAT_PCM;
      if FStereo
        then nChannels := 2
        else nChannels := 1;
      nSamplesPerSec := FSamplesPerSec;
      nAvgBytesPerSec := FSamplesPerSec shl FAlignBits;
      nBlockAlign := 1  shl FAlignBits;
      WaveFmt.wBitsPerSample := (16 shl FAlignBits) shr nChannels;
      end;

    ckInfoRIFF.fccType := mmioStringToFOURCCA('WAVE', 0);
    rc := mmioCreateChunk(FHandle, @ckInfoRIFF, MMIO_CREATERIFF);
    ChkErr;

    //save Info strings
    {!}//WriteInfo;

    ckInfo.ckId := mmioStringToFOURCCA('fmt ', 0);
    ckInfo.ckSize := SizeOf(TPcmWaveFormat);
    rc := mmioCreateChunk(FHandle, @ckInfo, 0);
    ChkErr;
    rc := mmioWrite(FHandle, @WaveFmt, SizeOf(TPcmWaveFormat));
    ErrIf(rc <> SizeOf(TPcmWaveFormat), 'WAV write error');

    rc := mmioAscend(FHandle, @ckInfo, 0);
    ChkErr;

    ckInfo.ckid := mmioStringToFOURCCA('data', 0);
    //ckInfo.ckSize := 0;
    rc := mmioCreateChunk(FHandle, @ckInfo, 0);
    ChkErr;
  except
    mmioClose(FHandle, 0);
    raise;
  end;

  FSampleCnt := 0;
  FIsOpen := true;
end;


procedure TAlWavFile.Close;
begin
  ErrIf(not FIsOpen, 'File not open');

  if FWriteMode then
    begin
    //ascend from 'data'
    rc := mmioAscend(FHandle, @ckInfo, 0);
    {ChkErr;}

    {!}
    if FWriteMode then WriteInfo;

    //ascend from 'RIFF'
    rc := mmioAscend(FHandle, @ckInfoRiff, 0);
    {ChkErr;}
    end;

  rc := mmioClose(FHandle, 0);
  {ChkErr;}

  FIsOpen := false;
  FCurrentSample := 0;
end;


procedure TAlWavFile.Seek(SampleNo: LongWord);
var
  NewPos: integer;
begin
  ErrIf(not IsOpen, 'File not open');
  //ErrIf(FWriteMode, 'Cannot seek in write mode');
  ErrIf(SampleNo > FSampleCnt, 'Invalid Seek position');

  NewPos := ckInfo.dwDataOffset + (SampleNo shl FAlignBits);

  rc := mmioSeek(FHandle, NewPos, SEEK_SET);
  ErrIf(rc <> NewPos, 'WAV seek failed');

  FCurrentSample := SampleNo;
end;

{$ELSE}
//==============================================================================
//                     Stream-based RIFF implementation
//
// Replaces the Win32 mmio chunk API. Only what this application needs is
// supported: a single PCM 'fmt ' chunk, one 'data' chunk, and an optional
// LIST/INFO chunk. Chunk sizes that are not known until Close are written as
// placeholders and patched afterwards.
//==============================================================================

function ReadTag(S: TStream): TFourCC;
begin
  if S.Read(Result, 4) <> 4 then Result := #0#0#0#0;
end;


procedure WriteTag(S: TStream; const Tag: AnsiString);
var
  FourCC: TFourCC;
begin
  Move(Tag[1], FourCC, 4);
  S.WriteBuffer(FourCC, 4);
end;


function SameTag(const A: TFourCC; const B: AnsiString): boolean;
begin
  Result := (A[0] = B[1]) and (A[1] = B[2]) and (A[2] = B[3]) and (A[3] = B[4]);
end;


procedure TAlWavFile.OpenRead;
var
  Tag: TFourCC;
  ChunkSize: LongWord;
  Next: Int64;
  ListData: AnsiString;
  FmtFound, DataFound: boolean;
begin
  ErrIf(FIsOpen, 'File already open');

  FWriteMode := false;
  FCurrentSample := 0;

  FStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
  try
    ErrIf(not SameTag(ReadTag(FStream), 'RIFF'), 'Not a RIFF file');
    FStream.Seek(Int64(4), soCurrent);   //RIFF size, not needed
    ErrIf(not SameTag(ReadTag(FStream), 'WAVE'), 'Not a WAVE file');

    FmtFound := false;
    DataFound := false;
    FInfo.Clear;

    //walk the top-level chunks
    while FStream.Position + 8 <= FStream.Size do
      begin
      Tag := ReadTag(FStream);
      FStream.ReadBuffer(ChunkSize, 4);
      //chunks are word aligned
      Next := FStream.Position + ChunkSize + (ChunkSize and 1);

      if SameTag(Tag, 'fmt ') then
        begin
        ErrIf(ChunkSize < SizeOf(TWaveFormatPCM), 'Invalid header size');
        FStream.ReadBuffer(WaveFmt, SizeOf(TWaveFormatPCM));
        ErrIf(WaveFmt.wf.wFormatTag <> 1 {WAVE_FORMAT_PCM},
              'Unsupported compression method');
        FmtFound := true;
        end

      else if SameTag(Tag, 'data') then
        begin
        FDataOffset := FStream.Position;
        //a zero size, or a file truncated mid-recording, means "to end of file"
        if (ChunkSize = 0) or (FDataOffset + ChunkSize > FStream.Size) then
          ChunkSize := LongWord(FStream.Size - FDataOffset);
        FDataSize := ChunkSize;
        DataFound := true;
        Next := FDataOffset + ChunkSize + (ChunkSize and 1);
        end

      else if SameTag(Tag, 'LIST') and (ChunkSize > 4) then
        begin
        if SameTag(ReadTag(FStream), 'INFO') then
          begin
          SetLength(ListData, ChunkSize - 4);
          if Length(ListData) > 0 then
            FStream.ReadBuffer(ListData[1], Length(ListData));
          ParseInfo(ListData);
          end;
        end;

      FStream.Position := Next;
      end;

    ErrIf(not FmtFound, 'WAV format chunk not found');
    ErrIf(not DataFound, 'WAV data chunk not found');

    //store parameters
    FStereo := WaveFmt.wf.nChannels = 2;
    FSamplesPerSec := WaveFmt.wf.nSamplesPerSec;
    FBytesPerSample := WaveFmt.wBitsPerSample shr 3;

    case WaveFmt.wf.nBlockAlign of
      1: FAlignBits := 0;
      2: FAlignBits := 1;
      4: FAlignBits := 2;
      end;

    FSampleCnt := FDataSize shr FAlignBits;
    FStream.Position := FDataOffset;
  except
    FreeAndNil(FStream);
    raise;
  end;

  FIsOpen := true;
end;


procedure TAlWavFile.OpenWrite;
var
  Val: LongWord;
begin
  ErrIf(FIsOpen, 'File already open');

  FWriteMode := true;
  FCurrentSample := 0;

  FStream := TFileStream.Create(FFileName, fmCreate);
  try
    //fill WaveFmt
    with WaveFmt.wf do
      begin
      wFormatTag := 1;  //WAVE_FORMAT_PCM
      if FStereo
        then nChannels := 2
        else nChannels := 1;
      nSamplesPerSec := FSamplesPerSec;
      nAvgBytesPerSec := FSamplesPerSec shl FAlignBits;
      nBlockAlign := 1 shl FAlignBits;
      WaveFmt.wBitsPerSample := (16 shl FAlignBits) shr nChannels;
      end;

    // 'RIFF' <size> 'WAVE'
    WriteTag(FStream, 'RIFF');
    FRiffSizePos := FStream.Position;
    Val := 0;
    FStream.WriteBuffer(Val, 4);            //patched by Close
    WriteTag(FStream, 'WAVE');

    // 'fmt ' chunk
    WriteTag(FStream, 'fmt ');
    Val := SizeOf(TWaveFormatPCM);
    FStream.WriteBuffer(Val, 4);
    FStream.WriteBuffer(WaveFmt, SizeOf(TWaveFormatPCM));

    // 'data' chunk header; the samples follow
    WriteTag(FStream, 'data');
    FDataSizePos := FStream.Position;
    Val := 0;
    FStream.WriteBuffer(Val, 4);            //patched by Close
    FDataOffset := FStream.Position;
  except
    FreeAndNil(FStream);
    raise;
  end;

  FDataSize := 0;
  FSampleCnt := 0;
  FIsOpen := true;
end;


procedure TAlWavFile.Close;
var
  Pad: Byte;
  Val: LongWord;
  TotalSize: Int64;
begin
  ErrIf(not FIsOpen, 'File not open');

  try
    if FWriteMode then
      begin
      FStream.Position := FStream.Size;

      //chunks are word aligned
      if Odd(FDataSize) then
        begin
        Pad := 0;
        FStream.WriteBuffer(Pad, 1);
        end;

      WriteInfo;
      TotalSize := FStream.Size;

      //patch the placeholder sizes now that they are known
      Val := FDataSize;
      FStream.Position := FDataSizePos;
      FStream.WriteBuffer(Val, 4);

      Val := LongWord(TotalSize - (FRiffSizePos + 4));
      FStream.Position := FRiffSizePos;
      FStream.WriteBuffer(Val, 4);
      end;
  finally
    FreeAndNil(FStream);
    FIsOpen := false;
    FCurrentSample := 0;
  end;
end;


procedure TAlWavFile.Seek(SampleNo: LongWord);
begin
  ErrIf(not IsOpen, 'File not open');
  ErrIf(SampleNo > FSampleCnt, 'Invalid Seek position');

  FStream.Position := FDataOffset + (Int64(SampleNo) shl FAlignBits);

  FCurrentSample := SampleNo;
end;

{$ENDIF}







//------------------------------------------------------------------------------
//                                   Read
//------------------------------------------------------------------------------

procedure TAlWavFile.Read(ASampleCnt: LongWord);
begin
  //free output arrays
  FLData := nil;
  FRData := nil;
  if ASampleCnt = 0 then Exit;

  //allocate output arrays
  SetLength(FLData, ASampleCnt);
  try
    if FStereo
      then
        begin
        SetLength(FRData, ASampleCnt);
        ASampleCnt := ReadTo(@FLData[0], @FRData[0], ASampleCnt);
        end
      else
        ASampleCnt := ReadTo(@FLData[0], nil, ASampleCnt);
    //resize buffers to reflect the # of samples actually read
    SetLength(FLData, ASampleCnt);
    if FStereo then SetLength(FRData, ASampleCnt);
  except
    FRData := nil;
    FLData := nil;
    raise;
  end;
end;


function TAlWavFile.ReadTo(ALData, ARData: PSingle; ASampleCnt: LongWord): LongWord;
var
  Buf: TByteArray;
  DataType: integer;
  i: integer;
  {$IFNDEF MSWINDOWS}
  BytesLeft: Int64;
  {$ENDIF}
begin
  ErrIf(not IsOpen, 'File not open');
  ErrIf(FWriteMode, 'File open in write mode');
  ErrIf(ALData = nil, 'Left buffer not supplied');
  ErrIf(Stereo and (ARData = nil), 'Right buffer not supplied');

  //allocate buffer

  //to do: direct read from the mmio buffer like in lowpass.c MS demo
  //(sdk_Graphics_AUDIO_lowpass.exe)

  SetLength(Buf, ASampleCnt shl FAlignBits);
  try
    //read
    {$IFDEF MSWINDOWS}
    ASampleCnt := mmioRead(FHandle, @Buf[0], Length(Buf));
    ErrIf(Integer(ASampleCnt) = -1, 'WAV read error');
    //ErrIf(ASampleCnt = 0, 'End of file');
    {$ELSE}
    //never read past the end of the data chunk
    BytesLeft := (FDataOffset + FDataSize) - FStream.Position;
    if BytesLeft < 0 then BytesLeft := 0;
    if BytesLeft > Length(Buf) then BytesLeft := Length(Buf);
    ASampleCnt := LongWord(FStream.Read(Buf[0], BytesLeft));
    {$ENDIF}
    ASampleCnt := ASampleCnt shr FAlignBits;

    //convert data

    if FStereo
      then DataType := BytesPerSample shl 2
      else DataType := BytesPerSample;

    if ASampleCnt > 0 then
      case DataType of
        1: //8 bit mono
          for i:=0 to ASampleCnt-1 do
            begin
            //to do: access Buf by pointer

            //Buf[i]: byte          = 0..255
            //Integer(Buf[i])-128   = -128..127
            //shl 8                 = -32768..32512

            ALData^ := (Integer(Buf[i]) - 128) shl 8;
            Inc(ALData);
            end;

        2: //16 bit mono
          for i:=0 to ASampleCnt-1 do
            begin
            ALData^ := PSmallInt(@Buf[i shl 1])^;
            Inc(ALData);
            end;

        4: //8 bit stereo
          for i:=0 to ASampleCnt-1 do
            begin
            ALData^ := (Integer(Buf[i shl 1]) - 128) shl 8;
            ARData^ := (Integer(Buf[i shl 1] + 1) - 128) shl 8;
            Inc(ALData);
            Inc(ARData);
            end;

        8: //16 bit stereo
          for i:=0 to ASampleCnt-1 do
            begin
            ALData^ := PSmallInt(@Buf[i shl 2])^;
            ARData^ := PSmallInt(@Buf[(i shl 2) + 2])^;
            Inc(ALData);
            Inc(ARData);
            end;
        end;
  finally
    Buf := nil;
  end;

  Inc(FCurrentSample, ASampleCnt);
  Result := ASampleCnt;
end;






//------------------------------------------------------------------------------
//                                   Write
//------------------------------------------------------------------------------

procedure TAlWavFile.Write;
begin
  if Length(FLData) = 0 then Exit;
  if FRData = nil
    then WriteFrom(@FLData[0], nil, Length(FLData))
    else WriteFrom(@FLData[0], @FRData[0], Length(FLData));
end;


procedure TAlWavFile.WriteFrom(ALData, ARData: PSingle; ASampleCnt: LongWord);
var
  Buf: TByteArray;
  DataType: integer;
  i: integer;
begin
  ErrIf(not IsOpen, 'File not open');
  ErrIf(not FWriteMode, 'File open in read mode');
  ErrIf(ALData = nil, 'Left buffer not supplied');
  ErrIf(Stereo and (ARData = nil), 'Right buffer not supplied');

  //allocate buffer

  //to do: direct read from the mmio buffer like in lowpass.c MS demo
  //(sdk_Graphics_AUDIO_lowpass.exe)

  SetLength(Buf, ASampleCnt shl FAlignBits);
  try
    if FStereo
      then DataType := BytesPerSample shl 2
      else DataType := BytesPerSample;

    case DataType of
      1: //8 bit mono
        for i:=0 to ASampleCnt-1 do
          begin
          //ALData^    = -32767..32767 Single
          //Round()    = -32767..32767 integer
          //shr 8      = -128..127

          Buf[i] := (Round(ALData^) shr 8) + 128;
          Inc(ALData);
          end;

      2: //16 bit mono
        for i:=0 to ASampleCnt-1 do
          begin
          PSmallInt(@Buf[i shl 1])^ := Round(ALData^);
          Inc(ALData);
          end;

      4: //8 bit stereo
        for i:=0 to ASampleCnt-1 do
          begin
          Buf[i shl 1] := (Round(ALData^) shr 8) + 128;
          Buf[(i shl 1)+1] := (Round(ARData^) shr 8) + 128;
          Inc(ALData);
          Inc(ARData);
          end;

      8: //16 bit stereo
        for i:=0 to ASampleCnt-1 do
          begin
          PSmallInt(@Buf[i shl 2])^ := Round(ALData^);
          PSmallInt(@Buf[(i shl 2)+2])^ := Round(ARData^);
          Inc(ALData);
          Inc(ARData);
          end;
      end;

    //write
    {$IFDEF MSWINDOWS}
    rc := mmioWrite(FHandle, @Buf[0], Length(Buf));
    ErrIf(rc <> Length(Buf), 'WAV write error');
    {$ELSE}
    FStream.WriteBuffer(Buf[0], Length(Buf));
    Inc(FDataSize, LongWord(Length(Buf)));
    {$ENDIF}
    Inc(FSampleCnt, ASampleCnt);
    FCurrentSample := FSampleCnt;
  finally
    Buf := nil;
  end;
end;




//------------------------------------------------------------------------------
//                             Property get/set
//------------------------------------------------------------------------------

procedure TAlWavFile.SetBytesPerSample(const Value: LongWord);
begin
  ChkNotOpen;
  FBytesPerSample := Value;

  FAlignBits := FBytesPerSample shr 1;
  if FStereo then Inc(FAlignBits);
end;


procedure TAlWavFile.SetSamplesPerSec(const Value: LongWord);
begin
  ChkNotOpen;
  FSamplesPerSec := Value;
end;


procedure TAlWavFile.SetStereo(const Value: boolean);
begin
  ChkNotOpen;
  FStereo := Value;

  FAlignBits := FBytesPerSample shr 1;
  if FStereo then Inc(FAlignBits);
end;


procedure TAlWavFile.SetFileName(const Value: TFileName);
begin
  ChkNotOpen;
  FFileName := Value;
end;


procedure TAlWavFile.InfoChanging(Sender: TObject);
begin
 // ChkNotOpen;
end;


procedure TAlWavFile.SetInfo(const Value: TStrings);
begin
  FInfo.Assign(Value);
end;





//------------------------------------------------------------------------------
//                      Read/write LIST/INFO chunk
//------------------------------------------------------------------------------
{$IFDEF MSWINDOWS}

procedure TAlWavFile.WriteInfo;
var
  i: integer;
  InfName: string;
  InfValue: string;
  ckInfoLIST, ckInfoPiece: TMmckInfo;
begin
  //remove invalid info entries
  for i:= FInfo.Count-1 downto 0 do
    if (Length(FInfo[i]) < 6) or (FInfo[i][5] <> '=') then FInfo.Delete(i);
  //do not save empty info list
  if FInfo.Count = 0 then Exit;

  //create LIST chunk
  ckInfoLIST.fccType := mmioStringToFOURCCA('INFO', 0);
  rc := mmioCreateChunk(FHandle, @ckInfoLIST, MMIO_CREATELIST);
  ChkErr;

  //save info entries
  for i:= 0 to FInfo.Count-1 do
    begin
    InfName := Copy(FInfo[i], 1, 4);
    InfValue := Copy(FInfo[i], 6, MAXINT);
    //create subchunk
    ckInfoPiece.ckId := mmioStringToFOURCCA(PAnsiChar(AnsiString(InfName)), 0);
    ckInfoPiece.ckSize := Length(InfValue);
    rc := mmioCreateChunk(FHandle, @ckInfoPiece, 0);
    ChkErr;
    //save subchunk data
    rc := mmioWrite(FHandle, PAnsiChar(AnsiString(InfValue)), Length(InfValue));
    ErrIf(rc <> Length(InfValue), 'WAV write error');
    //exit subchunk
    rc := mmioAscend(FHandle, @ckInfoPiece, 0);
    ChkErr;
    end;

  //exit LIST
  rc := mmioAscend(FHandle, @ckInfoLIST, 0);
  ChkErr;
end;


procedure TAlWavFile.ReadInfo;
var
  Data: string;
  ckInfoLIST: TMmckInfo;
  InfName: string;
  InfValue: string;
  Len: integer;
begin
  FInfo.Clear;
  //descend into LIST/INFO
  ckInfoLIST.fccType := mmioStringToFOURCCA('INFO', 0);
  rc := mmioDescend(FHandle, @ckInfoLIST, @ckInfoRIFF, MMIO_FINDLIST);
  try
    if rc <> MMSYSERR_NOERROR then Exit;
    //read info
    SetLength(Data, ckInfoLIST.cksize - 4 {4-char list type});
    rc := mmioRead(FHandle, @Data[1], Length(Data));
    ErrIf(rc <> Length(Data), 'Unable to read header');
    //exit LIST
    rc := mmioAscend(FHandle, @ckInfoLIST, 0);
    ChkErr;
  finally
    //always rewind
    mmioSeek(FHandle, ckInfoRIFF.dwDataOffset + 4, SEEK_SET); 
  end;

  //parse info
  while Length(Data) > 8 {4 for chunk ID and 4 for length} do
    begin
    InfName := Copy(Data, 1, 4);
    Len := PInteger(@Data[5])^;
    InfValue := Copy(Data, 9, Len);
    Delete(Data, 1, 8+Len);
    if Copy(Data, 1, 1) = #0 then Delete(Data, 1, 1); //padded byte
    FInfo.Add(InfName + '=' + InfValue);
    end;
end;

{$ELSE}

procedure TAlWavFile.WriteInfo;
var
  i: integer;
  InfName: AnsiString;
  InfValue: AnsiString;
  Payload: TMemoryStream;
  Val: LongWord;
  Pad: Byte;
begin
  //remove invalid info entries
  for i:= FInfo.Count-1 downto 0 do
    if (Length(FInfo[i]) < 6) or (FInfo[i][5] <> '=') then FInfo.Delete(i);
  //do not save empty info list
  if FInfo.Count = 0 then Exit;

  //build the LIST payload first so that its size is known up front
  Payload := TMemoryStream.Create;
  try
    WriteTag(Payload, 'INFO');

    for i:= 0 to FInfo.Count-1 do
      begin
      InfName := AnsiString(Copy(FInfo[i], 1, 4));
      InfValue := AnsiString(Copy(FInfo[i], 6, MAXINT));

      WriteTag(Payload, InfName);
      Val := Length(InfValue);
      Payload.WriteBuffer(Val, 4);
      if Val > 0 then Payload.WriteBuffer(InfValue[1], Val);
      //sub-chunks are word aligned
      if Odd(Val) then
        begin
        Pad := 0;
        Payload.WriteBuffer(Pad, 1);
        end;
      end;

    WriteTag(FStream, 'LIST');
    Val := Payload.Size;
    FStream.WriteBuffer(Val, 4);
    FStream.WriteBuffer(Payload.Memory^, Payload.Size);
    if Odd(Val) then
      begin
      Pad := 0;
      FStream.WriteBuffer(Pad, 1);
      end;
  finally
    Payload.Free;
  end;
end;


//the LIST/INFO payload is collected by OpenRead while it walks the chunks
procedure TAlWavFile.ReadInfo;
begin
end;


procedure TAlWavFile.ParseInfo(Data: AnsiString);
var
  InfName: AnsiString;
  InfValue: AnsiString;
  Len: integer;
begin
  FInfo.Clear;

  while Length(Data) > 8 {4 for chunk ID and 4 for length} do
    begin
    InfName := Copy(Data, 1, 4);
    Len := PInteger(@Data[5])^;
    if (Len < 0) or (Len > Length(Data) - 8) then Break;
    InfValue := Copy(Data, 9, Len);
    Delete(Data, 1, 8+Len);
    if Copy(Data, 1, 1) = #0 then Delete(Data, 1, 1); //padded byte
    FInfo.Add(string(InfName) + '=' + string(InfValue));
    end;
end;

{$ENDIF}







//------------------------------------------------------------------------------
//                             Error checking
//------------------------------------------------------------------------------

procedure TAlWavFile.ChkErr;
{$IFDEF MSWINDOWS}
var
  Buf: array [0..MAXERRORLENGTH-1] of Char;
begin
  if rc = MMSYSERR_NOERROR then Exit;

  if waveInGetErrorText(rc, Buf, MAXERRORLENGTH) = MMSYSERR_NOERROR
    then raise Exception.Create(Buf)
    else raise Exception.Create('Unknown error: ' + IntToStr(rc));
end;
{$ELSE}
begin
  //stream I/O raises on failure, so there is no status code to check
end;
{$ENDIF}


procedure TAlWavFile.ErrIf(IsErr: boolean; Msg: string);
begin
  if IsErr then raise Exception.Create(Msg);
end;


procedure TAlWavFile.ChkNotOpen;
begin
  ErrIf(FIsOpen, 'Cannot change parameter when the file is open');
end;




procedure TAlWavFile.NormalizeData;
var
  i: integer;
  Mx: Single;
begin
  //find max in L
  Mx := 0;
  if FLData <> nil then
    for i:=0 to High(FLData) do
      if Abs(FLData[i]) > Mx then Mx := Abs(FLData[i]);
  //find max in R
  if FRData <> nil then
    for i:=0 to High(FRData) do
      if Abs(FRData[i]) > Mx then Mx := Abs(FRData[i]);
  //scale
  if Mx > 0 then
    begin
    Mx := 32767 / Mx;
    if FLData <> nil then
      for i:=0 to High(FLData) do FLData[i] := FLData[i] * Mx;
    if FRData <> nil then
      for i:=0 to High(FRData) do FRData[i] := FRData[i] * Mx;
    end;
end;


end.
