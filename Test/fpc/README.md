# Running the unit tests on Linux (FPC / Lazarus)

```sh
python3 tools/gen-fpc-tests.py     # regenerate Test/fpc/gen/
lazbuild Test/fpc/UnitTests.lpi    # builds ./UnitTests in the repo root
./UnitTests                        # exit code 0 when everything passes
```

Run both commands from the repository root. The runner must stay in the repo
root because the tests resolve data files (`DXCC.LIST`, `SSCW.txt`,
`IARU_HF.txt`, ...) relative to the executable — the same convention the
application uses, and the same place Delphi's `UnitTests.dproj` writes its
`.exe`.

## Why there is a generator

The suite is written against **DUnitX**, which discovers fixtures and test
cases from Delphi custom attributes:

```pascal
[Test(True)]
[TestCase('Simple US', 'K1ABC,K1ABC')]
procedure TestExtractCallsign(const AFullCall, AExpected: string);
```

FPC 3.2.x cannot *parse* custom attributes at all (there is no
`TCustomAttribute` in its RTL and no `prefixedattributes` mode switch), so the
test units cannot be compiled unchanged, and no runtime shim can recover the
~960 test cases those attributes encode.

`tools/gen-fpc-tests.py` therefore keeps `Test/*.pas` as the single source of
truth and derives, into `Test/fpc/gen/` (git-ignored, regenerate at will):

- a copy of each test unit with the attributes commented out and Delphi-only
  names mapped (`System.SysUtils` → `SysUtils`,
  `UTF8ToUnicodeString` → `UTF8Decode`), and
- for each unit, a spliced-in `RegisterFixtures_<Unit>` procedure plus a
  type-safe invoker per fixture.

The registration is spliced *into* each unit rather than collected in one
place because `LexerTest` and `SSLexerTest` declare their fixtures in the
implementation section, where an outside unit cannot see them.

Only fixtures actually passed to `TDUnitX.RegisterTestFixture` are emitted, so
the FPC run covers the same set of tests as the Delphi run. `[Test(False)]`
methods are registered but reported as skipped.

`DUnitX.TestFramework.pas` in this directory supplies the `Assert` class, the
`TDUnitX` stub and the console runner. It is a compatibility shim for this
suite, not a general DUnitX implementation — extend it as tests need more.

## Adding tests

Edit the DUnitX sources in `Test/` as usual (they must stay Delphi-compatible)
and re-run the generator. If a test uses an `Assert` method the shim does not
implement yet, add it to `DUnitX.TestFramework.pas`.
