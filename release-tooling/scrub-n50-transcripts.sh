#!/usr/bin/env bash
# scrub-n50-transcripts.sh - package raw disposition transcripts for public release: stage the
# per-cell run directories, scrub every text file, verify the staged tree, pack with neutral owners.
#
#   usage: SRC=<directory holding the per-cell results directories> scrub-n50-transcripts.sh
#   optional: OUT     output directory       (default: the bundle's transcripts/)
#             ARCHIVE archive file name      (default: the 2026-08-08 batch's name)
#             TOP     top directory in it    (default: n50)
#             CELLS   "source:dest ..." pairs; source gets "-results" appended
#             SCRUB_PATTERNS, TEXTCHECK_IDENTIFIERS  as for the gate
#
# Written from harness/scrub-n50-transcripts.sh, which packed the 2026-08-08 batch and stays in
# harness/ unchanged. That batch's archive is re-packed (repack-tarballs.py), never re-scrubbed.
# This copy is for the re-run's transcripts. What changed, and why:
#
#   * THE READER. The as-ran copy read the patterns file without confining the optional third
#     column and without stripping carriage returns - fixes its sibling assembler already had.
#     Both now come from scrub-lib.sh, one definition sourced by both scripts.
#   * SELF-REWRITE. The as-ran copy named its source directory and its own verification strings
#     literally, so the scrub rewrote them in the published copy: it verified that the
#     REPLACEMENTS were absent. Paths now come from the environment, and verification uses the
#     gate's own categories and the external patterns file.
#   * EXTENSIONS. The as-ran copy scrubbed four extensions and packed every other file verbatim,
#     the denylist shape the assembler recorded on 2026-08-11. This copy scrubs every text file,
#     whatever its name.
#   * MISSING CELLS. The as-ran copy skipped a missing cell silently and packed what it found.
#     This copy aborts.
#   * OWNERS. Tar headers carry the packing account. Archives are packed with owner and group 0
#     and no names.
set -uo pipefail

TOOL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE=$(dirname "$TOOL_DIR")
OUT=${OUT:-$BASE/public-release/transcripts}
ARCHIVE=${ARCHIVE:-n50-disposition-300-runs.scrubbed.tar.gz}
TOP=${TOP:-n50}
CELLS=${CELLS:-"arm-b-n50:opus-arm-b arm-a-n50:opus-arm-a \
       arm-b-sonnet-n50:sonnet-arm-b arm-a-sonnet-n50:sonnet-arm-a \
       arm-b-haiku-n50:haiku-arm-b arm-a-haiku-n50:haiku-arm-a"}

# shellcheck source=scrub-lib.sh
. "$TOOL_DIR/scrub-lib.sh"
scrub_find_patterns || { echo "ABORT: no scrub-patterns file; personal substitutions would silently not run"; exit 1; }
[ -n "${SRC:-}" ] && [ -d "$SRC" ] || { echo "ABORT: set SRC to the directory holding the per-cell results directories"; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

echo "=== staging ==="
for pair in $CELLS; do
  src="${pair%%:*}"; dst="${pair##*:}"
  [ -d "$SRC/$src-results" ] || { echo "ABORT: cell $src has no results directory under SRC"; exit 1; }
  mkdir -p "$STAGE/$TOP/$dst"
  cp -a "$SRC/$src-results/." "$STAGE/$TOP/$dst/"
  n=$(find "$STAGE/$TOP/$dst" -mindepth 1 -maxdepth 1 -type d -name 'R*' | wc -l)
  [ "$n" -gt 0 ] || { echo "ABORT: cell $src holds no runs"; exit 1; }
  echo "  $dst: $n runs"
done

echo "=== scrubbing every text file (rules: scrub-lib.sh) ==="
SCRUBBED=0
while IFS= read -r -d '' f; do
  if grep -Iq . "$f"; then scrub_file "$f"; SCRUBBED=$((SCRUBBED+1)); fi
done < <(find "$STAGE" -type f -print0)
echo "  text files scrubbed: $SCRUBBED"

echo "=== verifying the staged tree before it is packaged (the gate's categories) ==="
# The gate's own scan, imported, so the categories are defined in one place. Reports categories
# and counts only. Blocks on any hit, on an unarmed external category, and on reading nothing.
python3 - "$STAGE" "$TOOL_DIR/bundle-stopword-gate.py" <<'PY' || { echo "ABORT: the staged tree is not clean; nothing was packaged"; exit 1; }
import importlib.util, sys
sys.dont_write_bytecode = True  # never leave a cache beside the published tooling
spec = importlib.util.spec_from_file_location("release_gate", sys.argv[2])
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
hits, _ctrl, scanned, ids, _allowed, pers, _archives = gate.scan(sys.argv[1])
bad = False
print(f"  files scanned: {scanned}")
if scanned == 0:
    print("  🔴 nothing was scanned"); bad = True
if ids is None:
    print("  🔴 identifier list not found - that scan did not run"); bad = True
for c in gate.REQUIRED_EXTERNAL_CATEGORIES:
    if not pers.get(c):
        print(f"  🔴 external category not armed: {c}"); bad = True
for label in sorted(hits):
    print(f"  🔴 {label}: {len(hits[label])} file(s)"); bad = True
if not bad:
    print("  ✅ no category matched")
sys.exit(1 if bad else 0)
PY

echo "=== packaging ==="
mkdir -p "$OUT"
# --force-local: a Windows output path contains a colon, which GNU tar would otherwise read as a
# remote host.
tar --force-local --owner=0 --group=0 --numeric-owner -C "$STAGE" -czf "$OUT/$ARCHIVE" "$TOP"
ls -lh "$OUT/$ARCHIVE"
echo "  runs packaged: $(find "$STAGE/$TOP" -name 'stream.jsonl' | wc -l)"
