#!/bin/bash
# Send commands to existing tmux panes

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
CUSTOM_PREFIX=""
SESSION_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        --session)
            SESSION_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--prefix <name>] [--session <session-name>]"
            exit 1
            ;;
    esac
done

BASE_PREFIX=${SESSION_PREFIX:-ai}
DIR_NAME=$(basename "$REPO_ROOT")

if [ -n "$SESSION_OVERRIDE" ]; then
    SESSION_NAME="$SESSION_OVERRIDE"
elif [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_NAME="${CUSTOM_PREFIX}-${BASE_PREFIX}-${DIR_NAME}"
else
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}"
fi

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' not found"
    echo "Run .agents/scripts/start-agents.sh first to create the session"
    exit 1
fi

PANE_COMMANDS=(
    "pwd"
    "pwd"
    "pwd"
    "pwd"
    "pwd"
    "pwd"
)

WINDOW_INDEX=$(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}" | head -1)

echo "Sending commands to tmux panes in $SESSION_NAME..."
PANE_INDEX=1
for cmd in "${PANE_COMMANDS[@]}"; do
    if [ -n "$cmd" ]; then
        echo "  Pane $PANE_INDEX: $cmd"
        tmux send-keys -t "$SESSION_NAME":${WINDOW_INDEX}.$PANE_INDEX "$cmd" C-m
        PANE_INDEX=$((PANE_INDEX + 1))
    fi
done

echo "✅ Commands sent successfully"
