#!/usr/bin/env bash
# Stage 1: enumerate deny rules verbatim from the pinned commit's settings file.
set -u
exec > /tmp/stage1.log 2>&1

COPY=$HOME/advtest/agent-team-starter
PIN=a61aafd269fd27b92d619452cf43b2235d181e48
cd "$COPY" || exit 1

echo "=== PROVENANCE ==="
echo "repo path:   $COPY"
echo "commit:      $(git rev-parse HEAD)"
echo "file path:   .claude/settings.json"
echo "blob sha:    $(git rev-parse $PIN:.claude/settings.json)"
echo "worktree sha256: $(sha256sum .claude/settings.json | cut -d' ' -f1)"
echo "committed  sha256: $(git show $PIN:.claude/settings.json | sha256sum | cut -d' ' -f1)"
echo "worktree == committed: $([ "$(sha256sum < .claude/settings.json)" = "$(git show $PIN:.claude/settings.json | sha256sum)" ] && echo YES || echo NO)"

echo
echo "=== FULL settings.json AT PINNED COMMIT ==="
git show $PIN:.claude/settings.json

echo
echo "=== DENY ARRAY, ONE ENTRY PER LINE, VERBATIM ==="
git show $PIN:.claude/settings.json | python3 -c '
import json,sys
d=json.load(sys.stdin)
deny=d["permissions"]["deny"]
print("count:",len(deny))
for i,r in enumerate(deny,1):
    print("D%d\t%r" % (i,r))
'

echo
echo "=== ALLOW ARRAY COUNT (context only) ==="
git show $PIN:.claude/settings.json | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("allow entries:",len(d["permissions"]["allow"]))
print("ask entries:",len(d["permissions"].get("ask",[])))
'

echo
echo "=== ROLE AGENT FRONTMATTER (tools/permissions per role) ==="
for f in .claude/agents/*.md; do
  echo "--- $f ---"
  awk 'NR==1&&/^---/{inf=1;next} inf&&/^---/{exit} inf{print}' "$f"
done

echo
echo "=== ANY OTHER SETTINGS FILES IN TREE? ==="
find . -path ./.git -prune -o -name 'settings*.json' -print
echo "--- .claude tree ---"
find .claude -type f | sort
