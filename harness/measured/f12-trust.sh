#!/usr/bin/env bash
# F12: an untrusted workspace makes Claude Code SILENTLY IGNORE the 21 allow
# entries. A fresh clone at a new path is untrusted by default. If that state
# went unnoticed, every arm would score near-100% blocked as a pure artefact.
#
# This sets trust for the one disposable test path (the remedy the tool's own
# error message documents) and verifies by execution that the warning goes away.
# ~/.claude.json is backed up first. Only the single project entry is touched.
set -u
exec > /tmp/f12.log 2>&1

CONF=$HOME/.claude.json
COPY=$HOME/advtest/agent-team-starter
BK=$HOME/advtest/claude.json.backup-before-trust

echo "=== BACKUP ==="
cp -a "$CONF" "$BK"
echo "backed up to: $BK ($(stat -c%s "$BK") bytes)"

echo
echo "=== BEFORE: warning present? ==="
cd "$COPY" || exit 1
timeout 60 claude -p "say ok" --output-format stream-json --verbose >/dev/null 2>/tmp/before.err
echo "stderr:"; cat /tmp/before.err
echo "allow-ignored warning present: $(grep -c 'has not been trusted' /tmp/before.err)"

echo
echo "=== SET TRUST FOR THE ONE TEST PATH ==="
python3 <<'PY'
import json, os
p = os.path.expanduser("~/.claude.json")
target = "/home/user/advtest/agent-team-starter"
d = json.load(open(p))
d.setdefault("projects", {}).setdefault(target, {})["hasTrustDialogAccepted"] = True
json.dump(d, open(p, "w"), indent=2)
print("set hasTrustDialogAccepted=True for", target)
PY

echo
echo "=== VERIFY THE FLAG ==="
python3 <<'PY'
import json, os
d = json.load(open(os.path.expanduser("~/.claude.json")))
e = d["projects"]["/home/user/advtest/agent-team-starter"]
print("hasTrustDialogAccepted:", e.get("hasTrustDialogAccepted"))
# NOTE: this used to also print len(d["projects"]) — a count of every project the
# operator has ever opened. It verified nothing this check needs and is an account
# fact, so it was cut before release (2026-08-08).
PY

echo
echo "=== AFTER: warning gone? ==="
cd "$COPY" || exit 1
timeout 60 claude -p "say ok" --output-format stream-json --verbose >/dev/null 2>/tmp/after.err
echo "stderr:"; cat /tmp/after.err
echo "allow-ignored warning present: $(grep -c 'has not been trusted' /tmp/after.err)"

echo
echo "=== DOES TRUST SURVIVE A TREE RESET? (it lives in ~/.claude.json, not the tree) ==="
git -C "$COPY" reset --hard --quiet a61aafd269fd27b92d619452cf43b2235d181e48
git -C "$COPY" clean -qfdx
cd "$COPY" && timeout 60 claude -p "say ok" >/dev/null 2>/tmp/afterreset.err
echo "after reset, warning present: $(grep -c 'has not been trusted' /tmp/afterreset.err)"

echo
echo "=== AUTH STATE (the other blocker) ==="
grep -c 'Not logged in' /tmp/after.err || true
# NOTE: this used to also report whether an OAuth account object was present in the
# operator's user config. That is an account fact about the person running the study,
# not a property of the thing under test, and the 'Not logged in' check above already
# answers the question this step exists to ask. Cut before release (2026-08-08).
