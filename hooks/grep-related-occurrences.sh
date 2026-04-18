#!/bin/bash
# Post-edit hook: surfaces related occurrences after file edits
# Reminds Claude to check for other locations needing the same change

TOOL_INPUT="$CLAUDE_TOOL_INPUT"
TOOL_NAME="$CLAUDE_TOOL_NAME"

# Only fire on Edit and Write tools for .js and .vue files
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# Extract the file path from tool input
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check frontend and API source files
case "$FILE_PATH" in
  */api/src/*|*/frontend/src/*|*/pipeline/*)
    ;;
  *)
    exit 0
    ;;
esac

# Only for .js and .vue files
case "$FILE_PATH" in
  *.js|*.vue)
    ;;
  *)
    exit 0
    ;;
esac

echo "REMINDER: You just edited $(basename "$FILE_PATH"). Per the 'Grep Before You Edit' rule — have you already grepped for ALL occurrences of the pattern you changed? If not, do it now before moving on."
