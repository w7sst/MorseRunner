# MorseRunner — Linux/Lazarus port

Working branch: `linux-lazarus-port` (off `main`). Upstream is a Delphi/VCL Win32 app;
this branch makes it build and run on Linux under Lazarus/FPC **without forking** —
all platform splits use `{$IFDEF MSWINDOWS}` / `{$IFDEF FPC}` so the Delphi build
stays intact.

## Toolchain

- FPC 3.2.3, Lazarus 4.8 (`lazbuild`, `/usr/bin/lazarus-ide`)
- Build: `lazbuild MorseRunner.lpi` → `./MorseRunner`
- Units out to `lib/x86_64-linux/`
- Two build modes in `MorseRunner.lpi`:
  - **Default** (the default) — `-O1`, DWARF3 debug info, ~32 MB binary
  - **Release** — `lazbuild --build-mode=Release MorseRunner.lpi`; `-O3`,
    smart linking, no debug info, stripped → **3.7 MB**. Units go to
    `lib/x86_64-linux/release/`; both modes link to `./MorseRunner`, so
    always `-B` when switching modes. Use this for packaging (replaces the
    manual `strip MorseRunner` step noted below).
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

**Repo state (2026-08-05):** all of the above is committed as `defde9d`
"MorseRunnerCE-SOTA" on `linux-lazarus-port`, pushed to the user's own repo
`github.com/taekehf/MorseRunnerSOTA` (`origin`; the upstream w7sst repo is
the `upstream` remote). `main` still carries a junk commit `47cb11e` on top
of upstream — only the compiled 32 MB Linux binary and the regenerable
`Test/fpc/gen/` files; the plan (agreed, not yet executed) is
`git switch main && git reset --hard linux-lazarus-port &&
git push --force-with-lease origin main`, which puts the real code on main
and drops the blob from history. Release archives (Win32 Release exe +
Linux binary, each with all data files incl. the three SOTA files) are in
`D:\projects\MorseRunner-release\`, ready to attach to a GitHub release
targeting the code branch. The Linux binary is unstripped with DWARF3
debug info (`MorseRunner.lpi` builds -O1 with dsDwarf3) — ~32 MB instead
of ~6; `strip MorseRunner` on Linux (or a Release build mode in the .lpi)
before the next packaging.

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
  **Correction (2026-08-16): this is wrong — it was measured on an unrealised
  form.** Those are the streamed `.lfm` values, which is all a control reports
  before it has a widget. After `MainForm.Show` + `ProcessMessages`, gtk2
  autosizes them to the scaled font: at 192 dpi `Label1` is 45x30 (its font
  needs 30), `CheckBox4` 77x34, `ComboBox1` 130x42, `Edit1` 236x62,
  `SpinEdit1` 130x47. Heights do scale. What does *not* hold is that they
  scale to exactly 2x the Win32 design value (23 -> 42, not 46), which is the
  metric mismatch described next. Any future probe that reads control geometry
  must show the form first.
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

**Corrected 2026-08-23 — the old rule was wrong.** It took *the first*
`/`-separated element and nothing else, which gave `K0EMT/VE9` (a US call
operating in New Brunswick) a `W5T` summit. `TSota.SplitLocation` now returns
both where he is and which call area applies:

| signed | location | area | because |
| --- | --- | --- | --- |
| `LX/AB1DE/P` | `LX` | - | a leading prefix names the location and outranks any suffix |
| `K0EMT/VE9` | `VE9` | 9 | a trailing prefix relocates him (mostly a North-American habit) |
| `JL1EFV/5` | `JL1EFV` | 5 | a trailing digit keeps the country, changes the call area |
| `DL1GG/P` | `DL1GG` | 1 | `/P` is a modifier and says nothing about location |
| `2W0ILQ/M` | `2W0ILQ` | 0 | the original trap: `M` is mobile, not England |

The base callsign is the longest `/`-separated element; anything before it is a
location prefix, anything after it is a suffix. A **trailing single letter is
always a modifier** — that is what keeps `2W0ILQ/M` Welsh, since `M` is also a
valid England prefix. `MM`, `AM`, `QRP`, `QRPP`, `LH` and `BCN` are modifiers
too; any other trailing element is treated as a prefix that relocates him.

Country comes from **cty.dat** by longest-prefix match, with `=CALL` exact
overrides honoured and the `()[]<>{}~` CQ/ITU/coordinate overrides stripped.
The same lookup maps summit associations, because an association code *is* a
callsign prefix by SOTA convention — `W7O` → `W`, `KLA` → `KL`, `G` → `G`.
(This replaced an earlier DXCC.LIST-based attempt, which could not resolve a
bare `G`, `F` or `I` — three of the largest associations — without appending a
fake `1AA` suffix.) Measured by `tools/check-sota.py`: **248 of ~250 portable
callers in a 1000-call sample get a reference, and all 248 match their own
country.**

Summits are indexed **per association** (`W7O`, `JA5`, `VE9`), not per
country, because the country alone loses the call area — that was the other
half of the `K0EMT/VE9` bug. `PickSummitFor` prefers an association whose
call-area digit matches the operator's, falls back to the country-wide
associations that carry no digit (a JA1 station belongs in plain `JA`, since
only JA5/JA6/JA8 are split out), and only then to anywhere in the country.

That last fallback is doing real work and is correct: Russia has only `R3` and
`R9U`, so an `RD6A/P` gets `R3`; and where the digit belongs to the country
prefix itself rather than to a call area (`9A` Croatia, `S5` Slovenia, `CT3`
Madeira) nothing matches and the sole association is used. Measured over the
real call list: 370 of 378 portable callers get a reference, 175 of those
match on call area exactly, and the picker never mixes areas for one caller.

200 summits per association are kept, by reservoir sampling, which bounds
memory without biasing the choice toward `-001` and — unlike the old 500 per
*country* — cannot let a whole call area fall out of the sample. All three
files load in ~0.4 s.

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
  `Contest.pas` and all 12 overrides. **Superseded upstream 2026-08-09** by
  w7sst commit `a2bfed0`, which drops the modifier entirely: `station` is a
  class reference, so it is already a pointer and `var` only adds a level of
  indirection to every field access. The signature is now
  `GetExchange(id: Integer; station: TDxStation)` everywhere. The original
  `out` complaint is still answered — that was the point — and the extra
  indirection is gone with it.
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
  Later superseded by upstream `a2bfed0`, which removes the modifier
  altogether — see the note above.
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
- `GetExchange` was `var station` in all **25** declaration/override sites,
  none left as `out`. Since 2026-08-23 it carries no modifier at all in any
  of them (upstream `a2bfed0`); `JarlContest.pas`, which postdates that
  commit, had to be brought into line by hand.
- `Exch2KeyPress`'s `etSotaRef` branch (a Delphi-assertion-only bug) is
  present and harmless on FPC.

Line endings were **not** mangled by editing on Windows: every Pascal source
in the tree is still LF-only. (The branch normalised the CRLF upstream files
to LF long ago, which is why `git status` shows nearly every file modified —
pre-existing, not new.)

Only pre-existing caveat reconfirmed: `check-leaks.py` **with** heaptrc is
still SIGKILLed on the GUI path (`rc=-9`, no summary), exactly as documented
above. Use `--no-heaptrc` for the GUI figures.

## "The radio sound isn't as good" (2026-08-16)

A user comment on the release: the band noise heard after starting, before
anything is happening, is worse than VE3NEA's original. A copy of the original
1.68 source was dropped in `/mnt/data/projects/Morserunnerve3nea/MorseRunner`
to compare against.

**The synthesis code is not the cause — it is identical.** Every unit that
contributes to that sound was diffed against 1.68 (ignoring CRLF) and the
bodies match:

| Unit | Verdict |
| --- | --- |
| `Contest.pas` `GetAudio` noise block, `Create` filter/AGC setup, `SwapFilters` | identical |
| `QrnStn.pas`, `QrmStn.pas`, `StnColl.AddQrn/AddQrm` | identical (CE adds exchange-type wiring only) |
| `Qsb.pas`, `VCL/MovAvg.pas`, `VCL/Mixers.pas`, `VCL/VolumCtl.pas`, `VCL/QuickAvg.pas`, `VCL/SndTypes.pas` | identical apart from `{$IFDEF MSWINDOWS}` on uses clauses |
| `TStation.GetBlock`, `TMainForm.SetPitch/SetBw`, `ReadCheckboxes` | identical |
| `Main.dfm` `AlSoundOut1` | same 11025 Hz, `BufCount = 8` |

The differences that do exist elsewhere are deliberate CE changes and affect
CW, not the noise floor: `VCL/MorseKey.pas` timing (48U vs 50U word, `~`
spacing), `RndFunc.RndGaussLim` (rejection sampling instead of clipping), the
self-monitor gain curve in `GetAudio` (proper dB scale plus a rolloff to zero),
and `TContest.OnMeFinishedSending`'s no-activity fallback.

### The actual cause: band-condition defaults

Upstream CE commit `93ebedb` "change MR defaults to match Alex in Ontario"
flipped **QRN, QRM, QSB, Flutter and LIDs from on to off**, in `Ini.pas` and in
the `Main.dfm` checkboxes. A fresh install has no `.INI`, so a new user hears
flat filtered noise: no static crashes, no other stations on frequency, no
fading. That is precisely "the radio emulation isn't as good".

Reverted to the 1.68 values in `Ini.pas` and re-ticked `CheckBox2..6` in both
`Main.dfm` and `Main.lfm`. Measured with `tools/check-audio.py --fresh`, the
crest factor of the recorded audio (peak over RMS — static crashes are short
and loud, so QRN lifts the peak well above the noise):

| Fresh install | Crest factor |
| --- | --- |
| all five off (CE default) | **12.3 dB** — plain Gaussian noise, a dead band |
| all five on (restored) | **18.4 dB** |

An existing `MorseRunner.ini` still wins, so this only changes first-run
behaviour. Note the repo's own `MorseRunner.ini` has `Qrm=0`; that is a stored
user setting, not a default.

`Qsk` also defaults to false in CE against true upstream (commit `10c6692`,
"QSK should be off by default"). Left alone — QSK only matters while *you* are
sending, so it is not part of the complaint.

### New tool: `tools/check-audio.py`

Written to rule the Linux audio path in or out, since identical DSP code meant
the fault could only have been in delivery. Same throwaway-program pattern as
the other probes: it builds a program from `MorseRunner.lpr`, creates the real
`TMainForm`, turns on WAV recording (which captures exactly what
`TContest.GetAudio` produced, before the sound device sees it), runs a pile-up
under `Application.Run` and stops. Meanwhile the app is pinned to a private
null sink via `PULSE_SINK` and `parec` records that sink's monitor.

**The Linux output path is transparent** — it is not the problem:

- block rate 21.49/s against the expected `DEFAULTRATE/BufSize` = 21.53/s, so
  the feeder thread paces the simulation correctly;
- zero dropouts (no 23 ms frame below 10% of the median RMS over 8 s);
- the played-back spectrum matches the WAV bin for bin within ~1 dB across
  0–3 kHz, and the peak sample is the same (19173 vs 19170).

Measurement traps it had to work around, both worth remembering:

- **The default sink's monitor is useless.** It carries every other stream on
  the desktop; a first attempt recorded full-scale broadband audio with a flat
  spectrum that looked like catastrophic distortion and was in fact somebody
  else's audio. Recording a purpose-made null sink is the only clean way.
- **The first second must be discarded when measuring pacing.**
  `TAlSoundOut.Start` primes one block per buffer at once, and
  `TContest.GetAudio` returns a 1-sample block until `BlockNumber` reaches 6 —
  neither is paced by the sound server, and counting them puts the apparent
  rate 4% high.

Regression after the change (FPC 3.2.3 / Lazarus 4.8): `lazbuild -B` links
clean at 22,290 lines; `./UnitTests` **897 passed, 0 failed, 60 skipped**;
`check-layout.py` 0 overflows at all four sizes; `check-sota.py`,
`check-histo.py` and `check-audio.py` all checks passed.

**Not verified:** that a human agrees the restored band sounds like the
original. The crest-factor and spectrum figures prove the noise is the same
signal the original code makes and that the defaults now match 1.68 — not that
the commenter's ear is satisfied. `Main.dfm` was edited but the Delphi build
has not been re-run.

### The clock read cyan on grey (2026-08-16)

Reported as "the timer is cyan". `Panel2` (the `hh:nn:ss` elapsed clock,
written by `Contest.pas:847`) carries `Font.Color = 14151712` = `$D7F020`,
which as a `TColor` is `$00BBGGRR` = **RGB(32, 240, 215)**, cyan. 1.68 has the
*same* cyan digits — the difference is the panel behind them: upstream is
`Color = clBlack`, CE changed it to `Color = clBackground`. That is the
*desktop* colour, which this gtk2 theme resolves to **`#E7E8E8`**, so cyan
digits ended up on pale grey instead of on black.

Fixed in **`Main.lfm` only**: `Font.Color = clBlack`. Verified with a
throwaway probe that reads the resolved colours off the live form:
`Panel2.Color = E7E8E8`, `Panel2.Font = 000000`.

`Main.dfm` is **not** changed, so Windows keeps the cyan digits. Deliberate:
`clBackground` there is whatever the user's Windows desktop colour is, and on a
dark desktop black digits would be unreadable. If Windows should match, the
robust change is to set `Color = clBlack` as well, not just the font — but that
needs a look at the real Delphi build.

### DPI awareness: where it stands (2026-08-16)

Asked whether the GUI can be made DPI-aware on both platforms. Largely it
already is; measured rather than assumed.

**Linux/LCL — works today.** `Application.Scaled := True` (`MorseRunner.lpr`)
plus `DesignTimePPI = 96` in `Main.lfm`/`ScoreDlg.lfm`. On the 192 dpi dev
machine the form comes up 1458 wide, exactly 2x the designed 729; fonts double
(`-12` -> `-24`, Panel2 `-24` -> `-48`); positions double; and once realised,
controls autosize to the scaled font (see the correction under "UI /
appearance"). Limits: LCL reads the DPI once at startup, so dragging the window
to a differently-scaled monitor does not re-lay-it-out — gtk2 has no
per-monitor DPI. Fractional scales (125%, 150%) are also weaker on gtk2 than
the integer 2x measured here. The `lcl-qt6` switch already listed in Next
steps is the real fix for both.

**Windows/Delphi — verified working (2026-08-16).** `AppDPIAwarenessMode =
PerMonitorV2` in `MorseRunner.dproj` (both Win32 configs) produces a manifest
carrying both `dpiAware: true/pm` and `dpiAwareness: PerMonitorV2`, and the
VCL scales the form correctly. Measured on a dev box with a 3840x2160 primary
at **150% (144 dpi)** and a 1920x1080 secondary at 100%:

| | client | form font | `Edit1` |
| --- | --- | --- | --- |
| designed (96 dpi) | 729x506 | -12 | 118x27 |
| on the 150% monitor | **1094x759** (1.501x) | -18 | 177x36 |
| dragged to the 100% monitor | 728x504 | -12 | 118x27 |

So per-monitor rescaling happens on `WM_DPICHANGED` as well as at startup,
in both directions (the 1-2 px lost on the round trip is integer rounding).
A Windows port of the layout probe reported **0 overflowing controls** at
150%, so the Win32-absolute layout survives VCL scaling — unlike gtk2, VCL
scales positions, sizes and fonts homogeneously, which is why the group-box
overflows seen on Linux have no Windows counterpart.

Both earlier loose ends are closed:

- **`Main.dfm` needs no `PixelsPerInch` line.** Adding `PixelsPerInch = 96`
  was tried and measured to be a **no-op** — 1094x759 either way — because
  `TCustomForm` initialises the field to the design DPI already. The line was
  reverted rather than left in as decoration. (`ScoreDlg.dfm` has one only
  because the IDE wrote it.)
- `BorderStyle = bsSingle` is not a trap: scaling does not overshoot.

**Measurement trap that cost an hour and will do so again.** A DPI-*unaware*
process asking about another process's window gets **virtualised** rectangles:
PowerShell/C# `GetClientRect` on the running app returned exactly 729x506 —
the scaled 1094x759 multiplied by 96/144 — which looks precisely like "scaling
is broken". `GetDpiForWindow` is *not* virtualised, so the giveaway is a
window reporting 144 dpi while its client rect still reads the design size.
Any probe must call `SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2)`
(-4) before measuring; a Delphi probe built with bare `dcc32` has no manifest
and is unaware by default, so it must do the same or it will report 96
everywhere.

**The standing risk is Linux-side only:** the layout is Win32-absolute
positions, so scaling exposes metric mismatches rather than reflowing. That is
exactly what bit the right-hand group boxes on gtk2; VCL scaling is uniform
and showed no overflow at 150%. Any DPI work needs the `check-layout.py` pass
afterwards, and layout fixes have to be made twice — `Main.lfm` for Linux,
`Main.dfm` for Windows.

#### Fractional scales: swept with Xephyr, one real bug found and fixed

`tools/check-layout.py` gained **`--dpi 96,120,144,192`**, which runs the probe
against a nested `Xephyr` started at each resolution (`Xephyr :N -screen
2600x1900 -dpi X`). The screen must be larger than the biggest window the probe
asks for (2400x1700) or `SetBounds` is clamped and the wide-window passes test
nothing. Xephyr opens a window on the desktop while the sweep runs.

The sweep is self-checking: it prints the form font height alongside the DPI,
and those track exactly — `-12 / -15 / -18 / -24` for 96 / 120 / 144 / 192,
with form widths 729 / 911 / 1094 / 1458 = 1.0 / 1.25 / 1.5 / 2.0x the designed
729. If a scale factor did not really take, the font gives it away first.

**The bug was at 100%, not at the fractional scales.** At 96 dpi
`ExchangeEdit` sat at top 44 with a realised height of 32, ending at 76 inside
a `ContestGroup` whose client height is only 74 — the same gtk2 caption-inset
overflow that was fixed for the right-hand boxes before, except the earlier fix
was tuned at 192 dpi only and left the unscaled case 2px over. **That is the
common case** — an ordinary 1080p Linux desktop at 100% — so it shipped broken
for most users while the 200% dev machine looked fine.

Fixed by raising `ContestGroup.Height` 90 -> 96 in **`Main.lfm` only** (gtk2
inset; VCL has no equivalent, so `Main.dfm` is untouched). Now clean at eight
scale factors: **96, 108, 120, 132, 144, 168, 192 and 240 dpi**, 0 overflowing
controls at all four window sizes each.

Lesson: a layout probe run at a single DPI proves nothing about the others, and
the *designed* DPI is the one most likely to be skipped.

#### What did not work: faking the DPI in-process

Recorded so it is not attempted again. Before Xephyr was installed, three
routes were tried and all three measure the harness rather than the app:

- **`Application.Scaled := False` + one `AutoAdjustLayout(96 -> target)`.**
  Without `Application.Scaled` the LCL does not scale the fonts the way the
  shipping path does: the form font came out `-8` at 120 dpi and `-9` at 144
  where it should be `-15` and `-18`. Every autosized control is then the wrong
  size. Proof it was invalid: forced-192 reported a Label19 overflow that the
  real 192 run does not have.
- **`Application.Scaled := True` + a second `AutoAdjustLayout(192 -> target)`.**
  The form would not shrink at all (1458 wide for every target) because
  `Constraints.MinWidth/MinHeight` had themselves been scaled to 1458x1120 on
  load, and the font stayed `-24` throughout.
- **Clearing the constraints first, then re-adjusting.** Hung the probe — no
  output, had to `kill -9`. Presumably an autosize loop on an already-shown
  form.

- **Faking the DPI from the environment does not work either.** `XENVIRONMENT`
  pointing at a file with `Xft.dpi: 144` changed nothing: GNOME's XSETTINGS
  daemon supplies Xft/DPI and gtk2 prefers it over the X resource database.

All of that was thrown away once `xorg-x11-server-Xephyr` was installed — a
nested server at the wanted DPI is the only faithful method, and it is what
`--dpi` now uses.

## SOTA: summit references now follow the call area (2026-08-23)

Reported from play-testing: a caller signing `K0EMT/VE9` was sent `W5T/NT-111`
-- the reference matched his *home* prefix instead of where he actually was.
Two independent causes, both fixed; see "Who is on a summit, and where" above
for the rules and the measured results. In short: `LocationPart` read only the
first `/`-separated element, and summits were indexed by DXCC entity, which
threw the call area away. `tools/check-sota.py` gained assertions for the new
cases (`K0EMT/VE9` -> VE9, `JL1EFV/5` -> JA5, `JL1EFV` -> JA, `W1AW/7` -> W7x,
`2W0ILQ/M` -> GW).

## Branch-wide cleanup (2026-08-23)

Follow-up to the audit below, run once the user confirmed upstream merges with
w7sst no longer matter — the deferred items became actionable. All changes are
compiler-verified plus behaviour-verified; Delphi tests stayed 897/897
throughout and the app builds Release with **no warnings**, only the five
deliberate `H2077` "value assigned never used" hints (defensive
`Result := false` initialisers; removing them would let a fall-through return
an undefined value).

- **`const` on 58 string parameters** across 21 units. Five routines used
  their parameter as a scratch variable and now take a local copy instead:
  `ExtractPrefix` (`Util/CallsignUtils.pas`), `CallToScore` (`Log.pas`),
  `TMyStation.AddToPieces`, `TQrmStation.SendText` and `TStation.SendText`.
  The compiler found every one of them (E2064/E2197) — this is the pass where
  the compiler does the auditing for you. Object-reference parameters were
  deliberately **not** made `const`: it buys nothing (no refcount) and
  misleads, since the pointed-to object stays mutable.
- **`ACAG.pas` and `ALLJA.pas` were literally the same program.** After
  normalising the contest name, only comments differed; the sole functional
  difference is the call-history file. Extracted **`JarlContest.pas`**
  (`TJarlContest`, with `CallHistoryFileName: string; virtual; abstract`); the
  two units are now 32-line descendants naming their file. 483 lines -> 318.
  Proved behaviour-identical by `JarlProbe`, a characterisation probe that
  dumps call/exch1/exch2/info for 25 stations of each contest under a fixed
  `RandSeed`: output is byte-for-byte identical before and after.
- **The other "clone" pairs were left alone** — measured, not assumed:
  CWOPS/CWSST differ in 160 non-comment lines, ArrlDx/IaruHf in 189,
  MorseKey/FarnsKeyer in 300. They share shape, not behaviour; merging them
  would invent commonality that is not there.
- **Audio-layer duplication removed**: six routines were byte-identical in
  both halves of `VCL/SndCustm.pas` (`Err`, `Loaded`, `SetEnabled`,
  `SetDeviceID`, `GetBufCount`, `SetBufCount`). They now live in one shared
  section below the `{$ENDIF}`; both class declarations still declare them, so
  each platform compiles exactly one copy. Verified structurally (each defined
  once, `SndTypes`/`ESoundError` reachable from both uses clauses) and at
  runtime on Windows (audio starts, stops, exits clean). **Since verified on
  Linux too** (2026-08-23): builds clean, and `check-audio.py` measures the
  feeder thread still pacing at 21.48 blocks/s with 0 dropouts.
- **`Main.pas` score-append duplication** (identical blocks in
  `PopupScoreWpx` and `PopupScoreHst`) extracted into `AppendLineToFile`.
- **Warnings fixed rather than silenced**: `W1035` on `TDxOperator.GetReply`
  (three `case Trunc(R2*n)` blocks got `else` branches that are unreachable
  because `Random < 1`, stating the guarantee the compiler cannot derive),
  `W1000` deprecated `FThread.Resume` -> `Start` (the FPC half already used
  `Start`), `W1057` UTF8String comparisons in `Util/Lexer.pas` asserts made
  explicit, and `W1023` signed/unsigned in `SndCustm` by casting the handle to
  `WPARAM`.

**Not done deliberately:** the five `H2077` hints (see above), and the ~150
lines of shared harness across `tools/check-*.py` (dev tooling, and each probe
genuinely diverges — Xephyr, parec, heaptrc).

**Test-coverage caveat that shaped all of the above:** the 897 tests cover
`CallsignUtils`, `DXCC`, the lexers and the SS exchange parser — and **no
contest unit, no keyer, no audio**. Anything touching those had to be verified
with purpose-built probes instead, which is why the JARL merge got a
characterisation probe before it was attempted.

## Linux re-verification after the audit (2026-08-23)

The audit was written and verified on Windows/Delphi; this is the FPC pass over
the same working tree. **One real break, in the one place Delphi could not see
it**, plus a coverage gap that is now closed.

### The break: `const` on a parameter used as scratch space

`VCL/WavFile.pas` failed to compile — `Can't assign values to const variable`
at `TAlWavFile.ParseInfo`, which walks the LIST/INFO payload by `Delete`ing
chunks off the front of its own `Data` parameter. Same class of mistake the
`const` pass caught five times in shared code (`ExtractPrefix`, `CallToScore`,
`AddToPieces`, the two `SendText`s) — but `ParseInfo` lives inside
`{$IFNDEF MSWINDOWS}`, so **`dcc32` never parsed it and the Delphi build could
not have caught it**. Fixed the same way as the other five: a local `Rest`
copy.

Worth generalising: any tree-wide pass that leans on "the compiler will find
them" only covers the half of an `{$IFDEF}` that the compiler you ran actually
compiled. The Linux-only halves — `WavFile.pas`, `SndPulse.pas`, the `{$ELSE}`
side of `SndCustm.pas` — need a build on the other compiler before the pass
counts as done.

### Full regression, FPC 3.2.3 / Lazarus 4.8

| Check | Result |
| --- | --- |
| `lazbuild -B MorseRunner.lpi` | clean, 22,268 lines (was 22,290 — the JARL merge) |
| `lazbuild -B --build-mode=Release` | clean, **3.8 MB stripped binary** |
| `Test/fpc/UnitTests.lpi` + `./UnitTests` | **897 passed, 0 failed, 60 skipped** |
| `tools/check-sota.py` | all checks passed |
| `tools/check-histo.py` | all checks passed |
| `tools/check-audio.py` | 21.48 blocks/s, 0 dropouts, crest 17.2 dB, band conditions 1 1 1 1 1 |
| `tools/check-layout.py --dpi 96,120,144,192` | 0 overflowing controls, all 4 sizes at all 4 scales |
| `tools/check-leaks.py --no-heaptrc` | fds 20→24→20, threads 10→12→10, flat over 5 cycles |
| `tools/check-contests.py` | **new** — all 13 contests |

Release binary additionally smoke-tested by hand: starts, stays up, exits on
SIGTERM, and all five `dlopen`ed libraries resolve on this box.

### New tool: `tools/check-contests.py`

Written because **`JarlContest.pas` was new code in the FPC build that no probe
touched**. The audit collapsed `ACAG.pas` and `ALLJA.pas` onto a shared base
and proved it byte-identical *on Delphi*; on Linux the merge had only ever been
compiled, never run. The 897 unit tests cover no contest unit (see the coverage
caveat under "Branch-wide cleanup"), so there was nothing between "it links"
and "a user picks ALL JA".

Same throwaway-program pattern as the other probes. For each of the 13
`TSimContest` values it calls `SetContest`, then `OnContestPrepareToStart`
(which is what actually reads the call-history file), then draws 100 stations
via `PickStation` / `GetCall` and asserts every draw yields a callsign and the
draws are not all the same station. All 13 pass, ACAG and ALLJA included.

Two things it got wrong first, both worth remembering:

- **`Stations.AddCaller` is not the way in.** Called on a contest that has not
  been prepared, it dies silently — the probe printed two contests and exited
  0. The call history is loaded by `OnContestPrepareToStart`, not by
  `SetContest`, so `PickStation` was indexing an empty list. (`AddCaller` also
  dereferences `Result` after a `break` that can leave it nil — upstream, not
  touched.)
- **`TStation.NrAsText` is not public**; use the `Exch1` / `Exch2` fields.

## Code-quality audit (2026-08-16)

Asked for a review of initialisation, `const` usage and duplicate code, first
on the SOTA work and then across the whole tree (51 units, ~20,000 lines;
`PerlRegEx/` excluded as third-party).

### Applied

- **SOTA messages left the base class.** `msgSotaRef` / `msgRefQm` /
  `msgAgnQm` / `msgTu73` were rendered in `TContest.SendMsg`, where the
  `msgRefQm` branch was **unreachable** (`TSota.SendMsg` always handles it and
  never calls `inherited` for it). All four now live in `TSota.SendMsg`; the
  base class keeps only a comment pointing there.
- **`TSota.EntityOfPublic` deleted.** It was a pure pass-through to the
  private `EntityOf`, existing only so `tools/check-sota.py` could reach it.
  `EntityOf` is public now; the checker follows the rename.
- **`339` no longer hard-coded in two units.** `Sota.MakeRst` produced it and
  `DxOper.IsWeakCopier` tested `Station.RST = 339`, so changing the weak-signal
  report in `Sota.pas` would silently disable weak-caller behaviour with no
  compile error. Now `TContest.CallerCopiesPoorly(AStn): boolean; virtual`
  (False by default) with a `TSota` override against a named `WeakRst = 339`.
  `IsWeakCopier` also loses its `SimContest = scSota` test — the contest
  object decides.

Verified: 897/897 Delphi tests; a contest-aware probe reproduces the rates
(S2S asks 900/1000 with 0 skipped; weak-caller repeats 354 vs 84 strong,
ratio 4.2 against an expected ~3.5); every SOTA message still renders
(`REF <ref> <ref>`, `REF?`, `AGN?`, `TU 73`, `R 5NN <ref> <ref> REF?`) and
non-SOTA messages still reach the base class through `inherited`.

### Findings left alone (with reasons)

- **Initialisation is sound tree-wide.** No `W1036` anywhere; the only
  `W1035` (`GetReply`) is upstream and provably covered. All 45 `out`
  parameters are safe: the `FindCallRec` family are class references set to
  `nil` before use and all 11 call sites guard on the result. No raw
  `GetMem`/`New` without initialisation. Note Pascal does *not* zero locals
  (only class fields and managed types), so this rests on explicit assignment.
- **`const`: SOTA code is fully const-correct** (zero by-value string
  parameters). Upstream has **64** by-value `string`/`TStringList` parameters
  (`MyStn.pas` 6, `Station.pas` 5, `Main.pas` 4, ...). Cost is one refcount
  per call, none on an audio-block path; changing them would churn signatures
  across the tree and conflict with w7sst upstream merges.
- **Duplication is mostly upstream by design**: `ACAG.pas`/`ALLJA.pas` are
  near-clone JARL contests (30 repeated 8-line windows), `FarnsKeyer`/
  `MorseKey` 17, `CWOPS`/`CWSST` 8, and a copy-pasted score-append block in
  `Main.pas` (2378 and 2417).
- **The one duplication this branch introduced** is in the audio layer:
  `VCL/SndCustm.pas` has 6 routines byte-identical between its Win32 and
  PulseAudio halves (`Err`, `Loaded`, `SetEnabled`, `SetDeviceID`,
  `GetBufCount`, `SetBufCount` — ~23 lines) and `SndOut.pas` repeats its class
  declaration per platform. Hoisting those above the `{$IFDEF}` would remove
  the repetition, but it restructures the one component that has already
  produced a deadlock, it can only be tested for Windows from here, and the
  branch convention is explicitly to keep the platform paths side by side.
  Left as is; revisit only with a Linux run available.

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
6. ~~Commit the branch once runtime is confirmed~~ — done 2026-08-05
   (`defde9d`, pushed to `origin`). ~~Reset `main` onto the branch~~ — done,
   the working tree is on `main` now. ~~Strip the Linux binary and repackage~~
   — done 2026-08-23 via the Release build mode (3.8 MB, stripped). Still
   open: publish the GitHub release from
   `/mnt/data/projects/MorseRunner-release/2026-08-23/`, and commit the
   audit changes plus this CLAUDE.md update.

## Conventions

- Never remove the Windows code path — add the Linux one alongside it.
- `{$IFDEF MSWINDOWS}` for OS-specific APIs; `{$IFDEF FPC}` for
  compiler/RTL/LCL-vs-VCL differences.
- Keep this file updated as work progresses.
