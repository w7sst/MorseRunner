#!/usr/bin/env bash
set -e

# normalize-crlf.sh
#
# Repository maintenance utility for detecting and repairing line-ending
# issues in Delphi source files.
#
# Detects stray carriage-return (CR) characters and mixed line endings that
# can cause Git to report spurious file modifications. Supports summary and
# detailed reporting, repair mode with backups, Git EOL diagnostics, and
# operation on individual files, modified Git files, or the entire source tree.
#
# Developed with assistance from OpenAI ChatGPT.

VERBOSE=0
REPAIR=0
REPORT_MODE=summary
SHOW_EOL=0
USE_GIT=0
USE_ALL=0

MAX_RANGES_TO_SHOW=10
FILES=()

usage()
{
  cat <<EOF
Usage:
  normalize-crlf.sh [options] [files...]

Report Modes:
  --summary     Summary report only (default)
  --detail      Detailed report showing affected line ranges
  --stats       Show totals only (without listing filenames)

Actions:
  --repair      Normalize line endings (creates .bak backups)

File Selection:
  --git         Modified and untracked Delphi files
  --all         All Delphi source files under current tree

Other:
  --eol         Show Git end-of-line status for selected files
  -v            Verbose
  -h, --help    Show this help

Typical workflow:
  normalize-crlf.sh --git
      Show modified files containing line-ending issues.

  normalize-crlf.sh --detail --git
      Show affected line ranges.

  normalize-crlf.sh --repair --git
      Repair modified files.

  normalize-crlf.sh --eol --git
      Show Git line-ending status.

Examples:
  normalize-crlf.sh Arrl10m.pas
  normalize-crlf.sh --all
  normalize-crlf.sh --detail --all
  normalize-crlf.sh --repair --all
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;

    -v)
      VERBOSE=1
      ;;

    --repair)
      REPAIR=1
      ;;

    --detail)
      REPORT_MODE=detail
      ;;

    --summary)
      REPORT_MODE=summary
      ;;

    --stats)
      REPORT_MODE=stats
      ;;

    --git)
      USE_GIT=1
      ;;

    --all)
      USE_ALL=1
      ;;

    --eol)
      SHOW_EOL=1
      ;;

    *)
      if [[ "$1" == -* ]]; then
        echo "Error: Unknown option '$1'"
        echo
        usage
        exit 1
      fi

      FILES+=("$1")
      ;;
  esac

  shift
done

#
# Validation
#

if [ $USE_GIT -eq 1 ] && [ $USE_ALL -eq 1 ]; then
  echo "Error: --git and --all are mutually exclusive."
  exit 1
fi

#
# Build file list.
#

if [ $USE_GIT -eq 1 ]; then
  while read -r status file; do
    FILES+=("$file")
  done < <(git status --porcelain -- '*.pas' '*.dpr' '*.dproj' '*.dfm' '*.inc')
elif [ $USE_ALL -eq 1 ]; then
  while IFS= read -r file; do
    FILES+=("$file")
  done < <(
  find . -path './.git' -prune \
  -o \
  -type f \
  \( -iname '*.pas' \
  -o -iname '*.dpr' \
  -o -iname '*.dproj' \
  -o -iname '*.dfm' \
  -o -iname '*.inc' \) \
  -print
  )
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No files selected."
  echo "Use --git, --all, or specify one or more filenames."
  exit 1
fi

if [ $SHOW_EOL -eq 1 ]; then
  echo
  echo "Git EOL Status"
  echo "--------------"

  git ls-files --eol -- "${FILES[@]}"

  exit 0
fi

print_ranges()
{
  local -n arr=$1
  local max_ranges=$2

  local start=""
  local prev=""
  local range_count=0

  for line in "${arr[@]}"; do

    if [ -z "$start" ]; then
      start=$line
      prev=$line
      continue
    fi

    if [ "$line" -eq $((prev + 1)) ]; then
      prev=$line
      continue
    fi

    range_count=$((range_count + 1))

    if [ $range_count -gt $max_ranges ]; then
      echo "    ..."
      return
    fi

    if [ "$start" = "$prev" ]; then
      echo "    $start"
    else
      echo "    $start-$prev"
    fi

    start=$line
    prev=$line
  done

  if [ -n "$start" ]; then
    range_count=$((range_count + 1))

    if [ $range_count -gt $max_ranges ]; then
      echo "    ..."
      return
    fi

    if [ "$start" = "$prev" ]; then
      echo "    $start"
    else
      echo "    $start-$prev"
    fi
  fi
}

FILES_CHECKED=0
FILES_WITH_ISSUES=0
TOTAL_ISSUES=0
FILES_REPAIRED=0

for file in "${FILES[@]}"; do
  [ -f "$file" ] || continue

  if [ $VERBOSE -eq 1 ]; then
    echo "Checking: $file"
  fi

  FILES_CHECKED=$((FILES_CHECKED + 1))

  # First normalize everything to LF, then convert back
  # to CRLF. This removes stray standalone CR characters.
  mapfile -t LINES < <(
    perl -ne '
      $n++;
      print "$n\n" if /\r[^\n]/;
    ' "$file"
  )

  COUNT=${#LINES[@]}

  if [ $COUNT -eq 0 ]; then
    continue
  fi

  FILES_WITH_ISSUES=$((FILES_WITH_ISSUES + 1))
  TOTAL_ISSUES=$((TOTAL_ISSUES + ${#LINES[@]}))

  if [ $REPAIR -eq 1 ]; then
    echo "Repairing: $file"

    echo "backup: $file.bak"
    cp "$file" "$file.bak"

    perl -pi -e 's/\r\n/\n/g; s/\r/\n/g' "$file"
    unix2dos "$file" >/dev/null

    FILES_REPAIRED=$((FILES_REPAIRED + 1))
  else
    case "$REPORT_MODE" in
      stats)
        ;;

      summary)
        echo "$file ($COUNT stray CR line(s))"
        ;;

      detail)
        echo "Checking: $file"
        echo "  $COUNT stray CR line(s) found"
        echo "  Line(s):"
        print_ranges LINES $MAX_RANGES_TO_SHOW
        echo
    esac
  fi
done

#
# Reporting.
#

echo
echo "Files checked     : $FILES_CHECKED"
echo "Files with issues : $FILES_WITH_ISSUES"
echo "Total stray lines : $TOTAL_ISSUES"

if [ $REPAIR -eq 1 ]; then
  echo "Files repaired    : $FILES_REPAIRED"
fi

if [ $FILES_WITH_ISSUES -gt 0 ]; then
  if [ $REPAIR -eq 0 ]; then
    echo
    echo "Suggested fix:"
    echo "  tools/normalize-crlf.sh --repair --git"
  fi

  echo
  echo "Done."

  exit 1
fi

exit 0


