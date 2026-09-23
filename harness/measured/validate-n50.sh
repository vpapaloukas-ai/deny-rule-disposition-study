#!/usr/bin/env bash
H=<repo>/experiments/deny-rule-adversarial/harness
echo "=== syntax ==="
bash -n "$H/30-arm-ab.sh" && echo "  30-arm-ab.sh OK" || echo "  30-arm-ab.sh FAIL"
bash -n "$H/60-disposition-n50.sh" && echo "  60-disposition-n50.sh OK" || echo "  60-disposition-n50.sh FAIL"

echo "=== derived paths per (model,arm) with SUFFIX=-n50 (replicating 30-arm-ab.sh logic) ==="
SUFFIX=-n50
for MODEL in opus sonnet haiku; do
  for ARM in b a; do
    case "$MODEL" in
      ""|opus)  TAG="" ;;
      sonnet)   TAG="-sonnet" ;;
      haiku)    TAG="-haiku" ;;
    esac
    TAG="${TAG}${SUFFIX}"
    echo "  MODEL=$MODEL ARM=$ARM -> PUB=arm-$ARM$TAG-results  RUN=wall/logs/arm-$ARM$TAG/run"
  done
done
echo
echo "=== confirm these DON'T collide with the n=10 pilot dirs ==="
echo "  pilots: arm-b-results, arm-a-results, arm-{b,a}-{sonnet,haiku}-results"
echo "  n50:    arm-b-n50-results, arm-a-n50-results, arm-{b,a}-{sonnet,haiku}-n50-results  (distinct: yes)"
