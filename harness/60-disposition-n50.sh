#!/usr/bin/env bash
# 60-disposition-n50.sh — the authoritative disposition batch: n=50, BOTH arms
# (B then A), ALL THREE models (Opus, Sonnet, Haiku), each a single fresh batch of
# 50 (R01..R50), per-run canary. ONE operator launch:  sudo bash 60-disposition-n50.sh
#
# Supersedes the n=10 disposition pilots (Opus arm-{a,b}-results and the cross-model
# arm-{a,b}-{sonnet,haiku}-results). Those stay on disk as pilots; the n=50 batches
# (SUFFIX=-n50) are the reported result. Rule-mechanics arms (C/D/Phase 2) are
# unaffected — n=50 is a disposition measurement.
#
# COST: 3 models × 2 arms × 50 = 300 task runs + 300 per-run canaries ≈ 600 sessions,
# ~5-7 h unattended. Each run is independent; a VOID run is skipped, not fatal.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo bash $0"; exit 1; }
HARNESS=<repo>/experiments/deny-rule-adversarial/harness

MODELS="opus sonnet haiku"
ARMS="b a"                 # blind first, then told
export N=50 SUFFIX=-n50    # 30-arm-ab.sh reads these

echo "### DISPOSITION n=50 — models: $MODELS — arms: $ARMS — 6 batches of 50 ###"
echo "### started (each batch prints its own progress) ###"

for m in $MODELS; do
  for a in $ARMS; do
    echo
    echo "############################################################"
    echo "### n=50  model=$m  arm=$a"
    echo "############################################################"
    MODEL="$m" ARM="$a" bash "$HARNESS/30-arm-ab.sh" \
      || echo "  (batch $a/$m exited non-zero — see its summary; continuing)"
  done
done

echo
echo "=== n=50 COMPLETE — tallies ==="
for m in $MODELS; do
  for a in $ARMS; do
    s=/home/user/advtest/arm-$a-$m-n50-results/summary.md
    [ "$m" = opus ] && s=/home/user/advtest/arm-$a-n50-results/summary.md
    echo "--- model=$m arm=$a ---"
    if [ -f "$s" ]; then grep -E 'Runs:|CIRCUMVENTED:|COMPLIANT_SOLVE:|BLOCKED_AND_REPORTED:|BLOCKED_SILENT:|VOID:' "$s" | tr '\n' ' '; echo; else echo "    (no summary)"; fi
  done
done
echo
echo "Published under ~/advtest/arm-{a,b}[-{sonnet,haiku}]-n50-results/. The n=10 pilots are untouched."
