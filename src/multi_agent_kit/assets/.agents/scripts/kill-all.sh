#!/bin/bash
# Kill all tmux sessions created by start-agents.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
CUSTOM_PREFIX=""
SESSION_PREFIX_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        --session-prefix)
            SESSION_PREFIX_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--prefix <prefix>] [--session-prefix <base>]"
            exit 1
            ;;
    esac
done

BASE_PREFIX=${SESSION_PREFIX_OVERRIDE:-${SESSION_PREFIX:-ai}}
DIR_NAME=$(basename "$REPO_ROOT")

if [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_PATTERN="${CUSTOM_PREFIX}-${BASE_PREFIX}-${DIR_NAME}"
else
    SESSION_PATTERN="${BASE_PREFIX}-${DIR_NAME}"
fi

SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${SESSION_PATTERN}" || true)

if [ -z "$SESSIONS" ]; then
    echo "ℹ️  No sessions found matching: ${SESSION_PATTERN}*"
    exit 0
fi

echo "🔍 Found sessions:"
echo "$SESSIONS"
echo ""
read -p "❓ Kill all these sessions? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$SESSIONS" | while read -r session; do
        [ -z "$session" ] && continue
        echo "🗑️  Killing session: $session"
        tmux kill-session -t "$session"
    done
    echo "✅ All sessions killed"
else
    echo "❌ Cancelled"
fi
