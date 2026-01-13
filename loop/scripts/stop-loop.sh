#!/bin/bash

# Loop Stop Script
# Stops the loop for the current terminal session

set -euo pipefail

TERM_SID="${TERM_SESSION_ID:-unknown}"
FOUND=0

for f in .claude/loop-*.local.md; do
  [ -e "$f" ] || continue

  FILE_SID=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$f" | grep '^term_session_id:' | sed 's/term_session_id: *//' | sed 's/^"\(.*\)"$/\1/')

  if [ "$FILE_SID" = "$TERM_SID" ]; then
    rm -f "$f"
    echo "Stopped loop for this session."
    FOUND=1
    break
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "No active loop found for this session."
fi
