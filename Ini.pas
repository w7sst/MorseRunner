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
  SEC_SET = 'Settings';
  SEC_DBG = 'Debug';

  DEFAULTBUFCOUNT = 8;
  DEFAULTBUFSIZE = 512;
  DEFAULTRATE = 11025;

  DEFAULTWEBSERVER = 'http://www.dxatlas.com/MorseRunner/MrScore.asp';
type
  // Adding a contest: Append new TSimContest enum value for each contest.
  TSimContest = (scWpx, scCwt, scFieldDay, scNaQp, scHst, scCQWW, scArrlDx,
                 scSst, scAllJa, scAcag);
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);

  // Exchange Field #1 types
  TExchange1Type = (etRST, etOpName, etFdClass);

  // Exchange Field #2 Types
  TExchange2Type = (etSerialNr, etGenericField, etArrlSection, etStateProv,
                    etCqZone, etItuZone, etAge, etPower, etJaPref, etJaCity);

  // Contest definition.
  TContestDefinition = record
    Name: PChar;    // Contest Name. Used in SimContestCombo dropdown box.
    Key: PChar;     // Identifying key (used in Ini files)
    ExchType1: TExchange1Type;
    ExchType2: TExchange2Type;
    ExchCaptions: array[0..1] of String; // exchange field captions
    ExchFieldEditable: Boolean; // whether the Exchange field is editable
    ExchDefault: PChar; // contest-specific Exchange default message
    Msg: PChar;     // Exchange error message
    T: TSimContest; // used to verify array ordering and lookup by Name
  end;

  PContestDefinition = ^TContestDefinition;

const
  UndefExchType1 : TExchange1Type = TExchange1Type(-1);
  UndefExchType2 : TExchange2Type = TExchange2Type(-1);

  {
    Each contest is declared here. Long-term, this will be a generalized
    table-driven implementation allowing new contests to be configured
    by updating an external configuration file, perhaps a .yaml file.

    Note: The order of this table must match the declared order of
    TSimContest above.

    Adding a contest: update ContestDefinitions[] array (append at end
    because .INI uses TSimContest value).
  }
  ContestDefinitions: array[TSimContest] of TContestDefinition = (
    (Name: 'CQ WPX';
     Key: 'CqWpx';
     ExchType1: etRST;
     ExchType2: etSerialNr;
     ExchFieldEditable: False;
     ExchDefault: '5NN <#>';
     Msg: '''RST <serial>'' (e.g. 5NN #|123)';
     T:scWpx),
     // 'expecting RST (e.g. 5NN)'

    (Name: 'CWOPS CWT';
     Key: 'Cwt';
     ExchType1: etOpName;
     ExchType2: etGenericField;
     ExchCaptions: ('Name', 'Exch');
     ExchFieldEditable: True;
     ExchDefault: 'David 1';
     Msg: '''<op name> <CWOPS Number|State|Country>'' (e.g. DAVID 123)';
     T:scCwt),
     // expecting two strings [Name,Number] (e.g. David 123)
     // Contest Exchange: <Name> <CW Ops Num|State|Country Prefix>

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
     T:scHst),
     // expecting RST (e.g. 5NN)

    (Name: 'CQ WW';
     Key: 'CQWW';
     ExchType1: etRST;
     ExchType2: etCQZone;
     ExchFieldEditable: True;
     ExchDefault: '5NN 3';
     Msg: '''RST <cq-zone>'' (e.g. 5NN 3)';
     T:scCQWW),

    (Name: 'ARRL DX';
     Key: 'ARRLDXCW';
     ExchType1: etRST;
     ExchType2: etStateProv;  // or etPower
     ExchFieldEditable: True;
     ExchDefault: '5NN OR';   // or '5NN KW'
     Msg: '''RST <state|province|power>'' (e.g. 5NN OR)';
     T:scARRLDX),

    (Name: 'K1USN Slow Speed Test';
     Key: 'K1USNSST';
     ExchType1: etOpName;
     ExchType2: etGenericField;  // or etStateProvDx?
     ExchCaptions: ('Name', 'State/Prov/DX');
     ExchFieldEditable: True;
     ExchDefault: 'Bruce MA';
     Msg: '''<op name> <State|Prov|DX>'' (e.g. BRUCE MA)';
     T:scSst),
     // expecting two strings [Name,QTH] (e.g. BRUCE MA)
     // Contest Exchange: <Name> <State|Prov|DX>

    (Name: '[JA]ALL JA Contest';
     Key: 'ALLJA';
     ExchType1: etRST;
     ExchType2: etJaPref;  // or etStateProvDx?
     ExchFieldEditable: True;
     ExchDefault: '5NN 10H';
     Msg: '''RST <Pref><Power>'' (e.g. 5NN 10H)';
     T:scAllJa),

    (Name: '[JA]ACAG Contest';
     Key: 'ACAG';
     ExchType1: etRST;
     ExchType2: etJaCity;  // or etStateProvDx?
     ExchFieldEditable: True;
     ExchDefault: '5NN 1002H';
     Msg: '''RST <City|Gun|Ku><Power>'' (e.g. 5NN 1002H)';
     T:scAcag)
  );

var
  Call: string = 'VE3NEA';
  HamName: string = 'Alex';
  ArrlClass: string = '3A';
  ArrlSection: string = 'GTA';
  Wpm: integer = 25;
  MaxRxWpm: integer = 0;
  MinRxWpm: integer = 0;
  NRDigits: integer = 1;
  BandWidth: integer = 500;
  Pitch: integer = 600;
  Qsk: boolean = false;
  Rit: integer = 0;
  BufSize: integer = DEFAULTBUFSIZE;
  WebServer: string = '';
  SubmitHiScoreURL: string= '';
  PostMethod: string = '';
  ShowCallsignInfo: integer= 1;
  Activity: integer = 2;
  Qrn: boolean = false;
  Qrm: boolean = false;
  Qsb: boolean = false;
  Flutter: boolean = false;
  Lids: boolean = false;
  NoActivityCnt: integer=0;
  NoStopActivity: integer=0;
  GetWpmUsesGaussian: boolean = false;

  Duration: integer = 30;
  RunMode: TRunMode = rmStop;
  HiScore: integer;
  CompDuration: integer = 60;

  SaveWav: boolean = false;
  CallsFromKeyer: boolean = false;
  F8: string = '';

  { display parsed Exchange field settings; calls/exchanges (in rmSingle mode) }
  DebugExchSettings: boolean = false;
  DebugCwDecoder: boolean = false;  // stream CW to status bar
  DebugGhosting: boolean = false;   // enable DxStation Ghosting debug

  SimContest: TSimContest = scWpx;
  ActiveContest: PContestDefinition = @ContestDefinitions[scWpx];
  UserExchangeTbl: array[TSimContest] of string;
  UserExchange1: array[TSimContest] of string;
  UserExchange2: array[TSimContest] of string;

procedure FromIni;
procedure ToIni;
function IsNum(Num: String): Boolean;
function FindContestByName(const AContestName : String) : TSimContest;


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
      MainForm.SimContestCombo.ItemIndex :=
        MainForm.SimContestCombo.Items.IndexOf(ActiveContest.Name);

      // Adding a contest: read contest-specfic Exchange Strings from .INI file.
      // load contest-specific Exchange Strings
      UserExchangeTbl[scWpx] := ReadString(SEC_STN, 'CqWpxExchange', '5NN #');
      UserExchangeTbl[scCwt] := ReadString(SEC_STN, 'CwtExchange',
        Format('%s 1234', [HamName]));
      UserExchangeTbl[scFieldDay] := ReadString(SEC_STN, 'ArrlFdExchange', '3A GTA');
      UserExchangeTbl[scNaQp] := ReadString(SEC_STN, 'NAQPExchange', 'ALEX ON');
      UserExchangeTbl[scHst] := ReadString(SEC_STN, 'HSTExchange', '5NN #');
      UserExchangeTbl[scCQWW] := ReadString(SEC_STN, 'CQWWExchange', '5NN 4');
      UserExchangeTbl[scArrlDx] := ReadString(SEC_STN, 'ArrlDxExchange', '5NN ON');
      UserExchangeTbl[scSst] := ReadString(SEC_STN, 'SstExchange', 'BRUCE MA');
      UserExchangeTbl[scAllJa] := ReadString(SEC_STN, 'AllJaExchange', '5NN 10H');
      UserExchangeTbl[scAcag] := ReadString(SEC_STN, 'AcagExchange', '5NN 1002H');

      ArrlClass := ReadString(SEC_STN, 'ArrlClass', '3A');
      ArrlSection := ReadString(SEC_STN, 'ArrlSection', 'ON');

      // load station settings...
      // Calls to SetMyCall, SetPitch, SetBw, etc., moved to MainForm.SetContest
      Call := ReadString(SEC_STN, 'Call', Call);
      MainForm.ComboBox1.ItemIndex := ReadInteger(SEC_STN, 'Pitch', 3);
      MainForm.ComboBox2.ItemIndex := ReadInteger(SEC_STN, 'BandWidth', 9);

      HamName := ReadString(SEC_STN, 'Name', '');
      DeleteKey(SEC_STN, 'cwopsnum');  // obsolete at v1.83

      MainForm.UpdCWMaxRxSpeed(ReadInteger(SEC_STN, 'CWMaxRxSpeed', MaxRxWpm));
      MainForm.UpdCWMinRxSpeed(ReadInteger(SEC_STN, 'CWMinRxSpeed', MinRxWpm));
      MainForm.UpdNRDigits(ReadInteger(SEC_STN, 'NRDigits', NRDigits));

      Wpm := ReadInteger(SEC_STN, 'Wpm', Wpm);
      Qsk := ReadBool(SEC_STN, 'Qsk', Qsk);
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

      V := ReadInteger(SEC_STN, 'SelfMonVolume', 0);
      MainForm.VolumeSlider1.Value := V / 80 + 0.75;

      SaveWav := ReadBool(SEC_STN, 'SaveWav', SaveWav);

      // [Settings]

      // [Debug]
      DebugExchSettings := ReadBool(SEC_DBG, 'DebugExchSettings', DebugExchSettings);
      DebugCwDecoder := ReadBool(SEC_DBG, 'DebugCwDecoder', DebugCwDecoder);
      DebugGhosting := ReadBool(SEC_DBG, 'DebugGhosting', DebugGhosting);
      F8 := ReadString(SEC_DBG, 'F8', F8);
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
      WriteString(SEC_STN, 'CqWWExchange', UserExchangeTbl[scCQWW]);
      WriteString(SEC_STN, 'ArrlDxExchange', UserExchangeTbl[scArrlDx]);
      WriteString(SEC_STN, 'SstExchange', UserExchangeTbl[scSst]);
      WriteString(SEC_STN, 'AllJaExchange', UserExchangeTbl[scAllJa]);
      WriteString(SEC_STN, 'AcagExchange', UserExchangeTbl[scAcag]);

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


function FindContestByName(const AContestName : String) : TSimContest;
var
  C : TContestDefinition;
begin
  for C in ContestDefinitions do
    if CompareText(AContestName, C.Name) = 0 then
      begin
        Result := C.T;
        // DebugLn('Ini.FindContestByName(%s) --> %s', [AContestName, DbgS(Result)]);
        Exit;
      end;

  raise Exception.Create(
      Format('error: ''%s'' is an unsupported contest name', [AContestName]));
  Halt;
end;


end.

