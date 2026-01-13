#!/bin/bash

# Loop Claim Hook (UserPromptSubmit)
# Claims unclaimed state files immediately when session starts responding
# This prevents cross-session interference by binding files to sessions early

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get transcript path to identify this session
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null) || TRANSCRIPT_PATH=""

# Can't claim without a transcript path
if [[ -z "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Look for unclaimed loop state files
for f in .claude/loop-*.local.md; do
  [[ -e "$f" ]] || continue
  [[ -f "$f" ]] || continue

  # Check if already claimed
  STORED_TRANSCRIPT=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | grep '^transcript_path:' | sed 's/transcript_path: *//' | sed 's/^"\(.*\)"$/\1/' || true)

  if [[ -z "$STORED_TRANSCRIPT" ]] || [[ "$STORED_TRANSCRIPT" == "null" ]]; then
    # Unclaimed file - try to claim it atomically
    LOCK_FILE="${f}.lock"
    if (set -o noclobber; echo "$$" > "$LOCK_FILE") 2>/dev/null; then
      trap 'rm -f "$LOCK_FILE"' EXIT

      # Double-check still unclaimed after acquiring lock
      STORED_TRANSCRIPT=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | grep '^transcript_path:' | sed 's/transcript_path: *//' | sed 's/^"\(.*\)"$/\1/' || true)
      if [[ -z "$STORED_TRANSCRIPT" ]] || [[ "$STORED_TRANSCRIPT" == "null" ]]; then
        # Claim it
        TEMP_FILE="${f}.tmp.$$"
        awk -v tp="$TRANSCRIPT_PATH" '
          /^started_at:/ && !added { print "transcript_path: \"" tp "\""; added=1 }
          { print }
        ' "$f" > "$TEMP_FILE" && mv "$TEMP_FILE" "$f"
      fi

      rm -f "$LOCK_FILE"
      trap - EXIT
    fi
    # Only claim one file per session
    break
  elif [[ "$STORED_TRANSCRIPT" == "$TRANSCRIPT_PATH" ]]; then
    # Already claimed by this session
    break
  fi
done

exit 0
