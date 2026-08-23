#!/usr/bin/env python3
"""Check the main form's layout for controls that overflow their parent.

The Delphi form uses absolute coordinates tuned for VCL/Win32 metrics. The LCL
lays things out differently -- most importantly a TGroupBox insets its client
area below the caption, which VCL does not -- so children silently spill
outside their parent and paint across frames.

This builds a throwaway program from MorseRunner.lpr that creates the real
TMainForm, then walks every control and reports any whose bounds fall outside
its parent's client rectangle. The form is checked at several sizes so that
resizing regressions show up too.

Needs a running X/Wayland display (it realises real widgets).

With --dpi it sweeps scale factors by running the probe against a nested
Xephyr server started at each resolution. That is the only faithful way to do
it here: the desktop sits at one fixed DPI, and every attempt to simulate a
different one in-process produced numbers that measured the harness instead of
the app (see "Fractional scales" in CLAUDE.md). Xephyr opens a window on the
desktop for the few seconds each pass takes.

Usage: tools/check-layout.py [--dpi 96,120,144,192] [<repo-root>]
"""

import argparse
import os
import subprocess
import sys
import time

PROBE_BODY = '''
var
  Problems: integer = 0;

procedure Check(C: TControl; Indent: integer);
var
  I, PW, PH: integer;
  Pad: string;
  W: TWinControl;
begin
  Pad := StringOfChar(' ', Indent);
  if C.Parent <> nil then
  begin
    PW := C.Parent.ClientWidth;
    PH := C.Parent.ClientHeight;
    if (C.Left + C.Width > PW) or (C.Top + C.Height > PH) or
       (C.Left < 0) or (C.Top < 0) then
    begin
      Inc(Problems);
      WriteLn(Format('%s%-16s %-13s %4d,%-4d %4dx%-4d  <== outside parent client %dx%d',
        [Pad, C.Name, C.ClassName, C.Left, C.Top, C.Width, C.Height, PW, PH]));
    end;
  end;
  if C is TWinControl then
  begin
    W := TWinControl(C);
    for I := 0 to W.ControlCount - 1 do
      Check(W.Controls[I], Indent + 2);
  end;
end;

var
  I, J, Total: integer;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;
  Application.ProcessMessages;
  Total := 0;
  //the font is reported so the sweep is self-checking: if a scale factor did
  //not really take, the font height gives it away before the counts do
  WriteLn('Screen PPI = ', Screen.PixelsPerInch,
          '  form font.h = ', MainForm.Font.Height);
  for J := 0 to 3 do
  begin
    case J of
      0: ;
      1: MainForm.SetBounds(0, 0, MainForm.Constraints.MinWidth,
                            MainForm.Constraints.MinHeight);
      2: MainForm.SetBounds(0, 0, 1800, 1300);
      3: MainForm.SetBounds(0, 0, 2400, 1700);
    end;
    Application.ProcessMessages;
    Problems := 0;
    WriteLn(Format('--- form %dx%d client=%dx%d',
      [MainForm.Width, MainForm.Height,
       MainForm.ClientWidth, MainForm.ClientHeight]));
    for I := 0 to MainForm.ControlCount - 1 do
      Check(MainForm.Controls[I], 0);
    WriteLn('    overflowing controls: ', Problems);
    Inc(Total, Problems);
  end;
  if Total > 0 then
    ExitCode := 1;
end.
'''


def free_display():
    """First X display number not already taken."""
    for n in range(9, 40):
        if not os.path.exists("/tmp/.X11-unix/X%d" % n):
            return n
    raise RuntimeError("no free X display")


def run_probe(exe, root, display):
    run = subprocess.run([exe], capture_output=True, text=True, cwd=root,
                         env={**os.environ, "DISPLAY": display})
    print("\n".join(l for l in run.stdout.splitlines()
                    if not l.startswith("Gtk-Message")))
    return run.returncode


def run_probe_at_dpi(exe, root, dpi):
    """Run the probe against a nested Xephyr started at the given resolution.

    The screen has to be bigger than the largest window the probe asks for
    (2400x1700), or SetBounds is clamped and the wide-window passes test
    nothing.
    """
    n = free_display()
    disp = ":%d" % n
    xephyr = subprocess.Popen(
        ["Xephyr", disp, "-screen", "2600x1900", "-dpi", str(dpi),
         "-ac", "-nolisten", "tcp"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            if os.path.exists("/tmp/.X11-unix/X%d" % n):
                break
            time.sleep(0.1)
        else:
            print("Xephyr did not start for %d dpi" % dpi, file=sys.stderr)
            return 2
        time.sleep(0.5)
        print("=== %d dpi (%d%% of the designed 96)" % (dpi, round(100 * dpi / 96)))
        return run_probe(exe, root, disp)
    finally:
        xephyr.terminate()
        try:
            xephyr.wait(timeout=5)
        except subprocess.TimeoutExpired:
            xephyr.kill()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=os.getcwd())
    ap.add_argument("--dpi", help="comma-separated DPI values to sweep in a "
                                  "nested Xephyr, e.g. 96,120,144,192")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    lpr = os.path.join(root, "MorseRunner.lpr")
    lpi = os.path.join(root, "MorseRunner.lpi")

    src = open(lpr, encoding="utf-8").read()
    head = src.split("begin")[0].replace("program MorseRunner;",
                                         "program checklayout;", 1)
    # The probe walks the control tree and formats its report.
    head = head.replace("  Forms,", "  Forms, Controls, StdCtrls, SysUtils,", 1)

    probe_lpr = os.path.join(root, "checklayout.lpr")
    probe_lpi = os.path.join(root, "checklayout.lpi")
    open(probe_lpr, "w", encoding="utf-8").write(head + PROBE_BODY)
    proj = open(lpi, encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", "checklayout.lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="checklayout"/>')
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

        exe = os.path.join(root, "checklayout")
        if not args.dpi:
            return run_probe(exe, root, os.environ.get("DISPLAY", ":0"))

        rc = 0
        for dpi in args.dpi.split(","):
            if run_probe_at_dpi(exe, root, int(dpi.strip())):
                rc = 1
        return rc
    finally:
        # The app writes an ini named after its executable on shutdown.
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checklayout"),
                  os.path.join(root, "checklayout.lps"),
                  os.path.join(root, "checklayout.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
