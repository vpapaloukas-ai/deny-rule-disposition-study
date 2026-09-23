#!/usr/bin/env bash
set -u
exec > /tmp/origin.log 2>&1
COPY=$HOME/advtest/agent-team-starter
R=$HOME/advtest/remote.git
REAL=<repo>

echo "=== WHERE origin POINTS NOW ==="
git -C "$COPY" remote -v

echo
echo "=== IS THE REAL REPO REFERENCED ANYWHERE IN THE COPY'S GIT CONFIG? ==="
if grep -q "vpapaloukas-ai/agent-team-starter" "$COPY/.git/config"; then
  echo "  YES -- STILL A HAZARD"; grep -n "vpapaloukas" "$COPY/.git/config"
else
  echo "  NO -- clean"
fi

echo
echo "=== THROWAWAY REMOTE GUARDS ==="
echo "  denyDeletes:         $(git --git-dir="$R" config --get receive.denyDeletes)"
echo "  denyNonFastforwards: $(git --git-dir="$R" config --get receive.denyNonFastforwards)"
echo "  refs currently in throwaway: $(git --git-dir="$R" for-each-ref | wc -l)"

echo
echo "=== REAL REPO STATE ON THE WINDOWS DRIVE (must be untouched) ==="
echo "  HEAD:   $(git -C "$REAL" rev-parse HEAD)"
echo "  branches: $(git -C "$REAL" branch | tr -d ' ' | tr '\n' ' ')"
echo "  status: $(git -C "$REAL" status --porcelain | wc -l) porcelain lines (0 = clean)"
echo "  reflog entries today: $(git -C "$REAL" reflog --date=short 2>/dev/null | wc -l)"

echo
echo "=== LIVE TEST: a push from the copy lands in the THROWAWAY, not the real repo ==="
cd "$COPY" || exit 1
git push -q origin HEAD:refs/heads/verify-check
echo "  throwaway refs after push:"
git --git-dir="$R" for-each-ref --format='    %(refname) %(objectname:short)'
echo "  real repo branches after push:"
git -C "$REAL" branch | sed 's/^/    /'
echo "  real repo HEAD unchanged: $(git -C "$REAL" rev-parse --short HEAD)"
echo "  -- cleaning the verify ref (force, since denyDeletes blocks the push route) --"
git --git-dir="$R" update-ref -d refs/heads/verify-check
echo "  throwaway refs after cleanup: $(git --git-dir="$R" for-each-ref | wc -l)"
