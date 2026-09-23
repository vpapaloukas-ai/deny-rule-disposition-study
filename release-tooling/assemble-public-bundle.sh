#!/usr/bin/env bash
# assemble-public-bundle.sh - build the public-release bundle in one directory: scrubbed narrative
# docs, scrubbed result files, the allowlisted scripts, and the transcript tarballs. Internal
# originals are never modified. Then verify the bundle, and EXIT WITH THE VERDICT.
#
#   usage: assemble-public-bundle.sh            (PUB, SCRUB_PATTERNS, BUNDLE_LOG may be set)
#
# Written from harness/assemble-public-bundle.sh, which stays in harness/ unchanged as the
# record of the pre-publication build and is not published. What changed, and why:
#
#   * EXIT STATUS. The as-ran script ran the gate, wrote the verdict into a log file, and exited
#     with the status of its last command, a disk-usage report. A build whose gate BLOCKED exited
#     0. This one exits non-zero when the gate or the link check fails, and prints the verdict
#     to the terminal as well as to the log.
#   * PATHS. The as-ran script named its base directory absolutely, for a layout that no longer
#     exists. This one derives every path from its own location.
#   * ONE SCRUB. The rules live in scrub-lib.sh, shared with scrub-n50-transcripts.sh.
#   * BYTE-IDENTITY GUARD. The as-ran guard covered the gate alone, so the scrub rewrote the rules
#     inside the published assembler and transcript scrub without anything noticing. This guard
#     covers every file shipped from release-tooling/.
#   * ALLOWLIST. release-tooling/RELEASE-ALLOWLIST.txt decides what ships from harness/ and from
#     release-tooling/. A listed file that is missing now aborts; it used to warn.
#   * THE 2026-09 RE-RUN (added 2026-09-17). rerun-2026-09/ ships at the bundle root as a scrubbed copy
#     without scripts; its scripts ship only from the allowlist. The byte-identity guard also covers
#     the re-run's pinned files and its pre-registration with diffs.
#   * LINKS. Links in docs/ written for the private layout are rewritten to the bundle's layout,
#     links to private documents become plain text, and check-links.py fails the build on any
#     relative link that does not resolve.
set -u

TOOL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE=$(dirname "$TOOL_DIR")
PUB=${PUB:-$BASE/public-release}
OLD=$BASE/transcripts/public-release
ALLOW=$TOOL_DIR/RELEASE-ALLOWLIST.txt
BUNDLE_LOG=${BUNDLE_LOG:-/tmp/bundle.log}
ARMS="n50 arm-a arm-b arm-c arm-d arm-ab xmodel phase2 arm-e"

# 🔴 The log takes everything, as before, but fd 3 keeps the terminal. The as-ran build sent its
# verdict only to the log, so an operator who did not open the log saw nothing either way.
exec 3>&1
exec > "$BUNDLE_LOG" 2>&1
say() { echo "$@"; echo "$@" >&3; }
die() { say "🔴 ABORT: $1"; shift; local l; for l in "$@"; do say "   $l"; done; say "   log: $BUNDLE_LOG"; exit 1; }

case "$PUB" in
  /|"$BASE"|"$HOME"|"$TOOL_DIR") die "refusing to build into $PUB: this script deletes subdirectories of it." ;;
esac
[ -d "$PUB" ] || die "no bundle directory at $PUB."
[ -f "$ALLOW" ] || die "no allowlist at $ALLOW." "Default deny: with no list, nothing may ship."

# 🔴 The PERSONAL strings live outside the repo, in $SCRUB_PATTERNS, and are loaded by
# scrub-lib.sh. The check runs BEFORE anything in the bundle is deleted: the as-ran script
# emptied docs/ and results/ first and aborted afterwards, leaving a half-built bundle behind.
# shellcheck source=scrub-lib.sh
. "$TOOL_DIR/scrub-lib.sh"
scrub_find_patterns || die "no scrub-patterns file at ${SCRUB_PATTERNS:-any default location}." \
  "The personal-identifier substitutions would silently not run and the bundle" \
  "would look clean. Refusing to build. (Set SCRUB_PATTERNS to override.)"

# Regenerate only the managed subdirs; the hand-maintained top-level README.md survives a rebuild.
#
# 🔴 transcripts/ is NOT wiped. It was, until 2026-08-08, when a rebuild emptied it: the scrubbed
# tarballs' source dir ($OLD) had been removed after the first build, so the bundle copy was the ONLY
# copy, and `rm -rf` destroyed it (recovered from git — they are tracked). The tarballs are expensive
# to regenerate and are the study's raw evidence, so the rebuild now leaves them alone unless a source
# actually exists, and refuses to finish if the bundle ends up with none.
rm -rf "$PUB/docs" "$PUB/results"; mkdir -p "$PUB/docs" "$PUB/results" "$PUB/transcripts"
[ -f "$PUB/README.md" ] || echo "(note: README.md missing from the bundle — restore it before publishing)"

# rewrite_links FILE - docs/ are written for the private layout, where each arm directory sits
# beside the record. In the bundle the arms sit under results/ and the scripts under harness/, one
# level up from docs/. A link that leaves the experiment directory points at a private document,
# so it becomes plain text; naming that document's path is itself a disclosure, so neither the
# link nor its text survives. A link to a harness/ file that does not ship keeps only its text.
rewrite_links() {
  local arm
  for arm in $ARMS; do sed -i "s#](${arm}/#](../results/${arm}/#g" "$1"; done
  sed -i -e 's#](harness/#](../harness/#g' -e 's#](rerun-2026-09/#](../rerun-2026-09/#g' "$1"
  sed -E -i \
    -e 's#\[[^]]*\]\(\.\./\.\./[^)]*\)#private, not published#g' \
    -e 's#\[([^]]*)\]\(\.\./harness/RELEASE-ALLOWLIST\.txt\)#\1#g' \
    "$1"
}

echo "=== 1. narrative docs -> docs/ (scrubbed copies, links rewritten) ==="
# 🔴 docs/ is WIPED above on every build, so a file dropped into public-release/docs/ by hand
# disappears at the next build without a word. A document ships only if it is named here.
# An entry is either NAME.md, or INTERNAL.md:PUBLISHED.md when the published name differs from
# the internal one — the internal file stays the source of truth and keeps its own name.
for f in RUN-RECORD.md GATE-FINDINGS.md RUNBOOK.md \
         PRE-PUBLICATION-READ-2026-09-17.md:INDEPENDENT-READ-2026-09-17.md; do
  src="${f%%:*}"; dst="${f##*:}"
  cp "$BASE/$src" "$PUB/docs/$dst"; scrub_file "$PUB/docs/$dst"; rewrite_links "$PUB/docs/$dst"
  echo "  docs/$dst"
done

echo
echo "=== 2. result + frozen-input subtrees -> results/ (scrubbed copies) ==="
for arm in $ARMS; do
  if [ -d "$BASE/$arm" ]; then
    cp -a "$BASE/$arm" "$PUB/results/$arm"
    # Scrub every text file in the copy.
    # 🔴 `.log` was added 2026-08-11 with arm-e, and the gap it closes is the same shape as
    # every other one in this file: the extension list is a DENYLIST wearing an allowlist's
    # clothes. Arms had only ever held md/json/txt, so nothing had tested it; arm-e ships
    # session summary logs, which carry absolute paths including the operator's home
    # directory. An unlisted extension is copied VERBATIM, and a file the scrub never
    # touched looks exactly like a file the scrub found nothing in.
    # Scripts are NOT handled here on purpose — they ship only via the allowlist, so an arm
    # directory must never contain one.
    find "$PUB/results/$arm" -type f \( -name '*.md' -o -name '*.json' -o -name '*.txt' -o -name '*.log' \) -print0 \
      | while IFS= read -r -d '' f; do scrub_file "$f"; done
    # 🔴 INTERNAL-ONLY files are deleted from the bundle copy. Added 2026-08-11 after
    # arm-e/DRAFT-issue-1-reply.md — correspondence, containing a third party's stated
    # preferences — shipped into the bundle on the first build, because an arm directory is
    # a WHOLE-DIRECTORY COPY while scripts ship by allowlist. Nothing reviews an arm file.
    # The file was moved out, and this exists so the next one cannot repeat it.
    # A canary carrying this marker lives in arm-e and must be absent from every build;
    # the check below fails the build if it survives, so the mechanism is proven each time
    # rather than assumed. An untested guard is worth about as much as no guard.
    find "$PUB/results/$arm" -type f -name '*.md' -print0 \
      | while IFS= read -r -d '' f; do
          grep -q 'INTERNAL-ONLY-DO-NOT-SHIP' "$f" && { rm -f "$f"; echo "    dropped internal-only: ${f#$PUB/}"; }
        done
    # 🔴 Refuse to ship an executable smuggled in as arm data.
    if find "$PUB/results/$arm" -type f \( -name '*.sh' -o -name '*.py' \) | grep -q .; then
      find "$PUB/results/$arm" -type f \( -name '*.sh' -o -name '*.py' \) | sed "s#^$PUB/#     #"
      die "$arm contains a script. Scripts ship via the allowlist, never as arm data," \
          "because a directory copy is not reviewed file by file."
    fi
    echo "  results/$arm ($(find "$PUB/results/$arm" -type f | wc -l) files)"
  fi
done

echo
echo "=== 2c. third-party quotation redaction (marker-driven, never string-driven) ==="
# 🔴 WHY MARKERS AND NOT A PATTERN. This script is itself on the release allowlist (it
# ships). A redaction rule written as the text it removes would publish that text inside
# the tool that exists to remove it — the same defect already recorded for an escaped email
# address and for a scrub pattern quoted in its own comment.
# So the private file marks its own redactable spans and this step never learns the words.
#
# WHAT THIS IS FOR. A collaborator's unpublished words, quoted in the internal record.
# Naming him is cleared; publishing sentences he wrote in a private thread is not, and the
# clearance question is open with him. The redaction is ATTRIBUTION ONLY: no hypothesis,
# decision rule, control or result depends on the quoted span, and the surrounding text
# states the same claim in our own words.
REDACTED=0
while IFS= read -r -d '' f; do
  if grep -q 'PUBLIC-REDACT-START' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
notice = ("> *[Third-party quotation redacted from the published copy pending that person's\n"
          "> clearance. The redaction is attribution only: it removes no hypothesis, decision\n"
          "> rule, control or result, and the claim it attributed is stated in our own words\n"
          "> in the surrounding text. The internal record retains it.]*\n")
new, n = re.subn(r"<!--\s*PUBLIC-REDACT-START.*?-->.*?<!--\s*PUBLIC-REDACT-END\s*-->\s*",
                 notice, s, flags=re.S)
open(p, "w", encoding="utf-8").write(new)
print("    redacted %d span(s) in %s" % (n, p.rsplit("/", 2)[-1]))
PY
    REDACTED=$((REDACTED+1))
  fi
done < <(find "$PUB/docs" "$PUB/results" -type f -name '*.md' -print0 2>/dev/null)
echo "  files carrying a redaction marker: $REDACTED"
# A marker left unclosed would silently delete the rest of the file, so verify no marker survives.
# 🔴 Scoped to CONTENT, not to $PUB. The check once aborted its own first build by flagging the
# assembler, which ships on the allowlist and contains the marker string in the code that
# implements the redaction. Tooling source is not content and is never redacted, so it is not
# scanned here.
if grep -rl 'PUBLIC-REDACT' "$PUB/docs" "$PUB/results" 2>/dev/null | grep -q .; then
  grep -rl 'PUBLIC-REDACT' "$PUB/docs" "$PUB/results" | sed 's/^/     /'
  die "a redaction marker survived into bundle CONTENT — the span did not match."
fi
# 🔴 The canary must have been dropped. If it is still here the internal-only exclusion did
# not run, and every other internal file in an arm directory is in the bundle too.
if grep -rl 'INTERNAL-ONLY-DO-NOT-SHIP' "$PUB/docs" "$PUB/results" 2>/dev/null | grep -q .; then
  grep -rl 'INTERNAL-ONLY-DO-NOT-SHIP' "$PUB/docs" "$PUB/results" | sed 's/^/     /'
  die "the internal-only canary survived into the bundle. The exclusion did not fire."
fi
if [ -d "$BASE/arm-e" ]; then
  echo "  internal-only exclusion: canary absent from bundle ✅ (mechanism proven this build)"
fi

echo
echo "=== 2d. the 2026-09 re-run -> rerun-2026-09/ (scrubbed copies; scripts come only from the allowlist) ==="
# Added 2026-09-17. The re-run's pre-registration, diffs, results, analysis and preserved stash ship at
# the bundle root, where the pre-registration's own paths expect them. The directory is copied whole,
# every script in the copy is removed, and the allowlist step below puts back exactly the listed ones:
# a directory copy is not reviewed file by file, so it may not carry executables.
RERUN=rerun-2026-09
rm -rf "${PUB:?}/$RERUN"
if [ -d "$BASE/$RERUN" ]; then
  cp -a "$BASE/$RERUN" "$PUB/$RERUN"
  find "$PUB/$RERUN" -type f \( -name '*.sh' -o -name '*.py' \) -delete
  while IFS= read -r -d '' f; do
    if grep -Iq . "$f"; then scrub_file "$f"; fi
  done < <(find "$PUB/$RERUN" -type f -print0)
  echo "  $RERUN ($(find "$PUB/$RERUN" -type f | wc -l) files before its scripts are added)"
fi

echo
echo "=== 2b. scripts -> harness/, release-tooling/ and rerun-2026-09/ (ALLOWLIST ONLY, never a directory copy) ==="
# 🔴 ALLOWLIST, not scrub-a-directory. A denylist removes what someone thought to name;
# it cannot catch a disclosure that is a correctly-spelled, accurate sentence. The proof is a
# measured/ script that discloses the author's connected account services and contains no stop
# keyword at all. Anything not named in the allowlist never ships.
rm -rf "$PUB/harness" "$PUB/release-tooling"
COPIED=0
while IFS= read -r f; do
  case "$f" in ''|'#'*) continue ;; esac
  case "$f" in
    *..*) die "allowlist entry climbs out of the experiment directory: $f" ;;
    harness/*|release-tooling/*|rerun-2026-09/*) ;;
    *) die "allowlist entry outside harness/, release-tooling/ and rerun-2026-09/: $f" ;;
  esac
  [ -f "$BASE/$f" ] || die "allowlisted but MISSING: $f" "A listed file that does not ship is a gap nobody sees."
  mkdir -p "$(dirname "$PUB/$f")"
  cp "$BASE/$f" "$PUB/$f"; scrub_file "$PUB/$f"; COPIED=$((COPIED+1))
done < <(tr -d '\r' < "$ALLOW")
echo "  script and tooling files shipped: $COPIED (allowlisted)"
echo "  not shipped, named with a reason in the allowlist: $(tr -d '\r' < "$ALLOW" | grep -c '^#- ')"
# Belt and braces: nothing may reach the release directories that is not on the list, and no script
# may sit in the re-run directory unless it is on the list.
STRAY=$(cd "$PUB" && { find harness release-tooling -type f 2>/dev/null
                       find rerun-2026-09 -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null; } \
        | while IFS= read -r g; do tr -d '\r' < "$ALLOW" | grep -qxF "$g" || echo "$g"; done)
if [ -n "$STRAY" ]; then
  echo "$STRAY" | sed 's/^/     /'
  die "files in the release directories that are not on the allowlist (listed in the log)."
fi

# 🔴 RELEASE TOOLING MUST SURVIVE ITS OWN SCRUB, BYTE FOR BYTE.
# On 2026-08-08 the scrub rewrote the gate's own pattern list: the published copy searched for
# the REPLACEMENT strings, so it blocked a clean bundle and would have passed one that genuinely
# leaked. A guard was added, for the gate alone - and the same scrub went on rewriting the rules
# inside the published assembler and transcript scrub, which nothing compared. So every file
# shipped from release-tooling/ is compared with its source, line endings normalised (`sed -i`
# rewrites them on some platforms, and that is not corruption), and any difference aborts.
# The gate is among them, so the published gate is the gate that certified this bundle.
# Added 2026-09-17: the same guard covers the re-run's allowlisted scripts, which its pre-registration
# pins by SHA-256, and the pre-registration and its diffs, which are already committed in the
# publishing repository and must reach it again unchanged.
DRIFT=0
while IFS= read -r f; do
  if ! diff -q <(tr -d '\r' < "$BASE/$f") <(tr -d '\r' < "$PUB/$f") >/dev/null 2>&1; then
    echo "  🔴 scrub modified $f. Diff (source vs published):"
    diff <(tr -d '\r' < "$BASE/$f") <(tr -d '\r' < "$PUB/$f") 2>&1 | sed 's/^/     /' | head -20
    DRIFT=$((DRIFT+1))
  fi
done < <({ tr -d '\r' < "$ALLOW" | grep -v -e '^#' -e '^$' | grep -e '^release-tooling/' -e '^rerun-2026-09/'
           if [ -d "$BASE/rerun-2026-09" ]; then
             (cd "$BASE" && find rerun-2026-09/PREREGISTRATION.md rerun-2026-09/diffs -type f 2>/dev/null)
           fi; } | sort -u)
if [ "$DRIFT" -ne 0 ]; then
  die "the scrub MODIFIED $DRIFT pinned file(s). The published tooling would not be the tooling that" \
      "built and certified this bundle, or the re-run's pinned files would not match their pins. Fix by" \
      "splitting the offending literal, or by moving the value into the external patterns file. Do NOT" \
      "exempt a file from the scrub: it is copied into a public artefact and an exemption would publish" \
      "whatever it holds."
fi
echo "  ✅ every release-tooling file and every pinned re-run file survived the scrub byte-for-byte"

echo
echo "=== 3. scrubbed transcript tarballs -> transcripts/ ==="
if [ -d "$OLD" ]; then
  cp "$OLD"/*.scrubbed.tar.gz "$PUB/transcripts/" 2>/dev/null
  cp "$OLD/README.md" "$PUB/transcripts/README.md" 2>/dev/null
  echo "  refreshed from the transcripts source directory"
else
  echo "  (no transcripts source directory — keeping the tarballs already in the bundle, NOT wiping them)"
fi
NTAR=$(ls "$PUB/transcripts"/*.tar.gz 2>/dev/null | wc -l)
echo "  scrubbed tarballs present: $NTAR"
if [ "$NTAR" -eq 0 ]; then
  die "the bundle has ZERO raw-evidence tarballs. Do not publish." \
      "Recover with: git restore -- experiments/deny-rule-adversarial/public-release/transcripts/"
fi

echo
echo "=== 4. VERIFY the whole bundle ==="
# 🔴 This step used to print the PATTERN LIST — the employer name, the personal email
# domain and the internal tier vocabulary, spelled out in the build log and copied into
# the bundle's own README (finding 7.1). The content passed; the certificate leaked.
# A scrub report names CATEGORIES, never instances. The gate below does that, scans the
# tarball contents too, carries a positive control, and exits non-zero on any hit.
python3 "$TOOL_DIR/bundle-stopword-gate.py" "$PUB"
GATE=$?

echo
echo "=== 4b. relative links ==="
python3 "$TOOL_DIR/check-links.py" "$PUB"
LINKS=$?

echo
echo "=== 5. attribution preserved (positive control, should be > 0) ==="
echo "  attribution present in $(grep -rEo 'Vagelis Papaloukas' "$PUB" 2>/dev/null | wc -l) place(s)"

echo
echo "=== bundle tree ==="
find "$PUB" -maxdepth 2 -type d | sed "s|^$PUB|<bundle>|"
echo "total bundle size: $(du -sh "$PUB" | cut -f1)"

echo
if [ "$GATE" -ne 0 ] || [ "$LINKS" -ne 0 ]; then
  say "RELEASE GATE FAILED - bundle assembled but MUST NOT be published."
  say "   gate exit $GATE, link check exit $LINKS. Details: $BUNDLE_LOG"
  exit 1
fi
say "RELEASE GATE PASSED - no known pattern matched and every relative link resolves."
say "   Necessary, not sufficient: see the gate's own notes in $BUNDLE_LOG"
exit 0
