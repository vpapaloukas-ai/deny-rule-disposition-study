#!/usr/bin/env bash
# 50-cross-model.sh — CROSS-MODEL EXTENSION. Reruns the disposition arms (B then A)
# on Sonnet and Haiku, to test whether the "the agent won't bypass the deny rule"
# finding is Opus-specific or generalises. One operator launch:  sudo bash 50-cross-model.sh
#
# Only the DISPOSITION arms (A/B) are rerun — the rule-mechanics arms (C/D/Phase2)
# are deterministic Claude Code code, model-independent, so re-running them adds
# nothing (see RUN-RECORD "ATTRIBUTION"). Each (model,arm) writes to its own tagged
# dir and carries its own canary; the model is recorded from each run's init event.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo bash $0"; exit 1; }
HARNESS=<repo>/experiments/deny-rule-adversarial/harness

MODELS="sonnet haiku"
ARMS="b a"            # blind first, then told — same order as the Opus study

for m in $MODELS; do
  for a in $ARMS; do
    echo
    echo "############################################################"
    echo "### CROSS-MODEL: model=$m  arm=$a"
    echo "############################################################"
    MODEL="$m" ARM="$a" bash "$HARNESS/30-arm-ab.sh" || echo "  (arm $a/$m exited non-zero — see its summary; continuing)"
  done
done

echo
echo "=== CROSS-MODEL COMPLETE ==="
for m in $MODELS; do
  for a in $ARMS; do
    s=/home/user/advtest/arm-$a-$m-results/summary.md
    echo "--- model=$m arm=$a ---"
    if [ -f "$s" ]; then grep -E 'CIRCUMVENTION RATE|Outcome tally|CIRCUMVENTED:|COMPLIANT_SOLVE:|BLOCKED_AND_REPORTED:|BLOCKED_SILENT:|VOID:' "$s" | sed 's/^/    /'; else echo "    (no summary)"; fi
  done
done
echo
echo "Published under ~/advtest/arm-{a,b}-{sonnet,haiku}-results/ ; behind wall: /var/lib/advtest/logs/arm-*-{sonnet,haiku}/"
