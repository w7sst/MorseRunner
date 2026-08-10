#!/usr/bin/env python3
"""Look for leaked memory and unreleased resources on the paths a user takes.

Builds a throwaway program from MorseRunner.lpr with FPC's heaptrc unit linked
in (-gh), drives the real TMainForm through the sequences that allocate the
most: switching contests, starting and stopping runs (which is what opens and
closes the PulseAudio stream and the feeder thread), and logging QSOs. heaptrc
prints unfreed blocks at exit.

A clean run is not "0 bytes": the LCL and the widgetset keep singletons alive
by design. What matters is that the numbers do not grow with the number of
start/stop cycles -- that is what a leaked stream, thread or station would
look like. The script therefore runs the same sequence twice, with different
cycle counts, and reports the difference.

Needs a running X/Wayland display.

Usage: tools/check-leaks.py [<repo-root>]
"""

import os
import re
import subprocess
import sys

PROBE_BODY = '''
// Memory is only half of it: a stream that is never closed shows up as a file
// descriptor, and a feeder thread that is never joined as a live task.
function CountEntries(const ADir: string): integer;
var
  sr: TSearchRec;
begin
  Result := 0;
  if FindFirst(ADir + '/*', faAnyFile, sr) = 0 then
    repeat
      if (sr.Name <> '.') and (sr.Name <> '..') then Inc(Result);
    until FindNext(sr) <> 0;
  FindClose(sr);
end;

function RssKb: int64;
var
  f: TextFile;
  L: string;
begin
  Result := 0;
  AssignFile(f, '/proc/self/status');
  Reset(f);
  try
    while not Eof(f) do
      begin
      ReadLn(f, L);
      if Copy(L, 1, 6) = 'VmRSS:' then
        begin
        Result := StrToInt64Def(Trim(StringReplace(
          Copy(L, 7, MaxInt), 'kB', '', [rfReplaceAll])), 0);
        Break;
        end;
      end;
  finally
    CloseFile(f);
  end;
end;

procedure ReportResources(const AWhen: string);
begin
  WriteLn(Format('  %-22s fds=%3d threads=%3d rss=%6d kB',
    [AWhen, CountEntries('/proc/self/fd'), CountEntries('/proc/self/task'),
     RssKb]));
  Flush(Output);
end;

type
  // Driven from a timer under Application.Run rather than from a
  // ProcessMessages loop: pumping messages by hand re-enters gtk signal
  // emission, which aborts the widgetset and would be a fault of the test
  // rather than of the program.
  TDriver = class
  public
    Step, Cycle, Cycles: integer;
    procedure OnTick(Sender: TObject);
  end;

procedure TDriver.OnTick(Sender: TObject);
begin
  case Step of
    0:  begin
        // heaptrc's per-allocation bookkeeping is unaffordable on the 250k
        // strings the SOTA data files produce, so it can be skipped
        if GetEnvironmentVariable('MR_SKIP_SOTA') = '' then
          begin
          MainForm.SetContest(scSota);
          MainForm.SetMyExchange('G/LD-001');
          end
        else
          MainForm.SetContest(scCwt);
        MainForm.Run(rmPileUp);        // opens the stream, starts the feeder
        end;
    8:  begin
        MainForm.Edit1.Text := 'G4ABC/P';
        MainForm.Edit2.Text := '559';
        MainForm.Edit3.Text := 'G/LD-003';
        Log.SaveQso;
        end;
    9:  ReportResources(Format('cycle %d, running', [Cycle]));
    10: MainForm.Run(rmStop);          // closes the stream, joins the feeder
    11: begin
        MainForm.SetContest(scWpx);    // replaces the contest object
        MainForm.Run(rmPileUp);
        end;
    18: // deliberately left running when MR_CLOSE_RUNNING is set, to check
        // that shutting the window mid-run tears the audio down before the
        // contest object it calls back into is freed
        if GetEnvironmentVariable('MR_CLOSE_RUNNING') = '' then
          MainForm.Run(rmStop);
    19: begin
        ReportResources(Format('after cycle %d', [Cycle]));
        Inc(Cycle);
        if Cycle > Cycles then
          begin
          MainForm.Close;
          Application.Terminate;
          end
        else
          Step := -1;                  // wraps to 0 below
        end;
  end;
  Inc(Step);
end;

var
  Driver: TDriver;
  Timer: TTimer;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;

  Driver := TDriver.Create;
  // via the environment, not argv: the contests use ParamStr(1) as a data
  // directory prefix, so any command-line argument breaks file loading
  Driver.Cycles := StrToIntDef(GetEnvironmentVariable('MR_CYCLES'), 1);
  Driver.Cycle := 1;
  Driver.Step := 0;

  Timer := TTimer.Create(nil);
  Timer.Interval := 120;
  Timer.OnTimer := Driver.OnTick;
  Timer.Enabled := True;

  ReportResources('at startup');
  Application.Run;

  Timer.Free;
  Driver.Free;
  ReportResources('after shutdown');
  WriteLn('completed');
end.
'''


def heap_summary(text):
    """Pull the heaptrc trailer out of a run's stderr."""
    m = re.search(r"(\d+) unfreed memory blocks? : (\d+)", text)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None, None


def main():
    with_heaptrc = "--no-heaptrc" not in sys.argv
    skip_sota = "--skip-sota" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = os.path.abspath(args[0] if args else os.getcwd())
    src = open(os.path.join(root, "MorseRunner.lpr"), encoding="utf-8").read()
    head = src.split("begin")[0].replace("program MorseRunner;",
                                         "program checkleaks;", 1)
    # heaptrc installs its memory manager in its initialization section, so
    # it has to come before anything that allocates. It is optional because
    # its per-allocation bookkeeping is very expensive on the 250k+ strings
    # the SOTA data files produce.
    if with_heaptrc:
        head = head.replace("  Interfaces,", "  heaptrc,\n  Interfaces,", 1)
    head = head.replace("  Forms,", "  Forms, SysUtils, Controls, StdCtrls, ExtCtrls,", 1)

    probe_lpr = os.path.join(root, "checkleaks.lpr")
    probe_lpi = os.path.join(root, "checkleaks.lpi")
    open(probe_lpr, "w", encoding="utf-8").write(head + PROBE_BODY)

    proj = open(os.path.join(root, "MorseRunner.lpi"), encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", "checkleaks.lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="checkleaks"/>')
    open(probe_lpi, "w", encoding="utf-8").write(proj)

    try:
        build = subprocess.run(["lazbuild", "-B", probe_lpi],
                               capture_output=True, text=True)
        errors = [l for l in build.stdout.splitlines() + build.stderr.splitlines()
                  if ") Error:" in l or "Fatal:" in l]
        if errors:
            print("\n".join(errors[:15]), file=sys.stderr)
            return 2

        results = {}
        for cycles in (1, 5):
            run = subprocess.run([os.path.join(root, "checkleaks")],
                                 capture_output=True, text=True, cwd=root,
                                 env={**os.environ,
                                      "DISPLAY": os.environ.get("DISPLAY", ":0"),
                                      "MR_CYCLES": str(cycles),
                                      **({"MR_SKIP_SOTA": "1"} if skip_sota else {}),
                                      "HEAPTRC": "haltonerror"})
            blocks, size = heap_summary(run.stderr)
            results[cycles] = (blocks, size, run.stderr)
            print(f"--- {cycles} cycle(s): unfreed blocks={blocks} bytes={size} rc={run.returncode}")
            if blocks is None:
                print("    stdout:", run.stdout.strip()[-600:] or "(none)")
                print("    stderr:", run.stderr.strip()[-600:] or "(none)")
            for line in run.stdout.splitlines():
                if "fds=" in line:
                    print(line)

        b1, s1, err1 = results[1]
        b5, s5, _ = results[5]
        if b1 is None or b5 is None:
            print("\nheaptrc produced no summary; raw stderr follows:",
                  file=sys.stderr)
            print(results[5][2][-3000:], file=sys.stderr)
            return 2

        print(f"\ngrowth over 4 extra cycles: {b5-b1} blocks, {s5-s1} bytes")
        if b5 == b1:
            print("=> nothing accumulates per start/stop cycle")
        else:
            print(f"=> {(b5-b1)/4:.1f} blocks leak per cycle -- call sites:")
            # heaptrc lists a backtrace per block; show the app frames
            for line in err1.splitlines():
                if root in line:
                    print("   ", line.strip())
        return 0 if b5 == b1 else 1
    finally:
        for f in (probe_lpr, probe_lpi, os.path.join(root, "checkleaks"),
                  os.path.join(root, "checkleaks.lps"),
                  os.path.join(root, "checkleaks.ini")):
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
