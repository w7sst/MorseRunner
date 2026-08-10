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

Usage: tools/check-layout.py [<repo-root>]
"""

import os
import subprocess
import sys

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
  WriteLn('Screen PPI = ', Screen.PixelsPerInch);
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


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
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

        run = subprocess.run([os.path.join(root, "checklayout")],
                             capture_output=True, text=True,
                             env={**os.environ, "DISPLAY": os.environ.get("DISPLAY", ":0")})
        print("\n".join(l for l in run.stdout.splitlines()
                        if not l.startswith("Gtk-Message")))
        return run.returncode
    finally:
        # The app writes an ini named after its executable on shutdown.
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checklayout"),
                  os.path.join(root, "checklayout.lps"),
                  os.path.join(root, "checklayout.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
