#!/usr/bin/env bash
# Phase 2 gating question: how is the Claude Code OS sandbox enabled, and does it
# engage? Measure — do not assume. (Stage 0 left this unsettled.)
set -u
exec > /tmp/sandbox-invest.log 2>&1
B=/usr/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
DTS=/usr/lib/node_modules/@anthropic-ai/claude-code/sdk-tools.d.ts

echo "=== 1. sandbox-related config keys in the binary ==="
strings -n 5 "$B" 2>/dev/null | grep -iE 'sandbox' | sort -u | head -60

echo
echo "=== 2. env vars mentioning sandbox ==="
strings -n 5 "$B" 2>/dev/null | grep -iE 'CLAUDE.*SANDBOX|SANDBOX.*=|_SANDBOX' | sort -u | head -30

echo
echo "=== 3. help: any sandbox/settings flags ==="
claude --help 2>&1 | grep -iE 'sandbox|--settings|permission' | head -20

echo
echo "=== 4. settings schema hints (sdk-tools.d.ts) ==="
grep -iE 'sandbox' "$DTS" 2>/dev/null | head -30 || echo "(no d.ts matches)"

echo
echo "=== 5. bwrap works at all? (positive control for the sandbox backend) ==="
if command -v bwrap >/dev/null; then
  echo "bwrap: $(bwrap --version)"
  # can bwrap create a minimal sandbox on this WSL2 kernel?
  bwrap --ro-bind / / --dev /dev --unshare-net echo "  bwrap net-unshare OK" 2>&1 | head -3
  bwrap --ro-bind / / --dev /dev echo "  bwrap basic OK" 2>&1 | head -3
else
  echo "bwrap NOT INSTALLED"
fi

echo
echo "=== 6. does 'claude sandbox' or a subcommand exist? ==="
claude --help 2>&1 | grep -iE '^\s+[a-z-]+ ' | head -40 | grep -i sandbox || echo "(no sandbox subcommand in top-level help)"
claude sandbox --help 2>&1 | head -15 || true

echo
echo "=== 7. grep binary for the settings key shape around sandbox ==="
strings -n 8 "$B" 2>/dev/null | grep -iE 'sandbox(Mode|Enabled|Config|Profile)?' | sort -u | head -40
