#!/usr/bin/env python3
"""Smoke-test every contest on Linux: create it, load its data files, and pull
stations out of it.

Written for the 2026-08-23 audit, whose two riskiest changes for the FPC build
are only reachable at runtime: JarlContest.pas (ACAG/ALLJA collapsed into a
shared base, never compiled by FPC before) and 58 parameters turned `const`,
where a routine that used its parameter as scratch space compiles fine and
misbehaves only when called.

Usage: check-contests.py [<repo-root>]
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

var
  C: TSimContest;
  i, id, nBlank: integer;
  Ready: boolean;
  Name, Sample, Call: string;
  Calls: TStringList;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;
  Application.ProcessMessages;

  Calls := TStringList.Create;

  for C := Low(TSimContest) to High(TSimContest) do
    begin
    Name := ContestDefinitions[C].Name;
    WriteLn('--- ', Name);

    MainForm.SetContest(C);
    Application.ProcessMessages;

    Check('contest object created', Assigned(Tst), Tst.ClassName);

    // What the Run button does before the first caller appears: this is where
    // the call-history file is actually read.
    Ready := Tst.OnContestPrepareToStart(Ini.Call, '');
    Check('call history loads', Ready, BoolToStr(Ready, True));
    if not Ready then Continue;

    // Pull real callers out of it. A const-parameter that used to be scratch
    // space, or a call-history file that never got read, shows up here: the
    // callsign comes back empty, or every draw returns the same station.
    nBlank := 0;
    Sample := '';
    Calls.Clear;
    for i := 0 to 99 do
      begin
      id := Tst.PickStation;
      Call := Tst.GetCall(id);
      if Call = '' then Inc(nBlank);
      if Calls.IndexOf(Call) < 0 then Calls.Add(Call);
      if i < 4 then Sample := Sample + Call + '  ';
      end;

    Check('100 draws all yield a callsign', nBlank = 0,
          IntToStr(100 - nBlank) + ' of 100');
    Check('the draws are not all the same station', Calls.Count > 10,
          IntToStr(Calls.Count) + ' distinct');
    WriteLn('        ', Sample);
    end;

  Calls.Free;

  WriteLn;
  if Failures = 0 then
    WriteLn('all contests: all checks passed')
  else
    WriteLn(Failures, ' FAILURE(S)');

  MainForm.Free;
  if Failures > 0 then Halt(1);
end.
'''


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    lpr = os.path.join(root, "MorseRunner.lpr")
    lpi = os.path.join(root, "MorseRunner.lpi")

    src = open(lpr, encoding="utf-8").read()
    head = src.split("begin")[0].replace("program MorseRunner;",
                                         "program checkcontests;", 1)
    head = head.replace(
        "  Forms,", "  Forms, Classes, Controls, StdCtrls, SysUtils, TypInfo, StrUtils,", 1)

    probe_lpr = os.path.join(root, "checkcontests.lpr")
    probe_lpi = os.path.join(root, "checkcontests.lpi")
    open(probe_lpr, "w", encoding="utf-8").write(head + PROBE_BODY)
    proj = open(lpi, encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", "checkcontests.lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="checkcontests"/>')
    open(probe_lpi, "w", encoding="utf-8").write(proj)

    try:
        build = subprocess.run(["lazbuild", "-B", probe_lpi],
                               capture_output=True, text=True)
        errors = [l for l in build.stdout.splitlines() + build.stderr.splitlines()
                  if ") Error:" in l or "Fatal:" in l]
        if errors:
            print("\n".join(errors[:15]), file=sys.stderr)
            return 2

        run = subprocess.run([os.path.join(root, "checkcontests")],
                             capture_output=True, text=True, cwd=root,
                             env={**os.environ,
                                  "DISPLAY": os.environ.get("DISPLAY", ":0")})
        print("\n".join(l for l in run.stdout.splitlines()
                        if not l.startswith("Gtk-Message")))
        if run.stderr.strip():
            print(run.stderr, file=sys.stderr)
        return run.returncode
    finally:
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checkcontests"),
                  os.path.join(root, "checkcontests.lps"),
                  os.path.join(root, "checkcontests.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
