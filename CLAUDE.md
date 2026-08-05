# MorseRunner — Linux/Lazarus port

Working branch: `linux-lazarus-port` (off `main`). Upstream is a Delphi/VCL Win32 app;
this branch makes it build and run on Linux under Lazarus/FPC **without forking** —
all platform splits use `{$IFDEF MSWINDOWS}` / `{$IFDEF FPC}` so the Delphi build
stays intact.

## Toolchain

- FPC 3.2.3, Lazarus 4.8 (`lazbuild`, `/usr/bin/lazarus-ide`)
- Build: `lazbuild MorseRunner.lpi` → `./MorseRunner`
- Units out to `lib/x86_64-linux/`
- Project files added for Lazarus: `MorseRunner.lpi`, `MorseRunner.lpr`
  (the Delphi `.dpr`/`.dproj` are untouched and still authoritative for Windows)
- **`README.md` carries a "Building on Linux (Lazarus/FPC)" section** (added
  2026-08-05) at the top, with the Fedora `dnf` line and the test workflow,
  **followed by a "Building on Windows (Delphi)" section** (added the same
  day: IDE and msbuild/rsvars instructions, the `EnvOptions.proj`/
  `DCC_ResourcePath` gotcha, and the `Test\UnitTests.dproj` runner).
  The three runtime libraries there are `dlopen`ed, not linked, so the build
  succeeding says nothing about whether the app will run: `libpcre.so.1`
  (**PCRE1 8.x, package `pcre` — not `pcre2`**), `libpulse-simple.so.0` /
  `libpulse.so.0`, and `libssl.so.3` / `libcrypto.so.3`.

## Status

**App builds clean** (hints only) and starts and exits cleanly on Fedora
(Wayland). **Unit tests build and pass on Linux: 897 passed, 0 failed, 60
skipped** (the skipped ones are `[Test(False)]`, matching Delphi).

**The same working tree now also builds and runs on Windows with Delphi 13**
(Studio 37.0) — see "Windows build verification" below. Delphi unit tests:
**897 found, 897 passed, 0 failed, 0 leaked.**

Nothing is committed yet — everything is still in the working tree.

### Done

- **Audio backend** — Win32 `waveOut` replaced on Linux by the PulseAudio
  *simple* API. New unit `VCL/SndPulse.pas` dynamically binds
  `libpulse-simple.so.0` / `libpulse.so.0` at runtime, so the binary has no
  link-time PulseAudio dependency (pipewire-pulse serves it on Fedora).
  `VCL/SndCustm.pas` and `VCL/SndOut.pas` carry parallel implementations behind
  `{$IFDEF MSWINDOWS}`; the Linux side uses a feeder thread in place of the
  waveOut callback.
- **Forms** — `Main.dfm` / `ScoreDlg.dfm` converted to `Main.lfm` / `ScoreDlg.lfm`.
  The score-summary ListView rows (Pts / Mult / Score) could not survive the
  resource conversion, so on FPC they are built in code
  (`TMainForm.BuildScoreSummaryRows`).
- **HTTP** — Indy `IdHTTP` → `fphttpclient` + `opensslsockets` on FPC
  (score-board upload / call-history download).
- **Shell integration** — `ShellExecute` → LCL `OpenURL` / `OpenDocument`
  (Readme, web pages, "play recorded audio").
- **WAV recording** — `VCL/WavFile.pas` given a non-Windows path (largest single
  file change, ~380 lines).
- **Threading** — `cthreads` first in the `.lpr` uses clause (required for
  `TThread` on Unix).
- **PCRE** — `PerlRegEx/pcre.pas` bound to the system libpcre on Linux.
- **Misc** — string/`PChar`, `TStringList`, ini-path and `LCLType`/`LMessages`
  fixes spread across the contest units, `Ini.pas`, `Log.pas`, `Station.pas`,
  `VCL/PermHint.pas`, `VCL/VolmSldr.pas`, `Util/*`.

### Unit tests on Linux

`Test/fpc/` holds the Lazarus counterpart to Delphi's `Test/UnitTests.dproj`.
See `Test/fpc/README.md` for the full rationale. Short version:

```sh
python3 tools/gen-fpc-tests.py     # regenerate Test/fpc/gen/ (git-ignored)
lazbuild Test/fpc/UnitTests.lpi    # builds ./UnitTests in the repo root
./UnitTests
```

FPC 3.2.x cannot parse Delphi custom attributes, so the DUnitX `[TestCase]`
attributes that encode ~960 cases are read at build time by
`tools/gen-fpc-tests.py`, which emits attribute-stripped copies of the test
units plus generated fixture registration. `Test/fpc/DUnitX.TestFramework.pas`
is a small `Assert`/runner shim. `Test/*.pas` stays the single source of truth
and must remain Delphi-compatible.

Two real bugs surfaced while getting the suite green — both are Delphi/FPC
behaviour differences in app-facing code, not test-only issues:

- `Util/SSExchParser.pas` — `TSSLexer.Create` called `Sections.Sort` but left
  `Sorted` False. Delphi's `TStringList.Find` tolerates that; FPC raises
  `EListError`. Now sets `Sorted := True`. **This affected the ARRL SS
  section lookup in the app itself**, not just the tests.
- `Test/SSLexerTest.pas` — same fix for the `badCalls` list, plus the
  hardcoded `C:\Users\mikeb\...` call-history path replaced with
  `ExtractFilePath(ParamStr(0))`.

Also fixed three Delphi-only inline `var X: T := ...` declarations in
`Test/LexerTest.pas` and `Test/SSLexerTest.pas` (moved to `var` blocks —
still valid Delphi).

### UI / appearance

Was broken: the last row of each right-hand group box collided with the box
below it (Contest lost "Exchange", Station lost "Mon. Level", Band Conditions
lost "QSB"). **Fixed — `tools/check-layout.py` now reports 0 overflowing
controls at four window sizes.** Still needs a human eye on it; "no control
is outside its parent" is not the same as "looks right".

Diagnosis, measured on the dev machine (gtk2, `Screen.PixelsPerInch = 192`)
with `tools/check-layout.py`, which builds a throwaway program from
`MorseRunner.lpr` that creates the real `TMainForm` and walks its controls:

- **DPI scaling works.** Form comes up 1458x1012, exactly 2x the designed
  729x506, and the font resolves to `h=-24 size=9`. (An earlier note in this
  file claimed gtk2 always reports 96 dpi and that `Application.Scaled` was a
  no-op — that was wrong.)
- **Positions and container sizes scale; standard control heights do not.**
  `ContestGroup` scales 195x74 -> 390x148, but its `ExchangeEdit` goes from
  top 44 to top 88 while its height stays 23. Labels stay 15px, check boxes
  17px, combos/edits 23px — all Win32 design-time values.
- **gtk2's group box caption inset is much larger than Win32's**: a 148px-tall
  group box has a client height of only 110 (38px inset, vs roughly 16 on
  Win32). `ExchangeEdit` ends at 88+23 = 111 > 110, so it overflows by a
  pixel and paints across the frame.

So the cause is metric mismatch between a Win32-tuned absolute layout and
gtk2, not the font and not the scaling. `Segoe UI` is indeed missing (falls
back to Adwaita Sans), but since fontconfig already substitutes it, naming a
different font changes nothing on its own.

Fixes applied (all in `Main.lfm` / `MorseRunner.lpr`):

- `Application.Scaled := True`, and explicit `DesignTimePPI = 96` in
  `Main.lfm` and `ScoreDlg.lfm`.
- The three right-hand group boxes get `Align = alTop` +
  `BorderSpacing.Around = 6` so they restack themselves, and ~16px more
  height each to absorb the LCL caption inset (Contest 74->90, Station
  155->172, Band Conditions 84->100). `AutoSize = True` was tried first and
  does nothing — LCL will not shrink-wrap absolutely-positioned children.
- `Panel10` 37->48 and `ToolBar1` 29->34: `ButtonHeight = 30` did not fit a
  29px toolbar once scaled.
- `Label19` (splash copyright, font `Consolas`, also missing on Linux) is now
  a full-width `Alignment = taCenter` label anchored left+right instead of a
  fixed-position autosized one, which overran its parent.
- Window is now resizable: `BorderStyle = bsSizeable`, `biMaximize` added,
  `Constraints.MinWidth/MinHeight` set, `ClientHeight` 506->580 so the taller
  right column fits. The top-level panels were already `alClient`/`alRight`/
  `alBottom`, so they reflow correctly — verified at 4 sizes up to 2400x1700.

Gotchas worth remembering:

- **`lazbuild` does not notice `.lfm`-only edits** and will silently link a
  stale form resource. Always `lazbuild -B` after changing a form, or you
  will debug the previous layout (this cost real time).
- **`.lfm` files do not accept Pascal `{ }` comments** — the resource compiler
  fails with "Wrong token type: Symbol expected but { found".
- `.lfm` files are Linux-only (Delphi reads the `.dfm`), so layout changes
  there cannot affect the Windows build.

### Runtime bug found and fixed: Stop hung the application

First interactive test found it: clicking **Stop** froze the app, and the
desktop offered "quit or wait for the program to respond". A hard deadlock
between the main thread and the Pulse feeder thread.

The chain:

```
RunBtnClick            -> Tst.FStopPressed := true
TWaitThread.Execute    -> Synchronize(ProcessEvent)      [feeder thread parks]
  BufferDone           -> AlSoundOut1BufAvailable        [main thread]
  Tst.GetAudio         -> Contest.pas:860 sees FStopPressed
  MainForm.Run(rmStop) -> Main.pas:2207 AlSoundOut1.Enabled := false
  DoSetEnabled(false)  -> FThread.WaitFor                [main thread parks]
```

The feeder thread is parked *inside* `Synchronize` waiting for the main thread
to return; the main thread is inside `WaitFor` waiting for the feeder thread to
finish. FPC's `TThread.WaitFor` does pump `CheckSynchronize` when called from
the main thread (`rtl/unix/tthread.inc:259`) — an earlier comment in
`SndCustm.pas` relied on that — but it does not help here: the offending entry
has already been dequeued and is executing, so there is nothing left to pump
and the cycle cannot break.

Windows never hits this because its `DoSetEnabled(false)` is
`FThread.Terminate; Stop;` with no join — the `waveOut` thread is
`FreeOnTerminate` and exits on its own.

Fix, all in the `{$ELSE}` (non-Windows) half of `VCL/SndCustm.pas`:

- `TWaitThread.Execute` now uses **`Queue(ProcessEvent)` instead of
  `Synchronize`**. The feeder thread never waits for the main thread, so the
  join in `DoSetEnabled` is always reachable. Pacing is unaffected: it comes
  from `pa_simple_write` blocking on the ~200 ms server-side buffer, not from
  the callback being synchronous. gtk2 wires `WakeMainThread` to a pipe whose
  GIO callback calls `CheckSynchronize`, and FPC's `ThreadQueueAppend` invokes
  `WakeMainThread` for queued entries too, so `Queue` is delivered just as
  promptly as `Synchronize` was. Outstanding queued events are bounded by the
  ring size, and `TThread.Destroy` calls `RemoveQueuedEvents`.
- New `FClosing` flag, set at the top of `DoSetEnabled(false)` and checked in
  `TWaitThread.ProcessEvent`. `WaitFor` pumps the queue while it waits, so a
  queued `BufferDone` could otherwise run the simulation — and re-enter
  `Enabled := false` — during teardown.

## New activity: SOTA

Added on request (2026-07-27, expanded 2026-07-28) — a new `TSimContest` value
`scSota`, "SOTA Activation" in the contest dropdown. Not a contest: the user is
the activator on a summit and the callers are chasers. Two data files, both
read from the working directory:

| File | Contents |
| --- | --- |
| `SOTA_Calls_CW.txt` | 78,835 caller callsigns, one per line |
| `summitslist.txt` | official summits CSV, 181,604 rows; only column 1 (`SummitCode`) is used |
| `cty.dat` | AD1C country file; maps callsigns *and* summit associations to a country |

### How a QSO runs

- **Plain QSO** — I send `<his> <report>`, the caller answers `R <report>`, I
  fill in the report and press Enter to send TU.
- **Summit-to-summit** — one caller in ten is himself on a summit and keys
  `R <report> <ref> <ref>`; I fill in report *and* reference.
- **`REF?`** — about 8% of callers want my own reference before finishing.
  The caller keys `R <#> REF?`; **F6** sends `REF <my reference> <my
  reference>` (keyed twice, as on the air; 2026-07-30); the caller answers
  `TU 73` (90%) or `AGN?` (10%, ask again). **F8** sends a bare `REF?` and
  makes the caller repeat its exchange, which is how a missed reference is
  recovered (moved from F7 on request 2026-07-30; F7 is the usual `?` again).
  Pressing Enter always completes the QSO regardless — the sub-protocol is
  never a trap.

Refinements after play-testing on Windows (2026-07-29):

- **An S2S caller always asks for my reference** once he has copied my
  exchange — he needs it for his own log. His ask is `R <#> REF?` (his
  exchange first, then the question), so `SetState(osNeedMyRef)` replaced
  `osNeedEnd` for callers with `Station.Exch2 <> ''`. Plain chasers keep the
  ~8% occasional ask. `TDxOperator` gained a `Station: TStation` back-pointer
  (set in `TDxStation.CreateStation`) so the state machine can see what its
  station sends.
- **A weak caller (reported me 339) mis-copies more often**: the 90%
  copied-OK gate in `MsgReceived` (`CopyGate`) drops to 65% for him, so he
  asks for repeats of my exchange ~3.5x more often, and fails to copy my
  F6 reference (`AGN?`) at the same higher rate.
- **An S2S repeat no longer keys the reference four times.** `msgR_NR2`
  (`R <#> <#>`, a random 10% "send it twice" that predates SOTA) interacted
  with the deliberate doubled reference inside `<#>` to produce 4 copies.
  `TSota.SendMsg` now renders `msgR_NR2` as `R <#>` for a caller with a
  reference. Not signal-strength related — it was always the random 10%.

**Keys.** F6 and F8 are remapped for SOTA only, in `TMainForm.SendMsg`, rather
than by retagging the buttons — the tags are shared with every other contest.
Captions are swapped in `SetContest`: `F6 REF` (was `F6 B4`, useless here) and
`F8 REF?` (was `F8 NIL`; the menu item behind it is confusingly named `AGN1`).
F7 keeps its usual `?`.

**Spacebar** stops at the RST field instead of skipping it — `call -> RST
(middle digit selected) -> Ref -> call`. Everywhere else RST is skipped because
it is always 599; here it has to be typed. `Advance` (after Enter) does the
same.

Reports are realistic rather than a fixed 599, and the two directions are
independent, as they are on the air:

- **What a caller reports to me** is drawn at random: 339 for the 15% who
  can barely hear me, otherwise 5x9 with only the readability digit moving
  (539–599). Keyed with cut numbers, so `579` goes out as `57N`.
- **What I report to a caller** comes from that caller's actual
  `TDxStation.Amplitude`, so it varies per QSO without my having to type it.
  Cached against the callsign being worked so repeating the exchange does not
  change it mid-QSO.

The setup Exchange box therefore holds **only my own summit reference**
(default `G/LD-001`); it may be left empty. The received exchange fields are
RST and Ref, and Ref is the one exchange field in the program that may
legitimately be empty — a caller not on a summit sends none.

### Who is on a summit, and where

Only a caller **signing portable or with a foreign prefix** can be on a summit
— a plain home callsign is someone at his own station. About a quarter of the
caller list signs that way, and 40% of those are given a summit, which lands
near one caller in ten overall.

The reference must belong to where the operator actually is:

```
LX/AB1DE/P   operating in Luxembourg  -> an LX summit
DL1GG/P      portable at home in DL   -> a DL summit
DL1GG        not portable             -> never on a summit
```

`TSota.LocationPart` takes **the first `/`-separated element** and nothing
else. That is the whole rule, and the reason for it is `2W0ILQ/M`: `M` is a
perfectly good England prefix, so anything that considers later elements reads
a Welsh station as English.

Country comes from **cty.dat** by longest-prefix match, with `=CALL` exact
overrides honoured and the `()[]<>{}~` CQ/ITU/coordinate overrides stripped.
The same lookup maps summit associations, because an association code *is* a
callsign prefix by SOTA convention — `W7O` → `W`, `KLA` → `KL`, `G` → `G`.
(This replaced an earlier DXCC.LIST-based attempt, which could not resolve a
bare `G`, `F` or `I` — three of the largest associations — without appending a
fake `1AA` suffix.) Measured by `tools/check-sota.py`: **248 of ~250 portable
callers in a 1000-call sample get a reference, and all 248 match their own
country.**

Only 500 summits per country are kept, by reservoir sampling, which bounds
memory without biasing the choice toward `-001`. All three files load in
~0.4 s.

### Scoring

One point per QSO with a constant multiplier, so Score = chaser count. "A point
only if the whole exchange is copied" is the **Verified** column, which
MorseRunner already restricts to error-free QSOs; the reference participates in
that check via `CheckExch2`.

### Code

New exchange field type `etSotaRef`, new station messages `msgSotaRef` /
`msgRefQm` / `msgAgnQm` / `msgTu73`, and one new operator state `osNeedMyRef`.
`osNeedMyRef` deliberately never reaches `osDone` on its own — only the user's
TU may do that, because `TContest.GetAudio` writes the caller's true data into
the log off `osDone`, and letting the caller finish by itself would attach that
data to the wrong QSO.

Files touched, following the `Adding a contest:` markers already in the source:

| File | Change |
| --- | --- |
| `Sota.pas` | **new** — `TSota`; call list, summit list, entity mapping, reports, `CQ SOTA <my>` |
| `ExchFields.pas` | `etSotaRef` + settings row (regex validated against all 181,604 codes) |
| `Ini.pas` | `scSota` enum value, `ContestDefinitions[]` entry (key `Sota`) |
| `Station.pas` | four new messages; `NrAsText` renders report + doubled reference |
| `cty.dat` | (data) read by `TSota.LoadCountryFile` |
| `DxOper.pas` | `osNeedMyRef`, `PendingReply`, the REF?/AGN?/TU 73 transitions |
| `DxStn.pas` | report left to the contest for SOTA; `DataToLastQso` case |
| `Contest.pas` | new message texts, validate/save cases |
| `Main.pas` | factory, F6/F7 remap + captions, `SetMyExch2`, field widths, Enter logic, spacebar/`Advance` |
| `Log.pas` | score table columns, log row, `CheckExch2` case |
| `MorseRunner.lpr` / `.dpr` / `.dproj` | register `Sota.pas` (Delphi build kept in step) |

### Verification

`tools/check-sota.py` drives the whole path headlessly (same throwaway-program
trick as `check-layout.py`) and all checks pass: field types and widths, setup
validation, reference/entity matching over 1000 callers, report distribution
and S2S rate over 2000 callers, what I key, the REF? sub-protocol over 200
rounds plus its frequency over 1000, and the log rows and score columns.

Bugs it caught along the way:

- `TStation.NrAsText` only rewrote `599` → `5NN` when `SentExchTypes.Exch1 =
  etRST`, so early SOTA callers keyed a long-form `599`.
- **Pre-existing, affected every contest on FPC:** `ScoreTableInit` deleted one
  column too many, so the score table lost its **Wpm** column. It ended the
  column loop and then did `while I < Columns.Count do Columns.Delete(I)`,
  assuming `I = High(ColDefs)+1`. The value of a `for` counter after the loop
  is not defined by the language and FPC leaves it at `High`. Now counted from
  the end against `Length(ColDefs)`. Verified against CQ WPX, which was equally
  affected.

### Runtime bug found and fixed: Run did nothing, silently

Reported as "the program doesn't start when I press start". Two faults, one of
them mine and one older:

1. The user's `MorseRunner.ini` held `SotaExchange=PA-PA003`. The canonical
   form is `PA/PA-003` (that summit exists), so validation rejected it and
   `TMainForm.Run` took its `Exit` path without starting.
2. **The refusal was invisible.** Exchange and callsign errors go to the status
   bar, and the status bar is hidden unless *Show callsign info* is on — it was
   off (`ShowCallsignInfo=0`). So the Run button appeared to do nothing at all.

Fault 2 is not SOTA-specific: any contest with an invalid stored exchange and
the status bar hidden behaved the same way, and it had been like that all
along. Fixes:

- `TMainForm.ReportCannotStart` puts the reason in a message box when Run
  refuses to start, instead of only in a status bar that may not be visible.
- A rejected exchange now leaves `UserExchangeDirty` True, so Run re-validates
  it and reports rather than sailing past a value that failed at load time.
- `TSota.NormaliseRef` accepts the separators being wrong or missing —
  `PA-PA003`, `PA/PA003`, `pa pa 003` all become `PA/PA-003` — and
  `SetMyExchange` writes the corrected form back into the Exchange box so the
  user can see what will actually be sent. Genuine nonsense is still rejected,
  now with an error naming the expected shape and two examples.

Reproduced before and after with a throwaway program built from
`MorseRunner.lpr` against a copy of the real `.ini`: before, `RunMode` stayed
`rmStop` with the reason only in the hidden bar; after, the box reads
`PA/PA-003` and `RunMode` is `rmPileup`.

### Runtime bug found and fixed: the QSO-rate histogram was a black box

Reported as "the field in the middle of the bottom bar shows a bar graph on
Windows, on Linux it is just black". `PaintBox1` in `Panel3`, painted by
`THisto.Repaint` (`Log.pas`). **Two independent faults**, only one of which is
a port bug:

1. **The near-black background — this is what was actually seen.** The paint
   box is `Color = clInfoBk`, the tooltip background. On Win32 that is pale
   yellow; under this gtk2 theme `ColorToRGB(clInfoBk)` is **`#343434`**, so
   the panel painted almost black and the dark-green bars barely registered
   against it. Nothing to do with the drawing code — it filled exactly the
   colour it was told to. Fixed in **`Main.lfm` only** (`clInfoBk` → `clCream`,
   `$F0FBFF`); `Main.dfm` still says `clInfoBk`, so Windows is untouched.

2. **The bars were laid out against the wrong control.** `THisto.Repaint` opened
   `with Self.PaintBoxH, Self.PaintBoxH.Canvas do` and then used bare `Width`
   and `Height`. **LCL's `TCanvas` publishes `Width`/`Height`; Delphi's VCL
   `TCanvas` does not**, and the last entry of a with-list wins — so on FPC
   those resolved to the canvas. A `TPaintBox` is a `TGraphicControl` with no
   window of its own, so its canvas is the *parent's* DC: measured during a
   real on-screen paint, it reports **450x134 (Panel3)** where the paint box is
   **448x132**. The bars were therefore drawn 2px low and their bottom row fell
   outside the box. Fixed by dropping the canvas from the with-list and
   qualifying `Canvas.Brush` / `Canvas.FillRect` explicitly — identical
   semantics under Delphi, where all four names already resolved to the paint
   box.

Note the visual weight: fault 2 is only a 2px shift here (Panel3 is barely
bigger than its child), so **fault 1 is the one the user saw**. `Color` was
checked too and resolves correctly to the paint box on both compilers.

New tool **`tools/check-histo.py`**, same throwaway-program pattern as the
others. Two measurement traps it had to work around, both worth remembering:

- **`Canvas.Pixels[]` reads back junk from a live control DC on gtk2** — probing
  three known-colour pixels returned `$8BF6A8`, `$C008E5`, `$34BAD4`. Pixel
  readback from a `TBitmap` is fine; from a widget's DC it is not.
- **`PaintTo` redirects `Canvas.Handle` to the target**, which changes the very
  quantity the bug depends on. Turned into an advantage: the probe renders
  `Panel3` into a bitmap deliberately *taller* than the panel, so buggy code
  puts the bars near y=300 and fixed code puts them just above y=132. Verified
  it fails on the unfixed source (bottom row 132) and passes on the fixed one
  (bottom row 130).
- gtk2 double-buffers, so `PaintTo` can blit a backing store rendered before
  `QsoList` was populated; the probe `Invalidate`s and pumps first.

Regression run after the fix (2026-08-05, FPC 3.2.3 / Lazarus 4.8):
`lazbuild -B MorseRunner.lpi` links clean at 22,285 lines; `./UnitTests`
**897 passed, 0 failed, 60 skipped**; `check-layout.py` 0 overflows at all four
sizes; `check-sota.py` and `check-histo.py` all checks passed.

**Not verified:** that `clCream` looks right next to the surrounding panels.
`check-histo.py` proves the background is light (luma 250) and that the bars
contrast against it (175) — not that the shade is a good choice. Same caveat as
the layout work: needs a human at the GUI.

## Windows build verification (2026-07-28)

Done on a Windows 11 machine with both Delphi 13 (Embarcadero Studio 37.0,
`dcc32` 37.0) and Lazarus 4.8 / FPC 3.2.2 installed. `MorseRunner.dproj`
builds in Debug and Release, the app starts with SOTA active (all three data
files load), and `Test/UnitTests.dproj` passes 897/897 with 0 leaks —
matching Linux. Two fixes were needed, **both pre-existing or accidental,
neither a flaw in the IFDEF strategy**:

- `PerlRegEx/pcre.pas` — Delphi 13 rejects `{$WEAKPACKAGEUNIT ON}` in a unit
  with global data (E2203). **The unmodified upstream file fails the same
  way**, so this is compiler-version strictness, not port breakage. The
  directive now compiles only for FPC or `CompilerVersion < 37`; it only
  matters when the unit is built into a package, which MorseRunner never does.
- `Main.pas` — the port had changed `RichEdit1: TRichEdit` to `TMemo`
  unconditionally, which broke the Delphi build (`Main.dfm` still streams a
  `TRichEdit`, and `Log.pas` uses `DefAttributes` on it). Now split:
  `TMemo` under `{$IFDEF FPC}`, `TRichEdit` otherwise. Note: if the Delphi
  IDE form designer rewrites the field list it may drop the IFDEF — check
  this line after editing the form in the IDE.

### SOTA bug the Delphi build exposed (fixed)

Typing anything in exchange field 2 during a SOTA run raised
`invalid exchange field 2 type: etSotaRef` — `TMainForm.Exch2KeyPress`
(`Main.pas`) had no `etSotaRef` branch in its key-filter `case`, so every
keystroke fell into the `else assert(false, ...)`. **Linux never showed it
because FPC compiles with assertions off by default; Delphi's Debug config has
them on.** The bug was present on both platforms all along — on Linux the
filter silently allowed every character. Added the branch (letters, digits,
`/`, `-`, backspace). The empty-ref-for-a-plain-chaser scoring path needed no
change: `CheckExch2` (`Log.pas`) already compares plain equality, where
`'' = ''` for a chaser is correct.

Verified live on Windows by driving the real app with posted window messages
(F9 → pile-up starts, audio initializes; `WM_CHAR` into call/RST/Ref fields):
`G/LD-001` accepted verbatim, `?`/`*` filtered, no assert dialog, and
`WM_CLOSE` mid-run shuts down cleanly.

Command-line quirk, not a repo issue: `msbuild MorseRunner.dproj` on a user
account that has never run the Delphi IDE lacks
`%APPDATA%\Embarcadero\BDS\37.0\EnvOptions.proj`, so VCL `.res` files
(`Controls.res` etc.) are not found. Workaround:
`/p:DCC_ResourcePath=C:\Program Files (x86)\Embarcadero\Studio\37.0\lib\win32\release`.
Building from the IDE, or after the IDE has run once, does not need this.

The FPC side is unaffected: both fixes are inert under `{$IFDEF FPC}`, and
FPC 3.2.2 was verified to scan the skipped `{$IF}…{$IFEND}` nesting in
`pcre.pas` correctly.

## Bug / hygiene audit (2026-07-28)

Run on request. Tooling added: **`tools/check-leaks.py`**, which builds a
throwaway program from `MorseRunner.lpr`, drives the real form through
start/stop/contest-switch cycles from a timer under `Application.Run`, and
reports unfreed heap blocks (FPC `heaptrc`), open file descriptors, live
threads and RSS after each cycle.

### Verified clean

- **No memory leak per cycle.** heaptrc over 1 and 3 full SOTA
  create/load/use/destroy lifecycles: **28 unfreed blocks / 27,206 bytes,
  identical** — the fixed RTL/LCL startup singletons. The call list, the
  summits-by-country dictionary and its owned lists, and both cty.dat
  dictionaries are all released.
- **Sound device and thread are released.** File descriptors go 20 → 24 while
  a run is active and back to 20 on stop; threads 10 → 12 and back to 10.
  Flat across five cycles, so the PulseAudio stream is closed and the feeder
  thread joined every time.
- **Closing the window mid-run is safe.** `FormClose` disables the sound
  output (joining the thread and closing the stream) *before* `FormDestroy`
  frees `Tst`, which the audio callback calls into. Tested by closing without
  stopping: clean shutdown, fds and threads back to baseline.
- **RSS drifts ~1.5 MB per contest switch but does not leak.** Every
  `SetContest` destroys and rebuilds the contest, re-parsing the 25 MB summits
  file; freed blocks are retained by the FPC heap manager rather than returned
  to the OS. heaptrc confirms nothing is actually lost.

### Fixed

- **Missing SOTA data file gave a bare `EFOpenError`.** SOTA needs three files;
  `TSota.RequireFile` now names the missing one and where it was expected.
- **`Tst.Free` in `FormDestroy` left a dangling global.** Now `FreeAndNil`,
  with an `Assigned(Tst)` guard in `AlSoundOut1BufAvailable`. Not reachable
  today (`FormClose` stops the audio first), but it turns a whole class of
  shutdown-ordering mistake from a use-after-free into a no-op.

### Known, not changed

- **`ParamStr(1)` is used as a data-directory prefix** by every contest
  (`ParamStr(1) + 'CQWWCW.txt'`). Any command-line argument therefore breaks
  data loading — `./MorseRunner -h` looks for `-hDXCC.LIST`. Upstream design;
  it cost time when a test harness passed an argument.
- ~~`GetExchange(id; out station: TDxStation)` reads `station` before writing
  it~~ — fixed in the 2026-07-29 Windows audit: `out` changed to `var` in
  `Contest.pas` and all 12 overrides. Behaviour is identical (`out` never
  cleared a class reference); the contract now says what it means and the
  FPC 5037 warnings go away.
- The remaining warnings are benign: `3175` (unlisted fields in typed constant
  arrays are zero-filled) and `4110` (the deliberate `TSimContest(-1)` sentinel
  casts in initialization sections).

### Caveat

`heaptrc` cannot be used on the full GUI + audio path here — it is SIGKILLed
regardless of the data set, so the GUI figures above rest on the fd/thread/RSS
evidence rather than on block accounting. The heaptrc numbers come from the
headless contest-lifecycle run, which is where the code added on this branch
lives.

### Not verified yet

- **Interactive runtime behaviour is only partly exercised.** Stop now works.
  Audio output, keying and timing during a run are still unconfirmed.
- SOTA has not been *played* — `check-sota.py` proves the wiring, not that a
  run feels right: pileup density, whether 10% S2S and 8% `REF?` are the right
  rates, and whether copying a 10-character reference at speed is reasonable.
- Audio latency / underruns of the Pulse feeder thread under load.
- WAV recording round-trip on Linux.

## Windows bug/hygiene audit (2026-07-29)

Re-run of the Linux audit on the Windows/Delphi build (heaptrc had SIGKILLed
the GUI path on Linux; Delphi's FastMM + a probe program cover it here).
Method: full-warning compile, review of every changed file plus the Win32
waveOut path, and a probe built from the real units that measures FastMM
allocated bytes, process handles and threads across live audio run/stop
cycles, all-contest switches, single-calls mode, and closing mid-run.

### Verified clean

- **No heap growth per run/stop cycle**: allocated bytes byte-identical
  across audio cycles 2-5 (5,584,480). Contest switching returns to baseline
  exactly (the ~5 MB of SOTA data is freed on switch-away). Freeing the form
  drops the heap to 49 KB — everything the app owns is released.
- **Sound hardware is released on stop-without-close**: `TAlSoundOut.Stop`
  does `waveOutReset` → unprepare all buffers → `waveOutClose`, called from
  `Enabled := false` on every stop. Handles/threads return to their steady
  state after each stop and after closing mid-run (312→285 handles, 8→6
  threads). The WAV recording file is closed on stop too (`TMainForm.Run`).
- **Crash paths**: an exception in the audio callback shows the error and
  terminates via component destruction (device closed); on a hard crash the
  OS reclaims the waveOut device and file handles.
- Delphi unit tests: 897/897, 0 leaked. Compiler diagnostics are all benign
  (defensive `Result := false` hints, upstream deprecated `Resume`, provable
  case-coverage W1035 in `GetReply`).
- The ini round-trip on a fresh install writes a complete, re-readable file
  (`Call=VE3NEA`, `SerialNrCustomRange=01-99`, ...).

### Fixed

- **`GetExchange` `out` → `var`** in `Contest.pas` + 12 overrides (see above).
- **Win32 `DoSetEnabled` failed-start handling** (`VCL/SndCustm.pas`,
  upstream bug): if `waveOutOpen` failed, the component stayed flagged
  enabled with a nil thread — re-enabling was impossible and the next
  disable called `Terminate` on nil. Now mirrors the FPC half: `FEnabled :=
  false` on the exception path and a nil-guard before `FThread.Terminate`.

### Noted, not changed

- `dwUser := DWORD(Buf)` in `SndOut.pas` truncates a pointer — fine for the
  Win32-only target, would break a Win64 build.
- The FPC-only `PostHiScore` creates three objects before its `try`; a
  constructor failure in the 2nd/3rd would leak the earlier ones. Theoretical.
- **Probe-writing gotcha** (cost an hour, worth remembering): a throwaway
  program that creates `TMainForm` but never calls `Application.Run` must
  `Free` the form explicitly before the program ends. Left to unit
  finalization, `FormDestroy → ToIni` runs *after* `Ini.pas`'s global
  strings are finalized and writes an ini full of empty values, which the
  next start rejects with a modal error. The real app is unaffected (the
  VCL exit path frees the form while units are alive — verified) and the
  probes use their own `<probename>.ini`, so no user data is at risk.

## Linux re-verification after the Windows work (2026-07-29)

Checked that the fixes made for the Delphi 13 build did not regress FPC.
**Nothing broke — the Linux side is unchanged.** FPC 3.2.3 / Lazarus 4.8:

| Check | Result |
| --- | --- |
| `lazbuild -B MorseRunner.lpi` | links clean, 22,275 lines, hints/benign warnings only |
| `lazbuild -B Test/fpc/UnitTests.lpi` + `./UnitTests` | **897 passed, 0 failed, 60 skipped** — same as baseline |
| `tools/check-layout.py` | 0 overflowing controls at all four sizes |
| `tools/check-sota.py` | all checks passed |
| `tools/check-leaks.py --no-heaptrc` | fds 20→24→20, threads 10→12→10, flat over 5 cycles |

The three shared-code fixes from the Windows audit are all inert or correct on
FPC, confirmed by inspection as well as by the build:

- `PerlRegEx/pcre.pas` — `{$WEAKPACKAGEUNIT ON}` still applies under
  `{$IFDEF FPC}`; FPC skips the `{$IF CompilerVersion < 37}` branch cleanly.
- `Main.pas:83-88` — the `TMemo` / `TRichEdit` `{$IFDEF FPC}` split survived
  the Delphi IDE (worth re-checking after any IDE form edit, per the note
  above).
- `GetExchange` is `var station` in all **25** declaration/override sites,
  none left as `out`.
- `Exch2KeyPress`'s `etSotaRef` branch (a Delphi-assertion-only bug) is
  present and harmless on FPC.

Line endings were **not** mangled by editing on Windows: every Pascal source
in the tree is still LF-only. (The branch normalised the CRLF upstream files
to LF long ago, which is why `git status` shows nearly every file modified —
pre-existing, not new.)

Only pre-existing caveat reconfirmed: `check-leaks.py` **with** heaptrc is
still SIGKILLed on the GUI path (`rc=-9`, no summary), exactly as documented
above. Use `--no-heaptrc` for the GUI figures.

## Next steps

1. Eyeball the main window after the layout fixes — `check-layout.py` proves
   nothing is clipped, not that spacing looks good.
2. Run `./MorseRunner`, start a contest, confirm audio + keying are correct.
   (Needs a human at the GUI — Wayland, and no `xdotool` installed.)
3. Exercise WAV recording (Settings → audio recording) and playback.
4. `ScoreDlg.lfm` has had no layout pass at all; it likely has the same group
   box / control-height issues as the main form.
5. Consider `lazarus-lcl-qt6` + `qt6pas` (both packaged on Fedora) instead of
   gtk2 — better HiDPI and a far more modern look. Set `LCLWidgetType` in
   `MorseRunner.lpi`. Not attempted yet.
6. Commit the branch once runtime is confirmed.

## Conventions

- Never remove the Windows code path — add the Linux one alongside it.
- `{$IFDEF MSWINDOWS}` for OS-specific APIs; `{$IFDEF FPC}` for
  compiler/RTL/LCL-vs-VCL differences.
- Keep this file updated as work progresses.
