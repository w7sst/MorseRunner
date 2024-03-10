//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Ini;

interface

uses
  IniFiles;

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
                 scSst, scAllJa, scAcag, scIaruHf);
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);

  // Exchange Field #1 types
  TExchange1Type = (etRST, etOpName, etFdClass);

  // Exchange Field #2 Types
  TExchange2Type = (etSerialNr, etGenericField, etArrlSection, etStateProv,
                    etCqZone, etItuZone, etAge, etPower, etJaPref, etJaCity,
                    etNaQpExch2, etNaQpNonNaExch2);

  // Serial NR types
  TSerialNRTypes = (snStartContest, snMidContest, snEndContest, snCustomRange);

  // Serial Number Settings.
  // Defines parameters used to generate various serial numbers.
  // Used by SerialNRGenerator. Stored in .ini file.
  TSerialNRSettings = record
    Key: PChar;         // .INI file keyword
    RangeStr: string;   // Range specification of the form: 01-99 (stored in .ini)
    MinVal: integer;    // range starting value
    MaxVal: integer;    // range ending value

    // MinDigits/MaxDigits below are used for formatting leading zeros:
    // (e.g. Format('%*d', [digits, NR]
    MinDigits: integer; // number of digits in MinVal
    MaxDigits: integer; // number of digits in max value

    procedure Init(const Range: string; AMin, AMax: integer);
    function IsValid : boolean;
    function ParseSerialNR(const ValueStr : string; var Err : string) : Boolean;
    function GetNR : integer;
  end;

  PSerialNRSettings = ^TSerialNRSettings;

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

  TErrMessageCallback = reference to procedure(const aMsg : string);

const
  UndefExchType1 : TExchange1Type = TExchange1Type(-1);
  UndefExchType2 : TExchange2Type = TExchange2Type(-1);

  SerialNrMidContestDef : string = '50-500';
  SerialNrEndContestDef : string = '500-5000';
  SerialNrCustomRangeDef : string = '01-99';

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
     ExchFieldEditable: True;
     ExchDefault: '5NN #';
     Msg: '''RST <serial>'' (e.g. 5NN #|123)';
     T:scWpx),
     // 'expecting RST (e.g. 5NN)'

    (Name: 'CWOPS CWT';
     Key: 'Cwt';
     ExchType1: etOpName;
     ExchType2: etGenericField;
     ExchCaptions: ('Name', 'Exch');
     ExchFieldEditable: True;
     ExchDefault: 'DAVID 123';
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
     ExchType2: etNaQpExch2;
     ExchFieldEditable: True;
     ExchDefault: 'ALEX ON';
     Msg: '''<name> [<state|prov|dxcc-entity>]'' (e.g. ALEX ON)';
     T:scNaQp),
     // expecting one or two strings {Name,[State|Prov|DXCC Entity]} (e.g. MIKE OR)

    (Name: 'HST (High Speed Test)';
     Key: 'HST';
     ExchType1: etRST;
     ExchType2: etSerialNr;
     ExchFieldEditable: False;
     ExchDefault: '5NN #';
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
     Key: 'ArrlDx';
     ExchType1: etRST;
     ExchType2: etStateProv;  // or etPower
     ExchFieldEditable: True;
     ExchDefault: '5NN ON';   // or '5NN KW'
     Msg: '''RST <state|province|power>'' (e.g. 5NN ON)';
     T:scARRLDX),

    (Name: 'K1USN Slow Speed Test';
     Key: 'Sst';
     ExchType1: etOpName;
     ExchType2: etGenericField;  // or etStateProvDx?
     ExchCaptions: ('Name', 'State/Prov/DX');
     ExchFieldEditable: True;
     ExchDefault: 'BRUCE MA';
     Msg: '''<op name> <State|Prov|DX>'' (e.g. BRUCE MA)';
     T:scSst),
     // expecting two strings [Name,QTH] (e.g. BRUCE MA)
     // Contest Exchange: <Name> <State|Prov|DX>

    (Name: 'JARL ALL JA';
     Key: 'AllJa';
     ExchType1: etRST;
     ExchType2: etJaPref;
     ExchFieldEditable: True;
     ExchDefault: '5NN 10H';
     Msg: '''RST <Pref><Power>'' (e.g. 5NN 10H)';
     T:scAllJa),

    (Name: 'JARL ACAG';
     Key: 'Acag';
     ExchType1: etRST;
     ExchType2: etJaCity;
     ExchFieldEditable: True;
     ExchDefault: '5NN 1002H';
     Msg: '''RST <City|Gun|Ku><Power>'' (e.g. 5NN 1002H)';
     T:scAcag),

    (Name: 'IARU HF';
     Key: 'IaruHf';
     ExchType1: etRST;
     ExchType2: etGenericField;
     ExchCaptions: ('RST', 'Zone/Soc');
     ExchFieldEditable: True;
     ExchDefault: '5NN 6';
     Msg: '''RST <Itu-zone|IARU Society>'' (e.g. 5NN 6)';
     T:scIaruHf)
  );

var
  Call: string = 'VE3NEA';
  HamName: string = 'Alex';
  ArrlClass: string = '3A';
  ArrlSection: string = 'GH';
  Wpm: integer = 25;
  WpmStepRate: integer = 2;
  MaxRxWpm: integer = 0;
  MinRxWpm: integer = 0;
  NRDigits: integer = 1;
  SerialNRSettings: array[TSerialNRTypes] of TSerialNRSettings = (
    (Key:'SerialNrStartContest'; RangeStr:'Default';  MinVal:1;   MaxVal:176;  minDigits:1; maxDigits:3),
    (Key:'SerialNrMidContest';   RangeStr:'50-500';   MinVal:50;  MaxVal:500;  minDigits:2; maxDigits:3),
    (Key:'SerialNrEndContest';   RangeStr:'500-5000'; MinVal:500; MaxVal:5000; minDigits:3; maxDigits:4),
    (Key:'SerialNrCustomRange';  RangeStr:'01-99';    MinVal:1;   MaxVal:99;   minDigits:2; maxDigits:2)
  );
  SerialNR: TSerialNRTypes = snStartContest;
  BandWidth: integer = 500;
  Pitch: integer = 600;
  Qsk: boolean = false;
  Rit: integer = 0;
  RitStepIncr: integer = 50;
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
  DefaultRunMode: TRunMode = rmPileUp;
  HiScore: integer;
  CompDuration: integer = 60;

  SaveWav: boolean = false;
  FarnsworthCharRate: integer = 25;
  AllStationsWpmS: integer = 0;      // force all stations to this Wpm
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

procedure FromIni(cb : TErrMessageCallback);
procedure ToIni;
function IsNum(Num: String): Boolean;
function FindContestByName(const AContestName : String) : TSimContest;


implementation

uses
  Classes,        // for TStringList
  Math,           // for Min, Max
  SysUtils,       // for Format(),
  Main, Contest;

procedure FromIni(cb : TErrMessageCallback);
var
  V: integer;
  C: PContestDefinition;
  SC: TSimContest;
  KeyName: String;

  procedure ReadSerialNRSetting(
    IniFile: TCustomIniFile;
    snt: TSerialNRTypes;
    const DefaultVal : string);
  var
    Err : string;
    ValueStr : string;
  begin
    var pRange : PSerialNRSettings := @Ini.SerialNRSettings[snt];
    ValueStr := IniFile.ReadString(SEC_STN, pRange.Key, DefaultVal);
    if not pRange.ParseSerialNR(ValueStr, Err) then
      begin
        Err := Format(
          'Error while reading MorseRunner.ini file.'#13 +
          'Invalid Keyword Value: ''%s=%s'':'#13 +
          '%s'#13 +
          'Please correct this keyword or remove the MorseRunner.ini file.',
          [pRange.Key, pRange.RangeStr, Err]);
        cb(Err);
      end;
  end;

begin
  var IniFile: TCustomIniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  with IniFile do
    try
      // initial Contest pick will be first item in the Contest Dropdown.
      V:= Ord(FindContestByName(MainForm.SimContestCombo.Items[0]));
      // Load SimContest, but do not call SetContest() until UI is initialized.
      V:= ReadInteger(SEC_TST, 'SimContest', V);
      if V > Length(ContestDefinitions) then V := 0;
      SimContest := TSimContest(V);
      ActiveContest := @ContestDefinitions[SimContest];
      MainForm.SimContestCombo.ItemIndex :=
        MainForm.SimContestCombo.Items.IndexOf(ActiveContest.Name);

      // load contest-specific Exchange Strings from .INI file.
      for SC := Low(ContestDefinitions) to High(ContestDefinitions) do begin
        C := @ContestDefinitions[SC];
        assert(C.T = SC);
        KeyName := Format('%sExchange', [C.Key]);
        UserExchangeTbl[SC] := ReadString(SEC_STN, KeyName, C.ExchDefault);
      end;

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

      // convert older NRDigits (pre-V1.84) to new SerialNR (v1.84)
      if ValueExists(SEC_STN, 'NRDigits') then begin
        NRDigits := ReadInteger(SEC_STN, 'NRDigits', NRDigits);
        case NRDigits of
          1: SerialNR := snStartContest;
          2: SerialNR := snCustomRange;
          3: SerialNR := snMidContest;
          4: SerialNR := snEndContest;
          else SerialNR := snStartContest;
        end;
        DeleteKey(SEC_STN, 'NRDigits');
        WriteInteger(SEC_STN, 'SerialNR', Ord(SerialNR));
        NRDigits := 0;
      end;

      ReadSerialNRSetting(IniFile, snMidContest, SerialNrMidContestDef);
      ReadSerialNRSetting(IniFile, snEndContest, SerialNrEndContestDef);
      ReadSerialNRSetting(IniFile, snCustomRange, SerialNrCustomRangeDef);
      MainForm.UpdSerialNRCustomRange(SerialNRSettings[snCustomRange].RangeStr);
      MainForm.UpdSerialNR(ReadInteger(SEC_STN, 'SerialNR', Ord(SerialNR)));

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

      V := ReadInteger(SEC_TST, 'DefaultRunMode', Ord(DefaultRunMode));
      MainForm.SetDefaultRunMode(Max(Ord(rmPileUp), Min(Ord(rmHst), V)));
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
      FarnsworthCharRate := ReadInteger(SEC_SET, 'FarnsworthCharacterRate', FarnsworthCharRate);
      WpmStepRate := Max(1, Min(20, ReadInteger(SEC_SET, 'WpmStepRate', WpmStepRate)));
      RitStepIncr := ReadInteger(SEC_SET, 'RitStepIncr', RitStepIncr);
      RitStepIncr := Max(-500, Min(500, RitStepIncr));

      // [Debug]
      DebugExchSettings := ReadBool(SEC_DBG, 'DebugExchSettings', DebugExchSettings);
      DebugCwDecoder := ReadBool(SEC_DBG, 'DebugCwDecoder', DebugCwDecoder);
      DebugGhosting := ReadBool(SEC_DBG, 'DebugGhosting', DebugGhosting);
      AllStationsWpmS := ReadInteger(SEC_DBG, 'AllStationsWpmS', AllStationsWpmS);
      F8 := ReadString(SEC_DBG, 'F8', F8);
    finally
      Free;
    end;
end;


procedure ToIni;
var
  V: integer;
  SC: TSimContest;
  KeyName: String;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      WriteBool(SEC_SYS, 'ShowCallsignInfo', MainForm.mnuShowCallsignInfo.Checked);

      // write contest-specfic Exchange Strings to .INI file.
      WriteInteger(SEC_TST, 'SimContest', Ord(SimContest));
      for SC := Low(ContestDefinitions) to High(ContestDefinitions) do begin
        assert(ContestDefinitions[SC].T = SC);
        KeyName := Format('%sExchange', [ContestDefinitions[SC].Key]);
        WriteString(SEC_STN, KeyName, UserExchangeTbl[SC]);
      end;

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
      WriteInteger(SEC_STN, 'SerialNR', Ord(SerialNR));
{ future...
      WriteString(SEC_STN, Ini.SerialNRSettings[snMidContest].Key,
                           Ini.SerialNRSettings[snMidContest].RangeStr);
      WriteString(SEC_STN, Ini.SerialNRSettings[snEndContest].Key,
                           Ini.SerialNRSettings[snEndContest].RangeStr);
}
      WriteString(SEC_STN, Ini.SerialNRSettings[snCustomRange].Key,
                           Ini.SerialNRSettings[snCustomRange].RangeStr);

      WriteInteger(SEC_BND, 'Activity', Activity);
      WriteBool(SEC_BND, 'Qrn', Qrn);
      WriteBool(SEC_BND, 'Qrm', Qrm);
      WriteBool(SEC_BND, 'Qsb', Qsb);
      WriteBool(SEC_BND, 'Flutter', Flutter);
      WriteBool(SEC_BND, 'Lids', Lids);

      WriteInteger(SEC_TST, 'DefaultRunMode', Ord(DefaultRunMode));
      WriteInteger(SEC_TST, 'Duration', Duration);
      WriteInteger(SEC_TST, 'HiScore', HiScore);
      WriteInteger(SEC_TST, 'CompetitionDuration', CompDuration);

      V := Round(80 * (MainForm.VolumeSlider1.Value - 0.75));
      WriteInteger(SEC_STN, 'SelfMonVolume', V);

      WriteBool(SEC_STN, 'SaveWav', SaveWav);

      // [Settings]
      WriteInteger(SEC_SET, 'FarnsworthCharacterRate', FarnsworthCharRate);
      WriteInteger(SEC_SET, 'WpmStepRate', WpmStepRate);
      WriteInteger(SEC_SET, 'RitStepIncr', RitStepIncr);

    finally
      Free;
    end;
end;


{ TSerialNRSettings methods...}
procedure TSerialNRSettings.Init(const Range: string; AMin, AMax: integer);
begin
  Self.RangeStr := Range;
  Self.MinVal := AMin;
  Self.MaxVal := AMax;
end;


function TSerialNRSettings.IsValid: Boolean;
begin
  Result := (MinVal > 0) and (MinVal <= MaxVal);
end;


function TSerialNRSettings.GetNR : integer;
begin
  assert(IsValid);
  if IsValid then
    Result := MinVal + Random(MaxVal - MinVal)
  else
    Result := 1;
end;


function TSerialNRSettings.ParseSerialNR(
  const ValueStr : string;
  var Err : string) : Boolean;
var
  sl : TStringList;
begin
  sl := TStringList.Create;
  try
    Self.RangeStr := ValueStr;

    // split Range into two strings [Min, Max)
    sl.Clear;
    ExtractStrings(['-'], [], PChar(ValueStr), sl);
    Err := '';
    if (sl.Count <> 2) or
       (ValueStr.CountChar('-') <> 1) or
       not TryStrToInt(sl[0], Self.MinVal) or
       not TryStrToInt(sl[1], Self.MaxVal) then
      Err := Format(
        'Error: ''%s'' is an invalid range.'#13 +
        'Expecting min-max values with up to 4-digits each (e.g. 100-300).',
        [ValueStr])
    else if (Self.MinVal > 9999) or (Self.MaxVal > 9999) then
      Err := Format(
        'Error: ''%s'' is an invalid range.'#13 +
        'Expecting range values to be less than or equal to 9999.',
        [ValueStr])
    else if (Self.MinVal > Self.MaxVal) then
      Err := Format(
        'Error: ''%s'' is an invalid range.'#13 +
        'Expecting Min value to be less than Max value.',
        [ValueStr]);
    if Err = '' then
      begin
        Self.MinDigits := sl[0].Length;
        Self.MaxDigits := sl[1].Length;
      end
    else
      begin
        Self.MinDigits := 0;
        Self.MaxDigits := 0;
      end;
    Result := Err = '';

  finally
    sl.Free;
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

