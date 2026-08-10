//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SndOut;

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF MSWINDOWS}
//==============================================================================
//                    Win32 waveOut implementation (Delphi)
//==============================================================================
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  MMSystem, SndTypes, SndCustm, Math;

type
  TAlSoundOut = class(TCustomSoundInOut)
  private
    FOnBufAvailable: TNotifyEvent;
    FCloseWhenDone: boolean;

    procedure CheckErr;
    function  NextEmptyBuffer: PWaveBuffer;
    procedure Unprepare(Buf: PWaveBuffer);
  protected
    procedure BufferDone(AHdr: PWaveHdr); override;
    procedure Start; override;
    procedure Stop; override;
  public
    function PutData(Data: TSingleArray): boolean;
    procedure Purge;
  published
    property Enabled;
    property DeviceID;
    property SamplesPerSec;
    property BufsAdded;
    property BufsDone;
    property BufCount;
    property CloseWhenDone: boolean read FCloseWhenDone write FCloseWhenDone default false;
    property OnBufAvailable: TNotifyEvent read FOnBufAvailable write FOnBufAvailable;
  end;

{$ELSE}
//==============================================================================
//                   PulseAudio implementation (FPC/Lazarus)
//==============================================================================
uses
  SysUtils, Classes, Controls, Forms, Math, SndTypes, SndCustm;

type
  TAlSoundOut = class(TCustomSoundInOut)
  private
    FOnBufAvailable: TNotifyEvent;
    FCloseWhenDone: boolean;
  protected
    procedure BufferDone(ABuf: PWaveBuffer); override;
    procedure Start; override;
    procedure Stop; override;
  public
    function PutData(Data: TSingleArray): boolean;
    procedure Purge;
  published
    property Enabled;
    property DeviceID;
    property SamplesPerSec;
    property BufsAdded;
    property BufsDone;
    property BufCount;
    property CloseWhenDone: boolean read FCloseWhenDone write FCloseWhenDone default false;
    property OnBufAvailable: TNotifyEvent read FOnBufAvailable write FOnBufAvailable;
  end;

{$ENDIF}

procedure Register;



implementation

procedure Register;
begin
  RegisterComponents('Al', [TAlSoundOut]);
end;

{$IFDEF MSWINDOWS}

{ TAlSoundOut }

//------------------------------------------------------------------------------
//                              Err handling
//------------------------------------------------------------------------------
procedure TAlSoundOut.CheckErr;
var
  Buf: array [0..MAXERRORLENGTH-1] of Char;
begin
  if rc = MMSYSERR_NOERROR then Exit;

  if waveOutGetErrorText(rc, Buf, MAXERRORLENGTH) = MMSYSERR_NOERROR
    then Err(Buf)
    else Err('Unknown error: ' + IntToStr(rc));
end;






//------------------------------------------------------------------------------
//                               start/stop
//------------------------------------------------------------------------------
procedure TAlSoundOut.Start;
var
  i: integer;
begin
  //open device
  rc := waveOutOpen(@DeviceHandle, DeviceID, @WaveFmt, GetThreadID, 0, CALLBACK_THREAD);
  CheckErr;

  //send all buffers to the player
  if Assigned(FOnBufAvailable) then
    for i:=0 to High(Buffers) do
      FOnBufAvailable(Self);
end;


procedure TAlSoundOut.Stop;
var
  i: integer;
begin
  //stop playback
  rc := waveOutReset(DeviceHandle);
  CheckErr;
  for i:=0 to High(Buffers) do Unprepare(@Buffers[i]);
  //close device
  rc := waveOutClose(DeviceHandle);
  CheckErr;
end;








//------------------------------------------------------------------------------
//                                Buffers
//------------------------------------------------------------------------------
function  TAlSoundOut.NextEmptyBuffer: PWaveBuffer;
var
  i: integer;
begin
  for i:=0 to High(Buffers) do
    if (Buffers[i].Hdr.dwFlags and (WHDR_INQUEUE or WHDR_PREPARED)) = 0 then
      begin Result := @Buffers[i]; Exit; end;

  Result := nil;
  //Err('Output buffers full');
end;



procedure TAlSoundOut.Unprepare(Buf: PWaveBuffer);
begin
    if (Buf.Hdr.dwFlags and WHDR_PREPARED) <> 0 then
      begin
      rc := WaveOutUnprepareHeader(DeviceHandle, @Buf.Hdr, SizeOf(TWaveHdr));
      Buf.Data := nil;
      Inc(FBufsDone);
      //CheckErr;
      end;
end;



function TAlSoundOut.PutData(Data: TSingleArray): boolean;
var
  Buf: PWaveBuffer;
  i: integer;
begin
  Result := false;
  if not Enabled then Exit;

  Buf := NextEmptyBuffer;
  Result := Buf <> nil;
  if not Result then Exit;

  //data to buffer  (Single -> SmallInt)
  Buf.Data := nil;
  SetLength(Buf.Data, Length(Data));
  for i:=0 to High(Data) do
    Buf.Data[i] := Max(-32767, Min(32767, Round(Data[i])));

  //fill header
  FillChar(Buf.Hdr, SizeOf(TWaveHdr), 0);
  with Buf.Hdr do
    begin
    lpData := @Buf.Data[0];
    dwBufferLength := Length(Buf.Data) * SizeOf(SmallInt);
    dwUser := DWORD(Buf);
    end;

  //send buffer
  rc := waveOutPrepareHeader(DeviceHandle, @Buf.Hdr, SizeOf(TWaveHdr));
  CheckErr;
  rc := waveOutWrite(DeviceHandle, @Buf.Hdr, SizeOf(TWaveHdr));
  CheckErr;

  Inc(FBufsAdded);
end;





//------------------------------------------------------------------------------
//                              events
//------------------------------------------------------------------------------
procedure TAlSoundOut.BufferDone(AHdr: PWaveHdr);
begin
  Unprepare(PWaveBuffer(AHdr.dwUser));

  if FCloseWhenDone and (FBufsDone = FBufsAdded)
    then Enabled := false
    else if Assigned(FOnBufAvailable) then FOnBufAvailable(Self);
end;



procedure TAlSoundOut.Purge;
begin
  Stop; Start;
end;

{$ELSE}

{ TAlSoundOut }

//------------------------------------------------------------------------------
//                               start/stop
//------------------------------------------------------------------------------
procedure TAlSoundOut.Start;
var
  i: integer;
begin
  OpenStream;

  //prime the queue: ask the application for one chunk per buffer
  if Assigned(FOnBufAvailable) then
    for i:=0 to High(Buffers) do
      FOnBufAvailable(Self);
end;


procedure TAlSoundOut.Stop;
begin
  //the writer thread has already been stopped by DoSetEnabled
  CloseStream;
  ResetQueue;
end;


//------------------------------------------------------------------------------
//                                Buffers
//------------------------------------------------------------------------------
function TAlSoundOut.PutData(Data: TSingleArray): boolean;
var
  Buf: PWaveBuffer;
  i: integer;
begin
  Result := false;
  if (not Enabled) or (Length(Buffers) = 0) then Exit;

  FLock.Acquire;
  try
    //no free slot: the sound server is still busy with what it has
    if FCount >= Length(Buffers) then Exit;
    Buf := @Buffers[FWriteIdx];
  finally
    FLock.Release;
  end;

  //filled outside the lock: this slot is not yet visible to the writer thread
  //data to buffer  (Single -> SmallInt)
  Buf.Data := nil;
  SetLength(Buf.Data, Length(Data));
  for i:=0 to High(Data) do
    Buf.Data[i] := SmallInt(Max(-32767, Min(32767, Round(Data[i]))));

  //publish the slot
  FLock.Acquire;
  try
    FWriteIdx := (FWriteIdx + 1) mod Length(Buffers);
    Inc(FCount);
  finally
    FLock.Release;
  end;

  Inc(FBufsAdded);
  FDataReady.SetEvent;
  Result := true;
end;


//------------------------------------------------------------------------------
//                              events
//------------------------------------------------------------------------------
//called on the main thread once the sound server has accepted a chunk
procedure TAlSoundOut.BufferDone(ABuf: PWaveBuffer);
begin
  Inc(FBufsDone);

  if FCloseWhenDone and (FBufsDone = FBufsAdded)
    then Enabled := false
    else if Assigned(FOnBufAvailable) then FOnBufAvailable(Self);
end;


procedure TAlSoundOut.Purge;
begin
  Enabled := false;
  Enabled := true;
end;

{$ENDIF}

end.
