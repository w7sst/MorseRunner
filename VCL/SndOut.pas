//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SndOut;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  BaseComp, SndTypes, SndCustm, Math, sdl;

type
  TAlSoundOut = class(TCustomSoundInOut)
  private
    FOnBufAvailable: TNotifyEvent;
    FCloseWhenDone: boolean;

    procedure CheckErr;
    function  NextEmptyBuffer: PWaveBuffer;
    procedure Unprepare(Buf: PWaveBuffer);
  protected
    procedure BufferDone(Buf : PWaveBuffer); override;
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

procedure Register;



implementation

procedure Register;
begin
  RegisterComponents('Al', [TAlSoundOut]);
end;


{ TAlSoundOut }

//------------------------------------------------------------------------------
//                              Err handling
//------------------------------------------------------------------------------
procedure TAlSoundOut.CheckErr;
//var
//  Buf: array [0..MAXERRORLENGTH-1] of Char;
begin
//  if rc = MMSYSERR_NOERROR then Exit;
//
//  if waveOutGetErrorText(rc, Buf, MAXERRORLENGTH) = MMSYSERR_NOERROR
//    then Err(Buf)
//    else Err('Unknown error: ' + IntToStr(rc));
end;






//------------------------------------------------------------------------------
//                               start/stop
//------------------------------------------------------------------------------
procedure TAlSoundOut.Start;
var
  i: integer;
begin
  //open device
  //rc := waveOutOpen(@DeviceHandle, DeviceID, @WaveFmt, GetThreadID, 0, CALLBACK_THREAD);
  Writeln('SoundOut.Start');
  CheckErr;

   SDL_PauseAudio(0);
   
  //send all buffers to the player
  if Assigned(FOnBufAvailable) then
    for i:=0 to Length(Buffers)-1 do
      begin
	Buffers[i].used := 0;
	FOnBufAvailable(Self);
      end;
end;


procedure TAlSoundOut.Stop;
var
  i: integer;
begin
  //stop playback
  //rc := waveOutReset(DeviceHandle);
  Writeln('SoundOut.Stop');
  CheckErr;

   SDL_PauseAudio(1);
   
  for i:=0 to Length(Buffers)-1 do Unprepare(@Buffers[i]);
  //close device
  //rc := waveOutClose(DeviceHandle);
  CheckErr;
end;








//------------------------------------------------------------------------------
//                                Buffers
//------------------------------------------------------------------------------
function  TAlSoundOut.NextEmptyBuffer: PWaveBuffer;
begin
  //for i:=0 to Length(Buffers)-1 do
     //if (Buffers[i].Hdr.dwFlags and (WHDR_INQUEUE or WHDR_PREPARED)) = 0 thne
  if (Buffers[0].used = 0) then
    begin Result := @Buffers[0]; Exit; end;

  //Result := nil;
  Err('Output buffers full');

end;



procedure TAlSoundOut.Unprepare(Buf: PWaveBuffer);
begin
  //Writeln('unprepare used = ', Buf.used);
  Inc(FBufsDone);
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

  //Writeln('PutData ', High(Data), ' ', Length(Data));

  Buf.len := Length(Data);
  Buf.used := 1;

  // This is Windows crap .. excise!
  //fill header
  //FillChar(Buf.Hdr, SizeOf(TWaveHdr), 0);
  //with Buf.Hdr do
  //  begin
  //  lpData := @Buf.Data[0];
  //  dwBufferLength := Length(Buf.Data) * SizeOf(SmallInt);
  //  dwUser := DWORD(Buf);
  //  end;
  //
  ////send buffer
  //rc := waveOutPrepareHeader(DeviceHandle, @Buf.Hdr, SizeOf(TWaveHdr));
  //CheckErr;
  //rc := waveOutWrite(DeviceHandle, @Buf.Hdr, SizeOf(TWaveHdr));
  //CheckErr;

   Inc(FBufsAdded);
end;





//------------------------------------------------------------------------------
//                              events
//------------------------------------------------------------------------------
procedure TAlSoundOut.BufferDone(Buf : PWaveBuffer);
begin
  Unprepare(Buf);

  if FCloseWhenDone and (FBufsDone = FBufsAdded)
    then Enabled := false
  else if Assigned(FOnBufAvailable) then FOnBufAvailable(Self);

end;



procedure TAlSoundOut.Purge;
begin
  Stop; Start;
end;



end.
