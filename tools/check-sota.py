#!/usr/bin/env python3
"""Smoke-test the SOTA activity end to end without a human at the GUI.

Builds a throwaway program from MorseRunner.lpr that creates the real
TMainForm, switches it to SOTA, loads the call history, keys the exchange the
way TStation would, and logs QSOs. It checks the things that are easy to get
wrong here: the summit reference handed to a caller must belong to that
caller's own country, reports must be realistic (339 or 5x9), roughly a tenth
of callers must be summit-to-summit, my own report must vary per caller but
not mid-QSO, F6 must key my reference, and the REF? / AGN? / TU 73 exchange
must always terminate.

Needs a running X/Wayland display (it realises real widgets).

Usage: tools/check-sota.py [<repo-root>]
"""

import os
import subprocess
import sys

PROBE_BODY = '''
var
  Failures: integer = 0;

procedure Check(const AName: string; ACondition: boolean; const AGot: string);
begin
  if ACondition then
    WriteLn('  ok    ', AName, '  [', AGot, ']')
  else
    begin
    Inc(Failures);
    WriteLn('  FAIL  ', AName, '  [', AGot, ']');
    end;
end;

function CountOcc(const ANeedle, AHay: string): integer;
var
  p: integer;
begin
  Result := 0;
  p := Pos(ANeedle, AHay);
  while p > 0 do
    begin
    Inc(Result);
    p := PosEx(ANeedle, AHay, p + Length(ANeedle));
    end;
end;

var
  i, id, S2S, Weak, Mismatch, RstBad, nRef: integer;
  Stn: TDxStation;
  Sota: TSota;
  Row, Ref, Assoc, Msg: string;
  T0: TDateTime;
  RstSeen: TStringList;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;
  Application.ProcessMessages;

  WriteLn('--- contest selection');
  Check('SOTA is listed in the contest combo',
        MainForm.SimContestCombo.Items.IndexOf('SOTA Activation') >= 0,
        IntToStr(MainForm.SimContestCombo.Items.IndexOf('SOTA Activation')));
  MainForm.SetContest(scSota);
  Application.ProcessMessages;
  Check('contest object is TSota', Tst is TSota, Tst.ClassName);
  Sota := Tst as TSota;

  WriteLn('--- exchange fields');
  Check('Exch1 type is etRST',
        MainForm.RecvExchTypes.Exch1 = etRST, ToStr(MainForm.RecvExchTypes.Exch1));
  Check('Exch2 type is etSotaRef',
        MainForm.RecvExchTypes.Exch2 = etSotaRef, ToStr(MainForm.RecvExchTypes.Exch2));
  Check('RST field shown', MainForm.Edit2.Showing, BoolToStr(MainForm.Edit2.Showing, True));
  Check('Ref field shown', MainForm.Edit3.Showing, BoolToStr(MainForm.Edit3.Showing, True));
  Check('Ref field holds 10 characters',
        MainForm.Edit3.MaxLength >= 10, IntToStr(MainForm.Edit3.MaxLength));
  Check('Exchange box is editable',
        MainForm.ExchangeEdit.Enabled, BoolToStr(MainForm.ExchangeEdit.Enabled, True));

  WriteLn('--- my own summit reference (setup)');
  Check('a valid reference is accepted',
        MainForm.SetMyExchange('G/LD-001'), Tst.Me.Exch2);
  Check('stored as my Exch2', Tst.Me.Exch2 = 'G/LD-001', Tst.Me.Exch2);
  Check('an empty reference is accepted (not on a summit)',
        MainForm.SetMyExchange(''), '"' + Tst.Me.Exch2 + '"');
  Check('a malformed reference is rejected',
        not MainForm.SetMyExchange('NOTAREF'), 'NOTAREF');
  // separators are the easy thing to get wrong, so they are optional
  Check('PA-PA003 is read as PA/PA-003',
        Sota.NormaliseRef('PA-PA003') = 'PA/PA-003', Sota.NormaliseRef('PA-PA003'));
  Check('PA/PA003 is read as PA/PA-003',
        Sota.NormaliseRef('PA/PA003') = 'PA/PA-003', Sota.NormaliseRef('PA/PA003'));
  Check('lower case is accepted',
        Sota.NormaliseRef('pa pa 003') = 'PA/PA-003', Sota.NormaliseRef('pa pa 003'));
  Check('a 3-character association survives',
        Sota.NormaliseRef('W7O/CN-123') = 'W7O/CN-123', Sota.NormaliseRef('W7O/CN-123'));
  Check('nonsense is still rejected', Sota.NormaliseRef('NOTAREF') = '',
        '"' + Sota.NormaliseRef('NOTAREF') + '"');
  Check('a sloppy entry is corrected in the box',
        MainForm.SetMyExchange('PA-PA003') and (Tst.Me.Exch2 = 'PA/PA-003'),
        MainForm.ExchangeEdit.Text);
  MainForm.SetMyExchange('G/LD-001');

  WriteLn('--- data files');
  T0 := Now;
  Check('call history and summits load',
        Tst.OnContestPrepareToStart(Ini.Call, ''), 'SOTA_Calls_CW.txt + summitslist.txt');
  WriteLn(Format('  load took %.2f s', [(Now-T0)*86400]));

  WriteLn('--- where a callsign says the operator is (cty.dat)');
  Check('LX/AB1DE/P is in LX', Sota.LocationPart('LX/AB1DE/P') = 'LX',
        Sota.LocationPart('LX/AB1DE/P'));
  Check('DL1GG/P is at home in DL', Sota.LocationPart('DL1GG/P') = 'DL1GG',
        Sota.LocationPart('DL1GG/P'));
  Check('the /M of 2W0ILQ/M is not England',
        Sota.LocationPart('2W0ILQ/M') = '2W0ILQ', Sota.LocationPart('2W0ILQ/M'));
  Check('DL1GG is not portable', not Sota.IsPortable('DL1GG'), 'DL1GG');
  Check('DL1GG/P is portable', Sota.IsPortable('DL1GG/P'), 'DL1GG/P');

  WriteLn('--- summit references match where the caller is operating');
  Mismatch := 0; nRef := 0; Row := '';
  for i := 0 to 999 do
    begin
    id := Tst.PickStation;
    Msg := Tst.GetCall(id);
    if not Sota.IsPortable(Msg) then Continue;
    Ref := Sota.PickSummitFor(Msg);
    if Ref = '' then Continue;
    Inc(nRef);
    // the summit's association must resolve to the caller's own country
    Assoc := Copy(Ref, 1, Pos('/', Ref)-1);
    if Sota.EntityOfPublic(Assoc) <> Sota.EntityOfPublic(Msg) then
      begin
      Inc(Mismatch);
      if Mismatch <= 5 then
        WriteLn('    mismatch: ', Msg, ' (', Sota.EntityOfPublic(Msg), ') -> ',
                Ref, ' (', Sota.EntityOfPublic(Assoc), ')');
      end;
    if nRef <= 6 then Row := Row + Msg + '=' + Ref + '  ';
    end;
  WriteLn('  samples: ', Row);
  Check('every reference is in the caller''s own country', Mismatch = 0,
        Format('%d of %d matched', [nRef-Mismatch, nRef]));
  Check('most portable callers can be given a summit', nRef > 180,
        IntToStr(nRef) + ' of ~250 portable in 1000');

  WriteLn('--- callers');
  S2S := 0; Weak := 0; RstBad := 0;
  RstSeen := TStringList.Create;
  RstSeen.Sorted := True; RstSeen.Duplicates := dupIgnore;
  for i := 0 to 1999 do
    begin
    Stn := TDxStation.CreateStation;
    try
      RstSeen.Add(IntToStr(Stn.RST));
      // report is 339, or 5x9 with only the readability digit moving
      if Stn.RST = 339 then Inc(Weak)
      else if (Stn.RST mod 10 <> 9) or (Stn.RST div 100 <> 5) or
              (Stn.RST < 539) or (Stn.RST > 599) then Inc(RstBad);
      if (Stn.Exch2 <> '') and not Sota.IsPortable(Stn.MyCall) then
        begin
        Inc(RstBad);
        WriteLn('  FAIL non-portable caller on a summit: ', Stn.MyCall);
        end;
      if Stn.Exch2 <> '' then
        begin
        Inc(S2S);
        // an S2S caller keys its reference twice after the report
        Stn.MsgText := '';
        Tst.SendMsg(Stn, msgNR);
        if S2S = 1 then WriteLn('  an S2S caller keys: ', Stn.MsgText);
        if Pos(Stn.Exch2, Stn.MsgText) = 0 then
          begin Inc(RstBad); WriteLn('  FAIL no ref in: ', Stn.MsgText); end;
        // a repeated exchange must still key the ref twice, not four times
        Stn.MsgText := '';
        Tst.SendMsg(Stn, msgR_NR2);
        if S2S = 1 then WriteLn('  the same caller repeating: ', Stn.MsgText);
        if CountOcc(Stn.Exch2, Stn.MsgText) <> 2 then
          begin Inc(RstBad); WriteLn('  FAIL ref not twice in: ', Stn.MsgText); end;
        end;
    finally
      Stn.Free;
    end;
    end;
  Check('reports are 339 or 5x9 only', RstBad = 0, RstSeen.CommaText);
  Check('roughly 1 caller in 10 is on a summit',
        (S2S > 120) and (S2S < 280), Format('%d of 2000', [S2S]));
  Check('some callers report me as weak (339)',
        (Weak > 150) and (Weak < 450), Format('%d of 2000', [Weak]));
  RstSeen.Free;

  WriteLn('--- what I key');
  Stn := TDxStation.CreateStation;
  Tst.Me.HisCall := Stn.MyCall;
  // AbortSend between sends: TMyStation queues pieces while it is already
  // sending, so MsgText would otherwise only be set by the first message
  Tst.Me.AbortSend;
  Tst.SendMsg(Tst.Me, msgNR);
  Msg := Tst.Me.MsgText;
  WriteLn('  my report to ', Stn.MyCall, ': ', Msg);
  Check('my report is a real report, not a fixed 5NN',
        (Msg = '33N') or ((Length(Msg) = 3) and (Msg[1] = '5')), Msg);
  Tst.Me.AbortSend;
  Tst.SendMsg(Tst.Me, msgNR);
  Check('my report does not change mid-QSO', Tst.Me.MsgText = Msg, Tst.Me.MsgText);
  Tst.Me.AbortSend;
  Tst.SendMsg(Tst.Me, msgSotaRef);
  Check('F6 keys REF + my own reference twice',
        Tst.Me.MsgText = 'REF G/LD-001 G/LD-001', Tst.Me.MsgText);
  Tst.Me.AbortSend;
  Tst.SendMsg(Tst.Me, msgRefQm);
  Check('F8 keys a bare REF?', Tst.Me.MsgText = 'REF?', Tst.Me.MsgText);
  // and a different caller gets its own report
  Tst.Me.HisCall := 'ZZ9ZZ';
  Tst.Me.AbortSend;
  Tst.SendMsg(Tst.Me, msgNR);
  WriteLn('  my report to a different caller: ', Tst.Me.MsgText);
  Stn.Free;

  WriteLn('--- the REF? sub-protocol');
  Stn := TDxStation.CreateStation;
  Stn.Oper.State := osNeedMyRef;
  Stn.Oper.Patience := 5;
  Stn.MsgText := '';
  Tst.SendMsg(Stn, Stn.Oper.GetReply);
  WriteLn('  caller asks: ', Stn.MsgText);
  Check('the ask carries the exchange and REF?',
        Pos('REF?', Stn.MsgText) > 0, Stn.MsgText);
  // answering it must end in either TU 73 or AGN?, never a hang
  Row := '';
  for i := 0 to 199 do
    begin
    Stn.Oper.State := osNeedMyRef;
    Stn.Oper.PendingReply := msgNone;
    Stn.Oper.MsgReceived([msgSotaRef]);
    Stn.MsgText := '';
    Tst.SendMsg(Stn, Stn.Oper.GetReply);
    if (Stn.MsgText <> 'TU 73') and (Stn.MsgText <> 'AGN?') then
      Row := Stn.MsgText;
    end;
  Check('answering REF? gives TU 73 or AGN?', Row = '',
        IfThen(Row = '', 'all 200 ok', Row));
  // how often a plain chaser asks at all (an S2S always does, tested below)
  Stn.Exch2 := '';
  Stn.RST := 599;
  nRef := 0;
  for i := 0 to 999 do
    begin
    Stn.Oper.State := osNeedNr;
    Stn.Oper.Patience := 5;
    Stn.Oper.MsgReceived([msgNR]);
    if Stn.Oper.State = osNeedMyRef then Inc(nRef);
    end;
  Check('plain chasers ask for my reference only occasionally',
        (nRef > 20) and (nRef < 140), Format('%d of 1000', [nRef]));
  // a summit-to-summit caller needs my reference for his own log: once he
  // has copied my exchange he must always ask, never go straight to the end
  Stn.Exch2 := 'G/LD-002';
  nRef := 0; id := 0;
  for i := 0 to 999 do
    begin
    Stn.Oper.State := osNeedNr;
    Stn.Oper.Patience := 5;
    Stn.Oper.MsgReceived([msgNR]);
    if Stn.Oper.State = osNeedMyRef then Inc(nRef);
    if Stn.Oper.State = osNeedEnd then Inc(id);
    end;
  Check('an S2S caller that copied me always asks for my reference',
        (nRef > 800) and (id = 0), Format('%d asked, %d skipped of 1000', [nRef, id]));
  // a weak caller (reported me 339) mis-copies and asks for repeats more often
  Stn.Exch2 := '';
  Stn.RST := 339;
  id := 0;
  for i := 0 to 999 do
    begin
    Stn.Oper.State := osNeedNr;
    Stn.Oper.Patience := 5;
    Stn.Oper.MsgReceived([msgNR]);
    if Stn.Oper.State = osNeedNr then Inc(id);   // stayed put = asked again
    end;
  Check('a weak caller (339) asks for repeats more often',
        (id > 250) and (id < 450), Format('%d of 1000', [id]));
  // F8 must make the caller repeat rather than be ignored
  Stn.Oper.State := osNeedEnd;
  Stn.Oper.Patience := 3;
  Stn.Oper.MsgReceived([msgRefQm]);
  Check('F8 keeps the caller in the QSO so it repeats',
        Stn.Oper.State = osNeedEnd, GetEnumName(TypeInfo(TOperatorState),
        Ord(Stn.Oper.State)));
  // TU must always be able to finish the QSO, even while it still wants a ref
  Stn.Oper.State := osNeedMyRef;
  Stn.Oper.MsgReceived([msgTU]);
  Check('my TU still completes the QSO', Stn.Oper.State = osDone,
        GetEnumName(TypeInfo(TOperatorState), Ord(Stn.Oper.State)));
  Stn.Free;

  WriteLn('--- logging');
  Log.Clear;
  MainForm.Edit1.Text := 'G4ABC/P';
  MainForm.Edit2.Text := '559';
  MainForm.Edit3.Text := 'G/LD-003';
  Log.SaveQso;
  Application.ProcessMessages;
  Check('one QSO in the log', Length(Log.QsoList) = 1, IntToStr(Length(Log.QsoList)));
  if Length(Log.QsoList) = 1 then
    begin
    Check('logged report', Log.QsoList[0].Rst = 559, IntToStr(Log.QsoList[0].Rst));
    Check('logged reference', Log.QsoList[0].Exch2 = 'G/LD-003', Log.QsoList[0].Exch2);
    end;
  // a plain QSO logs an empty reference and must not be flagged '?'
  MainForm.Edit1.Text := 'DL1XYZ';
  MainForm.Edit2.Text := '579';
  MainForm.Edit3.Text := '';
  Log.SaveQso;
  Check('an empty reference is not flagged as missing',
        Log.QsoList[1].Exch2 <> '?', '"' + Log.QsoList[1].Exch2 + '"');

  WriteLn('--- score table');
  Row := '';
  for i := 0 to MainForm.ListView2.Columns.Count-1 do
    Row := Row + MainForm.ListView2.Column[i].Caption + '|';
  WriteLn('  columns: ', Row);
  Check('six columns declared',
        MainForm.ListView2.Columns.Count = 6, IntToStr(MainForm.ListView2.Columns.Count));
  for i := 0 to MainForm.ListView2.Items.Count-1 do
    begin
    Row := MainForm.ListView2.Items[i].Caption + '|';
    for id := 0 to MainForm.ListView2.Items[i].SubItems.Count-1 do
      Row := Row + MainForm.ListView2.Items[i].SubItems[id] + '|';
    WriteLn('  row:     ', Row);
    end;

  WriteLn;
  if Failures = 0 then
    WriteLn('SOTA: all checks passed')
  else
    begin
    WriteLn('SOTA: ', Failures, ' check(s) failed');
    ExitCode := 1;
    end;
end.
'''


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    lpr = os.path.join(root, "MorseRunner.lpr")
    lpi = os.path.join(root, "MorseRunner.lpi")

    src = open(lpr, encoding="utf-8").read()
    head = src.split("begin")[0].replace("program MorseRunner;",
                                         "program checksota;", 1)
    head = head.replace(
        "  Forms,", "  Forms, Classes, Controls, StdCtrls, SysUtils, TypInfo, StrUtils,", 1)

    probe_lpr = os.path.join(root, "checksota.lpr")
    probe_lpi = os.path.join(root, "checksota.lpi")
    open(probe_lpr, "w", encoding="utf-8").write(head + PROBE_BODY)
    proj = open(lpi, encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", "checksota.lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="checksota"/>')
    open(probe_lpi, "w", encoding="utf-8").write(proj)

    try:
        # -B is required: lazbuild does not notice .lfm-only edits and would
        # otherwise link a stale compiled form resource.
        build = subprocess.run(["lazbuild", "-B", probe_lpi],
                               capture_output=True, text=True)
        errors = [l for l in build.stdout.splitlines() + build.stderr.splitlines()
                  if ") Error:" in l or "Fatal:" in l]
        if errors:
            print("\n".join(errors[:15]), file=sys.stderr)
            return 2

        run = subprocess.run([os.path.join(root, "checksota")],
                             capture_output=True, text=True, cwd=root,
                             env={**os.environ,
                                  "DISPLAY": os.environ.get("DISPLAY", ":0")})
        print("\n".join(l for l in run.stdout.splitlines()
                        if not l.startswith("Gtk-Message")))
        if run.stderr.strip():
            print(run.stderr, file=sys.stderr)
        return run.returncode
    finally:
        # The app writes an ini named after its executable on shutdown.
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checksota"),
                  os.path.join(root, "checksota.lps"),
                  os.path.join(root, "checksota.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
