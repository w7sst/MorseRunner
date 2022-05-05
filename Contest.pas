//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Contest;

{$MODE Delphi}

//{$define DEBUG_AUDIO_DETAIL enables additional logging}

interface

uses
  SysUtils, SndTypes, Station, StnColl, MyStn, Math,  Ini,
  MovAvg, Mixers, VolumCtl, RndFunc, TypInfo, DxStn, DxOper, Log,
{$ifdef DEBUG_AUDIO_DETAIL}
  LazLoggerBase;
{$else}
  LazLoggerDummy;
{$endif}

type
  TContest = class
  private
    function DxCount: integer;
    procedure SwapFilters;
  public
    BlockNumber: integer;
    Me: TMyStation;
    Stations: TStations;
    Agc: TVolumeControl;
    Filt, Filt2: TMovingAverage;
    Modul: TModulator;
    RitPhase: Single;
    FStopPressed: boolean;

    constructor Create;
    destructor Destroy; override;
    procedure Init;
    function Minute: Single;
    function HasPendingLastBlockStations : Boolean;
    function GetAudio: TSingleArray;
    procedure OnMeFinishedSending;
    procedure OnMeStartedSending;
  end;

var
  Tst: TContest;


implementation

uses
  Main;

{ TContest }

constructor TContest.Create;
begin
  Me := TMyStation.CreateStation;
  Stations := TStations.Create;
  Filt := TMovingAverage.Create(nil);
  Modul := TModulator.Create;
  Agc := TVolumeControl.Create(nil);

  Filt.Points := Round(0.7 * DEFAULTRATE / Ini.BandWidth);
  Filt.Passes := 3;
  Filt.SamplesInInput := Ini.BufSize;
  Filt.GainDb := 10 * Log10(500/Ini.Bandwidth);

  Filt2 := TMovingAverage.Create(nil);
  Filt2.Passes := Filt.Passes;
  Filt2.SamplesInInput := Filt.SamplesInInput;
  Filt2.GainDb := Filt.GainDb;

  Modul.SamplesPerSec := DEFAULTRATE;
  Modul.CarrierFreq := Ini.Pitch;

  Agc.NoiseInDb := 76;
  Agc.NoiseOutDb := 76;
  Agc.AttackSamples := 155;   //AGC attack 5 ms
  Agc.HoldSamples := 155;
  Agc.AgcEnabled := true;

  Init;
end;


destructor TContest.Destroy;
begin
  Me.Free;
  FreeAndNil(Stations);
  Filt.Free;
  Filt2.Free;
  Modul.Free;
  FreeAndNil(Agc);
  inherited;
end;


procedure TContest.Init;
begin
  Me.Init;
  Stations.Clear;
  BlockNumber := 0;
end;


// return whether any stations (my or dx) are ready to send their last block.
function TContest.HasPendingLastBlockStations : Boolean;
begin
   Result:= Me.IsLastBlock or Stations.AnyLastBlock;
end;


function TContest.GetAudio: TSingleArray;
const
  NOISEAMP = 6000;
var
  ReIm: TReImArrays;
  Blk: TSingleArray;
  i, Stn: integer;
  Bfo: Single;
  Smg, Rfg: Single;
  Temp: Single;
{$ifdef DEBUG_AUDIO_DETAIL}
  Debug: Boolean;
{$endif}
begin
{$ifdef DEBUG_AUDIO_DETAIL}
  Debug := HasPendingLastBlockStations or (BlockNumber < 32);
  if Debug then
    DebugLnEnter('TContest.GetAudio: BlkNum %d', [BlockNumber+1]);
{$endif}
try
  //minimize audio output delay
  SetLength(Result, 1);
  Inc(BlockNumber);
  if BlockNumber < 6 then Exit;

  //complex noise
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLn('add noise');
{$endif}
  SetLengthReIm(ReIm, Ini.BufSize);
  for i:=0 to High(ReIm.Re) do
    begin
    ReIm.Re[i] := 3 * NOISEAMP * (Random-0.5);
    ReIm.Im[i] := 3 * NOISEAMP * (Random-0.5);
    end;

  //QRN
  if Ini.Qrn then
    begin
{$ifdef DEBUG_AUDIO_DETAIL}
    if debug then DebugLn('add QRN...');
{$endif}
    //background
    for i:=0 to High(ReIm.Re) do
      if Random < 0.01 then ReIm.Re[i] := 60 * NOISEAMP * (Random-0.5);
    //burst
    if Random < 0.01 then Stations.AddQrn;
    end;

  //QRM
  if Ini.Qrm and (Random < 0.0002) then Stations.AddQrm;


  //audio from stations
  Blk := nil;
  for Stn:=0 to Stations.Count-1 do
    if Stations[Stn].State = stSending then
      begin
{$ifdef DEBUG_AUDIO_DETAIL}
      if debug then DebugLnEnter('add audio from %s, Bfo %f, RitPhase %f, Rit %d',
        [Stations[Stn].MyCall, Stations[Stn].Bfo, RitPhase, Ini.Rit]);
{$endif}
      Blk := Stations[Stn].GetBlock;
      for i:=0 to High(Blk) do
        begin
        Bfo := Stations[Stn].Bfo - RitPhase - i * TWO_PI * Ini.Rit / DEFAULTRATE;
        ReIm.Re[i] := ReIm.Re[i] + Blk[i] * Cos(Bfo);
        ReIm.Im[i] := ReIm.Im[i] - Blk[i] * Sin(Bfo);
        end;
{$ifdef DEBUG_AUDIO_DETAIL}
      if debug then DebugLnExit([]);
{$endif}
      end;

  //Rit
  RitPhase := RitPhase + Ini.BufSize * TWO_PI * Ini.Rit / DEFAULTRATE;
  while RitPhase > TWO_PI do RitPhase := RitPhase - TWO_PI;
  while RitPhase < -TWO_PI do RitPhase := RitPhase + TWO_PI;
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLn('add Rit %f radians, %d Hz', [RitPhase, Ini.Rit]);
{$endif}


  //my audio
  if Me.State = stSending then
    begin
{$ifdef DEBUG_AUDIO_DETAIL}
    if debug then DebugLnEnter('adding my audio');
{$endif}
    Blk := Me.GetBlock;
    //self-mon. gain
    Temp := MainForm.VolumeSlider1.Value;
    Smg := Power(10, (MainForm.VolumeSlider1.Value - 0.75) * 4);
    Rfg := 1;
    for i:=0 to High(Blk) do
      if Ini.Qsk
        then
           begin
           if Rfg > (1 - Blk[i]/Me.Amplitude)
             then Rfg := (1 - Blk[i]/Me.Amplitude)
             else Rfg := Rfg * 0.997 + 0.003;
           ReIm.Re[i] := Smg * Blk[i] + Rfg * ReIm.Re[i];
           ReIm.Im[i] := Smg * Blk[i] + Rfg * ReIm.Im[i];
           end
        else
          begin
          ReIm.Re[i] := Smg * (Blk[i]);
          ReIm.Im[i] := Smg * (Blk[i]);
          end;
{$ifdef DEBUG_AUDIO_DETAIL}
    if debug then DebugLnExit([]);
{$endif}
    end;


  //LPF
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLn('apply LPF');
{$endif}
  Filt2.Filter(ReIm);
  ReIm := Filt.Filter(ReIm);
  if (BlockNumber mod 10) = 0 then
    begin
{$ifdef DEBUG_AUDIO_DETAIL}
      if debug then DebugLn('SwapFilters');
{$endif}
      SwapFilters;
    end;

  //mix up to Pitch frequency
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLn('mix up to Pitch freq %f', [Modul.CarrierFreq]);
{$endif}
  Result := Modul.Modulate(ReIm);
  //AGC
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLn('apply AGC');
{$endif}
  Result := Agc.Process(Result);
  //save
  with MainForm.AlWavFile1 do
   if IsOpen then WriteFrom(@Result[0], nil, Ini.BufSize);

  //timer tick
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLnEnter('timer tick...');
{$endif}
  Me.Tick;
  for Stn:=Stations.Count-1 downto 0 do Stations[Stn].Tick;
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLnExit([]);
{$endif}


  //if DX is done, write to log and kill
    for i:=Stations.Count-1 downto 0 do
      if Stations[i] is TDxStation then
        with Stations[i] as TDxStation do
          if (Oper.State = osDone) and (QsoList <> nil) and (MyCall = QsoList[High(QsoList)].Call)
            then
              begin
              DebugLnEnter('dx is done, write log and delete');
              DataToLastQso; // deletes this TDxStation from Stations[]
              with MainForm.RichEdit1.Lines do Delete(Count-1);
              Log.CheckErr;
              Log.LastQsoToScreen;
              if Ini.RunMode = RmHst
                then Log.UpdateStatsHst
                else Log.UpdateStats;
              DebugLnExit([]);
              end;


  //show info
  ShowRate;
  MainForm.Panel2.Caption := FormatDateTime('hh:nn:ss', BlocksToSeconds(BlockNumber) /  86400);
  if Ini.RunMode = rmPileUp then
    MainForm.Panel4.Caption := Format('Pile-Up:  %d', [DxCount]);


  if ((RunMode = rmSingle){ or (Ini.ContestName = 'arrlfd')}) and (DxCount = 0) then
     begin
     DebugLnEnter('adding new calling station');
     Me.Msg := [msgCq]; //no need to send cq in this mode
     Stations.AddCaller.ProcessEvent(evMeFinished);
     DebugLnExit([]);
     end
  else if (RunMode = rmHst) and (DxCount < Activity) then
     begin
     DebugLnEnter('adding callers');
     Me.Msg := [msgCq];
     for i:=DxCount+1 to Activity do
       Stations.AddCaller.ProcessEvent(evMeFinished);
     DebugLnExit([]);
     end;


  if (BlocksToSeconds(BlockNumber) >= (Duration * 60)) or FStopPressed then
    begin
    if RunMode = rmHst then
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      MainForm.PopupScoreHst;
      end        
    else if (RunMode = rmWpx) and not FStopPressed then
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      MainForm.PopupScoreWpx;
      end
    else
      begin
      MainForm.Run(rmStop);
      FStopPressed := false;
      end;
{
    if (RunMode in [rmWpx, rmHst]) and not FStopPressed
      then begin MainForm.Run(rmStop); MainForm.PopupScore; end
      else MainForm.Run(rmStop);
}
    end;
finally
{$ifdef DEBUG_AUDIO_DETAIL}
  if debug then DebugLnExit([]);
{$endif}
end;
end;


function TContest.DxCount: integer;
var
  i: integer;
begin
  Result := 0;
  for i:=Stations.Count-1 downto 0 do
    if (Stations[i] is TDxStation) and
       (TDxStation(Stations[i]).Oper.State <> osDone)
      then Inc(Result);
end;


function TContest.Minute: Single;
begin
  Result := BlocksToSeconds(BlockNumber) / 60;
end;


procedure TContest.OnMeFinishedSending;
var
  i: integer;
begin
  DebugLnEnter('TContest.OnMeFinishedSending');
  //the stations heard my CQ and want to call
  if (not (RunMode in [rmSingle, {rmFieldDay,} RmHst])) then
    if (msgCQ in Me.Msg) or
    //   ((QsoList <> nil) and (msgTU in Me.Msg) and (msgMyCall in Me.Msg))then
    //for i:=1 to RndPoisson(Activity / 2) do Stations.AddCaller;
          ((QsoList <> nil) and ((msgTU in Me.Msg) or (msgMyCall in Me.Msg)))then
            begin
                 if DXCount < Activity/2 then
                   begin
                        for i:=1 to RndPoisson(Activity / 2) do Stations.AddCaller;
                   end;
            end;

 // DebugLn('in TContest.OnMeFinishedSending, count = ' + inttostr(Stations.Count));
  //tell callers that I finished sending
  for i:=Stations.Count-1 downto 0 do
    Stations[i].ProcessEvent(evMeFinished);

  DebugLnExit([]);
end;


procedure TContest.OnMeStartedSending;
var
  i: integer;
begin
  DebugLnEnter('TContest.OnMeStartedSending');
  //tell callers that I started sending
  for i:=Stations.Count-1 downto 0 do
    Stations[i].ProcessEvent(evMeStarted);
  DebugLnExit([]);
end;


procedure TContest.SwapFilters;
var
  F: TMovingAverage;
begin
  F := Filt;
  Filt := Filt2;
  Filt2 := F;
  Filt2.Reset;
end;



end.

