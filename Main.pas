//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Main;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

{$define DEBUG_LOGGING}  // enables LazLogging to Documents\N1MM Logger+\debug.txt

interface

uses
  LCLIntf, LCLType, {LMessages, Messages,} SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Buttons, SndCustm, SndOut, Contest, Ini, MorseKey, CallLst,
  VolmSldr, {VolumCtl,} StdCtrls, Station, Menus, ExtCtrls, Log, MAth,
  ComCtrls, Spin, {SndTypes, ToolWin,} ImgList, FileUtil, Crc32,
{$ifdef DEBUG_LOGGING}
  LazLogger,       // this unit enables debug logging
{$else}
  LazLoggerDummy,  // this unit disables debug logging
{$endif}
  LCLProc,
  WavFile, IniFiles, Windows, {UdpHandler,} ARRLFD;

const
    WM_TBDOWN = WM_USER+1;
    WM_STOP  = 32768 + 2;
    WM_CQWW  = 32768 + 3;
    WM_CQWPX  = 32768 + 4;
    WM_SETMYCALL  = 32768 + 5;
    WM_SETMYZONE  = 32768 + 6;
    WM_SETCALL  = 32768 + 7;
    WM_SETRST  = 32768 + 8;
    WM_SETNR  = 32768 + 9;
    WM_SETCWSPEED  = 32768 + 10;
    WM_SETAUDIO  = 32768 + 11;
    WM_GETTXSTATUS  = 32768 + 12;
    WM_SETMSGCQ  = 32768 + 13;
    WM_SETMSGNR  = 32768 + 14;
    WM_SETMSGTU  = 32768 + 15;
    WM_SETACTIVITY  = 32768 + 16;
    WM_SETQRN  = 32768 + 17;
    WM_SETQRM  = 32768 + 18;
    WM_SETQSB  = 32768 + 19;
    WM_SETFLUTTER  = 32768 + 20;
    WM_SETLIDS  = 32768 + 21;
    WM_SETBC  = 32768 + 22;
    WM_RITUP  = 32768 + 23;
    WM_RITDOWN  = 32768 + 24;
    WM_VOLUMEUP  = 32768 + 25;
    WM_VOLUMEDOWN  = 32768 + 26;
    WM_BWUP  = 32768 + 27;
    WM_BWDOWN  = 32768 + 28;
    WM_END  = 32768 + 29;
    WM_SETDURATION  = 32768 + 30;
    WM_PITCHUP  = 32768 + 32;
    WM_PITCHDOWN  = 32768 + 33;
    WM_COPYDATA = 74;
    WM_SETFREQUENCY = 32768 + 31;
    WM_PITCHSET = 32768 + 34;
    WM_ARRLFD = 32768 + 35;
    WM_SETMYEXCH = 32768 + 36;
    WM_ISCONTESTSUPPORTED = 32768 + 37;
    WM_SETCONTEST = 32768 + 38;
    WM_RUNPILEUP = 32768 + 39;
    WM_RUNSINGLE = 32768 + 40;
    KeysF1 = 112;
    KeysF2 = 113;
    KeysF3 = 114;
    KeysF4 = 115;
    KeysF5 = 116;
    KeysF6 = 117;
    KeysF7 = 118;
    KeysF8 = 119;
    KeysF9 = 120;
    KeysF10 = 121;
    KeysF11 = 122;
    KeysF12 = 123;
    KeysInsert = 45;
    KeysAdd = 107;

type

  {
    Defines the characteristics and behaviors of an exchange field.
    Used to declare various exchange field behaviors. Field Definitions
    are indexed by a contest definition (e.g. ARRL FD uses etFdClass and
    etStateProc). As new contests are added, new field definition
    may be required. When adding a new exchange field definition,
    search for existing code usages to find areas that will require changes.
  }
  TFieldDefinition = record
    C: PChar;     // Caption
    R: PChar;     // Regular Expression
    L: smallint;  // MaxLength
    T: smallint;  // Type
  end;

  PFieldDefinition = ^TFieldDefinition;

const
  // Exchange Field 1 settings/rules
  Exchange1Settings: array[TExchange1Type] of TFieldDefinition = (
    (C: 'RST';   R: '5[9N][9N]';        L: 3;  T:Ord(etRST)),
    (C: 'Name';  R: '[A-Z][A-Z]*';      L: 10; T:Ord(etOpName)),
    (C: 'Class'; R: '[1-9][0-9]*[A-F]'; L: 3;  T:Ord(etFdClass))
  );

  // Exchange Field 2 settings/rules
  Exchange2Settings: array[TExchange2Type] of TFieldDefinition = (
    (C: 'Nr.';        R: '([0-9][0-9]*)|(#)';              L: 4;  T:Ord(etSerialNr)),
    (C: 'Number';     R: '[1-9][0-9]*';                    L: 10; T:Ord(etCwopsNumber)),
    (C: 'Section';    R: '([A-Z][A-Z])|([A-Z][A-Z][A-Z])'; L: 3;  T:Ord(etArrlSection)),
    (C: 'State/Prov'; R: '[A-Z]*';                         L: 6;  T:Ord(etStateProv)),
    (C: 'Zone';       R: '[0-9]*';                         L: 2;  T:Ord(etCqZone)),
    (C: 'Zone';       R: '[0-9]*';                         L: 4;  T:Ord(etItuZone)),
    (C: 'Age';        R: '[0-9][0-9]';                     L: 2;  T:Ord(etAge)),
    (C: 'Power';      R: '([0-9]*)|(KW)|([0-9][OT]*)';     L: 4;  T:Ord(etPower)),
    (C: 'Number';     R: '[0-9]*[A-Z]';                    L: 12; T:Ord(etJarlOblastCode))
  );

  { display parsed Exchange field settings }
  BDebugExchSettings: boolean = false;

type

  { TMainForm }

  TMainForm = class(TForm)
    AlSoundOut1: TAlSoundOut;
    Edit5: TEdit;
    Label17: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    N40dB1: TMenuItem;
    N50dB1: TMenuItem;
    Send1: TMenuItem;
    CQ1: TMenuItem;
    Number1: TMenuItem;
    TU1: TMenuItem;
    MyCall1: TMenuItem;
    HisCall1: TMenuItem;
    QSOB41: TMenuItem;
    N1: TMenuItem;
    AGN1: TMenuItem;
    Bevel1: TBevel;
    Panel1: TPanel;
    Label1: TLabel;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    SpeedButton6: TSpeedButton;
    SpeedButton7: TSpeedButton;
    SpeedButton8: TSpeedButton;
    SpeedButton9: TSpeedButton;
    SpeedButton10: TSpeedButton;
    SpeedButton11: TSpeedButton;
    Edit1: TEdit;
    Label2: TLabel;
    Edit2: TEdit;
    Label3: TLabel;
    Edit3: TEdit;
    Bevel2: TBevel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Help1: TMenuItem;
    Readme1: TMenuItem;
    About1: TMenuItem;
    N2: TMenuItem;
    PaintBox1: TPaintBox;
    Panel5: TPanel;
    Exit1: TMenuItem;
    Panel6: TPanel;
    RichEdit1: TMemo;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Shape1: TShape;
    PopupMenu1: TPopupMenu;
    PileupMNU: TMenuItem;
    SingleCallsMNU: TMenuItem;
    CompetitionMNU: TMenuItem;
    N3: TMenuItem;
    StopMNU: TMenuItem;
    ImageList1: TImageList;
    Run1: TMenuItem;
    PileUp1: TMenuItem;
    SingleCalls1: TMenuItem;
    Competition1: TMenuItem;
    N4: TMenuItem;
    Stop1MNU: TMenuItem;
    ViewScoreBoardMNU: TMenuItem;
    ViewScoreTable1: TMenuItem;
    N5: TMenuItem;
    Panel7: TPanel;
    Label16: TLabel;
    Panel8: TPanel;
    Shape2: TShape;
    AlWavFile1: TAlWavFile;
    Panel9: TPanel;
    GroupBox3: TGroupBox;
    Label11: TLabel;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    CheckBox6: TCheckBox;
    SpinEdit3: TSpinEdit;
    GroupBox1: TGroupBox;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label9: TLabel;
    Edit4: TEdit;
    SpinEdit1: TSpinEdit;
    CheckBox1: TCheckBox;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    Panel10: TPanel;
    Label8: TLabel;
    SpinEdit2: TSpinEdit;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    Label10: TLabel;
    WebPage1: TMenuItem;
    Settings1: TMenuItem;
    Call1: TMenuItem;
    QSK1: TMenuItem;
    CWSpeed1: TMenuItem;
    N10WPM1: TMenuItem;
    N15WPM1: TMenuItem;
    N20WPM1: TMenuItem;
    N25WPM1: TMenuItem;
    N30WPM1: TMenuItem;
    N35WPM1: TMenuItem;
    N40WPM1: TMenuItem;
    N45WPM1: TMenuItem;
    N50WPM1: TMenuItem;
    N55WPM1: TMenuItem;
    N60WPM1: TMenuItem;
    CWBandwidth1: TMenuItem;
    CWBandwidth2: TMenuItem;
    N300Hz1: TMenuItem;
    N350Hz1: TMenuItem;
    N400Hz1: TMenuItem;
    N450Hz1: TMenuItem;
    N500Hz1: TMenuItem;
    N550Hz1: TMenuItem;
    N600Hz1: TMenuItem;
    N650Hz1: TMenuItem;
    N700Hz1: TMenuItem;
    N750Hz1: TMenuItem;
    N800Hz1: TMenuItem;
    N850Hz1: TMenuItem;
    N900Hz1: TMenuItem;
    N100Hz1: TMenuItem;
    N150Hz1: TMenuItem;
    N200Hz1: TMenuItem;
    N250Hz1: TMenuItem;
    N300Hz2: TMenuItem;
    N350Hz2: TMenuItem;
    N400Hz2: TMenuItem;
    N450Hz2: TMenuItem;
    N500Hz2: TMenuItem;
    N550Hz2: TMenuItem;
    N600Hz2: TMenuItem;
    MonLevel1: TMenuItem;
    N30dB1: TMenuItem;
    N20dB1: TMenuItem;
    N10dB1: TMenuItem;
    N0dB1: TMenuItem;
    N10dB2: TMenuItem;
    N6: TMenuItem;
    QRN1: TMenuItem;
    QRM1: TMenuItem;
    QSB1: TMenuItem;
    Flutter1: TMenuItem;
    LIDS1: TMenuItem;
    Activity1: TMenuItem;
    N11: TMenuItem;
    N21: TMenuItem;
    N31: TMenuItem;
    N41: TMenuItem;
    N51: TMenuItem;
    N61: TMenuItem;
    N71: TMenuItem;
    N81: TMenuItem;
    N91: TMenuItem;
    N7: TMenuItem;
    Duration1: TMenuItem;
    N5min1: TMenuItem;
    N10min1: TMenuItem;
    N15min1: TMenuItem;
    N30min1: TMenuItem;
    N60min1: TMenuItem;
    N90min1: TMenuItem;
    N120min1: TMenuItem;
    PlayRecordedAudio1: TMenuItem;
    N8: TMenuItem;
    AudioRecordingEnabled1: TMenuItem;
    HSTCompetition1: TMenuItem;
    HSTCompetition2: TMenuItem;
    Panel11: TPanel;
    ListView1: TListView;
    Operator1: TMenuItem;
    VolumeSlider1: TVolumeSlider;
    //UdpThread : TUdpThread;
    procedure FormCreate(Sender: TObject);
    procedure AlSoundOut1BufAvailable(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure Edit2KeyPress(Sender: TObject; var Key: Char);
    procedure Edit3KeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Edit1Enter(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure N40dB1Click(Sender: TObject);
    procedure N50dB1Click(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure Edit4Change(Sender: TObject);
    procedure Edit5Change(Sender: TObject);
    procedure ExchangeEditExit(Sender: TObject);
    procedure ComboBox2Change(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SpinEdit1Change(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure CheckBoxClick(Sender: TObject);
    procedure SpinEdit2Change(Sender: TObject);
    procedure SpinEdit3Change(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Readme1Click(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure RunMNUClick(Sender: TObject);
    procedure RunBtnClick(Sender: TObject);
    procedure SpinEdit4Change(Sender: TObject);
    procedure ViewScoreBoardMNUClick(Sender: TObject);
    procedure ViewScoreTable1Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Panel8MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Shape2MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Edit2Enter(Sender: TObject);
    procedure Edit3Enter(Sender: TObject);
    procedure VolumeSliderDblClick(Sender: TObject);
    procedure VolumeSlider1Change(Sender: TObject);
    procedure WebPage1Click(Sender: TObject);
    procedure Call1Click(Sender: TObject);
    procedure QSK1Click(Sender: TObject);
    procedure NWPMClick(Sender: TObject);
    procedure Pitch1Click(Sender: TObject);
    procedure Bw1Click(Sender: TObject);
    procedure File1Click(Sender: TObject);
    procedure PlayRecordedAudio1Click(Sender: TObject);
    procedure AudioRecordingEnabled1Click(Sender: TObject);
    procedure SelfMonClick(Sender: TObject);
    procedure Settings1Click(Sender: TObject);
    procedure LIDS1Click(Sender: TObject);
    procedure Activity1Click(Sender: TObject);
    procedure Duration1Click(Sender: TObject);
    procedure Operator1Click(Sender: TObject);
    procedure StopMNUClick(Sender: TObject);
  private
    MustAdvance: boolean;
    Hide_form: boolean;
    procedure ConfigureExchangeFields(
      AExchType1: TExchange1Type;
      AExchType2: TExchange2Type;
      AExchange:  String = '');
    procedure SetMyExch1(const AExchType: TExchange1Type; const Avalue: string);
    procedure SetMyExch2(const AExchType: TExchange2Type; const Avalue: string);
    function ValidateExchField(const FieldDef: PFieldDefinition;
      const Avalue: string) : Boolean;
    procedure ProcessSpace;
    // procedure ProcessEnter;
    procedure EnableCtl(Ctl: TWinControl; AEnable: boolean);
    procedure WmTbDown(var Msg: TMessage); message WM_TBDOWN;
    procedure SetToolbuttonDown(Toolbutton: TToolbutton; ADown: boolean);
    procedure UpdateRitIndicator;
    procedure DecSpeed;
    procedure IncSpeed;
    procedure MonitorUp;
    procedure MonitorDown;
    procedure PitchUp;
    procedure PitchDown;
  public
    CompetitionMode: boolean;
    NoRepeats: boolean;
    Name: string;
    procedure Run(Value: TRunMode);
    procedure WipeBoxes;
    procedure PopupScoreWpx;
    procedure PopupScoreHst;
    procedure Advance;
    procedure SetContest(AContestNum: TSimContest; AExchange : String = '');
    procedure SetContestByKey(constref AContestKey: String; AExchange : String = '');
    procedure SetMyExchange(constref AExchange: string);
    procedure SetQsk(Value: boolean);
    procedure SetMyCall(ACall: string);
    procedure SetMyZone(AZone: string);
    procedure SetPitch(PitchNo: integer);
    procedure SetBw(BwNo: integer);
    procedure ReadCheckboxes;
    procedure ProcessEnter;
    procedure IncRit(dF: integer);
    procedure SendMsg(Msg: TStationMessage);
  end;

var
  MainForm: TMainForm;
  PrevWndProc: WNDPROC;
  ContestKey: String;      // N1MM+'s contest key from Select Contest dialog
  SentExchange: String;    // N1MM+'s 'sent exchange' field from Contest setup
  recvdata: PCopyDataStruct;
  msgtype: Integer;
  msglen: Integer;
  str: string;
  tmpobj: TObject;

implementation

uses ScoreDlg, TypInfo;

{$R *.lfm}

function ToStr(const val : TExchange1Type) : string; overload;
begin
  Result := GetEnumName(typeInfo(TExchange1Type ), Ord(val));
end;

function ToStr(const val : TExchange2Type) : string; overload;
begin
  Result := GetEnumName(typeInfo(TExchange2Type ), Ord(val));
end;

{ return whether the Edit2 control is the RST exchange field. }
function Edit2IsRST: Boolean;
begin
  assert((not (SimContest in [scWpx, scHst])) or
    (ActiveContestExchType1 = etRST));
  Result := ActiveContestExchType1 = etRST;
end;

function WndCallback(Ahwnd: HWND; uMsg: UINT; wParam: WParam; lParam: LParam):LRESULT; stdcall;
var
  strlen: integer;
begin
  //DebugLn('uMsg = ', intToStr(uMsg));
  //DebugLn('wParam = ', intToStr(wParam));
  case uMsg of
     WM_KEYDOWN:
          case wParam of
               KeysF1:
               begin
                    DebugLnEnter('WM_KEYDOWN.KeysF1: received msgCQ');
                    MainForm.SendMsg(TStationMessage.msgCQ);
                    DebugLnExit([]);
                    exit;
               end;

               KeysInsert:
                 begin
                      if CallSent = True then // correct call TU message
                      begin
                           DebugLnEnter('WM_KEYDOWN.KeysInsert: CallSent is true, sending msgHisCall, msgNr');
                           MainForm.SendMsg(TStationMessage.msgHisCall);
                           MainForm.SendMsg(TStationMessage.msgNr);
                      end
                      else
                      begin
                           DebugLnEnter('WM_KEYDOWN.KeysInsert: CallSent is false, calling MainForm.ProcessEnter');
                           MainForm.ProcessEnter;
                      end;
                      //MainForm.Advance;
                      DebugLnExit([]);
                      exit;
                 end;
               //KeysAdd:  // let it be handled by standalone code
               //  begin
               //       if not CallSent then MainForm.SendMsg(TStationMessage.msgHisCall);
               //       MainForm.SendMsg(TStationMessage.msgTU);
               //       Log.SaveQso;
               //       exit;
               //  end;

          end;
     WM_CQWW:
       begin
          DebugLnEnter('WM_CQWW: starting cqww');
          if false then // arrl Field Day forced testing...
            // remove this section after adding WM_ARRLFD
            begin
              DebugLn('Forcing ARRL Field Day...');
              Ini.ContestName := '';
              SentExchange := '7A OR';
              assert(not SentExchange.IsEmpty(), 'WM_SETMYEXCH must occur before WM_CQWW');
              MainForm.SetContestByKey('FD', SentExchange);
              assert(Ini.ContestName = 'arrlfd');
              MainForm.Run(rmPileUp);
              DebugLnExit([]);
              exit;
            end;
          Ini.ContestName := '';
          assert(not SentExchange.IsEmpty(),
            'WM_SETMYZONE or WM_SETMYEXCH must be sent before WM_CQWW');
          MainForm.SetContestByKey('CQWWCW', SentExchange);
          assert(Ini.ContestName = 'cqww');
          MainForm.Run(rmPileUp);
          DebugLnExit([]);
          exit;
       end;
     WM_CQWPX:
       begin
            DebugLnEnter('WM_CQWPX: starting cqwpx');
            Ini.ContestName := '';
            assert(not SentExchange.IsEmpty(),
              'WM_SETMYZONE or WM_SETMYEXCH must be sent before WM_CQWPX');
            MainForm.SetContestByKey('CQWPXCW', SentExchange);
            assert(Ini.ContestName = 'cqwpx');
            MainForm.Run(rmPileUp);
            DebugLnExit([]);
            exit;
       end;
     WM_ARRLFD:
       begin
            DebugLnEnter('WM_ARRLFD: starting Arrl FD');
            assert(not SentExchange.IsEmpty(), 'WM_SETMYEXCH must be sent before WM_ARRLFD');
            MainForm.SetContestByKey('FD', SentExchange);
            assert(Ini.ContestName = 'arrlfd');
            MainForm.Run(rmPileUp);
            DebugLnExit([]);
            exit;
       end;
     WM_RUNPILEUP:
       begin
            // Note - must be sent after WM_SETMYEXCH & WM_SETCONTEST.
            DebugLnEnter('WM_RUNPILEUP:');
            assert(not ContestKey.IsEmpty(), 'WM_SETCONTEST must occur before WM_RUNPILEUP');
            assert(not SentExchange.IsEmpty(), 'WM_SETMYEXCH must occur before WM_RUNPILEUP');
            MainForm.SetContestByKey(ContestKey, SentExchange);
            MainForm.Run(rmPileUp);
            DebugLnExit([]);
            exit;
       end;
     WM_RUNSINGLE:
       begin
            // Note - must be sent after WM_SETMYEXCH & WM_SETCONTEST.
            DebugLnEnter('WM_RUNSINGLE:');
            assert(not ContestKey.IsEmpty(), 'WM_SETCONTEST must occur before WM_RUNSINGLE');
            assert(not SentExchange.IsEmpty(), 'WM_SETMYEXCH must occur before WM_RUNSINGLE');
            MainForm.SetContestByKey(ContestKey, SentExchange);
            MainForm.Run(rmSingle);
            DebugLnExit([]);
            exit;
       end;
     WM_STOP:
       begin
            DebugLn('WM_STOP:');
            MainForm.Run(rmStop);
            exit;
       end;
     WM_END:
       begin
            DebugLn('WM_END:');
            MainForm.Close;
            exit;
       end;
     WM_SETAUDIO:
       begin
            Ini.RadioAudio := lParam;
            MainForm.AlSoundOut1.ChangeSoundLevel(Ini.RadioAudio);
            DebugLn('WM_SETAUDIO: setaudio = ', intToStr(lParam));
            exit;
       end;
     WM_GETTXSTATUS:
      begin
           if Tst.Me.State = stSending then
             begin
             result := 1;
             end
           else
           begin
             result := 0;
           end;
           exit;
      end;
     WM_RITUP:
      begin
           MainForm.IncRit(1);
           exit;
      end;
     WM_RITDOWN:
      begin
           MainForm.IncRit(-1);
           exit;
      end;
     WM_VOLUMEUP:
      begin
           MainForm.MonitorUp;
           exit;
      end;
      WM_VOLUMEDOWN:
      begin
           MainForm.MonitorDown;
           exit;
      end;
      WM_PITCHUP:
      begin
           MainForm.PitchUp;
           exit;
      end;
      WM_PITCHDOWN:
      begin
           MainForm.PitchDown;
           exit;
      end;

     WM_SETBC:
       begin
       //DebugLn('wParam = ', intToStr(wParam));
       //DebugLn('lParam = ', intToStr(lParam));
         Ini.Standalone := False; //controlled by N1MM or DXLog
          case wParam of
                  WM_SETQRM:
                    begin
                         MainForm.CheckBox3.Checked := strToBool(intToStr(lParam));
                    end;
                  WM_SETQRN:
                    begin
                         MainForm.CheckBox4.Checked := strToBool(intToStr(lParam));
                    end;
                  WM_SETQSB:
                    begin
                         MainForm.CheckBox2.Checked := strToBool(intToStr(lParam));
                    end;
                  WM_SETFLUTTER:
                    begin
                         MainForm.CheckBox5.Checked := strToBool(intToStr(lParam));
                    end;
                  WM_SETLIDS:
                    begin
                         MainForm.CheckBox6.Checked := strToBool(intToStr(lParam));
                    end;
          end;
          MainForm.ReadCheckBoxes;
          exit;
       end;
     WM_COPYDATA :
       begin
            //DebugLn('wParam = ', intToStr(wParam));
            recvdata := PCopyDataStruct(lParam);
            msgtype := recvdata^.dwData;
            msglen := recvdata^.cbData;
            str := StrPas(PCHAR(Recvdata^.lpData));
           //DebugLn('WM_COPYDATA.msgtype = ', intToStr(msgtype));
           //DebugLn('WM_COPYDATA.str = ', str);
           case msgtype of
              WM_SETCWSPEED:
                begin
                     DebugLn('WM_SETCWSPEED: str=', str);
                     MainForm.SpinEdit1.Value := StrToInt(str);
                     Tst.Me.Wpm := StrToInt(str);
                     Wpm := StrToInt(str);
                     exit;
                end;
              WM_SETMYCALL:
                begin
                    DebugLnEnter('WM_SETMYCALL: str=', str);
                    MainForm.SetMyCall(str);
                    Call := str;
                    DebugLnExit([]);
                    exit;
                end;
              WM_SETMYZONE:
                begin
                    DebugLnEnter('WM_SETMYZONE: str=', str);
                    MainForm.SetMyZone(str);
                    NR := str;
                    SentExchange := Format('5nn %s', [str]); // long term, I'll drop the 5nn from exchange like N1MM contest setup.
                    DebugLnExit([]);
                    exit;
                end;
              WM_SETMYEXCH:
                begin
                  {
                    WM_COPYDATA WM_SETMYEXCH <sent-exchange>
                    where:
                      sent-exchange = Exchange value entered in the Morse Runner
                      Setup dialog (currently called "Zone"). Ideally this field
                      is populated with the "Sent Exchange" field entered on the
                      "Contest" tab of N1MM's Contest Selection dialog(s).
                      Like N1MM, the RST is omitted from this string.
                      Examples: '3', '#', '3A OR', 'Mike OR', etc.

                    This message replaces WM_SETMYZONE using a contest-specific
                    exchange string. This message sets the contest exchange
                    value. It is called before the WM_CQWW, WM_CQWPX OR
                    WM_ARRLFD messages.

                    Question: How do we return an error string for syntax error
                              in exchange string?
                  }
                    DebugLn('WM_SETMYEXCH: str=', str);
                    SentExchange := Trim(str);
                    exit;
                end;
              WM_ISCONTESTSUPPORTED:
                begin
                    // Return whether a Contest Key (e.g. 'CQWWCW') is supported?
                    Result := IfThen(Ini.IsContestSupported(str), 1, 0);
                    DebugLn('WM_ISCONTESTSUPPORTED(''%s''): %d', [str, Result]);
                    exit;
                end;
              WM_SETCONTEST:
                begin
                  {
                    WM_COPYDATA WM_SETCONTEST <contest-key>
                    where
                      contest-key = unique contest identifier from column 1
                                    of N1MM+'s Select Contest dialog
                                    (e.g. CQWWCW, CQWPXCW, FD, NAQPCW).

                    This message will select the current contest using
                    <contest-key> and set a default exchange value.
                    WM_SETMYEXCH must be called to set the contest-specific
                    exchange.

                    Question: How do we return an error string for an invalid
                              contest key?
                  }
                    DebugLnEnter('WM_SETCONTEST: str=', str);
                    assert(not SentExchange.IsEmpty,
                      'SETMYEXCH must be called before WM_SETCONTEST');
                    if Ini.IsContestSupported(str) then begin
                      ContestKey := str;
                      Mainform.SetContestByKey(ContestKey, SentExchange);
                      Result := 1
                    end
                    else begin
                      ContestKey := '';
                      Result := 0;
                    end;
                    DebugLnExit([]);
                    exit;
                end;
              WM_SETACTIVITY:
                begin
                     DebugLn('WM_SETACTIVITY: str=', str);
                     Activity := StrToInt(str);
                     MainForm.SpinEdit3.Value := Activity;
                     exit;
                end;
              WM_SETDURATION:
                begin
                     DebugLn('WM_SETDURATION: str=', str);
                     Duration := StrToInt(str);
                     MainForm.SpinEdit2.Value := Duration;
                     exit;
                end;
              WM_SETMSGCQ:
                begin
                     DebugLn('WM_SETMSGCQ: str=', str);
                     Ini.Messagecq := str;
                     exit;
                end;
              WM_SETCALL:
                begin
                     DebugLn('WM_SETCALL: str=', str);
                     MainForm.Edit1.Text := str;
                     MainForm.Edit1Change(tmpobj);
                     exit;
                end;
              WM_SETRST:
                begin
                     DebugLn('WM_SETRST: str=', str);
                     MainForm.Edit2.Text := str;
                     exit;
                end;
              WM_SETNR:
                begin
                     DebugLn('WM_SETNR: str=', str);
                     MainForm.Edit3.Text := str;
                     exit;
                end;
              WM_SETMSGTU:
                begin
                    DebugLn('WM_SETMSGTU: str=', str);
                    Ini.Messagetu := str;
                    exit;
                end;
              WM_SETMSGNR:
                begin
                    DebugLn('WM_SETMSGNR: str=', str);
                    strlen := Length(str);
                    str := RightStr(str, (strlen-4));
                    Tst.Me.NR := StrToInt(str);
                    exit;
                end;
              WM_PITCHSET:
                begin
                    DebugLnEnter('WM_PITCHSET: str=', str);
                    Pitch := (StrToInt(str) div 50) - 6;
                    MainForm.SetPitch(Pitch);
                    DebugLnExit([]);
                    exit;
                end;
           end;
       end;
    end;
  //DebugLn('uMsg = ', intToStr(uMsg));
  //DebugLn('wParam = ', intToStr(wParam));
  //DebugLn('lParam = ', intToStr(lParam));
  result:=CallWindowProc(PrevWndProc,Ahwnd, uMsg, WParam, LParam);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var programname : Ansistring;
  tfOut: TextFile;
  userdir:string;
arg1 : Ansistring;
arg2 : Ansistring;
begin
{$ifdef DEBUG_LOGGING}
  userdir := GetUserDir;
  DebugLogger.LogName:= Format('%sDocuments\N1MM Logger+\debug.txt', [userdir]);
{$endif}
  DebugLn('----------------------------------------');
  DebugLnEnter('TMainForm.FormCreate: GetCurrentThreadID %d', [GetCurrentThreadID()]);
  //DebugLnThreadLog('TMainForm.FormCreate...');

  PrevWndProc:=Windows.WNDPROC(SetWindowLongPtr(Self.Handle,GWL_WNDPROC,PtrInt(@WndCallback)));
  Randomize;
  Tst := TContest.Create;
  arg1 := ParamStr(1);
  arg2 := ParamStr(2);
  If arg1 = '-h' then
  begin
     Ini.Standalone := False;
  end;
  FromIni;
  LoadCallList;
  gARRLFD := TArrlFieldDay.Create;
  Ini.RadioAudio := 0;
  programname := ParamStr(0);

  DebugLn('arg1 = ', arg1);
  DebugLn('arg2 = ', arg2);

  Hide_form := False;
  //arg1 := '';

  If arg1 = '-h' then
  begin
   Hide_form := True;
  end;

  Name := '1';
  If arg2 = '-r1' then
  begin
       MainForm.Caption := MainForm.Caption + ':  R1';
       Ini.RadioAudio := 1;
       Name := '1';
  end;

  If arg2 = '-r2' then
  begin
       MainForm.Caption := MainForm.Caption + ':  R2';
       Ini.RadioAudio := 2;
       Name := '2';
  end;

  // ParamCount;
  //Randomize;
  //Tst := TContest.Create;
  //FromIni;
  //LoadCallList;
  //
  AlSoundOut1.Init(Ini.RadioAudio, 4);

  MakeKeyer;
  Keyer.Rate := DEFAULTRATE;
  Keyer.BufSize := Ini.BufSize;

  Panel2.DoubleBuffered := true;
  RichEdit1.Align := alClient;

  if Ini.Standalone then
    SetContest(SimContest, Ini.UserExchangeTbl[SimContest])
  else  // running embedded within N1MM
    SetContest(SimContest, '');
  DebugLnExit([]);
end;


procedure TMainForm.FormDestroy(Sender: TObject);
begin
  DebugLnEnter('TMainForm.FormDestroy');
  If Ini.Standalone = true then
  begin
       ToIni;
  end;
  gARRLFD.Free;
  Tst.Free;
  DestroyKeyer;
  DebugLnExit([]);
end;



procedure TMainForm.AlSoundOut1BufAvailable(Sender: TObject);
begin
  //DebugLnThreadLog('TMainForm.AlSoundOut1BufAvailable');
  if AlSoundOut1.Enabled then
    try AlSoundOut1.PutData(Tst.GetAudio); except end;
end;


procedure TMainForm.SendClick(Sender: TObject);
var
  Msg: TStationMessage;

begin
  Msg := TStationMessage((Sender as TComponent).Tag);
  DebugLnEnter('TMainForm.SendClick, Msg=%s', [DbgS(Msg)]);
    //If Ini.Standalone = False then
    //begin
    //    // DebugLnExit('TMainForm.SendClick exit ', DbgS(Msg));
    //exit;
    //end;

  SendMsg(Msg);

  case Msg of
    msgHisCall: CallSent:= true;
    msgNR: NrSent:= true;
    end;
  DebugLnExit([]);
end;



procedure TMainForm.SendMsg(Msg: TStationMessage);
begin
  if Msg = msgHisCall then
    begin
    if Edit1.Text <> '' then Tst.Me.HisCall := Edit1.Text;
    CallSent := true;
    end;

  if Msg = msgNR then  NrSent := true;

  Tst.Me.SendMsg(Msg);
end;


procedure TMainForm.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['A'..'Z', 'a'..'z', '0'..'9', '/', '?', #8]) then Key := #0;
end;

procedure TMainForm.Edit2KeyPress(Sender: TObject; var Key: Char);
begin
  case ActiveContestExchType1 of
    etRST:
      begin
        // valid RST characters...
        if not CharInSet(Key, ['0'..'9', #8]) then
          Key := #0;
      end;
    etOpName:
      begin
        // valid operator name characters
        if not CharInSet(Key, ['A'..'Z','a'..'z', #8]) then
          Key := #0;
      end;
    etFdClass:
      begin
        // valid Station Classification characters, [1-9][0-9]+[A-F]|DX
        if not CharInSet(Key, ['0'..'9','A'..'F','a'..'f','X','x',#8]) then
          Key := #0;
      end;
    else
      assert(false, Format('invalid exchange field 1 type: %s',
        [ToStr(ActiveContestExchType1)]));
  end;
end;

procedure TMainForm.Edit3KeyPress(Sender: TObject; var Key: Char);
begin
  case ActiveContestExchType2 of
    etSerialNr, etCwopsNumber, etCqZone, etItuZone, etAge:
      begin
        // valid Zone or NR field characters...
        if not CharInSet(Key, ['0'..'9', #8]) then
          Key := #0;
      end;
    etPower:
      begin
        case Key of
          'a', 'A': Key := '1';
          'n', 'N': Key := '9';
          't', 'T': Key := '0';
        end;
        // valid Power characters, including KW...
        if not CharInSet(Key, ['0'..'9', 'K', 'k', 'W', 'w', #8]) then
          Key := #0;
      end;
    etArrlSection:
      begin
        // valid Section characters (e.g. OR or STX)
        if not CharInSet(Key, ['A'..'Z', 'a'..'z', #8]) then
          Key := #0;
      end;
    etStateProv:
      begin
        // valid State/Prov characters (e.g. OR or BC)
        if not CharInSet(Key, ['A'..'Z', 'a'..'z', #8]) then
          Key := #0;
      end;
    else
      assert(false, Format('invalid exchange field 2 type: %s',
        [ToStr(ActiveContestExchType2)]));
  end;
end;


procedure TMainForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
{
    #13: //^M = ESM
      Ini.Esm := not Ini.Esm;
}
    #23: //^W  = Wipe
      WipeBoxes;

    #25: //^Y  = Edit
      ;

    #27: //Esc = Abort send
      begin
      if msgHisCall in Tst.Me.Msg then CallSent := false;
      if msgNR in Tst.Me.Msg then NrSent := false;
      Tst.Me.AbortSend;
      end;

    ';': //<his> <#>
      begin
      SendMsg(msgHisCall);
      SendMsg(msgNr);
      end;

    '.', '+', '[', ',': //TU & Save
      begin
      if not CallSent then SendMsg(msgHisCall);
      SendMsg(msgTU);
      Log.SaveQso;
      end;

    ' ': // advance to next exchange field; necessary to allow space (' ')
         // to be added to Edit5 (exchange field).
      if (ActiveControl = Edit1) or
         (ActiveControl = Edit2) or
         (ActiveControl = Edit3) then
        ProcessSpace
      else
        Exit;

    '\': // = F1
      begin
    //  DebugLn('in FormKeyPress F1');
      SendMsg(msgCQ);
      end;

    else Exit;
  end;

  Key := #0;
end;


procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT: //<his> <#>
      begin
      SendMsg(msgHisCall);
      SendMsg(msgNr);
      Key := 0;
      end;

    VK_RETURN: //Save
      ProcessEnter;

    VK_F11:
      WipeBoxes;

    87, 119: //Alt-W  = Wipe
      if GetKeyState(VK_MENU) < 0 then WipeBoxes else Exit;

{
    'M': //Alt-M  = Auto CW
      if GetKeyState(VK_MENU) < 0
        then Ini.AutoCw := not Ini.AutoCw
        else Exit;
}

    VK_UP:
      if GetKeyState(VK_CONTROL) >= 0 then IncRit(-1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex+1);

    VK_DOWN:
      if GetKeyState(VK_CONTROL) >= 0  then IncRit(1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex-1);

    VK_PRIOR: //PgUp
      IncSpeed;

    VK_NEXT: //PgDn
      DecSpeed;

     VK_F9:
       if (ssAlt in Shift) or  (ssCtrl in Shift) then DecSpeed;

     VK_F10:
       if (ssAlt in Shift) or  (ssCtrl in Shift) then IncSpeed;

    else Exit;
    end;

  Key := 0;
end;


procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT, VK_RETURN: Key := 0;
    end;
end;


procedure TMainForm.ProcessSpace;
begin
  MustAdvance := false;
  if Edit2IsRST then
    begin
      if ActiveControl = Edit1 then
        begin
          if Edit2.Text = '' then
            Edit2.Text := '599';
          ActiveControl := Edit3;
        end
      else if ActiveControl = Edit2 then
        begin
          if Edit2.Text = '' then
            Edit2.Text := '599';
          ActiveControl := Edit3;
        end
      else
        ActiveControl := Edit1;
    end
  else {otherwise, space bar moves cursor to next field}
    begin
      if ActiveControl = Edit1 then
        begin
          if SimContest = scFieldDay then
            UpdateSbar(Edit1.Text);
          ActiveControl := Edit2;
        end
      else if ActiveControl = Edit2 then
        ActiveControl := Edit3
      else
        ActiveControl := Edit1;
    end;
end;


procedure TMainForm.ProcessEnter;
var
  C, N, R: boolean;
begin
  DebugLnEnter('ProcessEnter...');
  if ActiveControl = Edit5 then
    begin
      ExchangeEditExit(ActiveControl);
      DebugLnExit([]);
      Exit;
    end;
  MustAdvance := false;

  if (GetKeyState(VK_CONTROL) or GetKeyState(VK_SHIFT) or GetKeyState(VK_MENU)) < 0 then
  begin
    Log.SaveQso;
    DebugLnExit([]);
    Exit;
  end;

  // for certain contests (e.g. ARRL Field Day), update update status bar
  if SimContest in [scFieldDay] then
    UpdateSbar(Edit1.Text);

  //no QSO in progress, send CQ
  if Edit1.Text = '' then
  begin
       SendMsg(msgCq);
       DebugLnExit([]);
       Exit;
  end;

  //current state
  C := CallSent;
  N := NrSent;
  R := Edit3.Text <> '';

  //send his call if did not send before, or if call changed
  if (not C) or ((not N) and (not R)) then SendMsg(msgHisCall);
  if not N then SendMsg(msgNR);
  if N and not R then SendMsg(msgQm);

  if R and (C or N)
    then
      begin
      SendMsg(msgTU);
      Log.SaveQso;
      end
    else
      MustAdvance := true;
  DebugLnExit([]);
end;


procedure TMainForm.Edit1Enter(Sender: TObject);
var
  P: integer;
begin
  P := Pos('?', Edit1.Text);
  if P > 1 then
    begin Edit1.SelStart := P-1; Edit1.SelLength := 1; end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  If Hide_form = True then
    begin
    Hide;
    end;
end;


procedure TMainForm.N40dB1Click(Sender: TObject);
begin

end;

procedure TMainForm.N50dB1Click(Sender: TObject);
begin

end;




procedure TMainForm.IncSpeed;
begin
  Wpm := Trunc(Wpm / 5) * 5 + 5;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;


procedure TMainForm.DecSpeed;
begin
  Wpm := Ceil(Wpm / 5) * 5 - 5;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;


procedure TMainForm.Edit4Change(Sender: TObject);
begin
  DebugLnEnter('TMainForm.Edit4Change');
  SetMyCall(Trim(Edit4.Text));
  DebugLnExit([]);
end;

procedure TMainForm.Edit5Change(Sender: TObject);
begin
  DebugLnEnter('TMainForm.Edit5Change');
  SetMyExchange(Trim(Edit5.Text));
  DebugLnExit([]);
end;

procedure TMainForm.ExchangeEditExit(Sender: TObject);
begin
  DebugLnEnter('TMainForm.ExchangeEditExit');
  SetMyExchange(Trim(Edit5.Text));
  DebugLnExit([]);
end;

procedure TMainForm.SetContest(AContestNum: TSimContest;
  AExchange : String = '');
begin
  DebugLnEnter('SetContest(%s, ''%s'')', [DbgS(AContestNum), AExchange]);
  // validate selected contest
  if not (AContestNum in [scWpx, scCQWW, scFieldDay, scHst]) then
  begin
    ShowMessage('The selected contest is not yet supported.');
    //SimContestCombo.ItemIndex:= Ord(Ini.SimContest);
    DebugLnExit('error: The selected contest is not yet supported.');
    Exit;
  end;

{  assert(ContestDefinitions[AContestNum].T = AContestNum,
    'Contest definitions are out of order');
}
  Ini.SimContest := AContestNum;
{
Ini.ActiveContest := @ContestDefinitions[AContestNum];
  SimContestCombo.ItemIndex := Ord(AContestNum);
}
  WipeBoxes;

  // update Exchange field labels and length settings (e.g. RST, Nr.)
  // note: this case statement will be replaced by table-driven lookup.
  case SimContest of
  scWpx:
    ConfigureExchangeFields(etRST, etSerialNr, AExchange);
  scCQWW:
    ConfigureExchangeFields(etRST, etCqZone, AExchange);
  scFieldDay:
    ConfigureExchangeFields(etFdClass, etArrlSection, AExchange);
  else
    assert(false, 'missing case');
  end;
  DebugLnExit([]);
end;


procedure TMainForm.SetContestByKey(constref AContestKey: String;
  AExchange : String = '');
const
  ContestNames: array[TSimContest] of string =
    ('cqwpx', 'cqww', 'arrlfd', 'hst');
var
  ContestNum : TSimContest;
begin
  DebugLnEnter('TMainForm.SetContestByKey(''%s'', ''%s'')', [AContestKey, AExchange]);
  if not Ini.FindContestByKey(AContestKey, ContestNum) then
    assert(false, Format('the requested contest is not supported: ''%s''', [AContestKey]));

  ContestName := ContestNames[ContestNum];
  SetContest(ContestNum, AExchange);
  DebugLnExit([]);
end;


{
  Set my exchange fields using the exchange string containing two values,
  separated by a space. Error/warning messages are displayed in the status bar.
}
procedure TMainForm.SetMyExchange(constref AExchange: string);
var
  sl: TStringList;
  Field1Def: PFieldDefinition;
  Field2Def: PFieldDefinition;
begin
  DebugLnEnter('TMainForm.SetMyExchange(''%s'')', [AExchange]);
  sl:= TStringList.Create;
  try
    Field1Def := @Exchange1Settings[ActiveContestExchType1];
    Field2Def := @Exchange2Settings[ActiveContestExchType2];

    // parse into two strings [Exch1, Exch2]
    ExtractStrings([' '], [], PChar(AExchange), sl);
    if sl.Count = 0 then
      sl.AddStrings(['', '']);
    if sl.Count = 1 then
      sl.AddStrings(['']);

    // set contest-specific exchange values
    SetMyExch1(ActiveContestExchType1, sl[0]);
    SetMyExch2(ActiveContestExchType2, sl[1]);

    // update the Exchange field value
    Edit5.Text := AExchange;
    Ini.UserExchangeTbl[SimContest]:= AExchange;

  finally
    sl.Free;
  end;
  DebugLnExit([]);
end;


procedure TMainForm.SetMyCall(ACall: string);
begin
  Ini.Call := ACall;
  Edit4.Text := ACall;
  Tst.Me.MyCall := ACall;
end;

{
  Exchange Field types are determined by each contest.
  Exchange field labels and exchange field maximum length are set.
  Prior field values from .INI file are applied.
  This procedure is called by SetContest() whenever the contest changes.
}
procedure TMainForm.ConfigureExchangeFields(
  AExchType1: TExchange1Type;
  AExchType2: TExchange2Type;
  AExchange:  String = '');

var
  AExchangeLabel: PChar = '';
  Visible: Boolean;

begin
  DebugLnEnter('ConfigureExchangeFields(%s, %s, ''%s'')',
               [DbgS(AExchType1), DbgS(AExchType2), AExchange]);

  // Optional Contest Exchange label and field
  case SimContest of
    scCQWW: AExchangeLabel := 'Zone';
    scWpx: AExchangeLabel := 'Zone';
    scFieldDay: AExchangeLabel := 'Exchange';
    else
      assert(false, 'missing case');
  end;
  Visible := AExchangeLabel <> '';
  Label20.Visible:= Visible;
  Edit5.Visible:= Visible;
  Edit5.Width := 80;
  Label20.Caption:= AExchangeLabel;

  // The Exchange field is editable in some contests
  //ExchangeEdit.Enabled := ActiveContest.ExchFieldEditable;
  Edit5.Enabled := SimContest in [scCQWW, scFieldDay];

  // setup Exchange Field 1 (e.g. RST)
  assert(AExchType1 = TExchange1Type(Exchange1Settings[AExchType1].T),
    Format('Exchange1Settings[%d] ordering error: found %s, expecting %s.',
      [Ord(AExchType1), ToStr(AExchType1),
      ToStr(TExchange1Type(Exchange1Settings[AExchType1].T))]));
  Label2.Caption:= Exchange1Settings[AExchType1].C;
  Edit2.MaxLength:= Exchange1Settings[AExchType1].L;
  Ini.ActiveContestExchType1 := AExchType1;

  // setup Exchange Field 2 (e.g. Serial #)
  assert(AExchType2 = TExchange2Type(Exchange2Settings[AExchType2].T),
    Format('Exchange2Settings[%d] ordering error: found %s, expecting %s.',
      [Ord(AExchType2), ToStr(AExchType2),
      ToStr(TExchange2Type(Exchange2Settings[AExchType2].T))]));
  Label3.Caption := Exchange2Settings[AExchType2].C;
  Edit3.MaxLength := Exchange2Settings[AExchType2].L;
  Ini.ActiveContestExchType2 := AExchType2;

  // Set my exchange value (from N1MM or .INI file)
  if AExchange.Length > 0 then
    SetMyExchange(AExchange);

  DebugLnExit([]);
end;

procedure TMainForm.SetMyExch1(const AExchType: TExchange1Type;
  const Avalue: string);
begin
  DebugLnEnter('SetMyExch1(%s, %s)', [DbgS(AExchType), Avalue]);
  case AExchType of
    etRST:
      begin
        // Format('invalid RST (%s)', [AValue]));
        //Ini.UserExchange1[SimContest] := Avalue;
        if BDebugExchSettings then Edit2.Text := Avalue; // testing only
      end;
    etFdClass:  // e.g. scFieldDay (3A)
      begin
        // 'expecting FD class (3A)'
        Ini.ArrlClass := Avalue;
        //Ini.UserExchange1[SimContest] := Avalue;
        Tst.Me.Exch1 := Avalue;
        if BDebugExchSettings then Edit2.Text := Avalue; // testing only
      end;
    else
      assert(false, Format('Unsupported exchange 1 type: %s.', [ToStr(AExchType)]));
  end;
  DebugLnExit([]);
end;

procedure TMainForm.SetMyExch2(const AExchType: TExchange2Type;
  const Avalue: string);
var
  i: integer;
begin
  DebugLnEnter('SetMyExch2(%s, %s)', [DbgS(AExchType), Avalue]);
  case AExchType of
    etSerialNr:
      begin
        //Ini.UserExchange2[SimContest] := Avalue;
        if not IsNum(Avalue) or (RunMode = rmHst) then
          Tst.Me.Nr := 1
        else
          Tst.Me.Nr := StrToInt(Avalue);
        if BDebugExchSettings then Edit3.Text := IntToStr(Tst.Me.Nr);  // testing only
      end;
    etArrlSection:  // e.g. Field Day (OR)
      begin
        // 'expecting FD section (e.g. OR)'
        Ini.ArrlSection := Avalue;
        //Ini.UserExchange2[SimContest] := Avalue;
        Tst.Me.Exch2 := Avalue;
        if BDebugExchSettings then Edit3.Text := Avalue; // testing only
      end;
    etStateProv:  // e.g. NAQP (OR)
      begin
        // 'expecting State or Providence (e.g. OR)'
        //Ini.UserExchange2[SimContest] := Avalue;
        Tst.Me.Exch2 := Avalue;
        if BDebugExchSettings then Edit3.Text := Avalue; // testing only
      end;
    etCqZone:
      begin
        //Ini.UserExchange2[SimContest] := Avalue;
        Tst.Me.Nr := StrToInt(Avalue);
        if BDebugExchSettings then Edit3.Text := IntToStr(Tst.Me.Nr);  // testing only
      end;
    //etItuZone:
    //etAge:
    //etPower:
    //etJarlOblastCode:
    else
      assert(false, Format('Unsupported exchange 2 type: %s.', [ToStr(AExchType)]));
  end;
  DebugLnExit([]);
end;


function TMainForm.ValidateExchField(const FieldDef: PFieldDefinition;
  const Avalue: string) : Boolean;
//var
  //reg: TPerlRegEx;
  //s: string;
begin
  {reg := TPerlRegEx.Create();
  try
    reg.Subject := UTF8Encode(Avalue);
    s:= '^(' + FieldDef.R + ')$';
    reg.RegEx:= UTF8Encode(s);
    Result:= Reg.Match;
  finally
    reg.Free;
  end;
  }
  Result := true;
end;

procedure TMainForm.SetMyZone(AZone: string);
begin
  DebugLnEnter('TMainForm.SetMyZone(''%s'')', [AZone]);
  Ini.NR := AZone;
  Edit5.Text := AZone;
  if (AZone = '') then AZone := '0';
  Tst.Me.NR := StrToInt(AZone);
  DebugLnExit([]);
end;

procedure TMainForm.PitchUp;
var
  currpitch : integer;
begin
   currpitch := (Ini.Pitch - 300) div 50;
   SetPitch(currpitch + 1);
end;

procedure TMainForm.PitchDown;
var
  currpitch : integer;
begin
   currpitch := (Ini.Pitch - 300) div 50;
   SetPitch(currpitch - 1);
end;

{
  Set pitch based on menu item number.
  Must be within range [0, ComboBox1.Items.Count).
}
procedure TMainForm.SetPitch(PitchNo: integer);
begin
  PitchNo := Max(0, Min(PitchNo, ComboBox1.Items.Count-1));
  Ini.Pitch := 300 + PitchNo * 50;
  ComboBox1.ItemIndex := PitchNo;
  Tst.Modul.CarrierFreq := Ini.Pitch;
  DebugLn('TMainForm.SetPitch(%d): Pitch %d, Tst.Modul.CarrierFreq %f',
    [PitchNo, Ini.Pitch, Tst.Modul.CarrierFreq]);
end;


{
  Set bandwidth based on menu item number.
  Must be within range [0, ComboBox2.Items.Count).
}
procedure TMainForm.SetBw(BwNo: integer);
begin
  BwNo := Max(0, Min(BwNo, ComboBox2.Items.Count-1));

  Ini.Bandwidth := 100 + BwNo * 50;
  ComboBox2.ItemIndex := BwNo;

  Tst.Filt.Points := Round(0.7 * DEFAULTRATE / Ini.BandWidth);
  Tst.Filt.GainDb := 10 * Log10(500/Ini.Bandwidth);
  Tst.Filt2.Points := Tst.Filt.Points;
  Tst.Filt2.GainDb := Tst.Filt.GainDb;
  DebugLn('TMainForm.SetBw(%d): Bandwidth %d, Filt.Points %d, Filt.GainDb %f',
    [BwNo, Ini.Bandwidth, Tst.Filt.Points, Tst.Filt.GainDb]);

  UpdateRitIndicator;
end;




procedure TMainForm.ComboBox2Change(Sender: TObject);
begin
  SetBw(ComboBox2.ItemIndex);
end;

procedure TMainForm.ComboBox1Change(Sender: TObject);
begin
  SetPitch(ComboBox1.ItemIndex);
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AlSoundOut1.Enabled := false;
  if AlWavFile1.IsOpen then AlWavFile1.Close;
end;

procedure TMainForm.SpinEdit1Change(Sender: TObject);
begin
  Ini.Wpm := SpinEdit1.Value;
  Tst.Me.Wpm := Ini.Wpm;
end;

procedure TMainForm.CheckBox1Click(Sender: TObject);
begin
  SetQsk(CheckBox1.Checked);
  ActiveControl := Edit1;
end;

procedure TMainForm.CheckBoxClick(Sender: TObject);
begin
  ReadCheckboxes;
  ActiveControl := Edit1;
end;


procedure TMainForm.ReadCheckboxes;
begin
  Ini.Qrn := CheckBox4.Checked;
  Ini.Qrm := CheckBox3.Checked;
  Ini.Qsb := CheckBox2.Checked;
  Ini.Flutter := CheckBox5.Checked;
  Ini.Lids := CheckBox6.Checked;
end;


procedure TMainForm.SpinEdit2Change(Sender: TObject);
begin
  Ini.Duration := SpinEdit2.Value;
end;

procedure TMainForm.SpinEdit3Change(Sender: TObject);
begin
  Ini.Activity := SpinEdit3.Value;
end;

procedure TMainForm.PaintBox1Paint(Sender: TObject);
begin
  Log.PaintHisto;
end;

procedure TMainForm.Exit1Click(Sender: TObject);
begin
  Close;
end;


procedure TMainForm.WipeBoxes;
begin
  Edit1.Text := '';
  Edit2.Text := '';
  Edit3.Text := '';
  ActiveControl := Edit1;

  CallSent := false;
  NrSent := false;
end;


procedure TMainForm.About1Click(Sender: TObject);
const
  Msg = 'CW CONTEST SIMULATOR'#13#13 +
        'Copyright © 2004-2006 Alex Shovkoplyas, VE3NEA'#13#13 +
        've3nea@dxatlas.com'#13;
begin
  Application.MessageBox(Msg, 'Morse Runner 1.70+', MB_OK or MB_ICONINFORMATION);
end;


procedure TMainForm.Readme1Click(Sender: TObject);
var
  FileName: string;
begin
  FileName := ExtractFilePath(ParamStr(0)) + 'readme.txt';
   OpenDocument(PChar(FileName)); { *Converted from ShellExecute* }
end;


{
  called whenever callsign field (Edit1) changes. Any callsign edit will
  invalidate the callsign and NR (Exchange) field(s) already sent, so clear
  the CallSent and NrSent values.
}
procedure TMainForm.Edit1Change(Sender: TObject);
begin
  if Edit1.Text = '' then NrSent := false;
  if not Tst.Me.UpdateCallInMessage(Edit1.Text)
    then
      begin
      CallSent := false;
      end;
end;


procedure TMainForm.RunMNUClick(Sender: TObject);
begin
  Run(TRunMode((Sender as TComponent).Tag));
end;


procedure TMainForm.Edit2Enter(Sender: TObject);
begin
  if Edit2IsRST then
  begin
    // for RST field, select middle digit
    if Length(Edit2.Text) = 3 then
    begin
      Edit2.SelStart := 1;
      Edit2.SelLength := 1;
    end;
  end
  else // otherwise select entire field
  begin
    Edit2.SelStart := 0;
    Edit2.SelLength := Edit2.GetTextLen;
  end;
end;

procedure TMainForm.Edit3Enter(Sender: TObject);
begin
  if Ini.SimContest = scFieldDay then
  begin
    // select entire field
    Edit3.SelStart := 0;
    Edit3.SelLength := Edit3.GetTextLen;
  end;
end;

procedure TMainForm.EnableCtl(Ctl: TWinControl; AEnable: boolean);
const
  Clr: array[boolean] of TColor = (clBtnFace, clWindow);
begin
  Ctl.Enabled := AEnable;
  if Ctl is TSpinEdit then (Ctl as TSpinEdit).Color := Clr[AEnable]
  else if Ctl is TEdit then (Ctl as TEdit).Color := Clr[AEnable];
end;


procedure TMainForm.Run(Value: TRunMode);
const
  Title: array[TRunMode] of string =
    ('', 'Pile-Up', 'Single Calls', 'COMPETITION', 'H S T');
var
  BCompet, BStop: boolean;
begin
  if Value = Ini.RunMode then Exit;
  DebugLnEnter('TMainForm.Run: %s', [DbgS(Value)]);

  BStop := Value = rmStop;
  BCompet := Value in [rmWpx, rmHst];
  RunMode := Value;

  //main ctls
  EnableCtl(Edit4,  BStop);
  EnableCtl(Edit5,  BStop);
  EnableCtl(SpinEdit2, BStop);
  SetToolbuttonDown(ToolButton1, not BStop);

  //condition checkboxes
  EnableCtl(CheckBox2, not BCompet);
  EnableCtl(CheckBox3, not BCompet);
  EnableCtl(CheckBox4, not BCompet);
  EnableCtl(CheckBox5, not BCompet);
  EnableCtl(CheckBox6, not BCompet);
  if RunMode = rmWpx then
    begin
    CheckBox2.Checked := true;
    CheckBox3.Checked := true;
    CheckBox4.Checked := true;
    CheckBox5.Checked := true;
    CheckBox6.Checked := true;
    SpinEdit2.Value := CompDuration;
    end
  else if RunMode = rmHst then
    begin
    CheckBox2.Checked := false;
    CheckBox3.Checked := false;
    CheckBox4.Checked := false;
    CheckBox5.Checked := false;
    CheckBox6.Checked := false;
    SpinEdit2.Value := CompDuration;
    end;

  //button menu
  PileupMNU.Enabled := BStop;
  SingleCallsMNU.Enabled := BStop;
  CompetitionMNU.Enabled := BStop;
  HSTCompetition1.Enabled := BStop;
  StopMNU.Enabled := not BStop;

  //main menu
  PileUp1.Enabled := BStop;
  SingleCalls1.Enabled := BStop;
  Competition1.Enabled := BStop;
  HSTCompetition2.Enabled := BStop;
  Stop1MNU.Enabled := not BStop;

  Call1.Enabled := BStop;
  Duration1.Enabled := BStop;
  QRN1.Enabled := not BCompet;
  QRM1.Enabled := not BCompet;
  QSB1.Enabled := not BCompet;
  Flutter1.Enabled := not BCompet;
  Lids1.Enabled := not BCompet;


  //hst specific
  Activity1.Enabled := Value <> rmHst;
  CWBandwidth2.Enabled := Value <> rmHst;

  EnableCtl(SpinEdit3, RunMode <> rmHst);
  if RunMode = rmHst then SpinEdit3.Value := 4;

  EnableCtl(ComboBox2, RunMode <> rmHst);
  if RunMode = rmHst then begin ComboBox2.ItemIndex :=10; SetBw(10); end;

  if RunMode = rmHst then ListView1.Visible := false
  else if RunMode <> rmStop then ListView1.Visible := true;


  //mode caption
  Panel4.Caption := Title[Value];
  if BCompet
    then Panel4.Font.Color := clRed else Panel4.Font.Color := clGreen;

  if not BStop then
    begin
    Tst.Me.AbortSend;
    Tst.BlockNumber := 0;
    if ActiveContestExchType2 = etSerialNr then
      Tst.Me.Nr := 1; // reset starting serial number to 1

    Log.Clear;
    WipeBoxes;
    RichEdit1.Visible := true;
    {! ?}Panel5.Update;
    end;

  if not BStop then IncRit(0);



  if BStop
    then
      begin
      if AlWavFile1.IsOpen then AlWavFile1.Close;
      end
    else
      begin
      AlWavFile1.FileName := ChangeFileExt(ParamStr(0), '.wav');
      if SaveWav then AlWavFile1.OpenWrite;
      end;

//  UdpThread := TUdpThread.Create(True); // This way it doesn't start automatically
    //...
    //[Here the code initialises anything required before the threads starts executing]
    //...
//  UdpThread.Start;

  AlSoundOut1.Enabled := not BStop;
  DebugLnExit([]);
end;


procedure TMainForm.RunBtnClick(Sender: TObject);
begin
  if RunMode = rmStop
    then Run(rmPileUp)
    else
    begin
      Tst.FStopPressed := true;
   //   UdpThread.Terminate;
    end;
end;

procedure TMainForm.SpinEdit4Change(Sender: TObject);
begin
  //Db := 80 * (SpinEdit4.Value - 0.75);
end;

procedure TMainForm.WmTbDown(var Msg: TMessage);
begin
  TToolbutton(Msg.LParam).Down := Boolean(Msg.WParam);
end;


procedure TMainForm.SetToolbuttonDown(Toolbutton: TToolbutton;
  ADown: boolean);
begin
     PostMessage(Handle, WM_TBDOWN, Integer(ADown), Integer(Toolbutton));
end;



procedure TMainForm.PopupScoreWpx;
var
  S, FName: string;
  Score: integer;
begin
  S := Format('%s %s %s %s ', [
    FormatDateTime('yyyy-mm-dd', Now),
    Ini.Call,
    ListView1.Items[0].SubItems[1],
    ListView1.Items[1].SubItems[1]]);

  S := S + '[' + IntToHex(CalculateCRC32(S, $C90C2086), 8) + ']';


  FName := ChangeFileExt(ParamStr(0), '.lst');
  with TStringList.Create do
    try
      if FileExists(FName) { *Converted from FileExists* } then LoadFromFile(FName);
      Add(S);
      SaveToFile(FName);
    finally Free; end;

  ScoreDialog.Edit1.Text := S;


  Score := StrToIntDef(ListView1.Items[2].SubItems[1], 0);
  if Score > HiScore
    then ScoreDialog.Height := 192
    else ScoreDialog.Height := 129;
  HiScore := Max(HiScore, Score);
  ScoreDialog.ShowModal;
end;


procedure TMainForm.PopupScoreHst;
var
  S: string;
  FName: TFileName;
begin
  S := Format('%s'#9'%s'#9'%s'#9'%s', [
    FormatDateTime('yyyy-mm-dd hh:nn', Now),
    Ini.Call,
    Ini.HamName,
    Panel11.Caption]);

  FName := ExtractFilePath(ParamStr(0)) + 'HstResults.txt';
  with TStringList.Create do
    try
      if FileExists(FName) { *Converted from FileExists* } then LoadFromFile(FName);
      Add(S);
      SaveToFile(FName);
    finally Free; end;

  ShowMessage('HST Score: ' + ListView1.Items[2].SubItems[1]);
end;


procedure OpenWebPage(Url: string);
begin
   OpenDocument(PChar(Url)); { *Converted from ShellExecute* }
end;


procedure TMainForm.ViewScoreBoardMNUClick(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/MorseRunner/MrScore.asp');
end;

procedure TMainForm.ViewScoreTable1Click(Sender: TObject);
var
  FName: string;
begin
  RichEdit1.Clear;
  FName := ChangeFileExt(ParamStr(0), '.lst');
  if FileExists(FName) { *Converted from FileExists* }
    then RichEdit1.Lines.LoadFromFile(FName)
    else RichEdit1.Lines.Add('Your score table is empty');
  RichEdit1.Visible := true;
end;


procedure TMainForm.Panel8MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if X < Shape2.Left then IncRit(-1)
  else if X > (Shape2.Left + Shape2.Width) then IncRit(1);
end;


procedure TMainForm.Shape2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  IncRit(0);
end;


procedure TMainForm.IncRit(dF: integer);
begin
  case dF of
   -1: Inc(Ini.Rit, -30);
    0: Ini.Rit := 0;
    1: Inc(Ini.Rit, 30);
    end;

  Ini.Rit := Min(500, Max(-500, Ini.Rit));
  UpdateRitIndicator;
end;


procedure TMainForm.UpdateRitIndicator;
begin
  Shape2.Width := Ini.Bandwidth div 9;
  Shape2.Left := ((Panel8.Width - Shape2.Width) div 2) + (Ini.Rit div 9);
end;


procedure TMainForm.Advance;
begin
  if not MustAdvance then Exit;
  DebugLn('TMainForm.Advance');

  if Edit2IsRST and (Edit2.Text = '') then
    Edit2.Text := '599';

  if Pos('?', Edit1.Text) > 0 then
    begin
      { stay in callsign field if callsign has a '?' }
      if ActiveControl = Edit1 then
        Edit1Enter(nil)
      else
        ActiveControl := Edit1;
    end
  else
    begin
      { otherwise advance to next field, skipping RST }
      if Edit2IsRST then
        ActiveControl := Edit3
      else
        ActiveControl := Edit2;
    end;
{
  if Ini.SimContest = scFieldDay then
  begin // mikeb - todo - work this logic
    if Edit2.Text = '' then
      ActiveControl := Edit2;
    if ActiveControl = Edit1 then
      Edit1Enter(nil)
    else
      ActiveControl := Edit2;
  end
  else begin
    if Edit2.Text = '' then Edit2.Text := '599';
    if Edit3.Text = '' then Edit3.Text := '14';

    if Pos('?', Edit1.Text) = 0 then ActiveControl := Edit3
    else if ActiveControl = Edit1 then Edit1Enter(nil)
    else ActiveControl := Edit1;
  end;
}

  MustAdvance := false;
end;



procedure TMainForm.VolumeSliderDblClick(Sender: TObject);
begin
  with Sender as TVolumeSlider do
    begin
    Value := 0.75;
    OnChange(Sender);
    end;
end;

procedure TMainForm.VolumeSlider1Change(Sender: TObject);
begin
  with VolumeSlider1 do
    begin
    //-60..+20 dB
    Db := 80 * (Value - 0.75);
    if dB > 0
      then Hint := Format('+%.0f dB', [dB])
      else Hint := Format( '%.0f dB', [dB]);
    end;
end;

procedure TMainForm.MonitorUp;

begin
  VolumeSlider1.Value := VolumeSlider1.Value + 0.1;
end;

procedure TMainForm.MonitorDown;
begin
  VolumeSlider1.Value := VolumeSlider1.Value - 0.1;
end;

procedure TMainForm.WebPage1Click(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/MorseRunner');
end;




//------------------------------------------------------------------------------
//                              accessibility
//------------------------------------------------------------------------------
procedure TMainForm.Call1Click(Sender: TObject);
begin
  SetMyCall(Trim(InputBox('Callsign', 'Callsign', Edit4.Text)));
end;


procedure TMainForm.SetQsk(Value: boolean);
begin
  Qsk := Value;
  CheckBox1.Checked := Qsk;
end;


procedure TMainForm.QSK1Click(Sender: TObject);
begin
  SetQsk(not QSK1.Checked);
end;


procedure TMainForm.NWPMClick(Sender: TObject);
begin
  Wpm := (Sender as TMenuItem).Tag;
  Wpm := Max(10, Min(120, Wpm));
  SpinEdit1.Value := Wpm;
  Tst.Me.Wpm := Wpm;
end;


procedure TMainForm.Pitch1Click(Sender: TObject);
begin
  SetPitch((Sender as TMenuItem).Tag);
end;

procedure TMainForm.Bw1Click(Sender: TObject);
begin
  SetBw((Sender as TMenuItem).Tag);
end;

procedure TMainForm.File1Click(Sender: TObject);
var
  Stp: boolean;
begin
  Stp := RunMode = rmStop;

  AudioRecordingEnabled1.Enabled := Stp;
  PlayRecordedAudio1.Enabled := Stp and FileExists(ChangeFileExt(ParamStr(0), '.wav')); { *Converted from FileExists* }

  AudioRecordingEnabled1.Checked := Ini.SaveWav;
end;

procedure TMainForm.PlayRecordedAudio1Click(Sender: TObject);
var
  FileName: string;
begin
  FileName := ChangeFileExt(ParamStr(0), '.wav');
   OpenDocument(PChar(FileName)); { *Converted from ShellExecute* }
end;


procedure TMainForm.AudioRecordingEnabled1Click(Sender: TObject);
begin
  Ini.SaveWav := not Ini.SaveWav;
end;


procedure TMainForm.SelfMonClick(Sender: TObject);
begin
  VolumeSlider1.Value := (Sender as TMenuItem).Tag / 80 + 0.75;
  VolumeSlider1.OnChange(Sender);
end;

procedure TMainForm.Settings1Click(Sender: TObject);
begin
  QSK1.Checked := Ini.Qsk;
  QRN1.Checked := Ini.Qrn;
  QRM1.Checked := Ini.Qrm;
  QSB1.Checked := Ini.Qsb;
  Flutter1.Checked := Ini.Flutter;
  LIDS1.Checked := Ini.Lids;
end;

//ALL checkboxes
procedure TMainForm.LIDS1Click(Sender: TObject);
begin
  with Sender as TMenuItem do Checked := not Checked;

  CheckBox4.Checked := QRN1.Checked;
  CheckBox3.Checked := QRM1.Checked;
  CheckBox2.Checked := QSB1.Checked;
  CheckBox5.Checked := Flutter1.Checked;
  CheckBox6.Checked := LIDS1.Checked;

  ReadCheckboxes;
end;



procedure TMainForm.Activity1Click(Sender: TObject);
begin
  Ini.Activity := (Sender as TMenuItem).Tag;
  SpinEdit3.Value := Ini.Activity;
end;


procedure TMainForm.Duration1Click(Sender: TObject);
begin
  Ini.Duration := (Sender as TMenuItem).Tag;
  SpinEdit2.Value := Ini.Duration;
end;


procedure TMainForm.Operator1Click(Sender: TObject);
begin
  HamName := InputBox('HST Operator', 'Enter operator''s name', HamName);

  if HamName <> ''
    then Caption := 'Morse Runner:  ' + HamName
    else Caption := 'Morse Runner';

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try WriteString(SEC_STN, 'Name', HamName);
    finally Free; end;
end;

procedure TMainForm.StopMNUClick(Sender: TObject);
begin
  Tst.FStopPressed := true;
end;

end.

