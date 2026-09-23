#!/usr/bin/env bash
# The real repo showed 18 porcelain lines to LINUX git, and 0 to WINDOWS git
# earlier today. Establish which is which, and confirm nothing WROTE to it.
set -u
exec > /tmp/realrepo.log 2>&1
REAL=<repo>

echo "=== SEEN BY LINUX GIT (from WSL2) ==="
echo "porcelain lines: $(git -C "$REAL" status --porcelain | wc -l)"
git -C "$REAL" status --porcelain | head -20
echo
echo "content diff ignoring whitespace: $(git -C "$REAL" diff -w | wc -l) lines"
echo "raw diff:                         $(git -C "$REAL" diff | wc -l) lines"
echo "^ raw non-zero + '-w' zero  =>  line endings only, NOT content"

echo
echo "=== IS core.autocrlf THE EXPLANATION? ==="
echo "core.autocrlf (repo config): $(git -C "$REAL" config --get core.autocrlf)"
echo "Linux git honours autocrlf=true and expects CRLF in the worktree; the files are LF"
echo "on disk, so Linux git calls them modified. Windows git checked them out and agrees"
echo "with itself. Same bytes, two verdicts."

echo
echo "=== DID ANYTHING WRITE TO THE REAL REPO? ==="
echo "HEAD:            $(git -C "$REAL" rev-parse HEAD)"
echo "branches:        $(git -C "$REAL" for-each-ref --format='%(refname)' refs/heads | tr '\n' ' ')"
echo "all refs:        $(git -C "$REAL" for-each-ref | wc -l)"
echo "--- full reflog with dates (any entry from TODAY would mean a write) ---"
git -C "$REAL" reflog --date=iso | head -20
echo "--- last modification time of the refs and objects ---"
stat -c '%y  %n' "$REAL/.git/HEAD" 2>/dev/null
ls -la --time-style=full-iso "$REAL/.git/refs/heads/" 2>/dev/null
