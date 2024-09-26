//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Log;

interface

uses
  System.UITypes,     // TColor
  Classes, ExtCtrls;

procedure SaveQso;
procedure LastQsoToScreen;
procedure Clear;
procedure UpdateStats(AVerifyResults : boolean);
procedure UpdateStatsHst;
procedure CheckErr;
//procedure PaintHisto;
procedure ShowRate;
procedure ScoreTableInit(const ColDefs: array of string);
procedure SetExchColumns(AExch1ColPos, AExch2ColPos: integer;
  AExch1ExColPos: integer = -1;
  AExch2ExColPos: integer = -1);
procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6: string; const ACol7: string = ''; const ACol8: string = '');
procedure ScoreTableUpdateCheck;
function FormatScore(const AScore: integer):string;
procedure UpdateSbar;
procedure SbarUpdateStationInfo(const ACallsign: string);
procedure SBarUpdateSummary(const AExchSummary: String);
procedure SBarUpdateDebugMsg(const AMsgText: string);
procedure DisplayError(const AExchError: string; const AColor: TColor);
function ExtractCallsign(Call: string): string;
function ExtractPrefix(Call: string; DeleteTrailingLetters: boolean = True): string;
{$ifdef DEBUG}
function ExtractPrefix0(Call: string): string;
{$endif}

{$ifdef DEBUG}
// Debugging API patterned after LazLogger.
// (Used in anticipation of a future port to Lazarus compiler)
procedure DebugLn(const AMsg: string) overload;
procedure DebugLn(const AFormat: string; const AArgs: array of const) overload;
procedure DebugLnEnter(const AMsg: string) overload;
procedure DebugLnEnter(const AFormat: string; const AArgs: array of const) overload;
procedure DebugLnExit(const AMsg: string) overload;
procedure DebugLnExit(const AFormat: string; const AArgs: array of const) overload;
{$endif}


type
  TLogError = (leNONE, leNIL,   leDUP, leCALL, leRST,
               leNAME, leCLASS, leNR,  leSEC,  leQTH,
               leZN,   leSOC,   leST,  lePWR,  leERR,
               lePREC, leCHK);

  PQso = ^TQso;
  TQso = record
    T: TDateTime;
    Call, TrueCall, RawCallsign: string;
    Rst, TrueRst: integer;
    Nr, TrueNr: integer;
    Prec, TruePrec: string;     // SS' Precedence character
    Check, TrueCheck: integer;  // SS' Chk (year licensed)
    Sect, TrueSect: string;     // SS' Arrl/RAC Section
    Exch1, TrueExch1: string;   // exchange 1 (e.g. 3A, OpName)
    Exch2, TrueExch2: string;   // exchange 2 (e.g. OR, CWOPSNum)
    TrueWpm: string;            // WPM of sending DxStn (reported in log)
    Pfx: string;                // extracted call prefix
    MultStr: string;            // contest-specific multiplier (e.g. Pfx, dxcc)
    Points: integer;            // points for this QSO
    Dupe: boolean;              // this qso is a DUP.
    ExchError: TLogError;       // Callsign error code
    Exch1Error: TLogError;      // Exchange 1 qso primary error code
    Exch1ExError: TLogError;    // Exchange 1 qso secondary error code (used by ARRL SS)
    Exch2Error: TLogError;      // Exchange 2 qso primary error code
    Exch2ExError: TLogError;    // Exchange 2 qso secondary error code (used by ARRL SS)
    Err: string;                // Qso error string (e.g. corrections)
    ColumnErrorFlags: Integer;  // holds column-specific errors using bit mask
                                // with (0x01 << ColumnInx).

    procedure CheckExch1(var ACorrections: TStringList);
    procedure CheckExch2(var ACorrections: TStringList);

    procedure SetColumnErrorFlag(AColumnInx: integer);
    function TestColumnErrorFlag(ColumnInx: Integer): Boolean;
  end;

  THisto= class(TObject)
    private Histo: array[0..47] of integer;
    //private w, h, CallCount: integer;
    private Duration: integer;
    private PaintBoxH: TPaintBox;
    public constructor Create(APaintBox: TPaintBOx);
    public procedure ReCalc(ADuration: integer);
    public procedure Repaint;
  end;

  {
    A MultList hold a set of unique strings, each representing a unique
    multiplier for the current contest. The underlying TStringList is sorted
    and duplicate strings are ignored.

    An instance of this class is used for both raw and verified multipliers.
  }
  TMultList= class(TStringList)
    public
      constructor Create;
      procedure ApplyMults(const AMultipliers: string);
  end;

const
  EM_SCROLLCARET = $B7;
  WM_VSCROLL= $0115;

var
  QsoList: array of TQso;
  RawMultList:      TMultList; // sorted, no dups; counts raw multipliers.
  VerifiedMultList: TMultList; // sorted, no dups; counts verified multipliers.
  RawPoints:        integer;   // accumalated raw QSO points total
  VerifiedPoints:   integer;   // accumulated verified QSO points total
  CallSent: boolean; // msgHisCall has been sent; cleared upon edit.
  NrSent: boolean;   // msgNR has been sent; cleared after qso is completed.
  ShowCorrections: boolean;   // show exchange correction column.
  SBarDebugMsg: String;         // sbar debug message
  SBarStationInfo: String;    // sbar station info (UserText from call history file)
  SBarSummaryMsg: String;     // sbar exchange summary (ARRL SS)
  SBarErrorMsg: String;       // sbar exchange error
  SBarErrorColor: TColor;     // sbar exchange error color
  Histo: THisto;

  // the following column index values are used to set error flags in TQso.ColumnErrorFlags
  CallColumnInx: Integer;
  Exch1ColumnInx: Integer;
  Exch1ExColumnInx: Integer;
  Exch2ColumnInx: Integer;
  Exch2ExColumnInx: Integer;
  CorrectionColumnInx: Integer;

{$ifdef DEBUG}
  RunUnitTest : boolean;  // run ExtractPrefix unit tests once
{$endif}


implementation

uses
  Windows, SysUtils, RndFunc, Math,
  Graphics,     // for TColor
  ExchFields,   // for exchange field types
  Controls,
  StdCtrls, PerlRegEx, StrUtils,
  Contest, Main, DxStn, DxOper, Ini, Station, MorseKey;

const
  ShowHstCorrections: Boolean = true;
  LogColUtcWidth: Integer = 80;   // matches value in resource file
  LogColPadding: Integer = 10;    // Additional padding space for columns

  {
    The following constants are used to initialize the Log Report columns
    for the various contests. Many of these declarations are used across
    many contests (e.g. UTC, Call, RST, etc...).
    See Log.Clear and Log.ScoreTableInit for more information.

    This declaration is composed as follows: <Name>,<Width>,<Justification>
    - Name - column name displayed at the top of each Log report column
    - Width - column width expressed in the number of characters to reserve
    - Justification - L, C, or R representing Left, Center, or Right
  }
  UTC_COL         = 'UTC,8,L';
  CALL_COL        = 'Call,10,L';
  NR_COL          = 'Nr,4,R';
  RST_COL         = 'RST,4,R';
  ARRL_SECT_COL   = 'Sect,4,L';
  FD_CLASS_COL    = 'Class,5,L';
  CORRECTIONS_COL = 'Corrections,11,L';
  WPM_COL         = 'Wpm,3.25,R';
  WPM_FARNS_COL   = 'Wpm,5,R';
  NAME_COL        = 'Name,8,L';
  STATE_PROV_COL  = 'State,5,L';
  PREFIX_COL      = 'Pref,4,L';
  ARRLDX_EXCH_COL = 'Exch,5,R';
  CWT_EXCH_COL    = 'Exch,5,L';
  SST_EXCH_COL    = 'Exch,5,L';
  ALLJA_EXCH_COL  = 'Exch,6,L';
  ACAG_EXCH_COL   = 'Exch,8,L';
  IARU_EXCH_COL   = 'Exch,6,L';
  WPX_EXCH_COL    = 'Exch,6,L';
  HST_EXCH_COL    = 'Exch,6,L';
  CQWW_RST_COL    = 'RST,4,L';
  CQ_ZONE_COL     = 'Zone,4,L';
  SS_CALL_COL     = 'Call,9,L';
  SS_PREC_COL     = 'Pr,2.5,L';
  SS_CHECK_COL    = 'Chk,3.25,C';

{$ifdef DEBUG}
  DEBUG_INDENT: Integer = 3;
{$endif}

var
  LogColScaling: Single;          // columns widths can be scaled.
  LogColWidthPerChar: Single;     // scaled pixel count per character
  ScaleTableInitialized: boolean; // initialize ScaleTable values one time only
{$ifdef DEBUG}
  Indent: Integer = 0;    // used by DebugLnEnter/DebugLnExit
{$endif}
  SBarLastCallsign: String;       // used to optimize SBrSetStationInfo

constructor THisto.Create(APaintBox: TPaintBOx);
begin
  Self.PaintBoxH:= APaintBox;
end;

procedure THisto.ReCalc(ADuration: integer);
begin
  Self.Duration:= ADuration;
end;

procedure THisto.Repaint;
var
  //Histo: array[0..47] of integer;
  i: integer;
  x, y, w: integer;
begin
  FillChar(Histo, SizeOf(Histo), 0);

  for i:=0 to High(QsoList) do begin
    x := Trunc(QsoList[i].T * 1440) div 5;  // How Many QSO in 5mins
    Inc(Histo[x]);
  end;

  with Self.PaintBoxH, Self.PaintBoxH.Canvas do begin
    w:= Trunc(ClientWidth / 48);
    Brush.Color := Color;
    FillRect(RECT(0,0, Width, Height));
    for i:=0 to High(Histo) do begin
      Brush.Color := clGreen;
      x := i * w;
      y := Height - 3 - Histo[i] * 2;
      FillRect(Rect(x, y, x+w-1, Height-2));
    end;
  end;
end;

constructor TMultList.Create;
begin
  inherited Create;
  Self.Sorted := true;
  Self.Duplicates := dupIgnore;
end;

{
  Split the multiplier string into one or more multiplier values.
  These are then added to the sorted, no-dups TMultList. The final
  count is the multiplier count for this contest run.
}
procedure TMultList.ApplyMults(const AMultipliers: string);
begin
  // split multiplier string on ';'. allows for multiple multipliers.
  AddStrings(SplitString(AMultipliers, ';'));
end;

function FormatScore(const AScore: integer):string;
begin
  FormatScore:= format('%6d', [AScore]);
end;

procedure TQso.SetColumnErrorFlag(AColumnInx: integer);
begin
  assert((AColumnInx > -1) and (AColumnInx < 32));
  if AColumnInx <> -1 then
    ColumnErrorFlags := ColumnErrorFlags or (1 shl AColumnInx);
end;

function TQso.TestColumnErrorFlag(ColumnInx: Integer): Boolean;
begin
  Result := (ColumnErrorFlags and (1 shl ColumnInx)) <> 0;
end;

{
  Initialize the Call Log Report.

  An array of ColDefs is passed in with one entry for each column.
  Each column definition string is defined as follows:
    <Name>,<Width>,<Justification>
    - Name - column name displayed at the top of each Log report column
    - Width - column width expressed in the number of characters to reserve
    - Justification - L, C, or R representing Left, Center, or Right
}
procedure ScoreTableInit(const ColDefs: array of string);
var
  I: integer;
  tl: TStringList;
  CallColumnName, CorrectionsColumnName: string;
  Name: string;
  Width: integer;
  Alignment: TAlignment;
  FS: TFormatSettings;

  // return the column name from a column definition string
  function GetColumnName(const AColDef: string): string;
  begin
    Result := AColDef.Substring(0, AColDef.IndexOf(','));
  end;

begin
  tl := TStringList.Create('''',',');
  FS := TFormatSettings.Create('en-US');  // DecimalPoint = '.'
  try
    // retain initial log column widths (used to restore column widths)
    if not ScaleTableInitialized then
      begin
        Width := MainForm.ListView2.Column[0].Width;
        LogColScaling := Width / LogColUtcWidth;  // e.g. 125% for laptops
        LogColWidthPerChar := Width / 8.5;  // UTC-column width, ~8.5 characters
        ScaleTableInitialized:= true;
      end;

    CallColumnInx := -1;
    Exch1ColumnInx := -1;
    Exch1ExColumnInx := -1;
    Exch2ColumnInx := -1;
    Exch2ExColumnInx := -1;
    CorrectionColumnInx := -1;
    CallColumnName := GetColumnName(CALL_COL);
    CorrectionsColumnName := GetColumnName(CORRECTIONS_COL);

    // initialize log report columns
    for I := Low(ColDefs) to High(ColDefs) do begin
      tl.DelimitedText := ColDefs[I];
      assert(tl.Count = 3);
      Name := tl[0];
      if I = 0 then // use existing width for UTC Column
        Width := MainForm.ListView2.Column[I].Width
      else
        Width := Round(StrToFloat(tl[1], FS) * LogColWidthPerChar + LogColPadding*LogColScaling);
      Alignment := taLeftJustify;
      case tl[2][1] of
        'L': Alignment := taLeftJustify;
        'C': Alignment := taCenter;
        'R': Alignment := taRightJustify;
        else
          assert(false, 'invalid alignment');
      end;

      // add additional columns if needed
      while I >= MainForm.ListView2.Columns.Count do
        MainForm.ListView2.Columns.Add;

      MainForm.ListView2.Column[I].Caption := Name;
      MainForm.ListView2.Column[I].Width := Width;
      MainForm.ListView2.Column[I].Alignment := Alignment;

      if Name = CallColumnName then
        CallColumnInx := I
      else if CorrectionsColumnName.StartsWith(Name) then
        CorrectionColumnInx := I;
    end;

    // delete unused columns
    while I < MainForm.ListView2.Columns.Count do
      MainForm.ListView2.Columns.Delete(I);

    // By default, exchance fields 1 and 2 are displayed in columns 2 and 3
    Log.SetExchColumns(2, 3);

  finally
  tl.Free;
  end;
end;


{
  Set column indices for dynamic exchange columns
}
procedure SetExchColumns(AExch1ColPos, AExch2ColPos: integer;
  AExch1ExColPos, AExch2ExColPos: integer);
begin
  Log.Exch1ColumnInx := AExch1ColPos;
  Log.Exch2ColumnInx := AExch2ColPos;
  Log.Exch1ExColumnInx := AExch1ExColPos;
  Log.Exch2ExColumnInx := AExch2ExColPos;
end;


{
  Add row to Score Table Log Report.
}
procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6, ACol7, ACol8: string);
begin
  MainForm.ListView2.Items.BeginUpdate;
  with MainForm.ListView2.Items.Add do begin
    Caption:= ACol1;
    SubItems.Add(ACol2);
    SubItems.Add(ACol3);
    SubItems.Add(ACol4);
    SubItems.Add(ACol5);
    SubItems.Add(ACol6);
    if ACol7 <> '' then SubItems.Add(ACol7);
    if ACol8 <> '' then SubItems.Add(ACol8);
    Selected:= True;
  end;
  MainForm.ListView2.Items.EndUpdate;

  MainForm.ListView2.Perform(WM_VSCROLL, SB_BOTTOM, 0);
end;

//Update Callsign info
procedure SbarUpdateStationInfo(const ACallsign: string);
var
  s: string;
begin
  if ACallSign = SBarLastCallsign then Exit;
  SBarLastCallsign := ACallsign;

  s:= '';
  if not ACallsign.IsEmpty then
  begin
    // Adding a contest: SbarUpdateStationInfo - update status bar with station info (e.g. FD shows UserText)
    s := Tst.GetStationInfo(ACallsign);

    // '&' are suppressed in this control; replace with '&&'
    s:= StringReplace(s, '&', '&&', [rfReplaceAll]);
  end;

  SBarStationInfo := s;
  UpdateSbar;
end;


procedure SBarUpdateSummary(const AExchSummary: String);
begin
  if SBarSummaryMsg = AExchSummary then Exit;

  SBarSummaryMsg := AExchSummary;
  UpdateSbar;
end;



procedure SBarUpdateDebugMsg(const AMsgText: string);
begin
  if SBarDebugMsg = AMsgText then Exit;

  if AMsgText.IsEmpty then
    SBarDebugMsg := ''
  else
    SBarDebugMsg := (AMsgText + '; ' + SBarDebugMsg).Substring(0, 40);
  UpdateSbar;
end;

// Refresh Status Bar
// [<Exchange Summary> --] [(Error | UserText)] [>> Debug]
procedure UpdateSbar;
var
  S: String;
begin
  // optional exchange summary...
  if Ini.ShowExchangeSummary <> 0 then
    if SimContest in [scArrlSS] then
      case Ini.ShowExchangeSummary of
        1:
          if SBarSummaryMsg.IsEmpty then
            Mainform.Label3.Caption := Exchange2Settings[etSSCheckSection].C
          else
            Mainform.Label3.Caption := SBarSummaryMsg;
        2:
          S := SBarSummaryMsg;
      end;

  // error or UserText...
  if not SBarErrorMsg.IsEmpty then
    begin
      if not S.IsEmpty then
        S := S + ' -- ';
      S := S + SBarErrorMsg;
    end
  else if not SBarStationInfo.IsEmpty then
    begin
      if not S.IsEmpty then
        S := S + ' -- ';
      S := S + SBarStationInfo;
    end;

  // during debug, use status bar to show CW stream
  if not SBarDebugMsg.IsEmpty then
    S := format('  %-45s >> %-40s', [S, SBarDebugMsg]);

  if SBarErrorMsg.IsEmpty then
    Mainform.sbar.Font.Color := clDefault
  else
    Mainform.sbar.Font.Color := SBarErrorColor;

  MainForm.sbar.Caption := S;
end;


procedure DisplayError(const AExchError: string; const AColor: TColor);
begin
  if (Log.SBarErrorMsg = AExchError) and
     (Log.SBarErrorColor = AColor) then Exit;

  Log.SBarErrorMsg := AExchError;
  Log.SBarErrorColor := AColor;
  UpdateSbar;
end;


{
  Update the error corrections column or error string in the Score Table.
}
procedure ScoreTableUpdateCheck;
begin
  // https://stackoverflow.com/questions/34239493/how-to-color-specific-list-view-item-in-delphi
  with MainForm.ListView2 do begin
    if CorrectionColumnInx > 0 then
      Items[Items.Count-1].SubItems[CorrectionColumnInx-1] := QsoList[High(QsoList)].Err;
    Items[Items.Count-1].Update;
  end;
end;


procedure Clear;
var
  Empty: string;
begin
  QsoList := nil;
  RawMultList.Clear;
  VerifiedMultList.Clear;
  RawPoints := 0;
  VerifiedPoints := 0;

  // Correction column is implemented for all contests; conditional for HST.
  ShowCorrections := (SimContest <> scHst) or ShowHstCorrections;

  Tst.Stations.Clear;
  MainForm.RichEdit1.Lines.Clear;
  MainForm.RichEdit1.DefAttributes.Name:= 'Consolas';
  MainForm.ListView2.Clear;

  // Adding a contest: set Score Table titles
  case Ini.SimContest of
    scCwt:
      ScoreTableInit([UTC_COL, CALL_COL, NAME_COL, CWT_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scSst:
      ScoreTableInit([UTC_COL, CALL_COL, NAME_COL, SST_EXCH_COL, CORRECTIONS_COL, WPM_FARNS_COL]);
    scFieldDay:
      ScoreTableInit([UTC_COL, CALL_COL, FD_CLASS_COL, ARRL_SECT_COL, CORRECTIONS_COL, WPM_COL]);
    scArrlSS:
      begin
      ScoreTableInit([UTC_COL, SS_CALL_COL, NR_COL, SS_PREC_COL, SS_CHECK_COL, ARRL_SECT_COL, CORRECTIONS_COL, WPM_COL]);
      SetExchColumns(2, 4, 3, 5);
      end;
    scNaQp:
      ScoreTableInit([UTC_COL, 'Call,8,L', NAME_COL, STATE_PROV_COL, PREFIX_COL, CORRECTIONS_COL, WPM_COL]);
    scCQWW:
      ScoreTableInit([UTC_COL, CALL_COL, CQWW_RST_COL, CQ_ZONE_COL, CORRECTIONS_COL, WPM_COL]);
    scArrlDx:
      ScoreTableInit([UTC_COL, CALL_COL, RST_COL, ARRLDX_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scAllJa:
      ScoreTableInit([UTC_COL, CALL_COL, RST_COL, ALLJA_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scAcag:
      ScoreTableInit([UTC_COL, CALL_COL, RST_COL, ACAG_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scIaruHf:
      ScoreTableInit([UTC_COL, CALL_COL, RST_COL, IARU_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scWpx:
      ScoreTableInit([UTC_COL, CALL_COL, RST_COL, WPX_EXCH_COL, CORRECTIONS_COL, WPM_COL]);
    scHst:
      if ShowCorrections then
        ScoreTableInit([UTC_COL, CALL_COL, RST_COL, HST_EXCH_COL, 'Score,5,R', 'Correct,8,L', WPM_COL])
      else
        ScoreTableInit([UTC_COL, CALL_COL, 'Recv,10,L', 'Sent,9,L', 'Score,5,R', 'Chk,3,L', WPM_COL]);
    else
      assert(false, 'missing case');
  end;  // end case

  if SimContest = scHst then
    Empty := ''
  else
    Empty := FormatScore(0);

  MainForm.ListView1.Items[0].SubItems[0] := Empty;
  MainForm.ListView1.Items[1].SubItems[0] := Empty;
  MainForm.ListView1.Items[0].SubItems[1] := Empty;
  MainForm.ListView1.Items[1].SubItems[1] := Empty;
  MainForm.ListView1.Items[2].SubItems[0] := FormatScore(0);
  MainForm.ListView1.Items[2].SubItems[1] := FormatScore(0);

  MainForm.PaintBox1.Invalidate;
end;


function CallToScore(S: string): integer;
var
  i: integer;
begin
  S := Keyer.Encode(S);
  Result := -1;
  for i:=1 to Length(S) do
    case S[i] of
      '.': Inc(Result, 2);
      '-': Inc(Result, 4);
      ' ': Inc(Result, 2);
    end;
end;

procedure UpdateStatsHst;
var
  CallScore, RawScore, Score: integer;
  i: integer;
begin
  RawScore := 0;
  Score := 0;

  for i:=0 to High(QsoList) do begin
    CallScore := CallToScore(QsoList[i].Call);
    Inc(RawScore, CallScore);
    if QsoList[i].Err = '   ' then
      Inc(Score, CallScore);
  end;

  MainForm.ListView1.Items[0].SubItems[0] := '';
  MainForm.ListView1.Items[1].SubItems[0] := '';
  MainForm.ListView1.Items[2].SubItems[0] := FormatScore(RawScore);

  MainForm.ListView1.Items[0].SubItems[1] := '';
  MainForm.ListView1.Items[1].SubItems[1] := '';
  MainForm.ListView1.Items[2].SubItems[1] := FormatScore(Score);

  MainForm.PaintBox1.Invalidate;

  MainForm.Panel11.Caption := IntToStr(Score);
end;

{
  Update cumulative QSO scoring, including both Raw and Verified scores.
  This procedure is called twice per QSO:
  1) after data is copied from the UI into the QSO record. Updates raw results.
  2) after data is verified against the actual DxStn. Update verified results.

  The AVerifyResults argument indicates whether to collect Raw results or
  Verify the final results for the current QSO.

  Note: care must be taken to be sure this function is called exactly two
  times, once each for Raw and Verified states. This is necessary since
  cumulative raw and verify QSO point totals are being accumulated in
  the variables RawPoints and VerifiedPoints.
}
procedure UpdateStats(AVerifyResults : boolean);
var
  Mul: integer;
begin
  // accumulate raw points count
  if not AVerifyResults then
    With QsoList[High(QsoList)] do
      begin
        Inc(RawPoints, Points);
        RawMultList.ApplyMults(MultStr);
      end;
  Mul := RawMultList.Count;

  MainForm.ListView1.Items[0].SubItems[0] := FormatScore(RawPoints);
  MainForm.ListView1.Items[1].SubItems[0] := FormatScore(Mul);
  MainForm.ListView1.Items[2].SubItems[0] := FormatScore(RawPoints*Mul);

  // accumulate verified points count
  if AVerifyResults then
    With QsoList[High(QsoList)] do
      if Err = '   ' then begin
        Inc(VerifiedPoints, Points);
        VerifiedMultList.ApplyMults(MultStr);
      end;
  Mul := VerifiedMultList.Count;

  MainForm.ListView1.Items[0].SubItems[1] := FormatScore(VerifiedPoints);
  MainForm.ListView1.Items[1].SubItems[1] := FormatScore(Mul);
  MainForm.ListView1.Items[2].SubItems[1] := FormatScore(VerifiedPoints*Mul);

  MainForm.PaintBox1.Invalidate;
end;

// Code by BG4FQD
function ExtractCallsign(Call: string):string;
var
    reg: TPerlRegEx;
    bMatch: bool;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= '';
        reg.Subject := UTF8Encode(Call);
        reg.RegEx:= '(([0-9][A-Z])|([A-Z]{1,2}))[0-9][A-Z0-9]*[A-Z]';
        bMatch:= reg.Match;
        if bMatch then begin
            if reg.MatchedOffset > 1 then
                bMatch:= (call[reg.MatchedOffset-1] = '/');
            if bMatch then begin
                Result:= String(reg.MatchedText);
            end;
        end;
    finally
        reg.Free;
    end;
end;


{$ifdef DEBUG}
function ExtractPrefix0(Call: string): string;
var
    reg: TPerlRegEx;
begin
    reg := TPerlRegEx.Create();
    try
        Result:= '-';
        reg.Subject := UTF8String(Call);
        reg.RegEx:= '(([0-9][A-Z])|([A-Z]{1,2}))[0-9]';
        if reg.Match then
            Result:= UTF8ToUnicodeString(reg.MatchedText);
    finally
        reg.Free;
    end;
end;
{$endif}


function ExtractPrefix(Call: string; DeleteTrailingLetters: boolean): string;
const
  DIGITS = ['0'..'9'];
  LETTERS = ['A'..'Z'];
var
  p: integer;
  S1, S2, Dig: string;
begin
{$ifdef DEBUG}
  if RunUnitTest then begin
    RunUnitTest := false;
    // original algorithm
    assert(ExtractPrefix0('W7SST') = 'W7');
    assert(ExtractPrefix0('W7SST/6') = 'W7');  // should be 'W6'
    assert(ExtractPrefix0('N7SST/6') = 'N7');  // should be 'N6'
    assert(ExtractPrefix0('F6/W7SST') = 'F6');
    assert(ExtractPrefix0('F6/AB7Q') = 'F6');
    assert(ExtractPrefix0('W7SST/W') = 'W7');  // should be 'W0'
    assert(ExtractPrefix0('F6FVY/W7') = 'F6'); // should be 'W7'

    // newer algorithm
    assert(ExtractPrefix('W7SST') = 'W7');
    assert(ExtractPrefix('W7SST/6') = 'W6');
    assert(ExtractPrefix('N7SST/6') = 'N6');
    assert(ExtractPrefix('F6/W7SST') = 'F6');
    assert(ExtractPrefix('W7SST/W') = 'W0');
    assert(ExtractPrefix('F6FVY/W7') = 'W7');
    assert(ExtractPrefix('F6/W7SST/P') = 'F6');
    assert(ExtractPrefix('W7SST/W/QRP') = 'W0');
    assert(ExtractPrefix('F6FVY/W7/MM') = 'W7');
  end;
{$endif}
  //kill modifiers
  Call := Call + '|';
  Call := StringReplace(Call, '/QRP|', '', []);
  Call := StringReplace(Call, '/MM|', '', []);
  Call := StringReplace(Call, '/M|', '', []);
  Call := StringReplace(Call, '/P|', '', []);
  Call := StringReplace(Call, '|', '', []);
  Call := StringReplace(Call, '//', '/', [rfReplaceAll]);
  if Length(Call) < 2 then
  begin
    Result := '';
    Exit;
  end;

  Dig := '';

  //select shorter piece
  p := Pos('/', Call);
  if p = 0 then Result := Call
  else if p = 1 then Result := Copy(Call, 2, MAXINT)
  else if p = Length(Call) then Result := Copy(Call, 1, p-1)
  else
    begin
    S1 := Copy(Call, 1, p-1);
    S2 := Copy(Call, p+1, MAXINT);

    if (Length(S1) = 1) and CharInSet(S1[1], DIGITS) then begin
        Dig := S1; Result := S2;
    end
    else
        if (Length(S2) = 1) and CharInSet(S2[1], DIGITS) then begin
            Dig := S2;
            Result := S1;
        end
        else
            if Length(S1) <= Length(S2) then
                Result := S1
            else
                Result := S2;
    end;
  if Pos('/', Result) > 0 then begin
    Result := '';
    Exit;
  end;

  // when ARRL.pas (DXCC support) is extracting the prefix, the trailing letters
  // are NOT removed. This allows longer prefixes to be recognized.
  // (e.g. The call RC2FX has a prefix RC2F, which is Kaliningrad.
  // if the trailing 'F' is removed, the prefix matches European Russia)
  if not DeleteTrailingLetters then
    Exit;

  //delete trailing letters, retain at least 2 chars
  for p:= Length(Result) downto 3 do
//    if Result[p] in DIGITS then
    if CharInSet(Result[p], DIGITS) then
      Break
    else
      Delete(Result, p, 1);

  //ensure digit
//  if not (Result[Length(Result)] in DIGITS) then
  if not CharInSet(Result[Length(Result)], DIGITS) then
    Result := Result + '0';
  //replace digit
  if Dig <> '' then
    Result[Length(Result)] := Dig[1];

  Result := Copy(Result, 1, 5);
end;


{
  Save QSO data into the Log.

  Called after user presses:
  - 'Enter' key (after sending 'TU' to caller).
  - 'Shift-Enter', 'Cntl-Enter' or 'Alt-Enter' (without sending 'TU' to caller).
}
procedure SaveQso;
var
  Call: string;
  ExchError: string;
  i: integer;
  Qso: PQso;
begin
  with MainForm do
    begin
    Call := StringReplace(Edit1.Text, '?', '', [rfReplaceAll]);

    // Verify callsign (simple length-based check); virtual
    if not Tst.CheckEnteredCallLength(Call, ExchError) then
      begin
        {Beep;}
        DisplayError(ExchError, clRed);
        Exit;
      end;

    //add new entry to log
    SetLength(QsoList, Length(QsoList)+1);
    Qso := @QsoList[High(QsoList)];

    //save data
    Qso.T := BlocksToSeconds(Tst.BlockNumber) /  86400;
    Qso.Call := Call;

    //save contest-specific exchange values into QSO
    Tst.SaveEnteredExchToQso(Qso^, Edit2.Text, Edit3.Text);

    Qso.Points := 1;  // defaults to 1; override in ExtractMultiplier()
    Qso.RawCallsign:= ExtractCallsign(Qso.Call);
    // Use full call when extracting prefix, not user's call.
    Qso.Pfx := ExtractPrefix(Qso.Call);
    // extract ';'-delimited multiplier string(s) and update Qso.Points.
    Qso.MultStr := Tst.ExtractMultiplier(Qso);
    if SimContest = scHst then
      Qso.Pfx := IntToStr(CallToScore(Qso.Call));

    //mark if dupe
    Qso.Dupe := false;
    for i:=0 to High(QsoList)-1 do
      with QsoList[i] do
        if (Call = Qso.Call) and (Err = '   ') then
          Qso.Dupe := true;

    // find Wpm from DX's log
    for i:=Tst.Stations.Count-1 downto 0 do
      if Tst.Stations[i] is TDxStation then
        with Tst.Stations[i] as TDxStation do
          if ((MyCall = Qso.Call) or (Oper.IsMyCall(Qso.Call, False) = mcAlmost)) then
          begin
            Qso.TrueWpm := WpmAsText();
            Break;
          end;

    //what's in the DX's log?
    for i:=Tst.Stations.Count-1 downto 0 do
      if Tst.Stations[i] is TDxStation then
        with Tst.Stations[i] as TDxStation do
          if (Oper.State = osDone) and
             ((MyCall = Qso.Call) or (Oper.IsMyCall(Qso.Call, False) = mcAlmost)) then
            begin
              DataToLastQso; //grab "True" data and delete this dx station!
              Break;
            end;

    //QsoList[High(QsoList)].Err:= '...';
    CheckErr;
  end;

  LastQsoToScreen;
  if SimContest = scHst then
    UpdateStatsHst
  else
    UpdateStats({AVerifyResults=}False);

  //wipe
  MainForm.WipeBoxes;

  //inc NR
  if (Tst.Me.SentExchTypes.Exch1 in [etSSNrPrecedence]) or
     (Tst.Me.SentExchTypes.Exch2 in [etSerialNr]) then
    Inc(Tst.Me.NR);
end;


{
  Adds last Qso to log as displayed on the screen. The Error information
  is not yet complete, so the Err column is not rendered at this time.
  The error will be updated by DataToLastQso after the DxStation has been
  confirmed and removed by TContest.GetAudio().
}
procedure LastQsoToScreen;
begin
  with QsoList[High(QsoList)] do begin
    // Adding a contest: LastQsoToScreen, add last qso to Score Table
    case Ini.SimContest of
    scCwt:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scSst:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scFieldDay:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scNaQp:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Pfx
        , Err, format('%3s', [TrueWpm]));
    scWpx:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , format('%4d', [NR])
        , Err, format('%3s', [TrueWpm]));
    scHst:
      if ShowCorrections then
        ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
          , format('%.3d', [Rst])
          , format(IfThen(RunMode = rmHst, '%.4d', '%4d'), [NR])
          , Pfx   // Score string was written into prefix field
          , Err, format('%3s', [TrueWpm]))
      else
        ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
          , format('%.3d %.4d', [Rst, Nr])                // Sent
          , format('%.3d %.4d', [Tst.Me.Rst, Tst.Me.NR])  // Recv
          , Pfx                                           // Score
          , Err, format('%3s', [TrueWpm]));
    scCQWW:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , format('%.2d', [Exch2.ToInteger])
        , Err, format('%3s', [TrueWpm]));
    scArrlDx:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scAllJa:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scAcag:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scIaruHf:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , Err, format('%3s', [TrueWpm]));
    scArrlSS:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%4d', [NR])
        , Prec
        , format('%.2d', [Check])
        , Sect
        , Err, format('%3s', [TrueWpm]));
    else
      assert(false, 'missing case');
    end;
  end;
end;


procedure TQso.CheckExch1(var ACorrections: TStringList);
begin
  Exch1Error := leNONE;
  Exch1ExError := leNONE;

  // Adding a contest: check for contest-specific exchange field 1 errors
  case Mainform.RecvExchTypes.Exch1 of
    etRST:     if TrueRst   <> Rst   then Exch1Error := leRST;
    etOpName:  if TrueExch1 <> Exch1 then Exch1Error := leNAME;
    etFdClass: if TrueExch1 <> Exch1 then Exch1Error := leCLASS;
    etSSNrPrecedence: begin
      // For ARRL SS, exchange 1 tests the raw NR and Prec values
      if TrueNR <> NR then Exch1Error := leNR;
      if TruePrec <> Prec then Exch1ExError := lePrec;
    end
    else
      assert(false, 'missing exchange 1 case');
  end;

  case Exch1Error of
    leNONE: ;
    leRST: ACorrections.Add(Format('%d', [TrueRst]));
    leNR: ACorrections.Add(Format('%d', [TrueNR]));
    else
      ACorrections.Add(TrueExch1);
  end;
  case Exch1ExError of
    lePrec: ACorrections.Add(TruePrec);
  end;
end;


procedure TQso.CheckExch2(var ACorrections: TStringList);

  // Reduce Power characters (T, O, A, N) to (0, 0, 1, 9) respectively.
  function ReducePowerStr(const text: string): string;
  begin
    assert(Mainform.RecvExchTypes.Exch2 in [etPower, etCqZone]);
    Result := text.Replace('T', '0', [rfReplaceAll])
                  .Replace('O', '0', [rfReplaceAll])
                  .Replace('A', '1', [rfReplaceAll])
                  .Replace('N', '9', [rfReplaceAll]);
  end;

  // Reduce numeric characters (T, O, A, N) to (0, 0, 1, 9) respectively.
  function ReduceNumeric(const text: string): integer;
  begin
    Result := StrToIntDef(ReducePowerStr(text), 0);
  end;

  begin
  Exch2Error := leNONE;
  Exch2ExError := leNONE;

  // Adding a contest: check for contest-specific exchange field 2 errors
  case Mainform.RecvExchTypes.Exch2 of
    etSerialNr:    if TrueNr <> NR then Exch2Error := leNR;
    etGenericField:
      // Adding a contest: implement comparison for Generic Field type
      case Ini.SimContest of
        scCwt:
          if TrueExch2 <> Exch2 then
            if IsNum(TrueExch2) then
              Exch2Error := leNR
            else
              Exch2Error := leQTH;
        scSst:
          if TrueExch2 <> Exch2 then
            Exch2Error := leQTH;
        scIaruHf:
          // need to add ReduceNumeric...
          if TrueExch2 <> Exch2 then
            if IsNum(TrueExch2) then
              Exch2Error := leZN
            else
              Exch2Error := leSOC;
        else
          if TrueExch2 <> Exch2 then
            Exch2Error := leERR;
      end;
    etCqZone:
      // use ReducePowerStr to reduce (T, O, A, N) to (0, 0, 1, 9) respectively
      if ReduceNumeric(TrueExch2) <> ReduceNumeric(Exch2) then
        Exch2Error := leZN;
    etArrlSection: if TrueExch2 <> Exch2 then Exch2Error := leSEC;
    etStateProv:   if TrueExch2 <> Exch2 then Exch2Error := leST;
    etItuZone:     if TrueExch2 <> Exch2 then Exch2Error := leZN;
    //etAge:
    etPower: if ReducePowerStr(TrueExch2) <> ReducePowerStr(Exch2) then
               Exch2Error := lePWR;
    etJaPref: if TrueExch2 <> Exch2 then Exch2Error := leNR;
    etJaCity: if TrueExch2 <> Exch2 then Exch2Error := leNR;
    etNaQpExch2: if TrueExch2 <> Exch2 then Exch2Error := leST;
    etNaQpNonNaExch2:
      // Non-NA stations do not send a location (typically logged as DX)
      if not (TrueExch2.Equals(Exch2) or
              (Exch2.Equals('DX') and TrueExch2.IsEmpty)) then
        Exch2Error := leST;
    etSSCheckSection: begin
      if TrueCheck <> Check then Exch2Error := leCHK;
      if TrueSect <> Sect then Exch2ExError := leSEC;
    end
    else
      assert(false, 'missing exchange 2 case');
  end;

  case Exch2Error of
    leNONE: ;
    leNR:
      if (SimContest = scHst) and ShowHstCorrections and (RunMode = rmHst) then
      begin
        assert(Mainform.RecvExchTypes.Exch2 = etSerialNr);
        ACorrections.Add(format('%.4d', [TrueNR]));
      end
      else if (SimContest = scArrlSS) then
        ACorrections.Add(TrueSect)
      else
        ACorrections.Add(TrueExch2);
    leCHK:
        ACorrections.Add(format('%.02d', [TrueCheck]));
    else
      ACorrections.Add(TrueExch2);
  end;

  case Exch2ExError of
    leNONE: ;
    leSEC:
      begin
        assert(SimContest = scArrlSS);
        ACorrections.Add(TrueSect);
      end;
    else
      assert(false);
  end;
end;


procedure CheckErr;
const
  ErrorStrs: array[TLogError] of string = (
    '',     'NIL', 'DUP', 'CALL', 'RST',
    'NAME', 'CL',  'NR',  'SEC',  'QTH',
    'ZN',   'SOC', 'ST',  'PWR',  'ERR',
    'PREC', 'CHK');
var
  Corrections: TStringList;
begin
  Corrections := TStringList.Create;
  try
    with QsoList[High(QsoList)] do begin
      // form the legacy Err String (e.g. RST, NR, CL, SEC, etc)
      if TrueCall = '' then
        ExchError := leNIL
      else if TrueCall <> Call then
      begin
        ExchError := leCALL;
        Corrections.Add(TrueCall);
      end
      else if Dupe and not Log.ShowCorrections then
        ExchError := leDUP
      else
        ExchError := leNONE;

      // find exchange errors for the current Qso
      Tst.FindQsoErrors(QsoList[High(QsoList)], Corrections);

      // column errors are stored as individual bits in TQso.ColumnErrorFlags
      ColumnErrorFlags := 0;

      // NIL or DUP errors have priority over showing corrected exchange
      if ExchError in [leNIL, leDUP] then
      begin
        Err := ErrorStrs[ExchError];
        if ExchError <> leDUP then SetColumnErrorFlag(CorrectionColumnInx);
      end
      else if ShowCorrections then
      begin
        if Dupe then
          Corrections.Insert(0, ErrorStrs[leDUP]);
        Corrections.StrictDelimiter	:= True;
        Corrections.Delimiter := ',';
        Err := Corrections.DelimitedText.Replace(',', ' ');  // Join(' ');
        if ExchError  <> leNONE then SetColumnErrorFlag(CallColumnInx);
        if Exch1Error <> leNONE then SetColumnErrorFlag(Exch1ColumnInx);
        if Exch1ExError <> leNONE then SetColumnErrorFlag(Exch1ExColumnInx);
        if Exch2Error <> leNONE then SetColumnErrorFlag(Exch2ColumnInx);
        if Exch2ExError <> leNONE then SetColumnErrorFlag(Exch2ExColumnInx);
      end
      else
      begin
        if Exch1Error <> leNONE then
          Err := ErrorStrs[Exch1Error]
        else if Exch2Error <> leNONE then
          Err := ErrorStrs[Exch2Error]
        else if Exch1ExError <> leNONE then
          Err := ErrorStrs[Exch1ExError]
        else if Exch2ExError <> leNONE then
          Err := ErrorStrs[Exch2ExError]
        else
          Err := '';
        SetColumnErrorFlag(CorrectionColumnInx);
      end;

      if Err.IsEmpty then
        Err := '   ';
    end; // end with QsoList[High(QsoList)]

  finally
    Corrections.Free;
  end;
end;

{
procedure PaintHisto;
var
  Histo: array[0..47] of integer;
  i: integer;
  x, y, w: integer;
begin
  FillChar(Histo, SizeOf(Histo), 1);

  for i:=0 to High(QsoList) do begin
    x := Trunc(QsoList[i].T * 1440) div 5;  // How Many QSO in 5mins
    Inc(Histo[x]);
  end;

  with MainForm.PaintBox1, MainForm.PaintBox1.Canvas do begin
    w:= Trunc(ClientWidth / 48);
    Brush.Color := Color;
    FillRect(RECT(0,0, Width, Height));
    for i:=0 to High(Histo) do begin
      Brush.Color := clGreen;
      x := i * w;
      y := Height - 3 - Histo[i] * 2;
      FillRect(Rect(x, y, x+w-1, Height-2));
    end;
  end;
end;
}

procedure ShowRate;
var
  i, Cnt: integer;
  T, D: Single;
begin
  T := BlocksToSeconds(Tst.BlockNumber) / 86400;
  if T = 0 then Exit;
  D := Min(5/1440, T);

  Cnt := 0;
  for i:=High(QsoList) downto 0 do
    if QsoList[i].T > (T-D) then Inc(Cnt) else Break;

  MainForm.Panel7.Caption := Format('%d  qso/hr.', [Round(Cnt / D / 24)]);
end;


{$ifdef DEBUG}
procedure DebugLn(const AMsg: string) overload;
begin
  OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + AMsg));
end;


procedure DebugLn(const AFormat: string; const AArgs: array of const) overload;
begin
  OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + format(AFormat, AArgs)));
end;


procedure DebugLnEnter(const AMsg: string) overload;
begin
  OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + AMsg));
  Inc(Log.Indent, DEBUG_INDENT);
end;


procedure DebugLnEnter(const AFormat: string; const AArgs: array of const) overload;
begin
  OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + format(AFormat, AArgs)));
  Inc(Log.Indent, DEBUG_INDENT);
end;


procedure DebugLnExit(const AMsg: string) overload;
begin
  if AMsg <> '' then
    OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + AMsg));
  if (Log.Indent >= DEBUG_INDENT) then Dec(Log.Indent, DEBUG_INDENT);
end;


procedure DebugLnExit(const AFormat: string; const AArgs: array of const) overload;
begin
  if AFormat <> '' then
    OutputDebugString(PChar(StringOfChar(' ', Log.Indent) + format(AFormat, AArgs)));
  if (Log.Indent >= DEBUG_INDENT) then Dec(Log.Indent, DEBUG_INDENT);
end;
{$endif}


initialization
  RawMultList := TMultList.Create;
  VerifiedMultList := TMultList.Create;
  ScaleTableInitialized := False;
{$ifdef DEBUG}
  RunUnitTest := true;
{$endif}

finalization
  RawMultList.Free;
  VerifiedMultList.Free;

end.

