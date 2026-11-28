#!/usr/bin/env bash
# opus.sh — hand a code-change brief to Claude Opus (4.6, falls back to 4.5).
# Usage:
#   opus.sh -C <workdir> -b <brief.md> [-m 4.5|4.6] [-e high] [-r <session_id>] [-l <log.json>]
#   echo "brief" | opus.sh -C <workdir>
# Prints: Opus final report, then a line "OPUS_SESSION=<id>" for follow-ups (-r).
set -euo pipefail

WORKDIR="$PWD"; BRIEF=""; MODEL="4.6"; EFFORT="high"; RESUME=""; LOG=""
while getopts "C:b:m:e:r:l:" o; do
  case $o in
    C) WORKDIR="$OPTARG" ;; b) BRIEF="$OPTARG" ;; m) MODEL="$OPTARG" ;;
    e) EFFORT="$OPTARG" ;; r) RESUME="$OPTARG" ;; l) LOG="$OPTARG" ;;
    *) echo "bad flag" >&2; exit 2 ;;
  esac
done

case "$MODEL" in
  4.6|claude-opus-4-6) PRIMARY=claude-opus-4-6; FALLBACK=claude-opus-4-5 ;;
  4.5|claude-opus-4-5) PRIMARY=claude-opus-4-5; FALLBACK=claude-opus-4-6 ;;
  *) echo "model must be 4.6 or 4.5" >&2; exit 2 ;;
esac

if [[ -n "$BRIEF" ]]; then PROMPT="$(cat "$BRIEF")"; else PROMPT="$(cat)"; fi
[[ -z "$PROMPT" ]] && { echo "empty brief" >&2; exit 2; }

RULES='You are the implementation agent. A planner model (GPT-6.1 Sol) wrote the brief below and will review your work.
- Implement exactly the brief. Do not redesign, do not expand scope.
- If the brief is ambiguous or wrong in a way that blocks you, stop and say so instead of guessing.
- Run the verification steps in the brief if any.
- Finish with a short report: files changed, what you did, verification result, open issues.'

LOG="${LOG:-$(mktemp -t opus-run).json}"
ARGS=(-p --model "$PRIMARY" --fallback-model "$FALLBACK" --effort "$EFFORT"
      --permission-mode bypassPermissions --output-format json
      --append-system-prompt "$RULES")
[[ -n "$RESUME" ]] && ARGS+=(--resume "$RESUME")

cd "$WORKDIR"
claude "${ARGS[@]}" "$PROMPT" > "$LOG" 2>/dev/null || true

python3 - "$LOG" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"OPUS_ERROR: could not parse output ({e}); raw log: {sys.argv[1]}"); sys.exit(1)
print(d.get("result", ""))
print("\nOPUS_MODEL=" + ",".join((d.get("modelUsage") or {}).keys()))
print("OPUS_SESSION=" + str(d.get("session_id", "")))
if d.get("is_error"): print("OPUS_ERROR=true"); sys.exit(1)
PY
