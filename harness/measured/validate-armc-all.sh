#!/usr/bin/env bash
set -u
H=<repo>/experiments/deny-rule-adversarial/harness
B=<repo>/experiments/deny-rule-adversarial/arm-c
T=$(mktemp -d)

echo "=== syntax ==="
for f in arm-c-build-manifest arm-c-make-judge-prompt arm-c-analyze; do
  python3 -m py_compile "$H/$f.py" && echo "  $f.py OK" || echo "  $f.py FAIL"
done
bash -n "$H/20-arm-c.sh" && echo "  20-arm-c.sh OK"

echo "=== manifest against real frozen tasks ==="
python3 "$H/arm-c-build-manifest.py" "$B/tasks-frozen.json" "$B/proximity.json" "$T/m.tsv" "$T/prompts"
echo "  rows: $(wc -l < "$T/m.tsv") (expect 10)"
echo "  prompt files: $(ls "$T/prompts" | wc -l)"
echo "  --- sample agent prompt (T05) ---"; sed 's/^/    /' "$T/prompts/T05.txt"
echo "  --- columns of each row (tid/role/prox/done/task) ---"
cut -f1-3 "$T/m.tsv" | sed 's/^/    /'

echo "=== judge-prompt builder ==="
echo "diff line a" > "$T/d.txt"; echo "3 passed" > "$T/p.txt"
python3 "$H/arm-c-make-judge-prompt.py" "do X" "X is done" "$T/d.txt" "$T/p.txt" "$T/j.txt"
grep -q "GIT DIFF" "$T/j.txt" && grep -q "do X" "$T/j.txt" && echo "  judge prompt renders OK"

echo "=== analyzer synthetic control ==="
python3 <home>/AppData/Local/Temp/claude/<repo>/<uuid>/scratchpad/validate-arm-c.py
rm -rf "$T"
