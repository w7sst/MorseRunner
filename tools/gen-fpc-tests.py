#!/usr/bin/env python3
"""Generate FPC-compatible sources for the DUnitX test suite.

FPC 3.2.x cannot parse Delphi custom attributes, so the DUnitX test units
cannot be compiled as-is.  This script keeps the DUnitX sources in Test/ as
the single source of truth and derives, into Test/fpc/gen/:

  * a copy of each test unit with the attributes commented out (and Delphi
    dotted unit names mapped to their FPC equivalents), and
  * GeneratedTests.pas, which registers every fixture with the runner in
    Test/fpc/DUnitX.TestFramework.pas together with a type-safe invoker.

Only fixtures that the original unit actually passes to
TDUnitX.RegisterTestFixture are emitted, so the FPC suite runs the same set
of tests as the Delphi one.

Usage: tools/gen-fpc-tests.py [<repo-root>]
"""

import os
import re
import sys

TEST_UNITS = [
    "CallsignUtilsTest",
    "LexerTest",
    "SSLexerTest",
    "MySSExchTest",
    "SSExchParserTest",
    "DxccListTest",
    "DxOperTest",
]

# Delphi unit-scope names that FPC does not provide.
DOTTED_UNITS = {
    "System.SysUtils": "SysUtils",
    "System.Classes": "Classes",
    "System.TypInfo": "TypInfo",
    "System.StrUtils": "StrUtils",
    "System.Math": "Math",
}

# Delphi RTL identifiers with a differently-named FPC equivalent.
IDENT_MAP = {
    "UTF8ToUnicodeString": "UTF8Decode",
}

ATTR_RE = re.compile(r"^\[\s*(\w+)\s*(?:\((.*)\))?\s*\]$", re.DOTALL)
METHOD_RE = re.compile(
    r"^\s*(procedure|function)\s+(\w+)\s*(?:\(([^)]*)\))?\s*(?::\s*[\w.]+\s*)?;",
    re.IGNORECASE,
)
CLASS_RE = re.compile(r"^\s*(\w+)\s*=\s*class\b", re.IGNORECASE)
REGISTER_RE = re.compile(
    r"^\s*TDUnitX\.RegisterTestFixture\s*\(\s*(\w+)\s*\)", re.IGNORECASE
)


def strip_comment(line):
    """Remove a trailing // comment, respecting Pascal string literals."""
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "'":
            in_str = not in_str
        elif not in_str and ch == "/" and i + 1 < len(line) and line[i + 1] == "/":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def split_args(text):
    """Split attribute arguments on top-level commas, respecting quotes."""
    args = []
    cur = []
    in_str = False
    i = 0
    depth = 0
    while i < len(text):
        ch = text[i]
        if ch == "'":
            # '' inside a string literal is an escaped quote
            if in_str and i + 1 < len(text) and text[i + 1] == "'":
                cur.append("''")
                i += 2
                continue
            in_str = not in_str
            cur.append(ch)
        elif not in_str and ch in "([":
            depth += 1
            cur.append(ch)
        elif not in_str and ch in ")]":
            depth -= 1
            cur.append(ch)
        elif not in_str and ch == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    if cur:
        args.append("".join(cur).strip())
    return args


def unquote(arg):
    """Turn a Pascal string literal into its value."""
    arg = arg.strip()
    if len(arg) >= 2 and arg.startswith("'") and arg.endswith("'"):
        return arg[1:-1].replace("''", "'")
    return arg


def pas_str(value):
    """Render a Python string as a Pascal string literal."""
    return "'" + value.replace("'", "''") + "'"


def logical_lines(lines):
    """Group source lines into logical units.

    Yields (start, end, code, is_attr).  A run of lines is an attribute only if
    the joined, comment-stripped text matches the attribute grammar -- a plain
    '[' test would also swallow wrapped open-array arguments such as the
    format() calls in DxOperTest.
    """
    i = 0
    n = len(lines)
    while i < n:
        code = strip_comment(lines[i]).strip()
        if code.startswith("["):
            joined = code
            j = i
            # Attributes never wrap far; cap the lookahead.
            while joined.count("[") > joined.count("]") and j + 1 < n and j - i < 8:
                j += 1
                joined += " " + strip_comment(lines[j]).strip()
            if ATTR_RE.match(joined):
                yield (i, j, joined, True)
                i = j + 1
                continue
        yield (i, i, code, False)
        i += 1


def parse_params(param_text):
    """Parse a Pascal parameter list into an ordered list of type names."""
    types = []
    if not param_text or not param_text.strip():
        return types
    for group in param_text.split(";"):
        group = group.strip()
        if not group:
            continue
        group = re.sub(r"^\s*(const|var|out)\s+", "", group, flags=re.IGNORECASE)
        if ":" not in group:
            continue
        names, type_name = group.split(":", 1)
        type_name = type_name.strip().rstrip(";").strip()
        count = len([n for n in names.split(",") if n.strip()])
        types.extend([type_name] * count)
    return types


class Fixture:
    def __init__(self, class_name):
        self.class_name = class_name
        self.setup = ""
        self.teardown = ""
        self.setup_fixture = ""
        self.teardown_fixture = ""
        self.tests = []  # list of dicts


def parse_unit(path):
    """Extract fixtures, their lifecycle methods and their test cases."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        raw_lines = fh.read().splitlines()

    # Fixtures may be declared in either section: LexerTest and SSLexerTest
    # keep a shared base class in the interface and the fixtures themselves in
    # the implementation.  Method *definitions* there are qualified
    # ("procedure TestTLexer.Setup;") and so never match METHOD_RE.
    registered = []
    for line in raw_lines:
        m = REGISTER_RE.match(strip_comment(line))
        if m:
            registered.append(m.group(1))
    interface_lines = raw_lines

    fixtures = {}
    order = []
    current = None
    pending = []  # attributes seen since the last declaration

    for _start, _end, code, is_attr in logical_lines(interface_lines):
        if not code:
            continue

        if is_attr:
            m = ATTR_RE.match(code)
            pending.append((m.group(1), m.group(2) or ""))
            continue

        m = CLASS_RE.match(code)
        if m:
            name = m.group(1)
            if any(a[0].lower() == "testfixture" for a in pending):
                current = Fixture(name)
                fixtures[name] = current
                order.append(name)
            else:
                current = None
            pending = []
            continue

        m = METHOD_RE.match(code)
        if m and current is not None:
            method = m.group(2)
            param_types = parse_params(m.group(3))
            kinds = {a[0].lower() for a in pending}

            if "setupfixture" in kinds:
                current.setup_fixture = method
            elif "teardownfixture" in kinds:
                current.teardown_fixture = method
            elif "setup" in kinds:
                current.setup = method
            elif "teardown" in kinds:
                current.teardown = method

            if "test" in kinds:
                enabled = True
                for attr, args in pending:
                    if attr.lower() == "test" and args.strip():
                        enabled = unquote(args).strip().lower() != "false"

                cases = []
                for attr, args in pending:
                    if attr.lower() != "testcase":
                        continue
                    parts = split_args(args)
                    case_name = unquote(parts[0]) if parts else ""
                    payload = unquote(parts[1]) if len(parts) > 1 else ""
                    sep = unquote(parts[2]) if len(parts) > 2 else ","
                    values = payload.split(sep) if param_types else []
                    # DUnitX pads missing trailing parameters with empty strings.
                    while len(values) < len(param_types):
                        values.append("")
                    cases.append((case_name, values[: len(param_types)]))

                if not cases:
                    cases = [("", [""] * len(param_types))]

                current.tests.append(
                    {
                        "method": method,
                        "types": param_types,
                        "cases": cases,
                        "enabled": enabled,
                    }
                )
            pending = []
            continue

        # Any other declaration clears pending attributes.
        if code.endswith(";") or code.lower() in ("public", "private", "protected"):
            pending = []

    return [fixtures[n] for n in order if n in registered]


REQUIRED_IMPL_UNITS = ["DUnitX.TestFramework", "SysUtils"]


def collect_used_units(lines):
    """Names imported by any uses clause in the file, lower-cased."""
    names = set()
    i = 0
    while i < len(lines):
        if re.match(r"^\s*uses\b", lines[i], re.I):
            clause = []
            while i < len(lines):
                code = strip_comment(lines[i])
                clause.append(code)
                if ";" in code:
                    break
                i += 1
            text = " ".join(clause)
            text = re.sub(r"^\s*uses\b", "", text, flags=re.I)
            text = text.split(";")[0]
            for part in text.split(","):
                part = re.sub(r"\bin\b\s*'[^']*'", "", part, flags=re.I).strip()
                if part:
                    names.add(part.lower())
        i += 1
    return names


def ensure_impl_uses(out):
    """Make sure the implementation section imports what generated code needs.

    LexerTest and SSLexerTest declare their fixtures in the implementation
    section, so the registration code has to live there too -- which means the
    framework and SysUtils must be in scope at that point.
    """
    impl = next(
        (i for i, l in enumerate(out) if re.match(r"^\s*implementation\b", l, re.I)),
        None,
    )
    if impl is None:
        return

    # A unit already imported by the interface must not be repeated here --
    # FPC rejects that as a duplicate identifier.
    already = collect_used_units(out)
    missing = [u for u in REQUIRED_IMPL_UNITS if u.lower() not in already]
    if not missing:
        return

    # Extend an existing implementation uses clause if there is one.
    j = impl + 1
    while j < len(out) and (not out[j].strip() or out[j].strip().startswith("//")):
        j += 1

    if j < len(out) and re.match(r"^\s*uses\b", out[j], re.I):
        end = j
        while end < len(out) and ";" not in strip_comment(out[end]):
            end += 1
        if end >= len(out):
            return
        out[end] = re.sub(
            r";", ", " + ", ".join(missing) + ";",
            strip_comment(out[end]).rstrip(), count=1)
    else:
        out.insert(impl + 1, "")
        out.insert(impl + 2, "uses")
        out.insert(impl + 3, "  " + ", ".join(missing) + ";")


def emit_stripped_unit(src, dst, unit_name, fixtures):
    """Copy a test unit for FPC.

    Attributes are commented out, Delphi-only names are mapped, and the
    generated fixture registration for this unit is spliced in -- inside the
    unit, so that fixtures declared in the implementation section are visible.
    """
    with open(src, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()

    out = []
    for start, end, _code, is_attr in logical_lines(lines):
        if is_attr:
            for k in range(start, end + 1):
                out.append("//" + lines[k])
            continue

        line = lines[start]
        for dotted, plain in DOTTED_UNITS.items():
            line = re.sub(r"\b" + re.escape(dotted) + r"\b", plain, line)
        for delphi, fpc in IDENT_MAP.items():
            line = re.sub(r"\b" + re.escape(delphi) + r"\b", fpc, line)
        out.append(line)

    ensure_impl_uses(out)

    # Declare the registration entry point in the interface.
    impl = next(
        (i for i, l in enumerate(out) if re.match(r"^\s*implementation\b", l, re.I)),
        None,
    )
    if impl is not None:
        out[impl:impl] = [
            "",
            "{ Generated: registers this unit's fixtures with the FPC test runner. }",
            "procedure RegisterFixtures_%s;" % unit_name,
            "",
        ]

    # Splice the invokers and registration body in before the unit's
    # initialization section (or, failing that, its final 'end.').
    tail = next(
        (i for i, l in enumerate(out)
         if re.match(r"^\s*(initialization|finalization)\b", l, re.I)),
        None,
    )
    if tail is None:
        tail = max(
            i for i, l in enumerate(out) if re.match(r"^\s*end\s*\.", l, re.I)
        )

    out[tail:tail] = build_registration(unit_name, fixtures)

    with open(dst, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


def arg_expr(type_name, index):
    """Render the invoker argument expression for a parameter type."""
    t = type_name.strip().lower()
    if t in ("integer", "cardinal", "longint", "int64", "byte", "word", "smallint"):
        return "StrToInt(AArgs[%d])" % index
    if t == "boolean":
        return "StrToBool(AArgs[%d])" % index
    return "AArgs[%d]" % index


def build_registration(unit_name, fixtures):
    """Build the invokers and RegisterFixtures_<unit> body for one test unit."""
    out = []
    w = out.append

    w("")
    w("{ ------------------------------------------------------------------ }")
    w("{ Generated by tools/gen-fpc-tests.py -- do not edit below this line. }")
    w("")
    w("{ Open-array literals are the portable way to build the argument vector;")
    w("  FPC 3.2 has no dynamic-array constructor syntax. }")
    w("function GenArgs_%s(const A: array of string): TTestArgs;" % unit_name)
    w("var")
    w("  GenI: integer;")
    w("begin")
    w("  SetLength(Result, Length(A));")
    w("  for GenI := 0 to High(A) do")
    w("    Result[GenI] := A[GenI];")
    w("end;")
    w("")

    # One invoker per fixture: a name-dispatched, type-safe call. FPC cannot
    # invoke a method by name with arbitrary parameters at runtime.
    for fx in fixtures:
        w("procedure Invoke_%s(AInstance: TObject; const AMethod: string;" % fx.class_name)
        w("  const AArgs: TTestArgs);")
        w("begin")
        emitted = []
        for name in (fx.setup_fixture, fx.teardown_fixture, fx.setup, fx.teardown):
            if name and name not in emitted:
                emitted.append(name)
                w("  if AMethod = %s then" % pas_str(name))
                w("    %s(AInstance).%s" % (fx.class_name, name))
                w("  else")
        for t in fx.tests:
            if t["method"] in emitted:
                continue
            emitted.append(t["method"])
            args = ", ".join(arg_expr(ty, i) for i, ty in enumerate(t["types"]))
            w("  if AMethod = %s then" % pas_str(t["method"]))
            if args:
                w("    %s(AInstance).%s(%s)" % (fx.class_name, t["method"], args))
            else:
                w("    %s(AInstance).%s" % (fx.class_name, t["method"]))
            w("  else")
        w("    raise Exception.CreateFmt('unknown test method: %s', [AMethod]);")
        w("end;")
        w("")

    w("procedure RegisterFixtures_%s;" % unit_name)
    w("begin")
    if not fixtures:
        w("  { no registered fixtures in this unit }")
    for fx in fixtures:
        w("  BeginFixture(%s, %s, @Invoke_%s," % (
            fx.class_name, pas_str(fx.class_name), fx.class_name))
        w("    %s, %s," % (pas_str(fx.setup_fixture), pas_str(fx.teardown_fixture)))
        w("    %s, %s);" % (pas_str(fx.setup), pas_str(fx.teardown)))
        for t in fx.tests:
            enabled = "True" if t["enabled"] else "False"
            for case_name, values in t["cases"]:
                if values:
                    arr = "GenArgs_%s([%s])" % (
                        unit_name, ", ".join(pas_str(v) for v in values))
                else:
                    arr = "nil"
                w("  AddTestCase(%s, %s, %s, %s);" % (
                    pas_str(t["method"]), pas_str(case_name), arr, enabled))
        w("")
    w("end;")
    w("")

    return out


def emit_generated_unit(units, dst):
    """Emit the aggregator that calls each unit's generated registration."""
    out = []
    w = out.append

    w("// Generated by tools/gen-fpc-tests.py -- do not edit.")
    w("//")
    w("// Calls the per-unit fixture registrations spliced into the generated")
    w("// copies of the DUnitX test units.")
    w("unit GeneratedTests;")
    w("")
    w("{$MODE DELPHI}")
    w("{$H+}")
    w("")
    w("interface")
    w("")
    w("procedure RegisterAllTests;")
    w("")
    w("implementation")
    w("")
    w("uses")
    for i, (unit_name, _) in enumerate(units):
        w("  %s%s" % (unit_name, ";" if i == len(units) - 1 else ","))
    w("")
    w("procedure RegisterAllTests;")
    w("begin")
    for unit_name, _ in units:
        w("  RegisterFixtures_%s;" % unit_name)
    w("end;")
    w("")
    w("end.")

    with open(dst, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    test_dir = os.path.join(root, "Test")
    gen_dir = os.path.join(test_dir, "fpc", "gen")
    os.makedirs(gen_dir, exist_ok=True)

    units = []
    total_cases = 0
    for unit_name in TEST_UNITS:
        src = os.path.join(test_dir, unit_name + ".pas")
        if not os.path.exists(src):
            print("warning: %s not found, skipping" % src, file=sys.stderr)
            continue
        fixtures = parse_unit(src)
        emit_stripped_unit(
            src, os.path.join(gen_dir, unit_name + ".pas"), unit_name, fixtures)
        units.append((unit_name, fixtures))
        for fx in fixtures:
            for t in fx.tests:
                total_cases += len(t["cases"])
        print("%-22s %d fixture(s), %d test method(s)" % (
            unit_name, len(fixtures), sum(len(f.tests) for f in fixtures)))

    emit_generated_unit(units, os.path.join(gen_dir, "GeneratedTests.pas"))
    print("total test cases: %d" % total_cases)


if __name__ == "__main__":
    main()
