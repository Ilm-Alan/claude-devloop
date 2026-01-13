#!/bin/bash

# Loop Setup Script
# Creates state file for iterative development loop

set -euo pipefail

# Generate unique session ID for this loop instance
SESSION_ID=$(date +%s)-$$-$RANDOM

# Parse arguments - from env var (handles special chars) or positional args
PROMPT_PARTS=()
MAX_ITERATIONS=-1  # -1 = unlimited (user can override with -m N)
COMPLETION_PROMISE="null"

# If LOOP_ARGS is set, parse it instead of positional args
if [[ -n "${LOOP_ARGS:-}" ]]; then
  # Use eval to properly split the args while respecting quotes
  eval "set -- $LOOP_ARGS"
fi

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Loop - Iterative development with enforced work each cycle

USAGE:
  /loop:start [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Task description (can be multiple words without quotes)

OPTIONS:
  -m, --max-iterations <n>      Maximum iterations (default: unlimited, use -m N to limit)
  -c, --completion-promise <text> Promise phrase to allow early exit (USE QUOTES)
  -h, --help                    Show this help message

DESCRIPTION:
  Starts an iterative development loop that forces meaningful work each cycle.
  The stop hook blocks exit and feeds the prompt back until completion.

  To signal early completion, output: <promise>YOUR_PHRASE</promise>
  The promise must be TRUE - do not lie to escape!

EXAMPLES:
  /loop:start Refactor the auth module -m 5
  /loop:start Build a REST API -c 'All endpoints implemented and tested'
  /loop:start Fix all type errors --max-iterations 20 --completion-promise 'Zero type errors'

STOPPING:
  - Reaching --max-iterations limit
  - Outputting <promise>TEXT</promise> when completion-promise is set and TRUE

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/loop-*.local.md

  # View full state:
  head -10 .claude/loop-*.local.md
HELP_EOF
      exit 0
      ;;
    -m|--max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     -m 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     -m 0  (unlimited)" >&2
        echo "" >&2
        echo "   You provided: $1 (with no number)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: $1 must be a non-negative integer, got: '$2'" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     -m 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     -m 0  (unlimited)" >&2
        echo "" >&2
        echo "   Invalid: decimals (10.5), negative numbers (-5), text" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    -c|--completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires a text argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     -c 'DONE'" >&2
        echo "     --completion-promise 'TASK COMPLETE'" >&2
        echo "     -c 'All tests passing'" >&2
        echo "" >&2
        echo "   You provided: $1 (with no text)" >&2
        echo "" >&2
        echo "   Note: Multi-word promises must be quoted!" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join prompt parts
PROMPT="${PROMPT_PARTS[*]}"

# Validate
if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided" >&2
  echo "" >&2
  echo "   Loop needs a task description to work on." >&2
  echo "" >&2
  echo "   Examples:" >&2
  echo "     /loop:start Build a REST API for todos" >&2
  echo "     /loop:start Fix the auth bug -m 20" >&2
  echo "     /loop:start -c 'DONE' Refactor code" >&2
  echo "" >&2
  echo "   For all options: /loop:start --help" >&2
  exit 1
fi

# Create state file
mkdir -p .claude

# Escape completion promise for YAML (handle quotes, colons, special chars)
# YAML double-quoted strings need: \ -> \\, " -> \", newlines normalized
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # First normalize whitespace: collapse newlines and multiple spaces to single space
  ESCAPED_PROMISE=$(echo "$COMPLETION_PROMISE" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
  # Escape backslashes first, then double quotes
  ESCAPED_PROMISE="${ESCAPED_PROMISE//\\/\\\\}"
  ESCAPED_PROMISE="${ESCAPED_PROMISE//\"/\\\"}"
  COMPLETION_PROMISE_YAML="\"$ESCAPED_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

STATE_FILE=".claude/loop-${SESSION_ID}.local.md"
TERM_SID="${TERM_SESSION_ID:-unknown}"
cat > "$STATE_FILE" <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
term_session_id: "$TERM_SID"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output
cat <<EOF
===============================================================
LOOP ACTIVATED - Iteration 1 of $(if [[ $MAX_ITERATIONS -ge 1 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
===============================================================

MANDATORY EACH ITERATION:
1. READ relevant files to see current state
2. IDENTIFY at least one specific improvement
3. MAKE code changes using Edit/Write tools
4. VERIFY changes work (build/test if applicable)

EOF

# Show completion promise info if set
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  cat <<EOF
EARLY EXIT AVAILABLE:
To complete before max iterations, output EXACTLY:
  <promise>$COMPLETION_PROMISE</promise>

CRITICAL: Only output this when the statement is GENUINELY TRUE.
Do NOT lie to escape the loop - the promise must be accurate!

EOF
else
  if [[ $MAX_ITERATIONS -ge 1 ]]; then
    cat <<EOF
No completion promise set - loop runs until iteration $MAX_ITERATIONS.

EOF
  else
    cat <<EOF
No completion promise set - loop runs infinitely.
Tip: Use -c 'promise text' for auto-completion detection.

EOF
  fi
fi

cat <<EOF
===============================================================

TASK:
EOF

echo "$PROMPT"
