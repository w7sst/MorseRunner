#!/usr/bin/env python3
"""Measure the Linux audio output path against the audio the simulation made.

The DSP that produces the band noise is byte-for-byte the same code as
VE3NEA's, so if the "radio sound" is worse on Linux the fault has to be in
delivery, not in synthesis. This probe measures delivery.

It builds a throwaway program from MorseRunner.lpr that creates the real
TMainForm, turns on WAV recording (which writes exactly what TContest.GetAudio
produced, before the sound device sees it), runs a pile-up for a few seconds
and stops. While that runs, the app is pinned to a private null sink and parec
records that sink's monitor, i.e. what actually came out. (The default sink's
monitor carries every other stream on the desktop and measures nothing.)

Two things are then checked:

  * pacing -- blocks per second must be DEFAULTRATE/BufSize (21.5 with the
    stock 512-sample buffer). A feeder thread that blocks too much or too
    little shows up here as a wrong rate, which on the air sounds like the
    whole contest running fast or slow.
  * dropouts -- the recorded monitor must not contain silent gaps. Band noise
    is continuous by construction, so any interval whose RMS collapses is the
    sound server running dry, which is heard as a click or a stutter.

Needs a running X/Wayland display and a PulseAudio/PipeWire server.

Usage: tools/check-audio.py [--seconds N] [<repo-root>]
"""

import argparse
import math
import os
import shutil
import struct
import subprocess
import sys
import time
import wave

PROBE_BODY = '''
type
  TDriver = class
  public
    Ticks: integer;
    T0: TDateTime;
    Blocks0: integer;
    procedure OnTick(Sender: TObject);
  end;

var
  Driver: TDriver;
  Timer: TTimer;

procedure TDriver.OnTick(Sender: TObject);
begin
  Inc(Ticks);
  if Ticks = 1 then
    begin
    Ini.SaveWav := True;
    MainForm.Run(rmPileup);
    WriteLn('started runmode=', Ord(Ini.RunMode));
    WriteLn('band=', Ord(Ini.Qrn), Ord(Ini.Qrm), Ord(Ini.Qsb),
                     Ord(Ini.Flutter), Ord(Ini.Lids));
    Flush(Output);
    end
  //the first second is skipped: Start primes one block per buffer at once,
  //and TContest.GetAudio returns a 1-sample block until BlockNumber reaches 6,
  //so neither is paced by the sound server
  else if Ticks = 2 then
    begin
    T0 := Now;
    Blocks0 := Tst.BlockNumber;
    end
  else if Ticks = %(seconds)d + 2 then
    begin
    WriteLn('elapsed=', FormatFloat('0.000', (Now - T0) * 86400));
    WriteLn('blocks=', Tst.BlockNumber - Blocks0);
    WriteLn('bufsize=', Ini.BufSize);
    WriteLn('bufsadded=', MainForm.AlSoundOut1.BufsAdded);
    WriteLn('bufsdone=', MainForm.AlSoundOut1.BufsDone);
    Flush(Output);
    MainForm.Run(rmStop);
    Application.Terminate;
    end;
end;

begin
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Morse Runner';
  Application.CreateForm(TMainForm, MainForm);

  Driver := TDriver.Create;
  Timer := TTimer.Create(nil);
  Timer.Interval := 1000;
  Timer.OnTimer := Driver.OnTick;
  Timer.Enabled := True;

  Application.Run;

  Timer.Free;
  Driver.Free;
end.
'''


def rms_envelope(samples, win):
    out = []
    for i in range(0, len(samples) - win, win):
        chunk = samples[i:i + win]
        acc = 0
        for v in chunk:
            acc += v * v
        out.append((acc / win) ** 0.5)
    return out


def read_wav_mono(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        raw = w.readframes(n)
        ch = w.getnchannels()
        rate = w.getframerate()
    vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if ch > 1:
        vals = vals[::ch]
    return list(vals), rate


def read_raw_s16(path, channels):
    raw = open(path, "rb").read()
    vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if channels > 1:
        vals = vals[::channels]
    return list(vals)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=os.getcwd())
    ap.add_argument("--seconds", type=int, default=8)
    ap.add_argument("--keep", action="store_true",
                    help="keep the probe binary and the recordings")
    ap.add_argument("--fresh", action="store_true",
                    help="run without an .INI, i.e. what a new user hears")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    name = "checkaudio"
    lpr = os.path.join(root, "MorseRunner.lpr")
    lpi = os.path.join(root, "MorseRunner.lpi")

    src = open(lpr, encoding="utf-8").read()
    head = src.split("\nbegin")[0].replace("program MorseRunner;",
                                           "program %s;" % name, 1)
    head = head.replace("  Forms,",
                        "  Forms, Classes, ExtCtrls, SysUtils,", 1)

    probe_lpr = os.path.join(root, name + ".lpr")
    probe_lpi = os.path.join(root, name + ".lpi")
    probe_ini = os.path.join(root, name + ".ini")
    probe_wav = os.path.join(root, name + ".wav")
    rec_raw = os.path.join(root, name + "-monitor.raw")

    open(probe_lpr, "w", encoding="utf-8").write(
        head + PROBE_BODY % {"seconds": args.seconds})
    proj = open(lpi, encoding="utf-8").read()
    proj = proj.replace("MorseRunner.lpr", name + ".lpr").replace(
        '<Filename Value="MorseRunner"/>', '<Filename Value="%s"/>' % name)
    open(probe_lpi, "w", encoding="utf-8").write(proj)

    # the app reads/writes an ini named after its executable
    if not args.fresh and os.path.exists(os.path.join(root, "MorseRunner.ini")):
        shutil.copyfile(os.path.join(root, "MorseRunner.ini"), probe_ini)

    failures = 0
    try:
        build = subprocess.run(["lazbuild", "-B", probe_lpi],
                               capture_output=True, text=True)
        errors = [l for l in build.stdout.splitlines() + build.stderr.splitlines()
                  if ") Error:" in l or "Fatal:" in l]
        if errors:
            print("\n".join(errors[:15]), file=sys.stderr)
            return 2

        # A private null sink, so the capture holds this app and nothing else.
        # The default sink's monitor carries every other stream on the desktop
        # and is useless for measuring dropouts.
        sink = "morserunner_probe"
        module = subprocess.run(
            ["pactl", "load-module", "module-null-sink",
             "sink_name=" + sink, "sink_properties=device.description=MRProbe"],
            capture_output=True, text=True).stdout.strip()
        rec = subprocess.Popen(
            ["parec", "-d", sink + ".monitor", "--format=s16le",
             "--rate=11025", "--channels=1", "--file-format=raw", rec_raw],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)

        try:
            run = subprocess.run([os.path.join(root, name)],
                                 capture_output=True, text=True, cwd=root,
                                 env={**os.environ,
                                      "PULSE_SINK": sink,
                                      "DISPLAY": os.environ.get("DISPLAY", ":0")})
        finally:
            rec.terminate()
            rec.wait(timeout=5)
            if module.isdigit():
                subprocess.run(["pactl", "unload-module", module],
                               capture_output=True)

        out = {}
        for line in run.stdout.splitlines():
            if "=" in line and not line.startswith("Gtk"):
                k, _, v = line.partition("=")
                out[k.strip()] = v.strip()
        if run.returncode != 0:
            print(run.stdout)
            print(run.stderr, file=sys.stderr)
            return 2

        # ---- pacing -------------------------------------------------------
        elapsed = float(out.get("elapsed", 0))
        blocks = int(out.get("blocks", 0))
        bufsize = int(out.get("bufsize", 512))
        want = 11025.0 / bufsize
        got = blocks / elapsed if elapsed else 0
        ok = abs(got - want) / want < 0.02
        failures += not ok
        print("  %s  block rate  [%.2f/s, want %.2f/s over %.1fs]"
              % ("ok  " if ok else "FAIL", got, want, elapsed))

        added = int(out.get("bufsadded", 0))
        done = int(out.get("bufsdone", 0))
        ok = 0 <= added - done <= 8
        failures += not ok
        print("  %s  buffers     [added %d, done %d]"
              % ("ok  " if ok else "FAIL", added, done))

        # ---- what the DSP made -------------------------------------------
        ref, rate = read_wav_mono(probe_wav)
        print("  info  recorded wav: %d samples @ %d Hz (%.1f s)"
              % (len(ref), rate, len(ref) / rate))

        # Crest factor separates a live band from a dead one: static crashes
        # are short and loud, so QRN lifts the peak far above the RMS. Flat
        # filtered noise on its own sits near 4x (12 dB).
        r = (sum(float(v) * v for v in ref) / len(ref)) ** 0.5
        peak = max(abs(v) for v in ref)
        band = out.get("band", "?????")
        print("  info  band cond   [QRN QRM QSB Flutter LIDs = %s]"
              % " ".join(band))
        print("  info  crest       [peak %d / rms %.0f = %.1f dB]"
              % (peak, r, 20 * math.log10(peak / r) if r else 0))

        # ---- what actually came out --------------------------------------
        mon = read_raw_s16(rec_raw, 1)
        win = 256                       # ~23 ms
        env = rms_envelope(mon, win)
        # ignore the lead-in and tail where the stream was not running
        loud = [i for i, v in enumerate(env) if v > 50]
        if not loud:
            print("  FAIL  monitor    [no audio captured from %s.monitor]" % sink)
            return 1
        lo, hi = loud[0], loud[-1]
        body = env[lo:hi + 1]
        floor = sorted(body)[len(body) // 2] * 0.1
        gaps = [i for i, v in enumerate(body) if v < floor]
        ok = not gaps
        failures += not ok
        print("  %s  dropouts    [%d of %d %dms frames below 10%% of median]"
              % ("ok  " if ok else "FAIL", len(gaps), len(body),
                 round(1000 * win / 11025)))
        print("  info  monitor    %.1f s captured, median RMS %.0f"
              % (len(mon) / 11025.0, sorted(body)[len(body) // 2]))

        print("\n%s" % ("all checks passed" if not failures
                        else "%d check(s) failed" % failures))
        return 1 if failures else 0
    finally:
        if not args.keep:
            for f in (probe_lpr, probe_lpi, probe_ini, probe_wav, rec_raw,
                      os.path.join(root, name),
                      os.path.join(root, name + ".lps")):
                if os.path.exists(f):
                    os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
