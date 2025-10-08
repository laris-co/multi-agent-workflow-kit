#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

# Default session prefix
SESSION_PREFIX="${SESSION_PREFIX:-ai}"
REPO_NAME=$(basename "$REPO_ROOT")

usage() {
    cat <<USAGE
Usage: direnv-allow.sh [options]

Send Ctrl+C and 'direnv allow .' to all agent panes in the tmux session.

Options:
  --prefix <name>    Custom session suffix (default: none, i.e., ai-<repo>)
  -h, --help         Show this help message

Example:
  direnv-allow.sh
  direnv-allow.sh --prefix sprint
USAGE
}

CUSTOM_PREFIX=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Build session name
if [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_NAME="${SESSION_PREFIX}-${REPO_NAME}-${CUSTOM_PREFIX}"
else
    SESSION_NAME="${SESSION_PREFIX}-${REPO_NAME}"
fi

# Check if tmux session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: tmux session '$SESSION_NAME' not found" >&2
    echo "Start a session first with: maw start" >&2
    exit 1
fi

# Get list of panes in the session
PANES=$(tmux list-panes -t "$SESSION_NAME" -F '#{pane_index}')

if [ -z "$PANES" ]; then
    echo "No panes found in session '$SESSION_NAME'" >&2
    exit 1
fi

echo "Sending Ctrl+C and 'direnv allow .' to all panes in session: $SESSION_NAME"

# Send Ctrl+C followed by direnv allow to each pane
for pane in $PANES; do
    echo "  → Pane $pane"
    # Send Ctrl+C
    tmux send-keys -t "$SESSION_NAME:0.$pane" C-c
    # Small delay to ensure Ctrl+C is processed
    sleep 0.1
    # Send direnv allow .
    tmux send-keys -t "$SESSION_NAME:0.$pane" "direnv allow ." Enter
done

echo "✅ Sent direnv allow to all panes"
