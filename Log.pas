//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Log;

interface

uses
  Graphics,     // for TColor
  Classes, Controls, ExtCtrls;

procedure SaveQso;
procedure LastQsoToScreen;
procedure Clear;
procedure UpdateStats(AVerifyResults : boolean);
procedure UpdateStatsHst;
procedure CheckErr;
//procedure PaintHisto;
procedure ShowRate;
procedure ScoreTableSetTitle(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6, ACol7 :string);
procedure ScoreTableScaleWidth(const ACol : integer; const AScaleWidth : Single);
procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6, ACol7 :string);
procedure ScoreTableUpdateCheck;
function FormatScore(const AScore: integer):string;
procedure UpdateSbar(const ACallsign: string);
function ExtractCallsign(Call: string): string;
function ExtractPrefix(Call: string; DeleteTrailingLetters: boolean = True): string;
{$ifdef DEBUG}
function ExtractPrefix0(Call: string): string;
{$endif}

type
  TLogError = (leNONE, leNIL,   leDUP, leCALL, leRST,
               leNAME, leCLASS, leNR,  leSEC,  leQTH,
               leZN,   leSOC,   leST,  lePWR,  leERR);

  PQso = ^TQso;
  TQso = record
    T: TDateTime;
    Call, TrueCall, RawCallsign: string;
    Rst, TrueRst: integer;
    Nr, TrueNr: integer;
    Exch1, TrueExch1: string;   // exchange 1 (e.g. 3A, OpName)
    Exch2, TrueExch2: string;   // exchange 2 (e.g. OR, CWOPSNum)
    TrueWpm: string;            // WPM of sending DxStn (reported in log)
    Pfx: string;                // extracted call prefix
    MultStr: string;            // contest-specific multiplier (e.g. Pfx, dxcc)
    Points: integer;            // points for this QSO
    Dupe: boolean;              // this qso is a DUP.
    ExchError: TLogError;       // Callsign error code
    Exch1Error: TLogError;      // Exchange 1 qso error code
    Exch2Error: TLogError;      // Exchange 2 qso error code
    Err: string;                // Qso error string (e.g. corrections)
    CallColumnColor: TColor;    // Callsign field color (clBlack or clRed)
    Exch1ColumnColor: TColor;   // Exchange 1 field color (clBlack or clRed)
    Exch2ColumnColor: TColor;   // Exchange 2 field color (clBlack or clRed)
    CorrectionsColumnColor: TColor; // Corrections field color (clBlack or clRed)

    procedure CheckExch1(var ACorrections: TStringList);
    procedure CheckExch2(var ACorrections: TStringList);
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
  NrSent: boolean;   // msgNR has been sent. Seems to imply exchange sent.
  ShowCorrections: boolean;    // show exchange correction column.
  Histo: THisto;
  LogColWidths : Array[0..6] of integer;  // retain original Log column widths
  LogColWidthInitialized : boolean;       // initialize LogColWidths on time only
{$ifdef DEBUG}
  RunUnitTest : boolean;  // run ExtractPrefix unit tests once
{$endif}


implementation

uses
  Windows, SysUtils, RndFunc, Math,
  StdCtrls, PerlRegEx, pcre, StrUtils,
  Contest, Main, DxStn, DxOper, Ini, Station, MorseKey;


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

procedure ScoreTableSetTitle(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6, ACol7 :string);
var
  I: Integer;

  // adjust column with for empty table title strings
  procedure SetCaption(const I : integer; const ACaption : string);
  begin
    MainForm.ListView2.Column[I].Width:= IfThen(ACaption.IsEmpty, 0, LogColWidths[I]);
    MainForm.ListView2.Column[I].Caption:= ACaption;
  end;

begin
  // retain initial log column widths (used to restore column widths)
  if not LogColWidthInitialized then
    begin
      for I := Low(LogColWidths) to High(LogColWidths) do
        LogColWidths[I]:= MainForm.ListView2.Column[I].Width;
      LogColWidthInitialized:= true;
    end;

  SetCaption(0, ACol1);
  SetCaption(1, ACol2);
  SetCaption(2, ACol3);
  SetCaption(3, ACol4);
  SetCaption(4, ACol5);
  SetCaption(5, ACol6);
  SetCaption(6, ACol7);
end;

{
  Adjust the Log Table column width by AScaleWidth scaling factor.
  This scaling number is multiplied by the original column width from the UI.
  Typical usage is to increase the width of a column for a given contest.
  For example, the SST contest will increase the column width from 3 to 5
  characters by using 'ScoreTableScaleWidth(6, 5.0/3)' or to increase width
  by 40% use 'ScoreTableScaleWidth(6, 1.4)'.
  This method can also be used to set the column width to zero if desired.
  Note that whenever a new contest is started, the column widths are restored
  to their original column widths.
}
procedure ScoreTableScaleWidth(const ACol : integer; const AScaleWidth : Single);
begin
  assert(LogColWidthInitialized, 'must be called after ScoreTableSetTitle');
  MainForm.ListView2.Column[ACol].Width:= Ceil(AScaleWidth * LogColWidths[ACol]);
end;

procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6, ACol7 :string);
begin
  with MainForm.ListView2.Items.Add do begin
    Caption:= ACol1;
    SubItems.Add(ACol2);
    SubItems.Add(ACol3);
    SubItems.Add(ACol4);
    SubItems.Add(ACol5);
    SubItems.Add(ACol6);
    SubItems.Add(ACol7);
    Selected:= True;
  end;
  //UpdateSbar(MainForm.ListView2.Items.Count);
  MainForm.ListView2.Perform(WM_VSCROLL, SB_BOTTOM, 0);
end;

//Update Callsign info
procedure UpdateSbar(const ACallsign: string);
var
  s: string;
begin
  s:= '';
  if not ACallsign.IsEmpty then
  begin
    // Adding a contest: UpdateSbar - update status bar with station info (e.g. FD shows UserText)
    s := Tst.GetStationInfo(ACallsign);

    // '&' are suppressed in this control; replace with '&&'
    s:= StringReplace(s, '&', '&&', [rfReplaceAll]);
  end;

  // during debug, use status bar to show CW stream
  if not s.IsEmpty and (BDebugCwDecoder or BDebugGhosting) then
    Mainform.sbar.Caption:= LeftStr(Mainform.sbar.Caption, 40) + ' -- ' + s
  else
    MainForm.sbar.Caption:= '  ' + s;
end;


procedure ScoreTableUpdateCheck;
begin
  // https://stackoverflow.com/questions/34239493/how-to-color-specific-list-view-item-in-delphi
  with MainForm.ListView2 do begin
    Items[Items.Count-1].SubItems[4] := QsoList[High(QsoList)].Err;
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

  ShowCorrections := SimContest in [scWpx, scCwt, scSst, scNaQp, scCQWW, scFieldDay, scArrlDx, scAllJa, scAcag, scIaruHF];

  Tst.Stations.Clear;
  MainForm.RichEdit1.Lines.Clear;
  MainForm.RichEdit1.DefAttributes.Name:= 'Consolas';

  if Ini.RunMode = rmHst then
    ScoreTableSetTitle('UTC', 'Call', 'Recv', 'Sent', 'Score', 'Chk', 'Wpm')
  else begin
    // Adding a contest: set Score Table titles
    case Ini.SimContest of
      scCwt:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'Name', 'Exch', '', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(3, 0.75);  // shrink Exch2 (NR or QTH) column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end;
      scSst:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'Name', 'Exch', '', 'Corrections', ' Wpm');
        ScoreTableScaleWidth(3, 0.75);  // shrink Exch column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        ScoreTableScaleWidth(6, 1.4);   // expand Wpm column for 22/25 Farnsworth
        end;
      scFieldDay:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'Class', 'Sect', '', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.75);  // shrink Class column
        ScoreTableScaleWidth(3, 0.75);  // shrink Section column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end;
      scNaQp:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'Name', 'State', 'Pref', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(1, 0.8);   // shrink Call column
        ScoreTableScaleWidth(3, 0.6);   // shrink State/Prov column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end;
      scCQWW:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'CQ-Zone', 'Pref', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.50);  // shrink RST column
        ScoreTableScaleWidth(3, 0.80);  // CQ-Zone column
        ScoreTableScaleWidth(4, 0.00);  // shrink Pref column
        ScoreTableScaleWidth(5, 2.50);  // expand Corrections column
        end;
      scArrlDx:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'Exch', '', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.50);  // shrink RST column
        ScoreTableScaleWidth(3, 0.75);  // Exch2 (<pref><power>) column
        ScoreTableScaleWidth(5, 2.50);  // expand Corrections column
        end;
      scAllJa:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'Exch', '', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.5);  // shrink RST column
        ScoreTableScaleWidth(3, 0.75);  // Exch2 (<pref><power>) column
        ScoreTableScaleWidth(5, 2.50);  // expand Corrections column
        end;
      scAcag:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'Exch', '', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.5);   // shrink RST column
        ScoreTableScaleWidth(3, 1.0);   // Exch2 (city/gun/ku) column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end;
      scIaruHf:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'Exch', 'Mult', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.5);   // shrink RST column
        ScoreTableScaleWidth(3, 0.75);  // shrink Exch2 column
        ScoreTableScaleWidth(4, 0.00);  // shrink Mult column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end;
      scWpx:
        begin
        ScoreTableSetTitle('UTC', 'Call', 'RST', 'Exch', 'Pref', 'Corrections', 'Wpm');
        ScoreTableScaleWidth(2, 0.5);   // shrink RST column
        ScoreTableScaleWidth(3, 0.75);  // shrink NR column
        ScoreTableScaleWidth(4, 0.00);  // hide Pref column
        ScoreTableScaleWidth(5, 2.5);   // expand Corrections column
        end
      else
        ScoreTableSetTitle('UTC', 'Call', 'Recv', 'Sent', 'Pref', 'Chk', 'Wpm');
    end;
  end;

  if Ini.RunMode = rmHst then
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


procedure SaveQso;
var
  i: integer;
  Qso: PQso;

  // Adding a contest: validate contest-specific exchange fields
  //validate Exchange 1 (Edit2) field lengths
  function ValidateExchField1(const text: string): Boolean;
  begin
    Result := false;
    case Mainform.RecvExchTypes.Exch1 of
      etRST:     Result := Length(text) = 3;
      etOpName:  Result := Length(text) > 1;
      etFdClass: Result := Length(text) > 1;
      else
        assert(false, 'missing case');
    end;
  end;

  //validate Exchange 2 (Edit3) field lengths
  function ValidateExchField2(const text: string): Boolean;
  begin
    Result := false;
    case Mainform.RecvExchTypes.Exch2 of
      etSerialNr:    Result := Length(text) > 0;
      etGenericField:Result := Length(text) > 0;
      etArrlSection: Result := Length(text) > 1;
      etStateProv:   Result := Length(text) > 1;
      etCqZone:      Result := Length(text) > 0;
      etItuZone:     Result := Length(text) > 0;
      //etAge:
      etPower:       Result := Length(text) > 0;
      etJaPref:      Result := Length(text) > 2;
      etJaCity:      Result := Length(text) > 3;
      etNaQpExch2:   Result := Length(text) > 0;
      etNaQpNonNaExch2: Result := Length(text) >= 0;
      else
        assert(false, 'missing case');
    end;
  end;

begin
  with MainForm do
    begin
    if (Length(Edit1.Text) < 3) or
      not ValidateExchField1(Edit2.Text) or
      not ValidateExchField2(Edit3.Text) then
      begin
        {Beep;}
        Exit;
      end;

    //add new entry to log
    SetLength(QsoList, Length(QsoList)+1);
    Qso := @QsoList[High(QsoList)];

    //save data
    Qso.T := BlocksToSeconds(Tst.BlockNumber) /  86400;
    Qso.Call := StringReplace(Edit1.Text, '?', '', [rfReplaceAll]);

    // Adding a contest: save contest-specific exchange values into QsoList
    //save Exchange 1 (Edit2)
    case Mainform.RecvExchTypes.Exch1 of
      etRST:     Qso.Rst := StrToInt(Edit2.Text);
      etOpName:  Qso.Exch1 := Edit2.Text;
      etFdClass: Qso.Exch1 := Edit2.Text;
      else
        assert(false, 'missing case');
    end;

    //save Exchange2 (Edit3)
    case Mainform.RecvExchTypes.Exch2 of
      etSerialNr:    Qso.Nr := StrToInt(Edit3.Text);
      etGenericField:Qso.Exch2 := Edit3.Text;
      etArrlSection: Qso.Exch2 := Edit3.Text;
      etStateProv:   Qso.Exch2 := Edit3.Text;
      etCqZone:      Qso.NR := StrToInt(Edit3.Text);
      etItuZone:     Qso.Exch2 := Edit3.Text;
      //etAge:
      etPower:       Qso.Exch2 := Edit3.Text;
      etJaPref:      Qso.Exch2 := Edit3.Text;
      etJaCity:      Qso.Exch2 := Edit3.Text;
      etNaQpExch2:   Qso.Exch2 := Edit3.Text;
      etNaQpNonNaExch2:
        if Edit3.Text = '' then
          Qso.Exch2 := 'DX'
        else
          Qso.Exch2 := Edit3.Text;
      else
        assert(false, 'missing case');
    end;

    Qso.Points := 1;  // defaults to 1; override in ExtractMultiplier()
    Qso.RawCallsign:= ExtractCallsign(Qso.Call);
    // Use full call when extracting prefix, not user's call.
    Qso.Pfx := ExtractPrefix(Qso.Call);
    // extract ';'-delimited multiplier string(s) and update Qso.Points.
    Qso.MultStr := Tst.ExtractMultiplier(Qso);
    if Ini.RunMode = rmHst then
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
          if (MyCall = Qso.Call) then
          begin
            Qso.TrueWpm := WpmAsText();
            Break;
          end;

    //what's in the DX's log?
    for i:=Tst.Stations.Count-1 downto 0 do
      if Tst.Stations[i] is TDxStation then
        with Tst.Stations[i] as TDxStation do
          if (Oper.State = osDone) and (MyCall = Qso.Call) then
            begin
              DataToLastQso; //grab "True" data and delete this dx station!
              Break;
            end;

    //QsoList[High(QsoList)].Err:= '...';
    CheckErr;
  end;

  LastQsoToScreen;
  if Ini.RunMode = rmHst then
    UpdateStatsHst
  else
    UpdateStats({AVerifyResults=}False);

  //wipe
  MainForm.WipeBoxes;

  //inc NR
  if Tst.Me.SentExchTypes.Exch2 = etSerialNr then
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
        , '', Err, format('%3s', [TrueWpm]));
    scSst:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , '', Err, format('%5s', [TrueWpm]));
    scFieldDay:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Pfx, Err, format('%3s', [TrueWpm]));
    scNaQp:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , Exch1
        , Exch2
        , Pfx, Err, format('%3s', [TrueWpm]));
    scWpx:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , format('%4d', [NR])
        , Pfx, Err, format('%3s', [TrueWpm]));
    scHst:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d %.4d', [Rst, Nr])
        , format('%.3d %.4d', [Tst.Me.Rst, Tst.Me.NR])
        , Pfx, Err, format('%3s', [TrueWpm]));
    scCQWW:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , format('%4d', [NR])
        , Pfx, Err, format('%3s', [TrueWpm]));
    scArrlDx:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , '', Err, format('%3s', [TrueWpm]));
    scAllJa:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , '', Err, format('%3s', [TrueWpm]));
    scAcag:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , '', Err, format('%3s', [TrueWpm]));
    scIaruHf:
      ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
        , format('%.3d', [Rst])
        , Exch2
        , MultStr, Err, format('%3s', [TrueWpm]));
    else
      assert(false, 'missing case');
    end;
  end;
end;


procedure TQso.CheckExch1(var ACorrections: TStringList);
begin
  Exch1Error := leNONE;

  // Adding a contest: check for contest-specific exchange field 1 errors
  case Mainform.RecvExchTypes.Exch1 of
    etRST:     if TrueRst   <> Rst   then Exch1Error := leRST;
    etOpName:  if TrueExch1 <> Exch1 then Exch1Error := leNAME;
    etFdClass: if TrueExch1 <> Exch1 then Exch1Error := leCLASS;
    else
      assert(false, 'missing exchange 1 case');
  end;

  case Exch1Error of
    leNONE: ;
    leRST: ACorrections.Add(Format('%d', [TrueRst]));
    else
      ACorrections.Add(TrueExch1);
  end;
end;


procedure TQso.CheckExch2(var ACorrections: TStringList);

  // Reduce Power characters (T, O, A, N) to (0, 0, 1, 9) respectively.
  function ReducePowerStr(const text: string): string;
  begin
    assert(Mainform.RecvExchTypes.Exch2 = etPower);
    Result := text.Replace('T', '0', [rfReplaceAll])
                  .Replace('O', '0', [rfReplaceAll])
                  .Replace('A', '1', [rfReplaceAll])
                  .Replace('N', '9', [rfReplaceAll]);
  end;

begin
  Exch2Error := leNONE;

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
    etCqZone:      if TrueNr    <> NR    then Exch2Error := leZN;
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
    else
      assert(false, 'missing exchange 2 case');
  end;

  case Exch2Error of
    leNONE: ;
    leNR: ACorrections.Add(TrueExch2);
    else
      ACorrections.Add(TrueExch2);
  end;
end;


procedure CheckErr;
const
  ErrorStrs: array[TLogError] of string = (
    '',     'NIL', 'DUP', 'CALL', 'RST',
    'NAME', 'CL',  'NR',  'SEC',  'QTH',
    'ZN',   'SOC', 'ST',  'PWR',  'ERR');
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
      begin
        ExchError := leNONE;

        // find exchange errors for the current Qso
        Tst.FindQsoErrors(QsoList[High(QsoList)], Corrections);
      end;

      CallColumnColor := clBlack;
      Exch1ColumnColor := clBlack;
      Exch2ColumnColor := clBlack;
      CorrectionsColumnColor := clBlack;

      // NIL or DUP errors have priority over showing corrected exchange
      if ExchError in [leNIL, leDUP] then
      begin
        Err := ErrorStrs[ExchError];
        if ExchError <> leDUP then CorrectionsColumnColor := clRed;
      end
      else if ShowCorrections then
      begin
        if Dupe then
          Corrections.Insert(0, ErrorStrs[leDUP]);
        Corrections.Delimiter := ' ';
        Err := Corrections.DelimitedText;  // Join(' ');
        if ExchError  <> leNONE then CallColumnColor := clRed;
        if Exch1Error <> leNONE then Exch1ColumnColor := clRed;
        if Exch2Error <> leNONE then Exch2ColumnColor := clRed;
      end
      else
      begin
        if Exch1Error <> leNONE then
          Err := ErrorStrs[Exch1Error]
        else if Exch2Error <> leNONE then
          Err := ErrorStrs[Exch2Error]
        else
          Err := '';
        CorrectionsColumnColor := clRed;
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


initialization
  RawMultList := TMultList.Create;
  VerifiedMultList := TMultList.Create;
{$ifdef DEBUG}
  RunUnitTest := true;
{$endif}

finalization
  RawMultList.Free;
  VerifiedMultList.Free;

end.

