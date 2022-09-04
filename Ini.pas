                                                    //------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Ini;

{$MODE Delphi}

interface

uses
  SysUtils, IniFiles, SndTypes, Math, LazLoggerBase;

const
  SEC_STN = 'Station';
  SEC_BND = 'Band';
  SEC_TST = 'Contest';
  SEC_SYS = 'System';

  DEFAULTBUFCOUNT = 8;
  DEFAULTBUFSIZE = 512;
  DEFAULTRATE = 11025;


type
  TSimContest = (scWpx, scCQWW, scFieldDay, scHst);
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);

  // Exchange Field #1 types
  TExchange1Type = (etRST, etOpName, etFdClass);

  // Exchange Field #2 Types
  TExchange2Type = (etSerialNr, etCwopsNumber, etArrlSection, etStateProv,
                    etCqZone, etItuZone, etAge, etPower, etJarlOblastCode);

  // Contest definition.
var
  Call: string = 'N2IC';
  NR: string = '8';
  HamName: string;
  ArrlClass: string = '3A';
  ArrlSection: string = 'OR';
  Wpm: integer = 30;
  BandWidth: integer = 500;
  Pitch: integer = 600;
  Qsk: boolean = true;
  Rit: integer = 0;
  BufSize: integer = DEFAULTBUFSIZE;

  Activity: integer = 2;
  Qrn: boolean = true;
  Qrm: boolean = true;
  Qsb: boolean = true;
  Flutter: boolean = true;
  Lids: boolean = true;

  Duration: integer = 30;
  RunMode: TRunMode = rmStop;
  HiScore: integer;
  CompDuration: integer = 60;

  SaveWav: boolean = false;
  CallsFromKeyer: boolean = false;
  RadioAudio: integer = 0;
  Messagecq: string = 'CQ';
  Messagehiscall: string;
  Messagenr: string;
  Messagetu: string = 'TU';
  Standalone: boolean = true;
  ContestName: string = 'cqww';
  SimContest: TSimContest = scCQWW;
  ActiveContestExchType1 : TExchange1Type = etRST;
  ActiveContestExchType2 : TExchange2Type = etCqZone;
  UserExchangeTbl: array[TSimContest] of string;

procedure FromIni;
procedure ToIni;
function IsNum(Num: String): Boolean;
function DbgS(const mode : TRunMode) : string; overload;
function DbgS(const contest : TSimContest) : string; overload;
function DbgS(const exchtype : TExchange1Type) : string; overload;
function DbgS(const exchtype : TExchange2Type) : string; overload;
function FindContestByKey(
  constref AContestKey : String;
  out AContestNum : TSimContest
) : Boolean;
function FindContestByName(constref AContestName : String) : TSimContest;

{ return whether the N1MM contest key is supported. }
function IsContestSupported(constref AContestKey : String) : Boolean;

implementation

uses
  Main, Contest;

procedure FromIni;
var
  V: integer;
begin
  DebugLnEnter('FromIni');
  if Standalone = true then
  begin
  DebugLn('standalone');
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      // Load SimContest, but do not call SetContest() until UI is initialized.
      //V:= ReadInteger(SEC_TST, 'SimContest', Ord(scWpx));
      //SimContest := TSimContest(V);
      ContestName := ReadString(SEC_TST, 'ContestName', 'cqwpx');
      SimContest := FindContestByName(ContestName);

      // Adding a contest: read contest-specfic Exchange Strings from .INI file.
      // load contest-specific Exchange Strings
      UserExchangeTbl[scWpx] := ReadString(SEC_STN, 'CqWpxExchange', '5NN #');
      UserExchangeTbl[scCQWW] := ReadString(SEC_STN, 'CqWWExchange', '5NN 3');
      UserExchangeTbl[scFieldDay] := ReadString(SEC_STN, 'ArrlFdExchange', '3A OR');

      ArrlClass := ReadString(SEC_STN, 'ArrlClass', '3A');
      ArrlSection := ReadString(SEC_STN, 'ArrlSection', 'OR');

      MainForm.SetMyCall(ReadString(SEC_STN, 'Call', Call));
      if SimContest = scCQWW then
       MainForm.SetMyZone(ReadString(SEC_STN, 'NR', NR));

      MainForm.SetPitch(ReadInteger(SEC_STN, 'Pitch', 3));
      MainForm.SetBw(ReadInteger(SEC_STN, 'BandWidth', 9));

      //HamName := ReadString(SEC_STN, 'Radio', '');
      //if HamName <> '' then
      //  begin
      //  MainForm.Caption := MainForm.Caption + ':  ' + HamName;
      //  MainForm.Name := HamName;
      //  end;
      //
      Wpm := ReadInteger(SEC_STN, 'Wpm', Wpm);
      Wpm := Max(10, Min(120, Wpm));
      MainForm.SpinEdit1.Value := Wpm;
      Tst.Me.Wpm := Wpm;

      MainForm.SetQsk(ReadBool(SEC_STN, 'Qsk', Qsk));
      CallsFromKeyer := ReadBool(SEC_STN, 'CallsFromKeyer', CallsFromKeyer);

      MainForm.NoRepeats := ReadBool(SEC_STN, 'NoRepeats', false);

      Activity := ReadInteger(SEC_BND, 'Activity', Activity);
      MainForm.SpinEdit3.Value := Activity;

      MainForm.CheckBox4.Checked := ReadBool(SEC_BND, 'Qrn', Qrn);
      MainForm.CheckBox3.Checked := ReadBool(SEC_BND, 'Qrm', Qrm);
      MainForm.CheckBox2.Checked := ReadBool(SEC_BND, 'Qsb', Qsb);
      MainForm.CheckBox5.Checked := ReadBool(SEC_BND, 'Flutter', Flutter);
      MainForm.CheckBox6.Checked := ReadBool(SEC_BND, 'Lids', Lids);
      MainForm.ReadCheckBoxes;

      Duration := ReadInteger(SEC_TST, 'Duration', Duration);
      MainForm.SpinEdit2.Value := Duration;
      HiScore := ReadInteger(SEC_TST, 'HiScore', HiScore);
      CompDuration := Max(1, Min(60, ReadInteger(SEC_TST, 'CompetitionDuration', CompDuration)));

      //buffer size
      V := ReadInteger(SEC_SYS, 'BufSize', 0);
      if V = 0 then
        begin V := 3; WriteInteger(SEC_SYS, 'BufSize', V); end;
      V := Max(1, Min(5, V));
      BufSize := 64 shl V;
      Tst.Filt.SamplesInInput := BufSize;
      Tst.Filt2.SamplesInInput := BufSize;

      V := ReadInteger(SEC_STN, 'SelfMonVolume', 0);
      MainForm.VolumeSlider1.Value := V / 80 + 0.75;

      V := ReadInteger(SEC_SYS, 'SoundDevice', -1);
      MainForm.AlSoundOut1.DeviceID := V;

      SaveWav := ReadBool(SEC_STN, 'SaveWav', SaveWav);
    finally
      Free;
    end;
  end
  else
  begin
      //MainForm.SetMyCall(ReadString(SEC_STN, 'Call', Call));
      //MainForm.SetMyZone(ReadString(SEC_STN, 'NR', NR));
      //MainForm.SetPitch(ReadInteger(SEC_STN, 'Pitch', 3));
      MainForm.SetPitch(3);
      //MainForm.SetBw(ReadInteger(SEC_STN, 'BandWidth', 9));
      //DebugLn('calling SetBW');
      MainForm.SetBW(3);

      //HamName := ReadString(SEC_STN, 'Radio', '');
      //if HamName <> '' then
      //  begin
      //  MainForm.Caption := MainForm.Caption + ':  ' + HamName;
      //  MainForm.Name := HamName;
      //  end;
      //
      //Wpm := ReadInteger(SEC_STN, 'Wpm', Wpm);
      //Wpm := Max(10, Min(120, Wpm));
      //MainForm.SpinEdit1.Value := Wpm;
      //Tst.Me.Wpm := Wpm;

      // MainForm.SetQsk(ReadBool(SEC_STN, 'Qsk', Qsk));
      MainForm.SetQSK(false);
      //CallsFromKeyer := ReadBool(SEC_STN, 'CallsFromKeyer', CallsFromKeyer);

      //MainForm.NoRepeats := ReadBool(SEC_STN, 'NoRepeats', false);
      MainForm.NoRepeats := true;

      //Activity := ReadInteger(SEC_BND, 'Activity', Activity);
      //MainForm.SpinEdit3.Value := Activity;

      //MainForm.CheckBox4.Checked := ReadBool(SEC_BND, 'Qrn', Qrn);
      //MainForm.CheckBox3.Checked := ReadBool(SEC_BND, 'Qrm', Qrm);
      //MainForm.CheckBox2.Checked := ReadBool(SEC_BND, 'Qsb', Qsb);
      //MainForm.CheckBox5.Checked := ReadBool(SEC_BND, 'Flutter', Flutter);
      //MainForm.CheckBox6.Checked := ReadBool(SEC_BND, 'Lids', Lids);
      //MainForm.ReadCheckBoxes;

      // Duration := ReadInteger(SEC_TST, 'Duration', Duration);
      MainForm.SpinEdit2.Value := Duration;
      // HiScore := ReadInteger(SEC_TST, 'HiScore', HiScore);
      // CompDuration := Max(1, Min(60, ReadInteger(SEC_TST, 'CompetitionDuration', CompDuration)));

      //buffer size
      //V := ReadInteger(SEC_SYS, 'BufSize', 0);
      //if V = 0 then
      //  begin V := 3; WriteInteger(SEC_SYS, 'BufSize', V); end;
      //V := Max(1, Min(5, V));
      V := 3;
      BufSize := 64 shl V;
      Tst.Filt.SamplesInInput := BufSize;
      Tst.Filt2.SamplesInInput := BufSize;

     // V := ReadInteger(SEC_STN, 'SelfMonVolume', 0);
     // MainForm.VolumeSlider1.Value := V / 80 + 0.75;
      MainForm.VolumeSlider1.Value := 0.125;

      // V := ReadInteger(SEC_SYS, 'SoundDevice', -1);
      MainForm.AlSoundOut1.DeviceID := -1;

      // SaveWav := ReadBool(SEC_STN, 'SaveWav', SaveWav);
  end;
  DebugLnExit([]);
end;


procedure ToIni;
var
  V: integer;
begin
  DebugLnEnter('ToIni');

  // do not write INI file when running in N1MM embedded mode
  if not Standalone then begin
    DebugLnExit('N1MM embedded mode (Standalone = False), .INI file not written.');
    exit;
  end;

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      // Adding a contest: write contest-specfic Exchange Strings to .INI file.
      WriteString(SEC_TST, 'ContestName', ContestName);
      WriteString(SEC_STN, 'CqWpxExchange', UserExchangeTbl[scWpx]);
      WriteString(SEC_STN, 'CqWWExchange', UserExchangeTbl[scCQWW]);
      WriteString(SEC_STN, 'ArrlFdExchange', UserExchangeTbl[scFieldDay]);

      WriteString(SEC_STN, 'ArrlClass', ArrlClass);
      WriteString(SEC_STN, 'ArrlSection', ArrlSection);

      WriteString(SEC_STN, 'Call', Call);
      WriteString(SEC_STN, 'NR', NR);
      WriteInteger(SEC_STN, 'Pitch', MainForm.ComboBox1.ItemIndex);
      WriteInteger(SEC_STN, 'BandWidth', MainForm.ComboBox2.ItemIndex);
      WriteInteger(SEC_STN, 'Wpm', Wpm);
      WriteBool(SEC_STN, 'Qsk', Qsk);

      WriteInteger(SEC_BND, 'Activity', Activity);
      WriteBool(SEC_BND, 'Qrn', Qrn);
      WriteBool(SEC_BND, 'Qrm', Qrm);
      WriteBool(SEC_BND, 'Qsb', Qsb);
      WriteBool(SEC_BND, 'Flutter', Flutter);
      WriteBool(SEC_BND, 'Lids', Lids);

      WriteInteger(SEC_TST, 'Duration', Duration);
      WriteInteger(SEC_TST, 'HiScore', HiScore);
      WriteInteger(SEC_TST, 'CompetitionDuration', CompDuration);

      V := Round(80 * (MainForm.VolumeSlider1.Value - 0.75));
      WriteInteger(SEC_STN, 'SelfMonVolume', V);

      WriteBool(SEC_STN, 'SaveWav', SaveWav);
    finally
      Free;
    end;
  DebugLnExit([]);
end;


function IsNum(Num: String): Boolean;
var
   X : Integer;
begin
   Result := Length(Num) > 0;
   for X := 1 to Length(Num) do begin
       if Pos(copy(Num,X,1),'0123456789') = 0 then begin
           Result := False;
           Exit;
       end;
   end;
end;


function DbgS(const mode : TRunMode) : string; overload;
begin
  WriteStr(Result, mode);
end;


function DbgS(const contest : TSimContest) : string; overload;
begin
  WriteStr(Result, contest);
end;


function DbgS(const exchtype : TExchange1Type) : string; overload;
begin
  WriteStr(Result, exchtype);
end;


function DbgS(const exchtype : TExchange2Type) : string; overload;
begin
  WriteStr(Result, exchtype);
end;


{
  Given a Contest Key from N1MM+, find the named contest in the
  contest definition table. Returns the corresponding TSimContest code.
  Returns true if successful; false otherwise.
}
function FindContestByKey(
  constref AContestKey : String;
  out AContestNum : TSimContest
) : Boolean;
begin
  Result := True;
  // this will be replaced by a table-driven algorithm. For now, check
  // the three contests supported by N1MM.
  if AContestKey = 'CQWPXCW' then
    AContestNum := scWpx
  else if AContestKey = 'CQWWCW' then
    AContestNum := scCQWW
  else if AContestKey = 'FD' then
    AContestNum := scFieldDay
  else begin
    assert(false, 'missing case');
    Result := false;
  end;
  DebugLn('Ini.FindContestByKey(''%s'') --> %s: %s', [AContestKey, DbgS(AContestNum), DbgS(Result)]);
end;


function IsContestSupported(constref AContestKey : String) : Boolean;
begin
  Result := (AContestKey = 'CQWPXCW') or
            (AContestKey = 'CQWWCW') or
            (AContestKey = 'FD');
end;


function FindContestByName(constref AContestName : String) : TSimContest;
begin
  if AContestName = 'cqwpx' then
    Result := scWpx
  else if AContestName = 'cqww' then
    Result := scCQWW
  else if AContestName = 'arrlfd' then
    Result := scFieldDay
  else
    begin
      raise Exception.Create(
        Format('error: ''%s'' is an unsupported contest name', [AContestName]));
      Halt;
    end;
  DebugLn('Ini.FindContestByName(%s) --> %s', [AContestName, DbgS(Result)]);
end;


end.


