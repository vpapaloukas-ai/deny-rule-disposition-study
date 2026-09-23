#!/usr/bin/env bash
# 04-freeze-substrate.sh — repair the two artefacts of the blinding constraint,
# then FREEZE the substrate into the template copy.
#
# WHY ANY EDIT AT ALL. The blind session was denied Bash, so it could never run
# ruff or pytest against its own work. It left two lint errors. That matters
# because the template's QA hook runs `ruff check .` on EVERY Edit/Write and exits
# 2 on failure, feeding stderr back to the agent -- so with pre-existing errors,
# every task in arms A/B/C would hit a failing gate for a reason that has nothing
# to do with the deny rules.
#
# These are corrections for an artefact of MY harness constraint, not shaping of
# the study: neither touches git, deletion, or the network, so neither can move a
# task toward or away from any of the six rules. Both are recorded verbatim below.
#
#   UP035  src/proration/money.py:13   typing.Sequence -> collections.abc.Sequence
#   B015   tests/test_money.py:34      comparison inside pytest.raises reads as
#                                      pointless to ruff; bind it so the intent is
#                                      explicit and the checker agrees
set -u

B=$HOME/advtest/substrate-build
COPY=$HOME/advtest/agent-team-starter
PIN=a61aafd269fd27b92d619452cf43b2235d181e48
export PATH="$HOME/.local/bin:$PATH"

echo "=== 0. PRE-STATE ==="
cd "$B" || exit 1
echo "  ruff before: $(ruff check . 2>&1 | tail -1)"
echo "  pytest before: $(python3 -m pytest -q 2>&1 | tail -1)"

echo
echo "=== 1. RECORD THE EXACT LINES BEING CHANGED ==="
echo "  money.py:13  -> $(sed -n '13p' src/proration/money.py)"
echo "  test_money.py:34 -> $(sed -n '34p' tests/test_money.py)"

echo
echo "=== 2. APPLY THE TWO FIXES ==="
ruff check --fix --quiet . 2>&1 | tail -3
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("tests/test_money.py")
s = p.read_text()
before = s
# make the raising comparison explicit rather than a bare expression statement
s = s.replace('        Money(100, "USD") < Money(100, "EUR")\n',
              '        _ = Money(100, "USD") < Money(100, "EUR")\n')
if s != before:
    p.write_text(s); print("  test_money.py: bound the comparison to _")
else:
    print("  test_money.py: NO CHANGE MADE -- pattern not found, inspect manually")
PY

echo
echo "=== 3. POST-STATE, VERIFIED BY EXECUTION ==="
echo "  money.py:13  -> $(sed -n '13p' src/proration/money.py)"
echo "  test_money.py:34 -> $(sed -n '34p' tests/test_money.py)"
echo "  ruff:   $(ruff check . 2>&1 | tail -1)"
echo "  pytest: $(python3 -m pytest -q 2>&1 | tail -1)"

echo
echo "=== 4. STRIP CACHES (artefacts of verification, must not be frozen) ==="
find "$B" \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.ruff_cache' \) -exec rm -rf {} + 2>/dev/null
find "$B" -type f | sed "s|$B|  .|" | sort

echo
echo "=== 5. FREEZE INTO THE TEMPLATE COPY ==="
# TWO COLLISIONS with the template, handled explicitly rather than by last-write-wins:
#
#   README.md  — the template's README documents the roles and the template itself.
#                Overwriting it would change the artefact under test. The template's
#                is RESTORED and the substrate's goes to docs/proration.md, which
#                ADDS a file rather than replacing one.
#   .gitignore — the template's is kept and the substrate's Python patterns are
#                APPENDED. Without them, running the test suite leaves untracked
#                __pycache__ everywhere, which would dirty the tree after every run
#                and give the clean-tree precondition and any `git clean` probe
#                something to trip over that has nothing to do with the study.
git -C "$COPY" reset --hard --quiet "$PIN"
git -C "$COPY" clean -qfdx

cp -a "$B/." "$COPY/"
git -C "$COPY" checkout --quiet -- README.md          # restore the template's
mkdir -p "$COPY/docs"
cp -a "$B/README.md" "$COPY/docs/proration.md"        # substrate's, relocated

git -C "$COPY" checkout --quiet -- .gitignore         # restore the template's
{
  echo ""
  echo "# --- added with the proration substrate ---"
  cat "$B/.gitignore"
} >> "$COPY/.gitignore"

echo "  template files MODIFIED (must be .gitignore and nothing else):"
git -C "$COPY" status --porcelain | grep '^ M' | sed 's/^/    /' || echo "    (none)"
echo "  README.md identical to the template's? $(git -C "$COPY" diff --quiet -- README.md && echo YES || echo NO)"
echo "  full tree status:"
git -C "$COPY" status --porcelain | sed 's/^/    /'

echo
echo "=== 6. DOES THE TEMPLATE'S QA HOOK NOW ACTIVATE? ==="
cd "$COPY" || exit 1
bash .claude/hooks/check.sh; rc=$?
echo "  hook exit code: $rc  (0 = pass; 2 = fail)"
echo "  ^ if it printed the 'checking NOTHING' notice, the gate is inert;"
echo "    if it printed nothing and exited 0, ruff ran and passed."

echo
echo "=== 7. FROZEN TREE HASH ==="
git -C "$COPY" add -A >/dev/null 2>&1
echo "  substrate tree hash: $(git -C "$COPY" write-tree)"
git -C "$COPY" reset --quiet
echo "  files added on top of $PIN: $(git -C "$COPY" status --porcelain | wc -l)"
