#!/usr/bin/env python3
"""Check that the QSO-rate histogram actually paints.

The bottom-centre panel of the main window shows a bar per 5-minute bucket of
the run. On Linux it came up solid black: no background, no bars.

Cause is a name-resolution difference inside THisto.Repaint (Log.pas), which
opens `with PaintBox, PaintBox.Canvas do`. LCL's TCanvas publishes Width and
Height; Delphi's VCL TCanvas does not. The last entry of a with-list wins, so
on FPC the fill and bar rectangles are computed from the canvas rather than
from the paint box. A TPaintBox is a TGraphicControl with no window of its
own, so its canvas is the *parent's* DC and reports the parent's size -- or
0x0 before the handle exists.

There were two faults. The bars were laid out against Panel3 rather than the
paint box (a with-block name-resolution difference in THisto.Repaint, Log.pas:
LCL's TCanvas publishes Width/Height and Delphi's does not, and the last entry
of a with-list wins). And the background colour, clInfoBk, is pale yellow on
Win32 but #343434 under gtk2 -- near-black, which is what was actually seen.

This builds a throwaway program from MorseRunner.lpr that creates the real
TMainForm, puts a known set of QSOs into QsoList, and inspects the geometry and
colours the real paint handler uses. It does not sample rendered pixels:
Canvas.Pixels[] reads back junk outside a paint cycle on gtk2.

Needs a running X/Wayland display (it realises real widgets).

Usage: tools/check-histo.py [<repo-root>]
"""

import os
import subprocess
import sys

PROBE_BODY = '''
var
  Failures: integer = 0;

procedure Expect(Ok: boolean; const What, Detail: string);
begin
  if Ok then
    WriteLn(Format('  ok    %-52s [%s]', [What, Detail]))
  else
    begin
      Inc(Failures);
      WriteLn(Format('  FAIL  %-52s [%s]', [What, Detail]));
    end;
end;

function Luma(C: TColor): integer;
var R: TColor;
begin
  R := ColorToRGB(C);
  Luma := (Red(R) * 30 + Green(R) * 59 + Blue(R) * 11) div 100;
end;

var
  I, X, Y, W, H, TallH: integer;
  Bmp: TBitmap;
  Green, Back, TopRow, BotRow: integer;
  BackRGB, GreenRGB: TColor;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;
  Application.ProcessMessages;

  // 60 QSOs spread over the first two hours, so most 5-minute buckets are
  // non-empty and the bars have a range of heights.
  SetLength(QsoList, 60);
  for I := 0 to High(QsoList) do
    QsoList[I].T := (I * 2) / 1440.0;

  W := MainForm.PaintBox1.Width;
  H := MainForm.PaintBox1.Height;
  BackRGB  := ColorToRGB(MainForm.PaintBox1.Color);
  GreenRGB := ColorToRGB(clGreen);

  WriteLn(Format('PaintBox1 = %dx%d   Panel3 = %dx%d',
    [W, H, MainForm.Panel3.Width, MainForm.Panel3.Height]));
  WriteLn(Format('background $%.6x (luma %d)   bars $%.6x (luma %d)',
    [BackRGB, Luma(BackRGB), GreenRGB, Luma(GreenRGB)]));

  { Render the real Panel3 -- which owns PaintBox1 -- into a bitmap that is
    deliberately much TALLER than the panel. During PaintTo the canvas handle
    is the bitmap DC, so Canvas.Height reports the bitmap height. That makes
    the test discriminating: code that lays bars out against the canvas puts
    them near y=TallH, far below the paint box, while code that uses the paint
    box puts them just above y=H. Reading pixels back from a TBitmap is
    reliable, unlike reading a live control DC on gtk2. }
  // Force a fresh paint now that QsoList is populated: gtk2 double-buffers and
  // PaintTo can otherwise blit a backing store rendered while the log was empty.
  MainForm.PaintBox1.Invalidate;
  Application.ProcessMessages;

  TallH := 300;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(MainForm.Panel3.Width, TallH);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    MainForm.Panel3.PaintTo(Bmp.Canvas, 0, 0);

    Green := 0; Back := 0; TopRow := TallH; BotRow := -1;
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        begin
          if Bmp.Canvas.Pixels[X, Y] = GreenRGB then
            begin
              Inc(Green);
              if Y < TopRow then TopRow := Y;
              if Y > BotRow then BotRow := Y;
            end
          else if Bmp.Canvas.Pixels[X, Y] = BackRGB then
            Inc(Back);
        end;

    WriteLn(Format('rendered %dx%d: green=%d px (rows %d..%d)  background=%d px',
      [Bmp.Width, TallH, Green, TopRow, BotRow, Back]));

    Expect(Back > (W * H) div 4, 'background is painted',
           IntToStr(Back) + ' px');
    Expect(Green > 200, 'bars are drawn', IntToStr(Green) + ' px');
    Expect((BotRow >= 0) and (BotRow < H),
           'bars sit inside the paint box, not against the canvas',
           Format('bottom row %d, paint box is %d tall', [BotRow, H]));
  finally
    Bmp.Free;
  end;

  Expect(Luma(BackRGB) > 128, 'background is light, not near-black',
         'luma ' + IntToStr(Luma(BackRGB)));
  Expect(Abs(Luma(BackRGB) - Luma(GreenRGB)) > 60,
         'bars contrast against the background',
         IntToStr(Abs(Luma(BackRGB) - Luma(GreenRGB))));

  SetLength(QsoList, 0);
  MainForm.Free;
  if Failures > 0 then
    begin
      WriteLn('histogram: ', Failures, ' check(s) FAILED');
      ExitCode := 1;
    end
  else
    WriteLn('histogram: all checks passed');
end.
'''


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    lpr = os.path.join(root, "MorseRunner.lpr")
    lpi = os.path.join(root, "MorseRunner.lpi")

    src = open(lpr, encoding="utf-8").read()
    head = src.split("begin")[0].replace("program MorseRunner;",
                                         "program checkhisto;", 1)
    # Log is already in MorseRunner.lpr's uses clause (it declares QsoList).
    head = head.replace("  Forms,",
                        "  Forms, Controls, Graphics, SysUtils, Types, ExtCtrls,", 1)

    probe_lpr = os.path.join(root, "checkhisto.lpr")
    probe_lpi = os.path.join(root, "checkhisto.lpi")
    open(probe_lpr, "w", encoding="utf-8").write(head + PROBE_BODY)
    proj = open(lpi, encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", "checkhisto.lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="checkhisto"/>')
    open(probe_lpi, "w", encoding="utf-8").write(proj)

    try:
        # -B is required: lazbuild does not notice .lfm-only edits and would
        # otherwise link a stale compiled form resource.
        build = subprocess.run(["lazbuild", "-B", probe_lpi],
                               capture_output=True, text=True)
        errors = [l for l in build.stdout.splitlines() + build.stderr.splitlines()
                  if ") Error:" in l or "Fatal:" in l]
        if errors:
            print("\n".join(errors[:10]), file=sys.stderr)
            return 2

        run = subprocess.run([os.path.join(root, "checkhisto")],
                             capture_output=True, text=True,
                             env={**os.environ,
                                  "DISPLAY": os.environ.get("DISPLAY", ":0")})
        print("\n".join(l for l in run.stdout.splitlines()
                        if not l.startswith("Gtk-Message")))
        return run.returncode
    finally:
        # The app writes an ini named after its executable on shutdown.
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checkhisto"),
                  os.path.join(root, "checkhisto.lps"),
                  os.path.join(root, "checkhisto.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
