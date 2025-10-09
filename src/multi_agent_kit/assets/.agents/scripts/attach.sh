#!/bin/bash
# Attach to an existing Multi-Agent Workflow tmux session

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

BASE_PREFIX=${SESSION_PREFIX:-ai}
DIR_NAME=$(basename "$REPO_ROOT")

CUSTOM_PREFIX=""
SESSION_OVERRIDE=""

usage() {
    cat <<'USAGE'
Usage: attach.sh [--prefix <prefix>] [--session <name>]

Attach to an existing tmux session created by the toolkit.

Options:
  --prefix <prefix>   Attach to session <prefix>-ai-<repo>
  --session <name>    Attach to a specific tmux session name
USAGE
}

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

if [[ -n "$CUSTOM_PREFIX" ]]; then
    SESSION_NAME="$CUSTOM_PREFIX-$BASE_PREFIX-$DIR_NAME"
else
    SESSION_NAME="$BASE_PREFIX-$DIR_NAME"
fi

if [[ -n "$SESSION_OVERRIDE" ]]; then
    SESSION_NAME="$SESSION_OVERRIDE"
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found in PATH. Install tmux to attach to agent sessions." >&2
    exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "📍 Attaching to tmux session: $SESSION_NAME"
    exec tmux attach-session -t "$SESSION_NAME"
fi

echo "❌ tmux session not found: $SESSION_NAME" >&2
echo "Available sessions:" >&2
tmux list-sessions -F "  #{session_name}" || true
exit 1
