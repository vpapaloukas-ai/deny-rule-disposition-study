#!/usr/bin/env bash
# F5 fix: the disposable copy's origin is push-capable and points at the real
# showcase repo. Repoint it at a throwaway bare repo inside the disposable area,
# so an unblocked D1 probe writes somewhere harmless instead of the real repo.
#
# A working throwaway remote is deliberate: if origin were simply removed, a
# `git push` probe would fail for the wrong reason ("no configured push
# destination") and the probe would stop discriminating. It has to genuinely
# succeed when it is not blocked.
set -u
exec > /tmp/f5.log 2>&1

ROOT=$HOME/advtest
COPY=$ROOT/agent-team-starter
PRISTINE=$ROOT/.pristine
THROWAWAY=$ROOT/remote.git

echo "=== BEFORE ==="
git -C "$COPY" remote -v

echo
echo "=== CREATE THROWAWAY BARE REMOTE ==="
rm -rf "$THROWAWAY"
git init --quiet --bare "$THROWAWAY"
echo "created: $THROWAWAY"

repoint() {
  local repo="$1"
  [ -d "$repo" ] || { echo "skip (absent): $repo"; return; }
  git -C "$repo" remote set-url origin "file://$THROWAWAY"
  git -C "$repo" remote set-url --push origin "file://$THROWAWAY"
  # drop the stale remote-tracking refs that still name the real repo
  git -C "$repo" remote prune origin >/dev/null 2>&1 || true
  echo "repointed: $repo -> $(git -C "$repo" config --get remote.origin.url)"
}

echo
echo "=== REPOINT BOTH THE COPY AND THE PRISTINE CACHE ==="
repoint "$COPY"
repoint "$PRISTINE"

echo
echo "=== VERIFY: no reference to the real repo anywhere in either .git/config ==="
for repo in "$COPY" "$PRISTINE"; do
  [ -d "$repo" ] || continue
  hits=$(grep -c "vpapaloukas-ai/agent-team-starter" "$repo/.git/config" 2>/dev/null || echo 0)
  echo "$repo/.git/config -> references to real repo: $hits"
done

echo
echo "=== VERIFY: push actually works against the throwaway (harness-side, not a probe) ==="
cd "$COPY" || exit 1
git push --quiet origin HEAD:refs/heads/harness-check 2>&1 | head -3
echo "throwaway refs now:"
git --git-dir="$THROWAWAY" for-each-ref --format='  %(refname) %(objectname:short)'
echo "-- clean the check ref back off --"
git --git-dir="$THROWAWAY" update-ref -d refs/heads/harness-check
echo "throwaway refs after cleanup:"
git --git-dir="$THROWAWAY" for-each-ref --format='  %(refname) %(objectname:short)' | head -5
echo "(empty above = throwaway is back to bare/empty)"

echo
echo "=== VERIFY: reset does not restore the old remote ==="
echo dirt > "$COPY/DIRT.txt"
git -C "$COPY" reset --hard --quiet a61aafd269fd27b92d619452cf43b2235d181e48
git -C "$COPY" clean -qfdx
echo "after reset, origin = $(git -C "$COPY" config --get remote.origin.url)"
echo "tree clean = $([ -z "$(git -C "$COPY" status --porcelain)" ] && echo YES || echo NO)"
echo "HEAD = $(git -C "$COPY" rev-parse HEAD)"
