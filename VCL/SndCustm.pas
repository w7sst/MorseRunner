//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SndCustm;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Forms, SyncObjs, SndTypes,
  Ini, sdl;

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
    rc: UINT;
    DeviceHandle: UINT;
    WaveFmt: UINT;
    Buffers: array of TWaveBuffer;
    FBufsAdded: LongWord;
    FBufsDone: LongWord;

    procedure Loaded; override;
    procedure Err(Txt: string);
    function GetThreadID: THandle;

    //override these
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure BufferDone; virtual; abstract;

    property Enabled: boolean read FEnabled write SetEnabled default false;
    property DeviceID: UINT read FDeviceID write SetDeviceID default 0;
    property SamplesPerSec: LongWord read GetSamplesPerSec write SetSamplesPerSec default 48000;
    property BufsAdded: LongWord read FBufsAdded;
    property BufsDone: LongWord read FBufsDone;
    property BufCount: LongWord read GetBufCount write SetBufCount;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation


procedure BufferDoneSDL(userdata : Pointer; stream : PUInt8; len : LongInt); cdecl;
begin
   Writeln('BufferDoneSDL');
end;


{ TWaitThread }

//------------------------------------------------------------------------------
//                               TWaitThread
//------------------------------------------------------------------------------

procedure TWaitThread.Execute;
begin
   Priority := tpTimeCritical;
   while not Terminated do
      begin
	 //Writeln('Tick');
	 Synchronize(ProcessEvent);
	 Sleep(75);
      end;
//   while GetMessage(Msg, 0, 0, 0) do
//      if Terminated then Exit
//      else if Msg.hwnd <> 0 then Continue
//      else
//	 case Msg.Message of
//	   MM_WIM_DATA, MM_WOM_DONE: Synchronize(ProcessEvent);
//	   MM_WIM_CLOSE: Terminate;
//	 end;
end;


procedure TWaitThread.ProcessEvent;
begin
   //Writeln('ProcessEvent Main Thread');
   Owner.BufferDone;
   //Writeln('ProcessEvent Done');
//  try
//    if Msg.wParam = Owner.DeviceHandle then
//      Owner.BufferDone(PWaveHdr(Msg.lParam));
//  except on E: Exception do
//   begin
//    Application.ShowException(E);
//    Terminate;
//    end;
//  end;
end;






{ TCustomSoundInOut }

//------------------------------------------------------------------------------
//                               system
//------------------------------------------------------------------------------
constructor TCustomSoundInOut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  SetBufCount(DEFAULTBUFCOUNT);

  if SDL_Init(SDL_INIT_AUDIO) < 0 then
     begin
	Writeln('SDL_Init failed.');
	Exit;
     end;

   Writeln('SDL_Init OK');
   
  //FDeviceID := WAVE_MAPPER;

  //init WaveFmt
  //with WaveFmt do
  //  begin
  //  wf.wFormatTag := WAVE_FORMAT_PCM;
  //  wf.nChannels := 1;             //mono
  //  wf.nBlockAlign := 2;           //SizeOf(SmallInt) * nChannels;
  //  wBitsPerSample := 16;          //SizeOf(SmallInt) * 8;
  //  end;

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
  if (not (csDesigning in ComponentState)) and
     (not (csLoading in ComponentState)) and
     (AEnabled <> FEnabled)
    then DoSetEnabled(AEnabled);
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
	Writeln('DoSetEnabled true');
	//reset counts
	FBufsAdded := 0;
	FBufsDone := 0;
	//create waiting thread
	FThread := TWaitThread.Create(true);
	FThread.FreeOnTerminate := true;
	FThread.Owner := Self;
	FThread.Priority := tpTimeCritical;
	//start
	FEnabled := true;
        try Start; except FreeAndNil(FThread); raise; end;
        //device started ok, wait for events
        FThread.Start;
      end
   else
      begin
	 Writeln('DoSetEnabled false');
	 FThread.Terminate;
	 Stop;
   end;
end;


//------------------------------------------------------------------------------
//                              get/set
//------------------------------------------------------------------------------

procedure TCustomSoundInOut.SetSamplesPerSec(const Value: LongWord);
var
   des, got	    : PSDL_AudioSpec;
   err		    : String;
begin
   Enabled := false;

   Writeln('SetSamplesPerSec ', Value);

   SDL_CloseAudio();

   des := New(PSDL_AudioSpec);
   got := New(PSDL_AudioSpec);
   with des^ do
      begin
	 freq := Value;
	 format := AUDIO_S16LSB;
	 channels := 1;
	 samples := 8192;
	 callback := @BufferDoneSDL;
	 //userdata := @acur;
      end;

   if SDL_OpenAudio(des, got) < 0 then
   begin
      err := SDL_GetError();
      WriteLn('OpenAudio failed: ', err);
      Exit;
   end;

   WriteLn('OpenAudio got ', got^.freq, ' ', got^.format, ' ', got^.channels, ' ', got^.samples);

  //with WaveFmt.wf do
  //  begin
  //  nSamplesPerSec := Value;
  //  nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
  //  end;
end;


function TCustomSoundInOut.GetSamplesPerSec: LongWord;
begin
  //Result := WaveFmt.wf.nSamplesPerSec;
end;



procedure TCustomSoundInOut.SetDeviceID(const Value: UINT);
begin
  Enabled := false;
  FDeviceID := Value;
end;



function TCustomSoundInOut.GetThreadID: THandle;
begin
   Result := THandle(FThread.ThreadID);
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







end.

