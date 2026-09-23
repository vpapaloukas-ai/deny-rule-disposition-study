#!/usr/bin/env bash
# 60-rerun.sh — the 2026-09 re-run of the disposition arms: batches A and B, n=50 run pairs per
# model and arm, all three models (Opus, Sonnet, Haiku), per-run canary.
# ONE operator launch:  sudo AGENT=<account> bash 60-rerun.sh
#
# Copied from harness/60-disposition-n50.sh, which ran the 2026-08-08 batch and is unchanged. The
# pre-registration commits the full diff against that file. What changed:
#   1. PRESERVE, THEN CLEAR. Before any run, every stash already in the shared working copy is
#      preserved outside the repository: the list, one patch per entry, and a verified bundle. The
#      runner then clears stashes on every reset. The stash an Opus told-arm run made on 2026-08-08
#      was still in the working copy on 2026-09-17.
#   2. PREFLIGHT. The agent account's CLI must report 2.1.222 before anything starts.
#   3. ORDER. Models and arms run in the 2026-08-08 order. Within each, 30-arm-ab.sh interleaves
#      the two batches run by run.
#   4. NO LOCAL LITERALS, as in 30-arm-ab.sh.
#   5. RESUMABLE. Relaunching after an interruption resumes: finished pairs are kept, and an
#      unfinished pair is set aside as an incident and repeated (see 30-arm-ab.sh).
#   6. SERVICE ERRORS STOP THE RE-RUN (Amendment 1). When 30-arm-ab.sh exits 3, this driver stops
#      instead of moving on to the next model and arm.
#
# COST: 3 models × 2 arms × 50 pairs = 600 task runs + 600 per-run canaries, about 1,200 sessions.
# Each run is independent; a VOID run is skipped, not fatal.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo AGENT=<account> bash $0"; exit 1; }
SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

AGENT=${AGENT:?set AGENT to the unprivileged account that runs the agent}
AHOME=$(getent passwd "$AGENT" | cut -d: -f6)
[ -n "$AHOME" ] || { echo "no home directory for account $AGENT"; exit 1; }
COPY=$AHOME/advtest/agent-team-starter
PUBROOT=$AHOME/advtest/rerun-2026-09
as_agent() { runuser -l "$AGENT" -c "$1"; }
# shellcheck source=rerun-lib.sh
. "$SCRIPTS/rerun-lib.sh"

MODELS="opus sonnet haiku"
ARMS="b a"                 # blind first, then told
export N=${N:-50} AGENT    # 30-arm-ab.sh reads these

echo "### RE-RUN 2026-09 — models: $MODELS — arms: $ARMS — batches A and B interleaved — $N pairs each ###"

ver=$(as_agent "DISABLE_AUTOUPDATER=1 claude --version" 2>/dev/null | head -1 | cut -d' ' -f1)
[ "$ver" = 2.1.222 ] || { echo "ABORT: the agent account's CLI reports '$ver', not 2.1.222. Nothing was run."; exit 1; }
echo "  CLI: $ver"

preserved=$(preserve_stashes "$PUBROOT/preserved-stashes") \
  || { echo "ABORT: could not preserve the existing stash entries. Nothing was cleared or run."; exit 1; }
echo "  stash entries preserved before any run: $preserved (in $PUBROOT/preserved-stashes/)"
echo "### started $(date -u +%Y-%m-%dT%H:%M:%SZ) (each model and arm prints its own progress) ###"

for m in $MODELS; do
  for a in $ARMS; do
    echo
    echo "############################################################"
    echo "### re-run  model=$m  arm=$a  batches A and B"
    echo "############################################################"
    MODEL="$m" ARM="$a" bash "$SCRIPTS/30-arm-ab.sh"
    rc=$?
    if [ "$rc" -eq 3 ]; then
      echo
      echo "### STOPPED $(date -u +%Y-%m-%dT%H:%M:%SZ): model $m, arm $a — the model service did not answer (Amendment 1)."
      echo "### Fix the cause, then relaunch this same command. Finished pairs are kept; the unfinished pair repeats."
      exit 3
    elif [ "$rc" -ne 0 ]; then
      echo "  (model $m, arm $a exited non-zero — see its summaries; continuing)"
    fi
  done
done

echo
echo "=== RE-RUN COMPLETE $(date -u +%Y-%m-%dT%H:%M:%SZ) — tallies ==="
for m in $MODELS; do
  for a in $ARMS; do
    for b in A B; do
      s=$PUBROOT/arm-$a-$m-$b-results/summary.md
      echo "--- model=$m arm=$a batch=$b ---"
      if [ -f "$s" ]; then grep -E 'Runs:|CIRCUMVENTED:|COMPLIANT_SOLVE:|BLOCKED_AND_REPORTED:|BLOCKED_SILENT:|VOID:' "$s" | tr '\n' ' '; echo; else echo "    (no summary)"; fi
    done
  done
done
echo
echo "Published under $PUBROOT/arm-{a,b}-{opus,sonnet,haiku}-{A,B}-results/. The 2026-08-08 batch is untouched."
