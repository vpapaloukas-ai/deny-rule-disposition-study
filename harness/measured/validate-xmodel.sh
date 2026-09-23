#!/usr/bin/env bash
H=<repo>/experiments/deny-rule-adversarial/harness
echo "=== syntax ==="
bash -n "$H/30-arm-ab.sh" && echo "  30-arm-ab.sh OK" || echo "  30-arm-ab.sh FAIL"
bash -n "$H/50-cross-model.sh" && echo "  50-cross-model.sh OK" || echo "  50-cross-model.sh FAIL"

echo "=== model -> flag/tag mapping (replicated from 30-arm-ab.sh) ==="
for MODEL in "" opus sonnet haiku; do
  case "$MODEL" in
    ""|opus)  MODEL_FLAG="";                       TAG="" ;;
    sonnet)   MODEL_FLAG="--model claude-sonnet-5"; TAG="-sonnet" ;;
    haiku)    MODEL_FLAG="--model claude-haiku-4-5-20251001"; TAG="-haiku" ;;
    *)        MODEL_FLAG="--model $MODEL";          TAG="-x" ;;
  esac
  printf "  MODEL=%-8s -> flag='%s'  RUN=arm-b%s-results\n" "${MODEL:-<unset>}" "$MODEL_FLAG" "$TAG"
done

echo "=== confirm --model reaches the runner (grep generated pattern in script) ==="
grep -q 'dangerously-skip-permissions \$MODEL_FLAG' "$H/30-arm-ab.sh" && echo "  task runner: MODEL_FLAG present OK" || echo "  task runner: MISSING"
grep -q 'dangerously-skip-permissions \$MODEL_FLAG --disallowedTools Task WebFetch WebSearch \\' "$H/30-arm-ab.sh" && echo "  canary runner: MODEL_FLAG present OK" || echo "  canary runner: check manually"

echo "=== does claude accept these model ids? (quick, no full run) ==="
export PATH=/home/user/.local/bin:/usr/local/bin:/usr/bin:/bin
for mid in claude-sonnet-5 claude-haiku-4-5-20251001; do
  r=$(cd /home/user/advtest/agent-team-starter && timeout 90 claude -p "reply with the single word ok" --model "$mid" --dangerously-skip-permissions --output-format stream-json --verbose 2>/tmp/mid.err | python3 -c "import json,sys
m=None;res=None
for l in sys.stdin:
    try:e=json.loads(l)
    except:continue
    if e.get('type')=='system' and e.get('subtype')=='init':m=e.get('model')
    if e.get('type')=='result':res=str(e.get('result'))[:60]
print('resolved-model='+str(m),'| result='+str(res))")
  echo "  $mid -> $r"
  grep -i 'error\|not found\|invalid\|not logged' /tmp/mid.err | head -1 | sed 's/^/     stderr: /'
done
