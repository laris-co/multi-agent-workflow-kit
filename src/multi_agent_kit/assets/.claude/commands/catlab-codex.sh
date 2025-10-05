#!/bin/bash
set -euo pipefail

PROMPT="$*"

if [ -z "$PROMPT" ]; then
    echo "Usage: catlab-codex.sh <prompt>"
    exit 1
fi

DIR_NAME=$(basename "$(pwd)")
SESSION_NAME="ai-${DIR_NAME}"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "❌ Error: Session '$SESSION_NAME' not found"
    exit 1
fi

WINDOW_INDEX=$(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}" | head -1)
TARGET_PANE="$SESSION_NAME:${WINDOW_INDEX}.1"

ENTER_KEYS=(
    Enter   # standard Enter key name recognised by tmux
    C-m     # carriage return (Enter)
    C-j     # line feed
    $'\r'   # raw carriage return byte
    $'\n'   # raw newline byte
)


echo "📤 Sending to codex: $PROMPT"
tmux send-keys -t "$TARGET_PANE" "$PROMPT"

for enter_key in "${ENTER_KEYS[@]}"; do
    tmux send-keys -t "$TARGET_PANE" "$enter_key"
    sleep 0.05
done

echo "✅ Sent successfully"
