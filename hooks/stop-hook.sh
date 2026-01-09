#!/bin/bash

# Devloop Stop Hook
# Prevents session exit when devloop is active
# Feeds the prompt back to continue the loop
# Allows early exit via completion promise

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Get transcript path to identify this session
# Use jq with // empty to handle null values properly
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || TRANSCRIPT_PATH=""

# Exit early if we can't identify this session - prevents cross-session interference
if [[ -z "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Find state file for this session
# Look for devloop-*.local.md files and match by stored transcript path
STATE_FILE=""

# Find state file - portable across bash/zsh
find_state_file() {
  for f in .claude/devloop-*.local.md; do
    # Skip if glob didn't expand (file doesn't exist)
    [[ -e "$f" ]] || continue
    [[ -f "$f" ]] || continue

    # Check if this file is claimed by a session
    STORED_TRANSCRIPT=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | grep '^transcript_path:' | sed 's/transcript_path: *//' | sed 's/^"\(.*\)"$/\1/')

    if [[ -z "$STORED_TRANSCRIPT" ]] || [[ "$STORED_TRANSCRIPT" == "null" ]]; then
      # Unclaimed file - skip, claim-hook.sh should have claimed it
      continue
    elif [[ "$STORED_TRANSCRIPT" == "$TRANSCRIPT_PATH" ]]; then
      # This file belongs to our session
      echo "$f"
      return 0
    fi
  done
  return 1
}

STATE_FILE=$(find_state_file) || true

if [[ -z "$STATE_FILE" ]] || [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse markdown frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "10")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//' || echo "true")
# Extract completion promise - handle potential multiline values by reading until next field
COMPLETION_PROMISE_RAW=$(echo "$FRONTMATTER" | awk '/^completion_promise:/{flag=1; sub(/^completion_promise: */, ""); print; next} flag && /^[a-z_]+:/{flag=0} flag{print}')
# Remove surrounding quotes and normalize whitespace
COMPLETION_PROMISE=$(echo "$COMPLETION_PROMISE_RAW" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//' | sed 's/^"\(.*\)"$/\1/')

# Check if deactivated
if [[ "$ACTIVE" == "false" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Validate iteration number
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: Devloop state corrupted, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^-?[0-9]+$ ]]; then
  echo "Warning: Devloop state corrupted (invalid max_iterations: '$MAX_ITERATIONS'), stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check max iterations (-1 or 0 means unlimited, any positive number is the limit)
if [[ $MAX_ITERATIONS -ge 1 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$STATE_FILE"
  exit 0
fi

# Check for completion promise in transcript
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Get last assistant message
    if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
      LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
      LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
        .message.content |
        map(select(.type == "text")) |
        map(.text) |
        join("\n")
      ' 2>&1)
      JQ_EXIT_CODE=$?
      if [[ $JQ_EXIT_CODE -ne 0 ]]; then
        echo "Warning: Failed to parse assistant message JSON: $LAST_OUTPUT" >&2
        LAST_OUTPUT=""
      fi

      if [[ -n "$LAST_OUTPUT" ]]; then
        # Extract text from <promise> tags
        PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

        # Check if promise matches (literal comparison, not pattern)
        if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
          echo "Devloop: Detected <promise>$COMPLETION_PROMISE</promise>"
          echo "Task completed at iteration $ITERATION."
          rm -f "$STATE_FILE"
          exit 0
        fi
      fi
    fi
  fi
fi

# Continue loop
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE" | sed '/./,$!d')

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Warning: No prompt found, stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Update iteration atomically using temp file
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"

# Build system message with iteration info (like ralph-loop)
if [[ $MAX_ITERATIONS -ge 1 ]]; then
  ITER_INFO="🔄 Devloop iteration $NEXT_ITERATION/$MAX_ITERATIONS"
else
  ITER_INFO="🔄 Devloop iteration $NEXT_ITERATION"
fi

# Add completion promise reminder to system message
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="$ITER_INFO | To exit: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE)"
else
  SYSTEM_MSG="$ITER_INFO | Use /devloop:stop to exit"
fi

# Block exit and feed prompt back
# Use systemMessage for clean iteration status (like ralph-loop)
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
