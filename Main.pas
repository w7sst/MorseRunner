//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Main;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Buttons, SndCustm, SndOut, Contest, Ini, MorseKey, CallLst,
  VolmSldr, VolumCtl, StdCtrls, Station, Menus, ExtCtrls, MAth,
  ComCtrls, Spin, SndTypes, ShellApi, jpeg, ToolWin, ImgList, Crc32,
  WavFile, IniFiles, Idhttp, ARRL, ARRLFD, NAQP, CWOPS, System.ImageList;

const
  WM_TBDOWN = WM_USER+1;
  sVersion: String = '1.71a';

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
    MainMenu1: TMainMenu;
    File1: TMenuItem;
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
    RichEdit1: TRichEdit;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Shape1: TShape;
    PopupMenu1: TPopupMenu;
    PileupMNU: TMenuItem;
    SingleCallsMNU: TMenuItem;
    CompetitionMNU: TMenuItem;
    HSTCompetition1: TMenuItem;
    StopMNU: TMenuItem;
    ImageList1: TImageList;
    Run1: TMenuItem;
    PileUp1: TMenuItem;
    SingleCalls1: TMenuItem;
    Competition1: TMenuItem;
    HSTCompetition2: TMenuItem;
    Stop1MNU: TMenuItem;
    ViewScoreBoardMNU: TMenuItem;
    ViewScoreTable1: TMenuItem;
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
    VolumeSlider1: TVolumeSlider;
    Label18: TLabel;
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
    Panel11: TPanel;
    ListView1: TListView;
    Operator1: TMenuItem;
    N9: TMenuItem;
    ListView2: TListView;
    sbar: TPanel;
    N5: TMenuItem;
    mnuShowCallsignInfo: TMenuItem;
    NRDigits1: TMenuItem;
    NRDigitsSet1: TMenuItem;
    NRDigitsSet2: TMenuItem;
    NRDigitsSet3: TMenuItem;
    NRDigitsSet4: TMenuItem;
    CWMaxRxSpeed1: TMenuItem;
    CWMinRxSpeed1: TMenuItem;
    CWMinRxSpeedSet1: TMenuItem;
    CWMinRxSpeedSet2: TMenuItem;
    CWMinRxSpeedSet4: TMenuItem;
    CWMinRxSpeedSet6: TMenuItem;
    CWMinRxSpeedSet8: TMenuItem;
    CWMinRxSpeedSet10: TMenuItem;
    CWMinRxSpeedSet0: TMenuItem;
    CWMaxRxSpeedSet0: TMenuItem;
    CWMaxRxSpeedSet1: TMenuItem;
    CWMaxRxSpeedSet2: TMenuItem;
    CWMaxRxSpeedSet4: TMenuItem;
    CWMaxRxSpeedSet6: TMenuItem;
    CWMaxRxSpeedSet8: TMenuItem;
    CWMaxRxSpeedSet10: TMenuItem;
    NRQM: TMenuItem;
    ContestGroup: TGroupBox;
    SimContestCombo: TComboBox;
    Label17: TLabel;
    ExchangeEdit: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure AlSoundOut1BufAvailable(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure Edit2KeyPress(Sender: TObject; var Key: Char);
    procedure Edit3KeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure Edit1Enter(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure Edit4Change(Sender: TObject);
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
    procedure ViewScoreBoardMNUClick(Sender: TObject);
    procedure ViewScoreTable1Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Panel8MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Shape2MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Edit2Enter(Sender: TObject);
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
    procedure CWMaxRxSpeedClick(Sender: TObject);
    procedure CWMinRxSpeedClick(Sender: TObject);
    procedure NRDigitsClick(Sender: TObject);
    procedure Activity1Click(Sender: TObject);
    procedure Duration1Click(Sender: TObject);
    procedure Operator1Click(Sender: TObject);
    procedure CWOPSNumberClick(Sender: TObject);
    procedure StopMNUClick(Sender: TObject);
    procedure ListView2CustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    //procedure SimContestComboClick(Sender: TObject);
    procedure ListView2SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure mnuShowCallsignInfoClick(Sender: TObject);
    procedure SimContestComboChange(Sender: TObject);
    procedure ExchangeEditExit(Sender: TObject);

  private
    MustAdvance: boolean;
    ExchangeField1Type: TExchange1Type;
    ExchangeField2Type: TExchange2Type;
    procedure ConfigureExchangeFields(
      AExchType1: TExchange1Type;
      AExchType2: TExchange2Type);
    procedure SetMyExch1(const AExchType: TExchange1Type; const Avalue: string);
    procedure SetMyExch2(const AExchType: TExchange2Type; const Avalue: string);
    function ValidateExchField(const FieldDef: PFieldDefinition;
      const Avalue: string) : Boolean;
    procedure ProcessSpace;
    procedure SendMsg(Msg: TStationMessage);
    procedure ProcessEnter;
    procedure EnableCtl(Ctl: TWinControl; AEnable: boolean);
    procedure WmTbDown(var Msg: TMessage); message WM_TBDOWN;
    procedure SetToolbuttonDown(Toolbutton: TToolbutton; ADown: boolean);
    procedure IncRit(dF: integer);
    procedure UpdateRitIndicator;
    procedure DecSpeed;
    procedure IncSpeed;
  public
    CompetitionMode: boolean;
    procedure Run(Value: TRunMode);
    procedure WipeBoxes;
    procedure PopupScoreWpx;
    procedure PopupScoreHst;
    procedure Advance;
    procedure SetContest(AContestNum: TSimContest);
    procedure SetMyExchange(const AExchange: string);
    procedure SetQsk(Value: boolean);
    procedure SetMyCall(ACall: string);
    procedure SetPitch(PitchNo: integer);
    procedure SetBw(BwNo: integer);
    procedure ReadCheckboxes;
    procedure UpdateTitleBar;
    procedure PostHiScore(const sScore: string);
    procedure UpdNRDigits(nrd: integer);
    procedure UpdCWMinRxSpeed(minspd: integer);
    procedure UpdCWMaxRxSpeed(Maxspd: integer);
    procedure ClientHTTP1Redirect(Sender: TObject; var dest: string;
      var NumRedirect: Integer; var Handled: Boolean; var VMethod: string);

  end;

function ToStr(const val : TExchange1Type): string; overload;
function ToStr(const val : TExchange2Type): string; overload;

var
  MainForm: TMainForm;

implementation
uses TypInfo, ScoreDlg, Log, PerlRegEx;

{$R *.DFM}

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
    (MainForm.ExchangeField1Type = etRST));
  Result := MainForm.ExchangeField1Type = etRST;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;

  Panel2.DoubleBuffered := True;
  RichEdit1.Align := alClient;
  RichEdit1.Font.Name:= 'Consolas';
  RichEdit1.Font.Size:= 11;
  Self.Caption:= format('Morse Runner %s', [sVersion]);
  Label12.Caption:= format('Morse Runner %s ', [sVersion]);
  Label13.Caption:= Label12.Caption;
  Label14.Caption:= Label12.Caption;
  ListView2.Visible:= False;
  ListView2.Clear;

  Tst := TContest.Create;
  LoadCallList;

  // Adding a contest: load call history file (be sure to delete it below).
  ARRLDX:= TARRL.Create;
  gARRLFD := TArrlFieldDay.Create;
  gNAQP := TNcjNaQp.Create;
  CWOPSCWT := TCWOPS.Create;

  Histo:= THisto.Create(PaintBox1);

  AlSoundOut1.BufCount := 4;
  FromIni;

  MakeKeyer;
  Keyer.Rate := DEFAULTRATE;
  Keyer.BufSize := Ini.BufSize;

  SetContest(Ini.SimContest);
end;


procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ToIni;
  ARRLDX.Free;
  gARRLFD.Free;
  gNAQP.Free;
  CWOPSCWT.Free;
  Histo.Free;
  Tst.Free;
  DestroyKeyer;
end;


procedure TMainForm.AlSoundOut1BufAvailable(Sender: TObject);
begin
  if AlSoundOut1.Enabled then
    try AlSoundOut1.PutData(Tst.GetAudio); except end;
end;


procedure TMainForm.SendClick(Sender: TObject);
var
  Msg: TStationMessage;
begin
  Msg := TStationMessage((Sender as TComponent).Tag);

  SendMsg(Msg);
end;


procedure TMainForm.SendMsg(Msg: TStationMessage);
begin
  if Msg = msgHisCall then begin
    // retain current callsign, including ''. if empty, return.
    Tst.Me.HisCall := Edit1.Text;
    CallSent := Edit1.Text <> '';
    if not CallSent then
      Exit;
  end;
  if Msg = msgNR then
    NrSent := true;
  Tst.Me.SendMsg(Msg);
end;


procedure TMainForm.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
  if not CharInSet(Key, ['A'..'Z', 'a'..'z', '0'..'9', '/', '?', #8]) then
    Key := #0;
end;

procedure TMainForm.Edit2KeyPress(Sender: TObject; var Key: Char);
begin
  case ExchangeField1Type of
    etRST:
      begin
        if RunMode <> rmHst then
        begin
          // for RST field, map (A,N) to (1,9)
          case Key of
            'a', 'A': Key := '1';
            'n', 'N': Key := '9';
          end;
        end;
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
        [ToStr(ExchangeField1Type)]));
  end;
end;

procedure TMainForm.Edit3KeyPress(Sender: TObject; var Key: Char);
begin
  case ExchangeField2Type of
    etSerialNr, etCwopsNumber, etCqZone, etItuZone, etAge:
      begin
        if RunMode <> rmHst then
          case Key of
            'a', 'A': Key := '1';
            'n', 'N': Key := '9';
            't', 'T': Key := '0';
          end;
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
        [ToStr(ExchangeField2Type)]));
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
    #21: //^U  pileup continuo se 1
      begin
        if NoStopActivity = 0 then
          begin
            Label8.Caption := 'min';
            NoStopActivity := 1
          end
        else
        begin
            NoStopActivity := 0;
            Label8.Caption := 'min.';
        end;

      end;
    #25: //^Y  = Edit
      ;

    #27: //Esc = Abort send
      begin
        if msgHisCall in Tst.Me.Msg then
          CallSent := false;
        if msgNR in Tst.Me.Msg then
          NrSent := false;
        Tst.Me.AbortSend;
      end;

    ';': //<his> <#>
      begin
        SendMsg(msgHisCall);
        SendMsg(msgNr);
      end;

    '.', '+', '[', ',': //TU & Save
      begin
        if not CallSent then
          SendMsg(msgHisCall);
        SendMsg(msgTU);
        Log.SaveQso;
      end;

    ' ': // advance to next exchange field
      if (ActiveControl = Edit1) or
         (ActiveControl = Edit2) or
         (ActiveControl = Edit3) then
        ProcessSpace
      else
        Exit;

    //'\': // = F1
    //  SendMsg(msgCQ);

    else
      Exit;
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

    87, 119: //Alt-W  = Wipe
      if GetKeyState(VK_MENU) < 0 then WipeBoxes else Exit;

{
    'M': //Alt-M  = Auto CW
      if GetKeyState(VK_MENU) < 0
        then Ini.AutoCw := not Ini.AutoCw
        else Exit;
}

    VK_UP:
      if GetKeyState(VK_CONTROL) >= 0 then IncRit(1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex+1);

    VK_DOWN:
      if GetKeyState(VK_CONTROL) >= 0  then IncRit(-1)
      else if RunMode <> rmHst then SetBw(ComboBox2.ItemIndex-1);

    VK_PRIOR: //PgUp
      IncSpeed;

    VK_NEXT: //PgDn
      DecSpeed;

    VK_F9:
      if (ssAlt in Shift) or  (ssCtrl in Shift) then DecSpeed;

    VK_F10:
      if (ssAlt in Shift) or  (ssCtrl in Shift) then IncSpeed;

    VK_F11:
      WipeBoxes;

    else
      Exit;
  end;
  Key := 0;
end;


procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT, VK_RETURN:
      Key := 0;
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
  C, N, R, Q: boolean;
begin
  if ActiveControl = ExchangeEdit then
    begin
      ExchangeEditExit(ActiveControl);
      Exit;
    end;
  MustAdvance := false;

  if (GetKeyState(VK_CONTROL) or GetKeyState(VK_SHIFT) or GetKeyState(VK_MENU)) < 0 then
  begin
    Log.SaveQso;
    Exit;
  end;

  // for certain contests (e.g. ARRL Field Day), update update status bar
  if SimContest in [scFieldDay] then
    UpdateSbar(Edit1.Text);

  //no QSO in progress, send CQ
  if Edit1.Text = '' then
  begin
    SendMsg(msgCq);
    Exit;
  end;

  //current state
  C := CallSent;
  N := NrSent;
  Q := Edit2.Text <> '';
  R := Edit3.Text <> '';

  //send his call if did not send before, or if call changed
  if (not C) or ((not N) and (not R)) then
    SendMsg(msgHisCall);
  if not N then
    SendMsg(msgNR);
  if N and (not R or not Q) then
    SendMsg(msgQm);

  if R and Q and (C or N) then
  begin
    SendMsg(msgTU);
    Log.SaveQso;
  end
  else
    MustAdvance := true;
end;


procedure TMainForm.Edit1Enter(Sender: TObject);
var
  P: integer;
begin
  P := Pos('?', Edit1.Text);
  if P > 1 then
  begin
    Edit1.SelStart := P-1;
    Edit1.SelLength := 1;
  end;
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
  SetMyCall(Trim(Edit4.Text));
end;

procedure TMainForm.ExchangeEditExit(Sender: TObject);
begin
  SetMyExchange(Trim(ExchangeEdit.Text));
end;

procedure TMainForm.SetContest(AContestNum: TSimContest);
begin
  // validate selected contest
  if not (AContestNum in [scWpx, scCwt, scFieldDay, scNaQp, scHst]) then
  begin
    ShowMessage('The selected contest is not yet supported.');
    SimContestCombo.ItemIndex:= Ord(Ini.SimContest);
    Exit;
  end;

  assert(ContestDefinitions[AContestNum].T = AContestNum,
    'Contest definitions are out of order');
  Ini.SimContest := AContestNum;
  Ini.ActiveContest := @ContestDefinitions[AContestNum];
  SimContestCombo.ItemIndex := Ord(AContestNum);
  WipeBoxes;

  // clear any status messages
  sbar.Caption := '';
  sbar.Font.Color := clDefault;
  sbar.Visible := mnuShowCallsignInfo.Checked;

  // update Exchange field labels and length settings (e.g. RST, Nr.)
  ConfigureExchangeFields(ActiveContest.ExchType1, ActiveContest.ExchType2);
end;

{procedure TMainForm.SetNumber(ANumber: string);
begin
   Ini.Number := ANumber;
   editNumber.Text := ANumber;
   Tst.Me.NR2 := ANumber;
end;}

{
  Set my exchange fields using the exchange string containing two values,
  separated by a space. Error/warning messages are displayed in the status bar.
}
procedure TMainForm.SetMyExchange(const AExchange: string);
var
  sl: TStringList;
  Field1Def: PFieldDefinition;
  Field2Def: PFieldDefinition;
begin
  sl:= TStringList.Create;
  try
    Field1Def := @Exchange1Settings[ActiveContest.ExchType1];
    Field2Def := @Exchange2Settings[ActiveContest.ExchType2];

    // parse into two strings [Exch1, Exch2]
    ExtractStrings([' '], [], PChar(AExchange), sl);
    if sl.Count = 0 then
      sl.AddStrings(['', '']);
    if sl.Count = 1 then
      sl.AddStrings(['']);

    // validate exchange string
    if not ValidateExchField(Field1Def, sl[0]) or
       not ValidateExchField(Field2Def, sl[1]) then
      begin
        sbar.Caption := Format('Invalid exchange: ''%s'' - expecting %s.',
          [AExchange, ActiveContest.Msg]);

        sbar.Align:= alBottom;
        sbar.Visible:= true;
        sbar.Font.Color := clRed;
      end
    else
      begin
        sbar.Visible := mnuShowCallsignInfo.Checked;
        sbar.Font.Color := clDefault;
        sbar.Caption := '';
      end;

    // set contest-specific exchange values
    SetMyExch1(ActiveContest.ExchType1, sl[0]);
    SetMyExch2(ActiveContest.ExchType2, sl[1]);

    // update the Exchange field value
    ExchangeEdit.Text := AExchange;
    Ini.UserExchangeTbl[SimContest]:= AExchange;

    // update application's title bar
    UpdateTitleBar;

  finally
    sl.Free;
  end;
end;


procedure TMainForm.UpdateTitleBar;
begin
  // Adding a contest: consider application's title bar.
  if Ini.ActiveContest = nil then
    Caption := 'Morse Runner'
  else if (SimContest = scHst) and not HamName.IsEmpty then  // for HST, add operator name
    Caption := Format('Morse Runner - %s:  %s', [Ini.ActiveContest.Name, HamName])
  else // Default is: Morse Runner - <contest name>
    Caption := Format('Morse Runner - %s', [Ini.ActiveContest.Name]);
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
  AExchType2: TExchange2Type);
const
  { the logic below allows Exchange label to be optional.
    If necessary, move this value into ContestDefinitions[] table. }
  AExchangeLabel: PChar = 'Exchange';

var
  Visible: Boolean;

begin
  // Optional Contest Exchange label and field
  Visible := AExchangeLabel <> '';
  Label17.Visible:= Visible;
  ExchangeEdit.Visible:= Visible;
  Label17.Caption:= AExchangeLabel;

  // The Exchange field is editable in some contests
  ExchangeEdit.Enabled := ActiveContest.ExchFieldEditable;

  // setup Exchange Field 1 (e.g. RST)
  assert(AExchType1 = TExchange1Type(Exchange1Settings[AExchType1].T),
    Format('Exchange1Settings[%d] ordering error: found %s, expecting %s.',
      [Ord(AExchType1), ToStr(AExchType1),
      ToStr(TExchange1Type(Exchange1Settings[AExchType1].T))]));
  Label2.Caption:= Exchange1Settings[AExchType1].C;
  Edit2.MaxLength:= Exchange1Settings[AExchType1].L;
  ExchangeField1Type := AExchType1;

  // setup Exchange Field 2 (e.g. Serial #)
  assert(AExchType2 = TExchange2Type(Exchange2Settings[AExchType2].T),
    Format('Exchange2Settings[%d] ordering error: found %s, expecting %s.',
      [Ord(AExchType2), ToStr(AExchType2),
      ToStr(TExchange2Type(Exchange2Settings[AExchType2].T))]));
  Label3.Caption := Exchange2Settings[AExchType2].C;
  Edit3.MaxLength := Exchange2Settings[AExchType2].L;
  ExchangeField2Type := AExchType2;

  // Set my exchange value (from INI file)
  SetMyExchange(Ini.UserExchangeTbl[SimContest]);
end;

procedure TMainForm.SetMyExch1(const AExchType: TExchange1Type;
  const Avalue: string);
begin
  case AExchType of
    etRST:
      begin
        // Format('invalid RST (%s)', [AValue]));
        Ini.UserExchange1[SimContest] := Avalue;
        if BDebugExchSettings then Edit2.Text := Avalue; // testing only
      end;
    etOpName: // e.g. scCwt (David)
      begin
        // Format('invalid OpName (%s)', [AValue]));
        Ini.HamName:= Avalue;
        Ini.UserExchange1[SimContest] := Avalue;
        Tst.Me.OpName := Avalue;
        if BDebugExchSettings then Edit2.Text := Avalue; // testing only
      end;
    etFdClass:  // e.g. scFieldDay (3A)
      begin
        // 'expecting FD class (3A)'
        Ini.ArrlClass := Avalue;
        Ini.UserExchange1[SimContest] := Avalue;
        Tst.Me.Exch1 := Avalue;
        if BDebugExchSettings then Edit2.Text := Avalue; // testing only
      end;
    else
      assert(false, Format('Unsupported exchange 1 type: %s.', [ToStr(AExchType)]));
  end;
end;

procedure TMainForm.SetMyExch2(const AExchType: TExchange2Type;
  const Avalue: string);
var
  i: integer;
begin
  case AExchType of
    etSerialNr:
      begin
        Ini.UserExchange2[SimContest] := Avalue;
        if not IsNum(Avalue) or (RunMode = rmHst) then
          Tst.Me.Nr := 1
        else
          Tst.Me.Nr := StrToInt(Avalue);

        if BDebugExchSettings then Edit3.Text := IntToStr(Tst.Me.Nr);  // testing only
      end;
    etCwopsNumber:  // e.g. scCwt (123)
      begin
        {Edit3.Text := sl[1];
        Ini.CWOPSNum:= sl[1];
        Tst.Me.CWOPSNR := StrToInt(sl[1]); }
        // todo - verify this is a number
        i := StrToIntDef(Avalue, 0);
        Ini.UserExchange2[SimContest] := Avalue;
        Ini.CWOPSNum:= IntToStr(i);
        // ExchangeEdit.Text := Avalue;
        if Avalue <> '' then
          Tst.Me.CWOPSNR := StrToIntDef(Avalue, 0)
        else
          Tst.Me.CWOPSNR := 0;
        if BDebugExchSettings then Edit3.Text := Avalue; // testing only
      end;
    etArrlSection:  // e.g. Field Day (OR)
      begin
        // 'expecting FD section (e.g. OR)'
        Ini.ArrlSection := Avalue;
        Ini.UserExchange2[SimContest] := Avalue;
        Tst.Me.Exch2 := Avalue;
        if BDebugExchSettings then Edit3.Text := Avalue; // testing only
      end;
    etStateProv:  // e.g. NAQP (OR)
      begin
        // 'expecting State or Providence (e.g. OR)'
        Ini.UserExchange2[SimContest] := Avalue;
        Tst.Me.Exch2 := Avalue;
        if BDebugExchSettings then Edit3.Text := Avalue; // testing only
      end;
    //etCqZone:
    //etItuZone:
    //etAge:
    //etPower:
    //etJarlOblastCode:
    else
      assert(false, Format('Unsupported exchange 2 type: %s.', [ToStr(AExchType)]));
  end;
end;


function TMainForm.ValidateExchField(const FieldDef: PFieldDefinition;
  const Avalue: string) : Boolean;
var
  reg: TPerlRegEx;
  s: string;
begin
  reg := TPerlRegEx.Create();
  try
    reg.Subject := UTF8Encode(Avalue);
    s:= '^(' + FieldDef.R + ')$';
    reg.RegEx:= UTF8Encode(s);
    Result:= Reg.Match;
  finally
    reg.Free;
  end;
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

  UpdateRitIndicator;
end;

procedure TMainForm.SimContestComboChange(Sender: TObject);
begin
  SetContest(TSimContest(SimContestCombo.ItemIndex));
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
  Histo.ReCalc(Ini.Duration);
end;

procedure TMainForm.SpinEdit3Change(Sender: TObject);
begin
  Ini.Activity := SpinEdit3.Value;
end;

procedure TMainForm.PaintBox1Paint(Sender: TObject);
begin
  Histo.Repaint;
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
    Msg= 'CW CONTEST SIMULATOR'#13#13 +
        'Copyright ©2004-2016 Alex Shovkoplyas, VE3NEA'#13#13 +
        've3nea@dxatlas.com'#13#13 +
        'Rebuild by BG4FQD. bg4fqd@gmail.com 20160712';
begin
    //Application.MessageBox(Msg, 'Morse Runner', MB_OK or MB_ICONINFORMATION);
    PopupScoreWpx;
end;          


procedure TMainForm.Readme1Click(Sender: TObject);
var
    FileName: string;
begin
    FileName := ExtractFilePath(ParamStr(0)) + 'readme.txt';
    ShellExecute(GetDesktopWindow, 'open', PChar(FileName), '', '', SW_SHOWNORMAL);
end;


{
  called whenever callsign field (Edit1) changes. Any callsign edit will
  invalidate the callsign and NR (Exchange) field(s) already sent, so clear
  the CallSent and NrSent values.
}
procedure TMainForm.Edit1Change(Sender: TObject);
begin
    if Edit1.Text = '' then
        NrSent := false;
    if not Tst.Me.UpdateCallInMessage(Edit1.Text) then begin
        CallSent := false;
        NrSent := false;
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
  Mode: array[TRunMode] of string =
    ('', 'Pile-Up', 'Single Calls', 'COMPETITION', 'H S T');
var
  BCompet, BStop: boolean;
  //S: string;
begin
  if Value = Ini.RunMode then
    Exit;

  BStop := Value = rmStop;
  BCompet := Value in [rmWpx, rmHst];
  RunMode := Value;

  //main ctls
  EnableCtl(SimContestCombo, BStop);
  EnableCtl(Edit4,  BStop);
  EnableCtl(ExchangeEdit, BStop);
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
  ViewScoreTable1.Enabled:= BStop;  // by bg4fqd

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
  Panel4.Caption := Mode[Value];
  Panel4.Font.Color := IfThen(BCompet, clRed, clGreen);

  if not BStop then
    begin
    Tst.Me.AbortSend;
    Tst.BlockNumber := 0;
    //Tst.Me.Nr := 1;
    Log.Clear;
    WipeBoxes;

    RichEdit1.Visible:= false;
    RichEdit1.Align:= alNone;
    sbar.Align:= alBottom;
    sbar.Visible:= mnuShowCallsignInfo.Checked;
    ListView2.Align:= alClient;
    ListView2.Clear;
    ListView2.Visible:= true;
    {! ?}
    Panel5.Update;
    end;

  if not BStop then
    IncRit(0);

  if BStop then begin
    {// save NR back to .INI File.
    // todo - there is a better way to this.
    if (not BCompet) and
      (Self.ExchangeField2Type = etSerialNr) and
      (SimContest in [scWpx]) then
      begin
        S := IntToStr(Tst.Me.NR);
        Self.SetMyExch2(etSerialNr, S);
      end;
      }
    if AlWavFile1.IsOpen then
      AlWavFile1.Close;
  end
  else begin
    AlWavFile1.FileName := ChangeFileExt(ParamStr(0), '.wav');
    if SaveWav then
      AlWavFile1.OpenWrite;
  end;

  AlSoundOut1.Enabled := not BStop;
end;


procedure TMainForm.RunBtnClick(Sender: TObject);
begin
  if RunMode = rmStop then
    Run(rmPileUp)
  else
    Tst.FStopPressed := true;
end;

procedure TMainForm.WmTbDown(var Msg: TMessage);
begin
  TToolbutton(Msg.LParam).Down := Boolean(Msg.WParam);
end;


procedure TMainForm.SetToolbuttonDown(Toolbutton: TToolbutton;
  ADown: boolean);
begin
    Windows.PostMessage(Handle, WM_TBDOWN, Integer(ADown), Integer(Toolbutton));
end;


procedure TMainForm.PopupScoreWpx;
var
    S, FName: string;
    Score: integer;
    DlgScore: TScoreDialog;
begin
    S := Format('%s %s %s %s ',
    [
        FormatDateTime('yyyy-mm-dd', Now),
        trim(Ini.Call),
        trim(ListView1.Items[0].SubItems[1]),
        trim(ListView1.Items[1].SubItems[1])
    ]);
 //for debug
{
  S := Format('%s %s %s %s ',
  [
    FormatDateTime('yyyy-mm-dd', Now),
    Ini.Call,
    '111',
    '107'
  ]);
}
    S := S + '[' + IntToHex(CalculateCRC32(S, $C90C2086), 8) + ']';
    FName := ChangeFileExt(ParamStr(0), '.lst');
    with TStringList.Create do
    try
        if FileExists(FName) then
            LoadFromFile(FName);
        Add(S);
        SaveToFile(FName);
    finally
        Free;
    end;

    DlgScore:= TScoreDialog.Create(Self);
    try
        DlgScore.Edit1.Text := S;

        Score := StrToIntDef(ListView1.Items[2].SubItems[1], 0);
        if Score > HiScore then
            DlgScore.Height := 192
        else
            DlgScore.Height := 129;
        HiScore := Max(HiScore, Score);
        DlgScore.ShowModal;
    finally
        DlgScore.Free;
    end;
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
      if FileExists(FName) then
        LoadFromFile(FName);
      Add(S);
      SaveToFile(FName);
    finally
      Free;
    end;

  ShowMessage('HST Score: ' + ListView1.Items[2].SubItems[1]);
end;


procedure OpenWebPage(Url: string);
begin
  ShellExecute(GetDesktopWindow, 'open', PChar(Url), '', '', SW_SHOWNORMAL);
end;


procedure TMainForm.ViewScoreBoardMNUClick(Sender: TObject);
begin
  //PopupScoreWpx;
  OpenWebPage(WebServer);
end;

procedure TMainForm.ViewScoreTable1Click(Sender: TObject);
var
  FName: string;
begin
  RichEdit1.Clear;
  ListView2.Align:= alNone;
  ListView2.Visible:= false;
  sbar.Visible:= false;
  RichEdit1.Align:= alClient;
  RichEdit1.Visible:= true;
  FName := ChangeFileExt(ParamStr(0), '.lst');
  if FileExists(FName) then
    RichEdit1.Lines.LoadFromFile(FName)
  else
    RichEdit1.Lines.Add('Your score table is empty');
  RichEdit1.Visible := true;
  RichEdit1.Font.Name:= 'Consolasf';
end;


procedure TMainForm.Panel8MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if X < Shape2.Left then
    IncRit(-1)
  else
    if X > (Shape2.Left + Shape2.Width) then
      IncRit(1);
end;


procedure TMainForm.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
    if WheelDelta>0 then
        IncRit(2)
      else
        IncRit(-2)
end;


procedure TMainForm.Shape2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  IncRit(0);
end;


procedure TMainForm.mnuShowCallsignInfoClick(Sender: TObject);
begin
    with Sender as TMenuItem do begin
        Checked := not Checked;
        if ListView2.Visible then
            sbar.Visible:= Checked;
    end;
end;

procedure TMainForm.ClientHTTP1Redirect(Sender: TObject; var dest: string;
  var NumRedirect: Integer; var Handled: Boolean; var VMethod: string);
begin
  (Sender as TIdHTTP).Tag:= 1;
  Handled:= true;
end;


procedure TMainForm.IncRit(dF: integer);
begin
  case dF of
   -2: Inc(Ini.Rit, -5);
   -1: Inc(Ini.Rit, -50);
    0: Ini.Rit := 0;
    1: Inc(Ini.Rit, 50);
    2: Inc(Ini.Rit, 5);
  end;

  Ini.Rit := Min(500, Max(-500, Ini.Rit));
  UpdateRitIndicator;
end;


procedure TMainForm.UpdateRitIndicator;
begin
  Shape2.Width := Ini.Bandwidth div 9;
  Shape2.Left := ((Panel8.Width - Shape2.Width) div 2) + (Ini.Rit div 9);
end;


{
  Move cursor to next exchange field.
  Called by TMyStation.GetBlock after callsign is sent.
  If the callsign field (Edit1) contains a '?', the active control is
  set to Edit1 and the '?' is selected.
  For contests with an RST field, the RST field is set to 599 and the active
  control is then set to Edit3 (skipping the RST field). Note that using
  TAB will select the RST field with the middle digit selected.
  For contests without an RST field, the active control is advanced to the
  next exchange field.
}
procedure TMainForm.Advance;
begin
  if not MustAdvance then
    Exit;

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

  MustAdvance := false;
end;



procedure TMainForm.VolumeSliderDblClick(Sender: TObject);
begin
  with Sender as TVolumeSlider do begin
    Value := 0.75;
    OnChange(Sender);
  end;
end;

procedure TMainForm.VolumeSlider1Change(Sender: TObject);
begin
  with VolumeSlider1 do begin
    //-60..+20 dB
    Db := 80 * (Value - 0.75);
    if dB > 0 then
      Hint := Format('+%.0f dB', [dB])
    else
      Hint := Format( '%.0f dB', [dB]);
    end;
end;


procedure TMainForm.WebPage1Click(Sender: TObject);
begin
  OpenWebPage('http://www.dxatlas.com/MorseRunner');
end;


procedure TMainForm.PostHiScore(const sScore: string);
var
  HttpClient: TIdHttp;
  ParamList: TStringList;
  s, sUrl, sp: string;
  response: TMemoryStream;
  p: integer;
begin
  HttpClient:= TIdHttp.Create();
  response:= TMemoryStream.Create;
  s:= format(SubmitHiScoreURL, [sScore]);
  s:= StringReplace(s, ' ', '%20', [rfReplaceAll]);
  try
    HttpClient.AllowCookies:= true;
    HttpClient.Request.ContentType:= 'application/x-www-form-urlencoded';
    HttpClient.Request.CacheControl:='no-cache';
    HttpClient.Request.UserAgent:='User-Agent=Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)';
    HttpClient.Request.Accept:='Accept=*/*';
    HttpClient.OnRedirect:= ClientHTTP1Redirect;
    if PostMethod<>'POST' then
    begin // Method = Get
      s:= StringReplace(s, '[', '%5B', [rfReplaceAll]);
      s:= StringReplace(s, ']', '%5D', [rfReplaceAll]);
      HttpClient.Get(s, response);
    end
    else
    begin // Method = Post
      p:= pos('?', s);
      sUrl:= copy(s, 0, p-1);
      sp:= copy(s, p + 1, MaxInt);
      ParamList:= TStringList.Create;
      ParamList.Delimiter:= '&';
      ParamList.DelimitedText:= sp;
      // procedure TStrings.SetDelimitedText(const Value: string); has a bug
      ParamList.Text:= StringReplace(ParamList.Text, '%20', ' ', [rfReplaceAll]);
      HttpClient.Request.ContentType:= 'application/x-www-form-urlencoded';
      s:= HttpClient.Post(sUrl, ParamList);
      ParamList.Free;
    end;
    if HttpClient.Tag=1 then
      ShowMessage('Sent!')
    else
      ShowMessage('Error!');
  finally
    HttpClient.Free;
  end;
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
  PlayRecordedAudio1.Enabled := Stp and FileExists(ChangeFileExt(ParamStr(0), '.wav'));

  AudioRecordingEnabled1.Checked := Ini.SaveWav;
end;

procedure TMainForm.PlayRecordedAudio1Click(Sender: TObject);
var
  FileName: string;
begin
  FileName := ChangeFileExt(ParamStr(0), '.wav');
  ShellExecute(GetDesktopWindow, 'open', PChar(FileName), '', '', SW_SHOWNORMAL);
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


procedure TMainForm.CWMaxRxSpeedClick(Sender: TObject);
Var
  maxspd:integer;
begin
  maxspd := (Sender as TMenuItem).Tag;

  UpdCWMaxRxSpeed(maxspd);
end;


procedure TMainForm.UpdCWMaxRxSpeed(Maxspd: integer);
begin
  Ini.MaxRxWpm := Maxspd;
  CWMaxRxSpeedSet0.checked := maxspd = 0;
  CWMaxRxSpeedSet1.checked := maxspd = 1;
  CWMaxRxSpeedSet2.checked := maxspd = 2;
  CWMaxRxSpeedSet4.checked := maxspd = 4;
  CWMaxRxSpeedSet6.checked := maxspd = 6;
  CWMaxRxSpeedSet8.checked := maxspd = 8;
  CWMaxRxSpeedSet10.checked := maxspd = 10;
end;


procedure TMainForm.CWMinRxSpeedClick(Sender: TObject);
Var
  minspd:integer;
begin
  minspd := (Sender as TMenuItem).Tag;

  UpdCWMinRxSpeed(minspd);
end;


procedure TMainForm.UpdCWMinRxSpeed(minspd: integer);
begin
   if (Wpm < 15) and  (minspd > 4) then
            minspd := 4;

  Ini.MinRxWpm := minspd;
  CWMinRxSpeedSet0.checked := minspd = 0;
  CWMinRxSpeedSet1.checked := minspd = 1;
  CWMinRxSpeedSet2.checked := minspd = 2;
  CWMinRxSpeedSet4.checked := minspd = 4;
  CWMinRxSpeedSet6.checked := minspd = 6;
  CWMinRxSpeedSet8.checked := minspd = 8;
  CWMinRxSpeedSet10.checked := minspd = 10;
end;

procedure TMainForm.NRDigitsClick(Sender: TObject);
Var
  nrd:integer;
begin
  nrd := (Sender as TMenuItem).Tag;

  UpdNRDigits(nrd);
end;


procedure TMainForm.UpdNRDigits(nrd: integer);
begin
  Ini.NRDigits := nrd;
  NRDigitsSet1.Checked := nrd = 1;
  NRDigitsSet2.Checked := nrd = 2;
  NRDigitsSet3.Checked := nrd = 3;
  NRDigitsSet4.Checked := nrd = 4;
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


procedure TMainForm.ListView2CustomDrawSubItem(Sender: TCustomListView;
  Item: TListItem; SubItem: Integer; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
    if (SubItem=5) then
      (Sender as TListView).Canvas.Font.Color:= clRed
    else
      (Sender as TListView).Canvas.Font.Color:= clBlack;
end;

procedure TMainForm.ListView2SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
    if (mnuShowCallsignInfo.Checked) then
        UpdateSbar(Item.SubItems[0]);
    //Item.Index  @QsoList[High(QsoList)];
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
  HamName := InputBox('HST/CWOps Operator', 'Enter operator''s name', HamName);
  HamName := UpperCase(HamName);

  Ini.UserExchangeTbl[scCwt] := Format('%s %s', [HamName, CWOPSNum]);
  if SimContest = scCwt then
    SetMyExchange(Ini.UserExchangeTbl[SimContest]);

  UpdateTitleBar;

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      WriteString(SEC_STN, 'Name', HamName);
    finally
      Free;
    end;
end;


procedure TMainForm.CWOPSNumberClick(Sender: TObject);
Var
buf: string;
begin
  buf := InputBox('CWOps Number', 'Enter CWOPS Number', CWOPSNum);
  if buf = '' then begin
       exit;
  end;
  if CWOPSCWT.isnum(buf)=False then  begin
       exit;
  end;
    CWOPSNum := buf;

  Ini.UserExchangeTbl[scCwt] := Format('%s %s', [HamName, CWOPSNum]);
  if SimContest = scCwt then
    SetMyExchange(Ini.UserExchangeTbl[SimContest]);

  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
    try
      WriteString(SEC_STN, 'cwopsnum', CWOPSNum);
    finally
      Free;
    end;
end;


procedure TMainForm.StopMNUClick(Sender: TObject);
begin
  Tst.FStopPressed := true;
end;

end.

