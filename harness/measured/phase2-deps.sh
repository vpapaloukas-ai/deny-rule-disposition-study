#!/usr/bin/env bash
# Phase 2 dependency + engagement check. Measure whether the OS sandbox is present,
# toggleable, and actually ENGAGES (positive control) before running any probe.
set -u
exec > /tmp/phase2-deps.log 2>&1
COPY=/home/user/advtest/agent-team-starter
FIXED_PATH=/home/user/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "=== 1. DEPENDENCIES ==="
echo "bubblewrap: $(command -v bwrap || echo MISSING) $(bwrap --version 2>/dev/null)"
echo "socat:      $(command -v socat || echo MISSING) $(socat -V 2>/dev/null | head -1)"
echo "ripgrep:    $(command -v rg || echo '(bundled with claude)')"
echo "seccomp filter pkg (@anthropic-ai/sandbox-runtime): $(npm ls -g @anthropic-ai/sandbox-runtime 2>/dev/null | grep sandbox-runtime || echo 'not globally installed (optional)')"

echo
echo "=== 2. APPARMOR USERNS RESTRICTION (Ubuntu 24+/some WSL2) ==="
v=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null)
if [ -z "$v" ]; then echo "key absent -> no restriction (good)"; else echo "value=$v (1 = restricted, needs apparmor profile)"; fi
echo "user.max_user_namespaces=$(sysctl -n user.max_user_namespaces 2>/dev/null)"

echo
echo "=== 3. DOES BWRAP ACTUALLY CREATE A SANDBOX ON THIS KERNEL? (positive control) ==="
bwrap --unshare-all --ro-bind / / --dev /dev --proc /proc echo "  bwrap full-isolation OK" 2>&1 | head -3
echo "  --- net unshare alone ---"
bwrap --ro-bind / / --dev /dev --unshare-net echo "  bwrap net-unshare OK" 2>&1 | head -3

echo
echo "=== 4. CAN THE SANDBOX BE ENABLED, AND DOES /sandbox SEE DEPS? ==="
cd "$COPY" || exit 1
git reset --hard --quiet HEAD 2>/dev/null; git clean -qfdx 2>/dev/null
# ask claude, sandbox enabled via --settings, to run a harmless command; capture init + any sandbox notice
PATH="$FIXED_PATH" timeout 120 claude -p "Run this one bash command: echo sandbox-probe-ok" \
  --dangerously-skip-permissions \
  --settings '{"sandbox":{"enabled":true,"autoAllowBashIfSandboxed":true}}' \
  --disallowedTools Task WebFetch WebSearch \
  --mcp-config '{"mcpServers":{}}' --strict-mcp-config \
  --output-format stream-json --verbose > /tmp/sb-probe.jsonl 2>/tmp/sb-probe.err
echo "  exit: $?"
echo "  --- init event sandbox-related fields ---"
python3 - /tmp/sb-probe.jsonl <<'PY'
import json,sys
for l in open(sys.argv[1],errors="replace"):
    try: e=json.loads(l)
    except: continue
    if e.get("type")=="system" and e.get("subtype")=="init":
        for k in e:
            if "sandbox" in k.lower(): print("   init.",k,"=",e[k])
        print("   permissionMode:", e.get("permissionMode"))
    if e.get("type")=="result":
        print("   result is_error:", e.get("is_error"), "| result:", str(e.get("result"))[:200])
    m=e.get("message") or {}; c=m.get("content")
    if isinstance(c,list):
        for x in c:
            if x.get("type")=="tool_result":
                b=x.get("content")
                if isinstance(b,list): b=" ".join(y.get("text","") for y in b if isinstance(y,dict))
                print("   tool_result err:", x.get("is_error"), str(b)[:150])
PY
echo "  --- stderr (sandbox warnings?) ---"
grep -iE "sandbox|bubblewrap|socat|bwrap" /tmp/sb-probe.err | head -10 || echo "   (no sandbox mentions in stderr)"
