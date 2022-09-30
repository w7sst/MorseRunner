//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Ini;

interface

uses
  SysUtils, IniFiles, SndTypes, Math;

const
  SEC_STN = 'Station';
  SEC_BND = 'Band';
  SEC_TST = 'Contest';
  SEC_SYS = 'System';

  DEFAULTBUFCOUNT = 8;
  DEFAULTBUFSIZE = 512;
  DEFAULTRATE = 11025;

  DEFAULTWEBSERVER = 'http://www.dxatlas.com/MorseRunner/MrScore.asp';
type
  TSimContest = (scWpx, scCwt, scFieldDay, scNaQp, scHst);
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);

  // Exchange Field #1 types
  TExchange1Type = (etRST, etOpName, etFdClass);

  // Exchange Field #2 Types
  TExchange2Type = (etSerialNr, etCwopsNumber, etArrlSection, etStateProv,
                    etCqZone, etItuZone, etAge, etPower, etJarlOblastCode);

  // Contest definition.
  TContestDefinition = record
    Name: PChar;    // Contest Name.
    Key: PChar;     // Identifying key (used in Ini files)
    ExchType1: TExchange1Type;
    ExchType2: TExchange2Type;
    ExchFieldEditable: Boolean; // whether the Exchange field is editable
    ExchDefault: PChar; // contest-specific Exchange default message
    Msg: PChar;     // Exchange error message
    T: TSimContest; // used to verify array ordering
  end;

  PContestDefinition = ^TContestDefinition;

const
  {
    Each contest is declared here. Long-term, this will be a generalized
    table-driven implementation allowing new contests to be configured
    by updating an external configuration file, perhaps a .yaml file.

    Note: The order of this table must match the declared order of
    TSimContest above.

    Adding a contest: Add to TSimContest enum (above) and update ContestDefinitions[] array.
  }
  ContestDefinitions: array[TSimContest] of TContestDefinition = (
    (Name: 'CQ Wpx';
     Key: 'CqWpx';
     ExchType1: etRST;
     ExchType2: etSerialNr;
     ExchFieldEditable: False;
     ExchDefault: '5NN <#>';
     Msg: '''RST <serial>'' (e.g. 5NN #|123)';
     T:scWpx),
     // 'expecting RST (e.g. 5NN)'

    (Name: 'CWOPS Cwt';
     Key: 'Cwt';
     ExchType1: etOpName;
     ExchType2: etCwopsNumber;
     ExchFieldEditable: True;
     ExchDefault: 'David 1';
     Msg: '''<op name> <CWOPS number>'' (e.g. DAVID 123)';
     T:scCwt),
     // expecting two strings [Name,Number] (e.g. David 123)
     // Contest Exchange: <Name> <CW Ops Num>

    (Name: 'ARRL Field Day';
     Key: 'ArrlFd';
     ExchType1: etFdClass;
     ExchType2: etArrlSection;
     ExchFieldEditable: True;
     ExchDefault: '3A OR';
     Msg: '''<class> <section>'' (e.g. 3A OR)';
     T:scFieldDay),
     // expecting two strings [Class,Section] (e.g. 3A OR)

    (Name: 'NCJ NAQP';
     Key: 'NAQP';
     ExchType1: etOpName;
     ExchType2: etStateProv;
     ExchFieldEditable: True;
     ExchDefault: 'MIKE OR';
     Msg: '''<name> <state-prov>'' (e.g. MIKE OR)';
     T:scNaQp),
     // expecting two strings [Name,State-Prov] (e.g. MIKE OR)

    (Name: 'HST (High Speed Test)';
     Key: 'HST';
     ExchType1: etRST;
     ExchType2: etSerialNr;
     ExchFieldEditable: False;
     ExchDefault: '';
     Msg: '''RST <serial>'' (e.g. 5NN #)';
     T:scHst)
     // expecting RST (e.g. 5NN)
  );

var
  Call: string = 'VE3NEA';
  HamName: string = 'Alex';
  CWOPSNum: string = '1';
  ArrlClass: string = '3A';
  ArrlSection: string = 'OR';
  Wpm: integer = 30;
  MaxRxWpm: integer = 0;
  MinRxWpm: integer = 0;
  NRDigits: integer = 1;
  BandWidth: integer = 500;
  Pitch: integer = 600;
  Qsk: boolean = true;
  Rit: integer = 0;
  BufSize: integer = DEFAULTBUFSIZE;
  WebServer: string = '';
  SubmitHiScoreURL: string= '';
  PostMethod: string = '';
  ShowCallsignInfo: integer= 1;
  Activity: integer = 2;
  Qrn: boolean = true;
  Qrm: boolean = true;
  Qsb: boolean = true;
  Flutter: boolean = true;
  Lids: boolean = true;
  NoActivityCnt: integer=0;
  NoStopActivity: integer=0;
  GetWpmUsesGaussian: boolean = false;

  Duration: integer = 30;
  RunMode: TRunMode = rmStop;
  HiScore: integer;
  CompDuration: integer = 60;

  SaveWav: boolean = false;
  CallsFromKeyer: boolean = false;

  SimContest: TSimContest = scWpx;
  ActiveContest: PContestDefinition = @ContestDefinitions[scWpx];
  UserExchangeTbl: array[TSimContest] of string;
  UserExchange1: array[TSimContest] of string;
  UserExchange2: array[TSimContest] of string;

procedure FromIni;
procedure ToIni;
function IsNum(Num: String): Boolean;


implementation

uses
  Main, Contest;

procedure FromIni;
var
  V: integer;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      // Load SimContest, but do not call SetContest() until UI is initialized.
      V:= ReadInteger(SEC_TST, 'SimContest', Ord(scWpx));
      SimContest := TSimContest(V);
      ActiveContest := @ContestDefinitions[SimContest];
      MainForm.SimContestCombo.ItemIndex := V;

      // Adding a contest: read contest-specfic Exchange Strings from .INI file.
      // load contest-specific Exchange Strings
      UserExchangeTbl[scWpx] := ReadString(SEC_STN, 'CqWpxExchange', '5NN #');
      UserExchangeTbl[scCwt] := ReadString(SEC_STN, 'CwtExchange',
        Format('%s 1234', [HamName]));
      UserExchangeTbl[scFieldDay] := ReadString(SEC_STN, 'ArrlFdExchange', '3A OR');
      UserExchangeTbl[scNaQp] := ReadString(SEC_STN, 'NAQPExchange', 'MIKE OR');
      UserExchangeTbl[scHst] := ReadString(SEC_STN, 'HSTExchange', '5NN #');

      ArrlClass := ReadString(SEC_STN, 'ArrlClass', '3A');
      ArrlSection := ReadString(SEC_STN, 'ArrlSection', 'OR');

      MainForm.SetMyCall(ReadString(SEC_STN, 'Call', Call));
      MainForm.SetPitch(ReadInteger(SEC_STN, 'Pitch', 3));
      MainForm.SetBw(ReadInteger(SEC_STN, 'BandWidth', 9));

      HamName := ReadString(SEC_STN, 'Name', '');
      CWOPSNum :=  ReadString(SEC_STN, 'cwopsnum', '');

      MainForm.UpdCWMaxRxSpeed(ReadInteger(SEC_STN, 'CWMaxRxSpeed', MaxRxWpm));
      MainForm.UpdCWMinRxSpeed(ReadInteger(SEC_STN, 'CWMinRxSpeed', MinRxWpm));
      MainForm.UpdNRDigits(ReadInteger(SEC_STN, 'NRDigits', NRDigits));

      Wpm := ReadInteger(SEC_STN, 'Wpm', Wpm);
      Wpm := Max(10, Min(120, Wpm));
      MainForm.SpinEdit1.Value := Wpm;
      Tst.Me.Wpm := Wpm;

      MainForm.SetQsk(ReadBool(SEC_STN, 'Qsk', Qsk));
      CallsFromKeyer := ReadBool(SEC_STN, 'CallsFromKeyer', CallsFromKeyer);
      GetWpmUsesGaussian := ReadBool(SEC_STN, 'GetWpmUsesGaussian', GetWpmUsesGaussian);

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

      WebServer := ReadString(SEC_SYS, 'WebServer', DEFAULTWEBSERVER);
      SubmitHiScoreURL := ReadString(SEC_SYS, 'SubmitHiScoreURL', '');
      PostMethod := UpperCase(ReadString(SEC_SYS, 'PostMethod', 'POST'));
      MainForm.mnuShowCallsignInfo.Checked := ReadBool(SEC_SYS, 'ShowCallsignInfo', true);

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

      SaveWav := ReadBool(SEC_STN, 'SaveWav', SaveWav);
    finally
      Free;
    end;
end;


procedure ToIni;
var
  V: integer;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      WriteBool(SEC_SYS, 'ShowCallsignInfo', MainForm.mnuShowCallsignInfo.Checked);

      // Adding a contest: write contest-specfic Exchange Strings to .INI file.
      WriteInteger(SEC_TST, 'SimContest', Ord(SimContest));
      WriteString(SEC_STN, 'CqWpxExchange', UserExchangeTbl[scWpx]);
      WriteString(SEC_STN, 'CwtExchange', UserExchangeTbl[scCwt]);
      WriteString(SEC_STN, 'ArrlFdExchange', UserExchangeTbl[scFieldDay]);
      WriteString(SEC_STN, 'NAQPExchange', UserExchangeTbl[scNaQp]);
      WriteString(SEC_STN, 'HSTExchange', UserExchangeTbl[scHst]);

      WriteString(SEC_STN, 'ArrlClass', ArrlClass);
      WriteString(SEC_STN, 'ArrlSection', ArrlSection);

      WriteString(SEC_STN, 'Call', Call);
      WriteInteger(SEC_STN, 'Pitch', MainForm.ComboBox1.ItemIndex);
      WriteInteger(SEC_STN, 'BandWidth', MainForm.ComboBox2.ItemIndex);
      WriteInteger(SEC_STN, 'Wpm', Wpm);
      WriteBool(SEC_STN, 'Qsk', Qsk);

      {
        Note - HamName and CWOPSNum are written to .ini file by
        TMainForm.Operator1Click and TMainForm.CWOPSNumberClick.
        Once specified, HamName and CWOPSNum are added to the application's
        title bar. Thus, HamName and cwopsnum are not written here.

        WriteString(SEC_STN, 'Name', HamName);
        WriteString(SEC_STN, 'cwopsnum', CWOPSNum);
      }
      WriteInteger(SEC_STN, 'CWMaxRxSpeed', MaxRxWpm);
      WriteInteger(SEC_STN, 'CWMinRxSpeed', MinRxWpm);
      WriteInteger(SEC_STN, 'NRDigits', NRDigits);

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



end.

