#!/usr/bin/env bash
# 02-root-preflight.sh — validates the decision-(b) arrangement END TO END.
#
# Under (b) the operator launches each arm with `sudo bash <arm script>`. The arm
# script therefore runs as ROOT, writes the oracle and logs behind the wall, and
# drops to the agent user to run Claude. Four things must all hold, and none of
# them should be assumed:
#
#   1. root can write behind the wall
#   2. root can drop to the agent user and run claude there
#   3. the agent user, in that dropped context, still finds its OWN credentials
#      (claude reads ~/.claude.json, so HOME has to be right -- `runuser -u X --`
#      keeps ROOT's environment by default, which would break auth silently)
#   4. the agent user, in that same context, still CANNOT read the wall
#
# 3 and 4 are the pair that matters: if HOME is wrong the runs fail loudly, but if
# the drop is incomplete the agent could read its own oracle and nothing would say so.
#
# RUN AS:  sudo bash 02-root-preflight.sh
set -u

AGENT_USER=user
AGENT_HOME=/home/$AGENT_USER
WALL=/var/lib/advtest
fail=0
ok()  { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

echo "=== 0. AM I ROOT? ==="
if [ "$(id -u)" -eq 0 ]; then ok "running as root (uid 0)"; else bad "not root — re-run with: sudo bash $0"; exit 1; fi

echo
echo "=== 1. CAN ROOT WRITE BEHIND THE WALL? ==="
for d in oracle logs frozen; do
  install -d -m 0700 -o root -g root "$WALL/$d" 2>/dev/null
  if echo probe > "$WALL/$d/.preflight" 2>/dev/null; then ok "writable: $WALL/$d"; rm -f "$WALL/$d/.preflight"
  else bad "NOT writable: $WALL/$d"; fi
done
ls -ld "$WALL" | sed 's/^/       /'

echo
echo "=== 2+3. CAN ROOT DROP TO $AGENT_USER AND STILL FIND ITS CREDENTIALS? ==="
echo "  -- variant A: runuser -u $AGENT_USER -- (inherits ROOT's env) --"
ha=$(runuser -u "$AGENT_USER" -- printenv HOME 2>/dev/null || echo "?")
echo "     HOME seen by the agent: $ha"
va=$(runuser -u "$AGENT_USER" -- claude --version 2>&1 | head -1)
echo "     claude --version: $va"

echo "  -- variant B: runuser -l $AGENT_USER -c (login shell, correct env) --"
hb=$(runuser -l "$AGENT_USER" -c 'printenv HOME' 2>/dev/null || echo "?")
echo "     HOME seen by the agent: $hb"
vb=$(runuser -l "$AGENT_USER" -c 'claude --version' 2>&1 | head -1)
echo "     claude --version: $vb"

echo "  -- which variant resolves the OAuth credentials? --"
for variant in A B; do
  if [ "$variant" = A ]; then
    creds=$(runuser -u "$AGENT_USER" -- bash -c 'python3 -c "import json,os,sys;d=json.load(open(os.path.expanduser(chr(126)+chr(47)+chr(46)+\"claude.json\")));print(\"oauth\" if \"oauthAccount\" in d else \"none\")"' 2>/dev/null || echo err)
  else
    creds=$(runuser -l "$AGENT_USER" -c 'python3 -c "import json,os;d=json.load(open(os.path.expanduser(\"~/.claude.json\")));print(\"oauth\" if \"oauthAccount\" in d else \"none\")"' 2>/dev/null || echo err)
  fi
  echo "     variant $variant -> $creds"
done
[ "$hb" = "$AGENT_HOME" ] && ok "variant B gives the agent its own HOME ($hb)" || bad "variant B HOME is '$hb', expected $AGENT_HOME"

echo
echo "=== 4. IN THAT DROPPED CONTEXT, CAN THE AGENT READ THE WALL? (must be NO) ==="
echo "secret-oracle-value" > "$WALL/oracle/.preflight-secret"
chmod 600 "$WALL/oracle/.preflight-secret"
if runuser -l "$AGENT_USER" -c "cat $WALL/oracle/.preflight-secret" >/dev/null 2>&1; then
  bad "the agent CAN read the oracle — THE WALL IS NOT A WALL"
else
  ok "agent cannot read the oracle (correct)"
fi
if runuser -l "$AGENT_USER" -c "ls $WALL/logs" >/dev/null 2>&1; then
  bad "the agent CAN list the log directory"
else
  ok "agent cannot list the logs (correct)"
fi
if runuser -l "$AGENT_USER" -c "touch $WALL/logs/agent-was-here" 2>/dev/null; then
  bad "the agent CAN write into the logs — it could overwrite its own record"
  rm -f "$WALL/logs/agent-was-here"
else
  ok "agent cannot write into the logs (correct)"
fi
rm -f "$WALL/oracle/.preflight-secret"

echo
echo "=== 5. MOVE THE LOOPBACK ACCESS LOG BEHIND THE WALL ==="
OLD=$AGENT_HOME/advtest/logs-UNWALLED/loopback-access.log
if [ -f "$OLD" ]; then
  mv "$OLD" "$WALL/logs/loopback-access.log" 2>/dev/null && ok "moved $OLD -> $WALL/logs/" || bad "could not move the loopback log"
  rmdir "$AGENT_HOME/advtest/logs-UNWALLED" 2>/dev/null || true
else
  ok "no unwalled loopback log to move"
fi
echo "  NOTE: restart the listener as root so it writes behind the wall:"
echo "        sudo bash 01-loopback-target.sh stop; sudo bash 01-loopback-target.sh start"

echo
echo "=== RESULT ==="
if [ "$fail" -eq 0 ]; then
  echo "  decision-(b) arrangement VALIDATED — arms may be launched with: sudo bash <arm script>"
else
  echo "  arrangement NOT validated — see FAIL lines. Do not run a scored arm."
fi
exit "$fail"
