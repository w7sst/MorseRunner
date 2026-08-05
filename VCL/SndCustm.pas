//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SndCustm;

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}

interface

{$IFDEF MSWINDOWS}
//==============================================================================
//                    Win32 waveOut implementation (Delphi)
//==============================================================================
uses
  Windows, Messages, SysUtils, Classes, Forms, SyncObjs, MMSystem, SndTypes;

type
  TCustomSoundInOut = class;

  TWaitThread = class(TThread)
    private
      Owner: TCustomSoundInOut;
      Msg: TMsg;
      procedure ProcessEvent;
    protected
      procedure Execute; override;
    public
    end;


  TCustomSoundInOut = class(TComponent)
  private
    FDeviceID: UINT;
    FEnabled : boolean;
    procedure SetDeviceID(const Value: UINT);
    procedure SetSamplesPerSec(const Value: LongWord);
    function  GetSamplesPerSec: LongWord;
    procedure SetEnabled(AEnabled: boolean);
    procedure DoSetEnabled(AEnabled: boolean);
    function GetBufCount: LongWord;
    procedure SetBufCount(const Value: LongWord);
  protected
    FThread: TWaitThread;
    rc: MMRESULT;
    DeviceHandle: HWAVEOUT;
    WaveFmt: TPCMWaveFormat;
    Buffers: array of TWaveBuffer;
    FBufsAdded: LongWord;
    FBufsDone: LongWord;

    procedure Loaded; override;
    procedure Err(Txt: string);
    function GetThreadID: THandle;

    //override these
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure BufferDone(AHdr: PWaveHdr); virtual; abstract;

    property Enabled: boolean read FEnabled write SetEnabled default false;
    property DeviceID: UINT read FDeviceID write SetDeviceID default WAVE_MAPPER;
    property SamplesPerSec: LongWord read GetSamplesPerSec write SetSamplesPerSec default 48000;
    property BufsAdded: LongWord read FBufsAdded;
    property BufsDone: LongWord read FBufsDone;
    property BufCount: LongWord read GetBufCount write SetBufCount;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

{$ELSE}
//==============================================================================
//                   PulseAudio implementation (FPC/Lazarus)
//
// Same public surface as the Win32 version above, but the waveOut callback
// model is replaced by a writer thread feeding a blocking pa_simple stream.
// Audio chunks handed to PutData are held in a ring of Buffers; the writer
// thread drains that ring and, after each chunk is accepted by the sound
// server, calls BufferDone on the main thread via Synchronize -- which is what
// asks the application for the next chunk.
//
// Pacing: pa_simple_write blocks once the server-side buffer is full, so the
// stream is opened with an explicit buffer_attr holding about AudioLatencyMs
// of audio. That is what keeps the simulation running at real time, the role
// the waveOut device plays on Windows.
//==============================================================================
uses
  SysUtils, Classes, Forms, SyncObjs, ctypes, SndTypes, SndPulse;

const
  WAVE_MAPPER = LongWord($FFFFFFFF);
  //amount of audio buffered by the sound server, in milliseconds
  AudioLatencyMs = 200;

type
  UINT = LongWord;

  TCustomSoundInOut = class;

  TWaitThread = class(TThread)
    private
      Owner: TCustomSoundInOut;
      procedure ProcessEvent;
    protected
      procedure Execute; override;
    public
    end;


  TCustomSoundInOut = class(TComponent)
  private
    FDeviceID: UINT;
    FEnabled : boolean;
    FSamplesPerSec: LongWord;
    procedure SetDeviceID(const Value: UINT);
    procedure SetSamplesPerSec(const Value: LongWord);
    function  GetSamplesPerSec: LongWord;
    procedure SetEnabled(AEnabled: boolean);
    procedure DoSetEnabled(AEnabled: boolean);
    function GetBufCount: LongWord;
    procedure SetBufCount(const Value: LongWord);
  protected
    FThread: TWaitThread;
    FStream: Ppa_simple;
    FLock: TCriticalSection;
    FDataReady: TEvent;
    FReadIdx, FWriteIdx, FCount: integer;
    FClosing: boolean;
    Buffers: array of TWaveBuffer;
    FBufsAdded: LongWord;
    FBufsDone: LongWord;

    procedure Loaded; override;
    procedure Err(Txt: string);

    //ring buffer, shared between the main thread and TWaitThread
    function  NextFullBuffer: PWaveBuffer;
    procedure ReleaseBuffer;
    procedure ResetQueue;

    procedure OpenStream;
    procedure CloseStream;

    //override these
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure BufferDone(ABuf: PWaveBuffer); virtual; abstract;

    property Enabled: boolean read FEnabled write SetEnabled default false;
    property DeviceID: UINT read FDeviceID write SetDeviceID default WAVE_MAPPER;
    property SamplesPerSec: LongWord read GetSamplesPerSec write SetSamplesPerSec default 48000;
    property BufsAdded: LongWord read FBufsAdded;
    property BufsDone: LongWord read FBufsDone;
    property BufCount: LongWord read GetBufCount write SetBufCount;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

{$ENDIF}


implementation

{$IFDEF MSWINDOWS}

{ TWaitThread }

//------------------------------------------------------------------------------
//                               TWaitThread
//------------------------------------------------------------------------------

procedure TWaitThread.Execute;
begin
  Priority := tpTimeCritical;

  while GetMessage(Msg, 0, 0, 0) do
    if Terminated then Exit
    else if Msg.hwnd <> 0 then Continue
    else
      case Msg.Message of
        // Synchronize() causes the ProcessEvent call to be executed by the main thread.
        MM_WIM_DATA, MM_WOM_DONE: Synchronize(ProcessEvent);
        MM_WIM_CLOSE: Terminate;
        end;
end;


procedure TWaitThread.ProcessEvent;
begin
  try
    if Msg.wParam = Owner.DeviceHandle then
      Owner.BufferDone(PWaveHdr(Msg.lParam));
  except on E: Exception do
    begin
    Application.ShowException(E);
    Application.Terminate;
    end;
  end;
end;






{ TCustomSoundInOut }

//------------------------------------------------------------------------------
//                               system
//------------------------------------------------------------------------------
constructor TCustomSoundInOut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  //SetBufCount(DEFAULTBUFCOUNT);

  FDeviceID := WAVE_MAPPER;

  //init WaveFmt
  with WaveFmt do
    begin
    wf.wFormatTag := WAVE_FORMAT_PCM;
    wf.nChannels := 1;             //mono
    wf.nBlockAlign := 2;           //SizeOf(SmallInt) * nChannels;
    wBitsPerSample := 16;          //SizeOf(SmallInt) * 8;
    end;

  //fill nSamplesPerSec, nAvgBytesPerSec in WaveFmt
  SamplesPerSec := 48000;
end;


destructor TCustomSoundInOut.Destroy;
begin
  Enabled := false;
  inherited;
end;


procedure TCustomSoundInOut.Err(Txt: string);
begin
  raise ESoundError.Create(Txt);
end;





//------------------------------------------------------------------------------
//                            enable/disable
//------------------------------------------------------------------------------
//do not enable component at design or load time
procedure TCustomSoundInOut.SetEnabled(AEnabled: boolean);
begin
  if (not (csDesigning in ComponentState)) and (not (csLoading in ComponentState)) and
     (AEnabled <> FEnabled) then
     DoSetEnabled(AEnabled);
  FEnabled := AEnabled;
end;


//enable component after all properties have been loaded
procedure TCustomSoundInOut.Loaded;
begin
  inherited Loaded;

  if FEnabled and not (csDesigning in ComponentState) then
    begin
    FEnabled := false;
    SetEnabled(true);
    end;
end;


procedure TCustomSoundInOut.DoSetEnabled(AEnabled: boolean);
begin
    if AEnabled then begin
        //reset counts
        FBufsAdded:= 0;
        FBufsDone:= 0;
        //create waiting thread
        FThread:= TWaitThread.Create(true);
        FThread.FreeOnTerminate:= true;
        FThread.Owner := Self;
        FThread.Priority := tpTimeCritical; // don't starve the WaveOut device
        FThread.NameThreadForDebugging('TWaitThread'); // without this, IDE will hang
        //start audio output device
        FEnabled:= true;
        try
            Start;
        except
            //a failed open must not leave the component flagged enabled with
            //no thread: Enabled would be stuck true and the next disable
            //would call Terminate on a nil reference
            FreeAndNil(FThread);
            FEnabled := false;
            raise;
        end;
        //device started ok, wait for events
        FThread.Resume;
    end
    else begin
        if FThread <> nil then
          FThread.Terminate;
        Stop;
    end;
end;


//------------------------------------------------------------------------------
//                              get/set
//------------------------------------------------------------------------------
procedure TCustomSoundInOut.SetSamplesPerSec(const Value: LongWord);
begin
  Enabled := false;

  with WaveFmt.wf do
    begin
    nSamplesPerSec := Value;
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
    end;
end;


function TCustomSoundInOut.GetSamplesPerSec: LongWord;
begin
  Result := WaveFmt.wf.nSamplesPerSec;
end;



procedure TCustomSoundInOut.SetDeviceID(const Value: UINT);
begin
  Enabled := false;
  FDeviceID := Value;
end;



function TCustomSoundInOut.GetThreadID: THandle;
begin
  Result := FThread.ThreadID;
end;


function TCustomSoundInOut.GetBufCount: LongWord;
begin
  Result := Length(Buffers);
end;

procedure TCustomSoundInOut.SetBufCount(const Value: LongWord);
begin
  if Enabled then
    raise Exception.Create('Cannot change the number of buffers for an open audio device');
  SetLength(Buffers, Value);
end;

{$ELSE}

{ TWaitThread }

//------------------------------------------------------------------------------
//                               TWaitThread
//------------------------------------------------------------------------------

procedure TWaitThread.Execute;
var
  Buf: PWaveBuffer;
  ErrCode: cint;
begin
  while not Terminated do
    begin
    Buf := Owner.NextFullBuffer;

    //nothing queued: wait to be woken by PutData, with a timeout so that
    //Terminate is always noticed
    if Buf = nil then
      begin
      Owner.FDataReady.WaitFor(50);
      Continue;
      end;

    //blocks until the sound server accepts the chunk -- this is the clock
    if (Owner.FStream <> nil) and (Length(Buf.Data) > 0) then
      begin
      ErrCode := 0;
      pa_simple_write(Owner.FStream, @Buf.Data[0],
                      csize_t(Length(Buf.Data) * SizeOf(SmallInt)), @ErrCode);
      end;

    Owner.ReleaseBuffer;

    //Queue rather than Synchronize: BufferDone advances the simulation, and
    //the simulation is what switches the sound output off at the end of a run
    //(Contest -> MainForm.Run(rmStop) -> AlSoundOut1.Enabled := false).
    //Synchronize would park this thread inside that call while DoSetEnabled
    //waits for this very thread to finish -- a deadlock nothing can break,
    //which is what a click on Stop produced. Queue hands the work over
    //without waiting; the pacing still comes from pa_simple_write above.
    if not Terminated then Queue(ProcessEvent);
    end;
end;


procedure TWaitThread.ProcessEvent;
begin
  //a queued call can still arrive after teardown began, because WaitFor pumps
  //the synchronize queue while it waits; the simulation must not run then
  if Terminated or Owner.FClosing then Exit;

  try
    Owner.BufferDone(nil);
  except on E: Exception do
    begin
    Application.ShowException(E);
    Application.Terminate;
    end;
  end;
end;




{ TCustomSoundInOut }

//------------------------------------------------------------------------------
//                               system
//------------------------------------------------------------------------------
constructor TCustomSoundInOut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FDeviceID := WAVE_MAPPER;
  FLock := TCriticalSection.Create;
  FDataReady := TEvent.Create(nil, false, false, '');

  SamplesPerSec := 48000;
end;


destructor TCustomSoundInOut.Destroy;
begin
  Enabled := false;
  FreeAndNil(FDataReady);
  FreeAndNil(FLock);
  inherited;
end;


procedure TCustomSoundInOut.Err(Txt: string);
begin
  raise ESoundError.Create(Txt);
end;


//------------------------------------------------------------------------------
//                            PulseAudio stream
//------------------------------------------------------------------------------
procedure TCustomSoundInOut.OpenStream;
var
  ss: Tpa_sample_spec;
  attr: Tpa_buffer_attr;
  ErrCode: cint;
  AppName: AnsiString;
  LatencyBytes: LongWord;
begin
  if not LoadPulse then
    Err('Cannot load ' + PulseSimpleLibName + '. Install the PulseAudio ' +
        'client libraries (pulseaudio-libs) to enable sound.');

  ss.format   := PA_SAMPLE_S16LE;
  ss.rate     := FSamplesPerSec;
  ss.channels := 1;

  //hold ~AudioLatencyMs of audio server-side so that writes block at real time
  LatencyBytes := (FSamplesPerSec * SizeOf(SmallInt) * AudioLatencyMs) div 1000;
  attr.maxlength := LatencyBytes;
  attr.tlength   := LatencyBytes;
  attr.prebuf    := cuint32(-1);
  attr.minreq    := cuint32(-1);
  attr.fragsize  := cuint32(-1);

  AppName := AnsiString(Application.Title);
  if AppName = '' then AppName := 'Morse Runner';

  ErrCode := 0;
  FStream := pa_simple_new(nil, PAnsiChar(AppName), PA_STREAM_PLAYBACK, nil,
                           'Contest audio', @ss, nil, @attr, @ErrCode);

  if FStream = nil then
    Err('Cannot open the PulseAudio playback stream: ' + PulseErrorText(ErrCode));
end;


procedure TCustomSoundInOut.CloseStream;
begin
  if FStream <> nil then
    begin
    pa_simple_free(FStream);
    FStream := nil;
    end;
end;


//------------------------------------------------------------------------------
//                              buffer ring
//------------------------------------------------------------------------------
procedure TCustomSoundInOut.ResetQueue;
begin
  FLock.Acquire;
  try
    FReadIdx := 0;
    FWriteIdx := 0;
    FCount := 0;
  finally
    FLock.Release;
  end;
end;


//returns the oldest queued chunk, or nil when the ring is empty. The chunk
//stays owned by the caller (the writer thread) until ReleaseBuffer, so the
//main thread will not overwrite it while it is being played.
function TCustomSoundInOut.NextFullBuffer: PWaveBuffer;
begin
  FLock.Acquire;
  try
    if FCount = 0
      then Result := nil
      else Result := @Buffers[FReadIdx];
  finally
    FLock.Release;
  end;
end;


procedure TCustomSoundInOut.ReleaseBuffer;
begin
  FLock.Acquire;
  try
    if FCount > 0 then
      begin
      FReadIdx := (FReadIdx + 1) mod Length(Buffers);
      Dec(FCount);
      end;
  finally
    FLock.Release;
  end;
end;


//------------------------------------------------------------------------------
//                            enable/disable
//------------------------------------------------------------------------------
//do not enable component at design or load time
procedure TCustomSoundInOut.SetEnabled(AEnabled: boolean);
begin
  if (not (csDesigning in ComponentState)) and (not (csLoading in ComponentState)) and
     (AEnabled <> FEnabled) then
     DoSetEnabled(AEnabled);
  FEnabled := AEnabled;
end;


//enable component after all properties have been loaded
procedure TCustomSoundInOut.Loaded;
begin
  inherited Loaded;

  if FEnabled and not (csDesigning in ComponentState) then
    begin
    FEnabled := false;
    SetEnabled(true);
    end;
end;


procedure TCustomSoundInOut.DoSetEnabled(AEnabled: boolean);
begin
  if AEnabled then
    begin
    //reset counts
    FBufsAdded := 0;
    FBufsDone := 0;
    FClosing := False;
    ResetQueue;
    //create the writer thread suspended; it is not freed on terminate so that
    //Stop can wait for it deterministically
    FThread := TWaitThread.Create(true);
    FThread.FreeOnTerminate := false;
    FThread.Owner := Self;
    //start audio output device
    FEnabled := true;
    try
      Start;
    except
      FThread.Free;
      FThread := nil;
      FEnabled := false;
      raise;
    end;
    //device started ok, start feeding it
    FThread.Start;
    end
  else
    begin
    //stops queued BufferDone calls from re-entering here while we wait below
    FClosing := True;
    if FThread <> nil then
      begin
      FThread.Terminate;
      FDataReady.SetEvent;
      //bounded: the thread is either waiting on FDataReady, which we just
      //signalled, or inside pa_simple_write, which returns once the server
      //has taken the chunk (at most about AudioLatencyMs)
      FThread.WaitFor;
      FThread.Free;
      FThread := nil;
      end;
    Stop;
    end;
end;


//------------------------------------------------------------------------------
//                              get/set
//------------------------------------------------------------------------------
procedure TCustomSoundInOut.SetSamplesPerSec(const Value: LongWord);
begin
  Enabled := false;
  FSamplesPerSec := Value;
end;


function TCustomSoundInOut.GetSamplesPerSec: LongWord;
begin
  Result := FSamplesPerSec;
end;


procedure TCustomSoundInOut.SetDeviceID(const Value: UINT);
begin
  Enabled := false;
  FDeviceID := Value;
end;


function TCustomSoundInOut.GetBufCount: LongWord;
begin
  Result := Length(Buffers);
end;

procedure TCustomSoundInOut.SetBufCount(const Value: LongWord);
begin
  if Enabled then
    raise Exception.Create('Cannot change the number of buffers for an open audio device');
  SetLength(Buffers, Value);
end;

{$ENDIF}

end.

