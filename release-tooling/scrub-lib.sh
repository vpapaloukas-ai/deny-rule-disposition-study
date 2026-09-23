#!/usr/bin/env bash
# scrub-lib.sh - the one definition of the publication scrub. Sourced, never executed, by
# assemble-public-bundle.sh and scrub-n50-transcripts.sh in this directory.
#
# WHY ONE FILE. The as-ran pair in harness/ each carried their own copy of these rules, and the
# copies drifted: the assembler's reader learned to confine an optional third column and to strip
# carriage returns, and the transcript scrub's reader never did. A rule stated in two places is
# enforced in one. Sourced from one file, it cannot drift from itself.
#
# 🔴 NO RULE HERE MATCHES ITS OWN SOURCE TEXT. This file is published, so the build scrubs it,
# and the build's byte-identity guard fails if the scrub changes a single byte. The as-ran rules
# were written as plain literals, so the scrub rewrote them inside the published copies: the
# repository-path rule became a rule that matches nothing, and the role-label rule became a
# rule that replaces a word with itself. Both scripts shipped broken and looked correct.
# Here every path rule begins with a character class where a literal letter would be, and the
# role label is split across two quoted strings. Comments describe shapes, never strings.
#
# 🔴 PATH SHAPES. The tree has lived at two depths below the web root, and a worktree adds two
# more segments. A rule that consumes a fixed number of segments is right for one depth and
# leaks the layout at the others, one segment short (recorded four times in this study). So the
# primary repository rules consume every segment up to the experiments directory, whatever the
# depth. The fixed-depth rules after them only handle paths that never reach it.
#
# 🔴 SPELLINGS. One location, five spellings: the Linux mount form, the Windows drive form with
# backslashes, the same form JSON-escaped, the drive form with forward slashes, and the Git Bash
# form; plus the project-directory slug Claude Code derives from the drive form. A literal-string
# matcher misses whichever spelling nobody listed - the study's own Arm D finding.

# scrub_find_patterns - sets SCRUB_PATTERNS to the external personal-patterns file, or returns 1.
# An explicitly set SCRUB_PATTERNS is honoured strictly and never falls back to a search. Every
# caller must abort on 1: without the file the personal substitutions silently do not run and
# the output looks clean.
scrub_find_patterns() {
  if [ -z "${SCRUB_PATTERNS:-}" ]; then
    local c
    for c in "$HOME/.claude/scrub-patterns.txt" /mnt/c/Users/*/.claude/scrub-patterns.txt; do
      [ -f "$c" ] && { SCRUB_PATTERNS="$c"; break; }
    done
  fi
  [ -f "${SCRUB_PATTERNS:-/nonexistent}" ]
}

# scrub_file FILE - in-place scrub of one text file. Requires SCRUB_PATTERNS (scrub_find_patterns).
scrub_file() {
  local pat rep _cat
  # Personal strings, from outside the repository. Tab-separated: pattern, replacement, and an
  # optional category that only the gate reads. `_cat` confines that third column: without it
  # `read` puts the tab and the category into the replacement. `tr -d '\r'` strips the carriage
  # return a Windows editor adds, which would otherwise be substituted into every replacement.
  while IFS=$'\t' read -r pat rep _cat; do
    case "$pat" in ''|'#'*) continue ;; esac
    sed -i "s/$pat/$rep/g" "$1"
  done < <(tr -d '\r' < "$SCRUB_PATTERNS")

  # Structural shapes. Order matters: home directories first, then repository paths anchored on
  # the experiments directory, then the fixed-depth fallbacks, then the rest.
  sed -E -i \
    -e 's#/mnt/[a-z]/Users/[A-Za-z0-9._-]+#<home>#g' \
    -e 's#[A-Za-z]:(\\\\|\\|/)Users(\\\\|\\|/)[A-Za-z0-9._-]+#<home>#g' \
    -e 's#(^|[^A-Za-z0-9._-])/[a-z]/Users/[A-Za-z0-9._-]+#\1<home>#g' \
    -e 's#/mnt/[a-z]/web/([A-Za-z0-9._-]+/)*experiments/#<repo>/experiments/#g' \
    -e 's#[A-Za-z]:(\\\\|\\|/)web(\\\\|\\|/)([A-Za-z0-9._-]+(\\\\|\\|/))*experiments(\\\\|\\|/)#<repo>/experiments/#g' \
    -e 's#(^|[^A-Za-z0-9._-])/[a-z]/web/([A-Za-z0-9._-]+/)*experiments/#\1<repo>/experiments/#g' \
    -e 's#/mnt/[a-z]/web/vpapaloukas-ai/[A-Za-z0-9._-]+#<repo>#g' \
    -e 's#[A-Za-z]:(\\\\|\\|/)web(\\\\|\\|/)vpapaloukas-ai(\\\\|\\|/)[A-Za-z0-9._-]+#<repo>#g' \
    -e 's#(^|[^A-Za-z0-9._-])/[a-z]/web/vpapaloukas-ai/[A-Za-z0-9._-]+#\1<repo>#g' \
    -e 's#/mnt/[a-z]/web/[A-Za-z0-9._-]+#<repo>#g' \
    -e 's#[A-Za-z]:(\\\\|\\|/)web(\\\\|\\|/)[A-Za-z0-9._-]+#<repo>#g' \
    -e 's#(^|[^A-Za-z0-9._-])/[a-z]/web/[A-Za-z0-9._-]+#\1<repo>#g' \
    -e 's#(^|[^A-Za-z0-9])[A-Za-z]--web-[A-Za-z0-9._-]+#\1<repo>#g' \
    -e 's/Found''er/Operator/g' \
    -e 's/found''er/operator/g' \
    -e 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/<uuid>/g' \
    "$1"
}
