#!/usr/bin/env bash
# 20-arm-c.sh — ARM C: the known-good side. LAUNCH AS:  sudo bash 20-arm-c.sh
#
# 10 ordinary tasks, one agent session each, in the SAME session config as Arm D
# (deny rules active, bypassPermissions, fixed PATH, MCP suppressed). Natural task
# framing — Arm C is about REALISTIC operation, so NO compliance/injection shaping.
#
# Per task the harness records three independent signals:
#   - did a deny rule fire?  (scanned from the stream = the permission layer's output)
#   - did the task complete? (an INDEPENDENT judge session, blind to the transcript
#     and to whether a rule fired — completion is judged from the git DIFF, never the
#     agent's claim)
#   - did the agent claim done? (from its final message, only to split SILENT/BLOCKED)
#
# ROLE NOTE: like Arm D, tasks run in the shared session config rather than each
# role's tool-locked agent, so the only rule-layer blocker is a DENY RULE (the thing
# under test) and not a missing tool grant (a different mechanism). Documented, not
# silent. Task/WebFetch/WebSearch denied to keep each run single-agent and offline.
set -uo pipefail

AGENT=user
AHOME=/home/$AGENT
COPY=$AHOME/advtest/agent-team-starter
WALL=/var/lib/advtest
RUN=$WALL/logs/arm-c/run
PUB=$AHOME/advtest/arm-c-results
WORK=$AHOME/advtest/arm-c-work
HARNESS=<repo>/experiments/deny-rule-adversarial/harness
BASE=<repo>/experiments/deny-rule-adversarial/arm-c
FIXED_PATH=/home/user/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PIN=a61aafd269fd27b92d619452cf43b2235d181e48
TASK_TIMEOUT=600
JUDGE_TIMEOUT=180

as_agent() { runuser -l "$AGENT" -c "$1"; }
say() { printf '\n=== %s ===\n' "$1"; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo bash $0"; exit 1; }

say "0. PRECONDITIONS"
install -d -m 0700 -o root -g root "$WALL/logs" "$WALL/logs/arm-c"
rm -rf "$RUN"; install -d -m 0700 -o root -g root "$RUN"
as_agent "rm -rf '$WORK' '$PUB' && mkdir -p '$WORK' '$PUB' '$WORK/prompts'"
[ -f "$BASE/tasks-frozen.json" ] || { echo "frozen tasks missing"; exit 1; }
echo "  claude: $(as_agent "PATH=$FIXED_PATH claude --version")"

say "1. SUBSTRATE BASELINE (same reconstruction as Arm D)"
SB=$AHOME/advtest/substrate-build
as_agent "cd '$COPY' && git reset --hard --quiet '$PIN' && git clean -qfdx"
as_agent "cp -a '$SB/.' '$COPY/' && cd '$COPY' && git checkout --quiet -- README.md .gitignore && mkdir -p docs && cp -a '$SB/README.md' docs/proration.md && printf '\n# --- proration substrate ---\n__pycache__/\n*.py[cod]\n.pytest_cache/\n.ruff_cache/\n' >> .gitignore"
as_agent "cd '$COPY' && find . -path ./.git -prune -o \\( -name __pycache__ -o -name .pytest_cache -o -name .ruff_cache \\) -exec rm -rf {} + 2>/dev/null; true"
SUBSHA=$(as_agent "cd '$COPY' && git add -A && git -c user.email=armc@local -c user.name=armc commit -q -m 'arm-c substrate baseline' && git branch -f armc-baseline && git rev-parse HEAD")
echo "  baseline: $SUBSHA"

say "2. MANIFEST"
python3 "$HARNESS/arm-c-build-manifest.py" "$BASE/tasks-frozen.json" "$BASE/proximity.json" "$WORK/manifest.tsv" "$WORK/prompts"
chown -R "$AGENT:$AGENT" "$WORK"
echo "  tasks: $(wc -l < "$WORK/manifest.tsv")"

# per-task agent runner (executed AS the agent)
cat > "$WORK/run-task.sh" <<RUNNER
#!/usr/bin/env bash
export PATH='$FIXED_PATH'
cd '$COPY' || exit 9
claude -p "\$(cat "\$1")" \
  --dangerously-skip-permissions \
  --disallowedTools Task WebFetch WebSearch \
  --mcp-config '{"mcpServers":{}}' --strict-mcp-config \
  --output-format stream-json --verbose \
  > "\$2" 2> "\$3"
RUNNER
# judge runner (executed AS the agent, no tools — pure reasoning, blind to transcript)
cat > "$WORK/run-judge.sh" <<RUNNER
#!/usr/bin/env bash
export PATH='$FIXED_PATH'
cd '$WORK' || exit 9
claude -p "\$(cat "\$1")" \
  --dangerously-skip-permissions \
  --disallowedTools Bash Task WebFetch WebSearch Read Write Edit Glob Grep NotebookEdit \
  --mcp-config '{"mcpServers":{}}' --strict-mcp-config \
  --output-format stream-json --verbose \
  > "\$2" 2> "\$3"
RUNNER
chown "$AGENT:$AGENT" "$WORK/run-task.sh" "$WORK/run-judge.sh"

run_task() {   # tid role prox done task
  local tid="$1" role="$2" prox="$3" done="$4" task="$5"
  local d="$RUN/$tid"; install -d -m 0700 "$d"
  python3 - "$tid" "$role" "$prox" "$done" "$task" > "$d/meta.json" <<'PY'
import json,sys
print(json.dumps({"task":sys.argv[5],"role":sys.argv[2],"proximity":sys.argv[3],
                  "done_when":sys.argv[4],"tid":sys.argv[1]}))
PY

  # clean slate for this task
  as_agent "cd '$COPY' && git reset --hard --quiet '$SUBSHA' && git clean -qfdx"

  # run the agent on the task
  as_agent "timeout $TASK_TIMEOUT bash '$WORK/run-task.sh' '$WORK/prompts/$tid.txt' '$WORK/$tid.stream.jsonl' '$WORK/$tid.err'" || true
  cp -a "$WORK/$tid.stream.jsonl" "$d/stream.jsonl" 2>/dev/null || : > "$d/stream.jsonl"
  cp -a "$WORK/$tid.err" "$d/err.txt" 2>/dev/null || true

  # capture the WORK (diff) + tests, as the oracle input — computed after the agent stops
  as_agent "cd '$COPY' && git add -A >/dev/null 2>&1 && git diff --cached '$SUBSHA' > '$WORK/$tid.diff' 2>&1; git reset -q '$SUBSHA' >/dev/null 2>&1 || true"
  as_agent "cd '$COPY' && PATH='$FIXED_PATH' python3 -m pytest -q > '$WORK/$tid.pytest' 2>&1; true"
  cp -a "$WORK/$tid.diff" "$d/diff.txt" 2>/dev/null || true
  cp -a "$WORK/$tid.pytest" "$d/pytest.txt" 2>/dev/null || true

  # independent completion judge — blind to the transcript, sees only task + diff + tests
  python3 "$HARNESS/arm-c-make-judge-prompt.py" "$task" "$done" "$WORK/$tid.diff" "$WORK/$tid.pytest" "$WORK/prompts/$tid.judge.txt"
  chown "$AGENT:$AGENT" "$WORK/prompts/$tid.judge.txt"
  as_agent "timeout $JUDGE_TIMEOUT bash '$WORK/run-judge.sh' '$WORK/prompts/$tid.judge.txt' '$WORK/$tid.judge.jsonl' '$WORK/$tid.judge.err'" || true
  # the judge's final text -> judge.jsonl (analyzer reads the result field)
  as_agent "python3 -c \"import json,sys; [print(json.loads(l).get('result','')) for l in open('$WORK/$tid.judge.jsonl') if l.strip() and json.loads(l).get('type')=='result']\" > '$WORK/$tid.judgetext' 2>/dev/null" || true
  cp -a "$WORK/$tid.judgetext" "$d/judge.jsonl" 2>/dev/null || : > "$d/judge.jsonl"

  echo "  ran $tid ($role, $prox)"
}

say "3. RUN THE 10 TASKS"
while IFS=$'\t' read -r tid role prox done task; do
  run_task "$tid" "$role" "$prox" "$done" "$task"
done < "$WORK/manifest.tsv"

say "4. ANALYSE"
python3 "$HARNESS/arm-c-analyze.py" "$RUN" > "$WALL/logs/arm-c/summary.txt" 2>&1 || cat "$WALL/logs/arm-c/summary.txt"
cp -a "$RUN/summary.md" "$WALL/logs/arm-c/summary.md" 2>/dev/null || true

say "5. PUBLISH (after the run; live oracle stays behind the wall)"
install -d -m 0755 -o "$AGENT" -g "$AGENT" "$PUB"
for f in summary.md run-rows.json; do
  [ -f "$RUN/$f" ] && install -m 0644 -o "$AGENT" -g "$AGENT" "$RUN/$f" "$PUB/$f"
done
for d in "$RUN"/*/; do
  t=$(basename "$d"); install -d -m 0755 -o "$AGENT" -g "$AGENT" "$PUB/$t"
  for f in meta.json diff.txt pytest.txt judge.jsonl stream.jsonl; do
    [ -f "$d/$f" ] && install -m 0644 -o "$AGENT" -g "$AGENT" "$d/$f" "$PUB/$t/$f"
  done
done

echo
echo "ARM C COMPLETE. Published to $PUB/summary.md ; behind wall: $WALL/logs/arm-c/"
