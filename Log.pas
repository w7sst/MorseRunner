//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Log;

interface

uses
  Windows, SysUtils, Classes, Graphics, RndFunc, Math, Controls,
  StdCtrls, ExtCtrls, ARRL, PerlRegEx, pcre;


procedure SaveQso;
procedure LastQsoToScreen;
procedure Clear;
procedure UpdateStats;
procedure UpdateStatsHst;
procedure CheckErr;
//procedure PaintHisto;
procedure ShowRate;
procedure ScoreTableSetTitle(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6 :string);
procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6 :string);
procedure ScoreTableUpdateCheck;
function FormatScore(const AScore: integer):string;
procedure UpdateSbar(const ACallsign: string);
function ExtractCallsign(Call: string): string;
function ExtractPrefix(Call: string): string;

type
  PQso = ^TQso;
  TQso = record
    T: TDateTime;
    Call, TrueCall, RawCallsign: string;
    Rst, TrueRst: integer;
    Nr, TrueNr: integer;
    Pfx: string;
    Dupe: boolean;
    Err: string;
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

const
  EM_SCROLLCARET = $B7;
  WM_VSCROLL= $0115;

var
  QsoList: array of TQso;
  PfxList: TStringList;
  CallSent, NrSent: boolean;
  Histo: THisto;


implementation

uses
  Contest, Main, DxStn, DxOper, Ini, MorseKey;


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

function FormatScore(const AScore: integer):string;
begin
  FormatScore:= format('%6d', [AScore]);
end;

procedure ScoreTableSetTitle(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6 :string);
begin
  MainForm.ListView2.Column[0].Caption:= ACol1;
  MainForm.ListView2.Column[1].Caption:= ACol2;
  MainForm.ListView2.Column[2].Caption:= ACol3;
  MainForm.ListView2.Column[3].Caption:= ACol4;
  MainForm.ListView2.Column[4].Caption:= ACol5;
  MainForm.ListView2.Column[5].Caption:= ACol6;
end;

procedure ScoreTableInsert(const ACol1, ACol2, ACol3, ACol4, ACol5, ACol6 :string);
begin
  with MainForm.ListView2.Items.Add do begin
    Caption:= ACol1;
    SubItems.Add(ACol2);
    SubItems.Add(ACol3);
    SubItems.Add(ACol4);
    SubItems.Add(ACol5);
    SubItems.Add(ACol6);
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
    s:= ARRLDX.Search(ACallsign);
    if (length(s) > 0) then
        MainForm.sbar.Caption:= '  ' + s
    else
        MainForm.sbar.Caption:= '  Unknow';
end;


procedure ScoreTableUpdateCheck;
begin
  with MainForm.ListView2 do begin
    Items[Items.Count-1].SubItems[4]:= QsoList[High(QsoList)].Err;
  end;
end;

procedure Clear;
var
  Empty: string;
begin
  QsoList := nil;
  Tst.Stations.Clear;
  MainForm.RichEdit1.Lines.Clear;
  MainForm.RichEdit1.DefAttributes.Name:= 'Consolas';
  if Ini.RunMode = rmHst then
    ScoreTableSetTitle('UTC', 'Call', 'Recv', 'Sent', 'Score', 'Chk')
  else
    ScoreTableSetTitle('UTC', 'Call', 'Recv', 'Sent', 'Pref', 'Chk');

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

  //MainForm.Panel11.Caption := IntToStr(Score);
end;

procedure UpdateStats;
var
  i, Pts, Mul: integer;
begin
  //raw

  Pts := Length(QsoList);
  PfxList.Clear;
  for i:=0 to High(QsoList) do
     PfxList.Add(QsoList[i].Pfx);
  Mul := PfxList.Count;

  MainForm.ListView1.Items[0].SubItems[0] := FormatScore(Pts);
  MainForm.ListView1.Items[1].SubItems[0] := FormatScore(Mul);
  MainForm.ListView1.Items[2].SubItems[0] := FormatScore(Pts*Mul);

  //verified
  Pts := 0;
  PfxList.Clear;
  for i:=0 to High(QsoList) do
    if QsoList[i].Err = '   ' then begin
      Inc(Pts);
      PfxList.Add(QsoList[i].Pfx);
    end;
  Mul := PfxList.Count;

  MainForm.ListView1.Items[0].SubItems[1] := FormatScore(Pts);
  MainForm.ListView1.Items[1].SubItems[1] := FormatScore(Mul);
  MainForm.ListView1.Items[2].SubItems[1] := FormatScore(Pts*Mul);

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

function ExtractPrefix(Call: string): string;
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
{
function ExtractPrefix(Call: string): string;
const
  DIGITS = ['0'..'9'];
  LETTERS = ['A'..'Z'];
var
  p: integer;
  S1, S2, Dig: string;
begin
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
}

procedure SaveQso;
var
  i: integer;
  Qso: PQso;
begin
  with MainForm do begin
    if (Length(Edit1.Text) < 3) or (Length(Edit2.Text) <> 3) or (Edit3.Text = '') then begin
      Beep;
      Exit;
    end;

    //add new entry to log
    SetLength(QsoList, Length(QsoList)+1);
    Qso := @QsoList[High(QsoList)];

    //save data
    Qso.T := BlocksToSeconds(Tst.BlockNumber) /  86400;
    Qso.Call := StringReplace(Edit1.Text, '?', '', [rfReplaceAll]);
    Qso.Rst := StrToInt(Edit2.Text);
    Qso.Nr := StrToInt(Edit3.Text);
    Qso.RawCallsign:= ExtractCallsign(Qso.Call);
    Qso.Pfx := ExtractPrefix(Qso.RawCallsign);
    {if PfxList.Find(Qso.Pfx, Idx) then Qso.Pfx := '' else }
    PfxList.Add(Qso.Pfx);
    if Ini.RunMode = rmHst then
      Qso.Pfx := IntToStr(CallToScore(Qso.Call));

    //mark if dupe
    Qso.Dupe := false;
    for i:=0 to High(QsoList)-1 do
      with QsoList[i] do
        if (Call = Qso.Call) and (Err = '   ') then
          Qso.Dupe := true;

    //what's in the DX's log?
    for i:=Tst.Stations.Count-1 downto 0 do
      if Tst.Stations[i] is TDxStation then
        with Tst.Stations[i] as TDxStation do
          if (Oper.State = osDone) and (MyCall = Qso.Call) then begin
            DataToLastQso;
            Break;
          end; //deletes the dx station!
    //QsoList[High(QsoList)].Err:= '...';
    CheckErr;
  end;

  LastQsoToScreen;
  if Ini.RunMode = rmHst then
    UpdateStatsHst
  else
    UpdateStats;

  //wipe
  MainForm.WipeBoxes;
  //inc NR
  Inc(Tst.Me.NR);
end;


procedure LastQsoToScreen;
begin
  with QsoList[High(QsoList)] do begin
    ScoreTableInsert(FormatDateTime('hh:nn:ss', t), Call
      , format('%.3d %.4d', [Rst, Nr])
      , format('%.3d %.4d', [Tst.Me.Rst, Tst.Me.NR])
      , Pfx, Err);
  end;
end;


procedure CheckErr;
begin
  with QsoList[High(QsoList)] do begin
    if TrueCall = '' then
      Err := 'NIL'
    else
      if Dupe then
        Err := 'DUP'
      else
        if TrueRst <> Rst then
          Err := 'RST'
        else
          if TrueNr <> NR then
            Err := 'NR '
          else
            Err := '   ';
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
  PfxList := TStringList.Create;
  PfxList.Sorted := true;
  PfxList.Duplicates := dupIgnore;

finalization
  PfxList.Free;

end.

