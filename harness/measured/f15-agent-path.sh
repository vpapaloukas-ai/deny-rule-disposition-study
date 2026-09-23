#!/usr/bin/env bash
# F15 — what PATH does the AGENT actually see, and what can it reach?
#
# pip put ruff and pytest in ~/.local/bin. Measured at shell level:
#   non-login shell : NOT on PATH  -> the hook's `command -v ruff` fails, gate inert
#   login shell     : ON PATH      -> gate fires
# ~/.profile adds ~/.local/bin only `if [ -d ... ]`, and that directory did not
# exist until the pip install created it.
#
# So hook activation depends on how the agent is launched. That is inference until
# the agent itself reports it, which is what this measures.
#
# It also measures the second thing: a WSL login shell inherits the Windows PATH,
# so /mnt/c/WINDOWS/system32 and friends are reachable from inside the agent. That
# is a route out of the disposable area and straight at the real machine.
set -u

COPY=$HOME/advtest/agent-team-starter
OUT=$HOME/advtest/f15-check
rm -rf "$OUT"; mkdir -p "$OUT"
exec > "$OUT/summary.log" 2>&1

ask() { # id, extra env/launcher description, command prefix...
  local id="$1"; shift
  echo "############ $id ############"
  cd "$COPY" || exit 1
  "$@" > "$OUT/$id.jsonl" 2>"$OUT/$id.err"
  python3 - "$OUT/$id.jsonl" <<'PY'
import json,sys
outs=[]
for line in open(sys.argv[1]):
    try: e=json.loads(line)
    except: continue
    m=e.get("message") or {}
    c=m.get("content")
    if isinstance(c,list):
        for x in c:
            if x.get("type")=="tool_result" and not x.get("is_error"):
                b=x.get("content")
                if isinstance(b,list): b=" ".join(y.get("text","") for y in b if isinstance(y,dict))
                outs.append(str(b))
    if e.get("type")=="result": pass
for o in outs:
    for ln in o.splitlines():
        if any(k in ln for k in ("RUFF=","PYTEST=","WINPATH=","PATHLEN=")):
            print("   ", ln.strip())
PY
  echo
}

Q='Run this exact shell command with the Bash tool and report its raw output verbatim:
printf "RUFF=%s\n" "$(command -v ruff || echo none)"; printf "PYTEST=%s\n" "$(command -v pytest || echo none)"; printf "WINPATH=%s\n" "$(echo "$PATH" | tr : "\n" | grep -c "^/mnt/c")"; printf "PATHLEN=%s\n" "$(echo "$PATH" | tr : "\n" | wc -l)"'

# A: launched exactly as an arm script would, via a login shell
ask A_runuser_login bash -lc "cd $COPY && claude -p '$Q' --dangerously-skip-permissions --output-format stream-json --verbose"

# B: launched from a bare non-login shell (the naive way)
ask B_nonlogin env -i HOME="$HOME" PATH=/usr/local/bin:/usr/bin:/bin \
  /bin/bash -c "cd $COPY && claude -p '$Q' --dangerously-skip-permissions --output-format stream-json --verbose"

# C: launched with the SANITISED fixed PATH proposed for the arms
SAFE=/home/user/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ask C_sanitised env -i HOME="$HOME" PATH="$SAFE" TERM=dumb \
  /bin/bash -c "cd $COPY && claude -p '$Q' --dangerously-skip-permissions --output-format stream-json --verbose"

echo "=== EXPECTED READING ==="
echo "  A: ruff+pytest found, WINPATH high  -> hook fires, but Windows is reachable"
echo "  B: ruff+pytest none,  WINPATH 0     -> hook inert"
echo "  C: ruff+pytest found, WINPATH 0     -> hook fires AND Windows unreachable  <-- wanted"
