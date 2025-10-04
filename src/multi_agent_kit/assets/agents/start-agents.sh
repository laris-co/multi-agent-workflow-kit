#!/bin/bash
# Start multiple AI agents in tmux panes

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PROFILES_DIR="$SCRIPT_DIR/profiles"
AGENTS_DIR="$SCRIPT_DIR/agents"

CUSTOM_PREFIX=""
PROFILE="profile1"
DETACHED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        --detach|-d)
            DETACHED=true
            shift
            ;;
        *)
            PROFILE="$1"
            shift
            ;;
    esac
done

PROFILE_FILE="$PROFILES_DIR/${PROFILE}.sh"

if [ -f "$PROFILE_FILE" ]; then
    # shellcheck disable=SC1090
    source "$PROFILE_FILE"
    echo "📋 Using profile: $PROFILE"
else
    echo "⚠️  Profile '$PROFILE' not found, using defaults"
    RIGHT_WIDTH=30
    TOP_RIGHT_HEIGHT=90
    BOTTOM_HEIGHT=30
fi

if [ ! -d "$AGENTS_DIR" ]; then
    echo "Error: $AGENTS_DIR not found"
    exit 1
fi

if [ -f "$REPO_ROOT/.tmux.conf" ]; then
    tmux source-file "$REPO_ROOT/.tmux.conf" 2>/dev/null || true
fi

AGENTS=$(cd "$AGENTS_DIR" && ls -d */ 2>/dev/null | sed 's#/##' | tr '\n' ' ')

if [ -z "$AGENTS" ]; then
    echo "⚠️  No agent worktrees detected in $AGENTS_DIR"
    echo "Run .agents/setup.sh or .agents/agents.sh create <name> first."
    exit 1
fi

BASE_PREFIX=${SESSION_PREFIX:-ai}
DIR_NAME=$(basename "$REPO_ROOT")

if [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}-${CUSTOM_PREFIX}"
else
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}"
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "❌ Error: Session '$SESSION_NAME' already exists"
        echo "💡 Use --prefix <name> to create a separate session"
        echo "   Example: .agents/start-agents.sh profile1 --prefix work"
        exit 1
    fi
fi

tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

AGENTS_ARRAY=($AGENTS)
TOTAL=${#AGENTS_ARRAY[@]}

if [ "$LAYOUT_TYPE" = "six-pane" ]; then
    echo "Starting session in root directory..."
    tmux new-session -d -s "$SESSION_NAME" -c "$REPO_ROOT"
else
    echo "Starting session with ${AGENTS_ARRAY[0]}..."
    tmux new-session -d -s "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[0]}"
fi

if [ "$LAYOUT_TYPE" = "three-pane" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -h -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$SESSION_NAME":1.1
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
elif [ "$LAYOUT_TYPE" = "top-full" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux split-window -h -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_RIGHT_WIDTH:-50}"
    fi
elif [ "$LAYOUT_TYPE" = "full-left" ]; then
    echo "Adding pane 2 (top-right)..."
    if [ $TOTAL -ge 2 ]; then
        tmux split-window -h -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
    else
        tmux split-window -h -t "$SESSION_NAME" -p "$RIGHT_WIDTH"
    fi

    echo "Adding pane 3 (middle-right)..."
    tmux select-pane -t "$SESSION_NAME":1.2
    if [ $TOTAL -ge 3 ]; then
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "$TOP_RIGHT_HEIGHT"
    else
        tmux split-window -v -t "$SESSION_NAME" -p "$TOP_RIGHT_HEIGHT"
    fi

    echo "Adding pane 4 (bottom-right)..."
    if [ $TOTAL -ge 4 ]; then
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}" -p "${MIDDLE_RIGHT_HEIGHT:-50}"
    else
        tmux split-window -v -t "$SESSION_NAME" -p "${MIDDLE_RIGHT_HEIGHT:-50}"
    fi
elif [ "$LAYOUT_TYPE" = "six-pane" ]; then
    if [ $TOTAL -ge 1 ]; then
        echo "Adding pane 2 for ${AGENTS_ARRAY[0]}..."
        tmux split-window -h -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[0]}" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane 3 for ${AGENTS_ARRAY[1]}..."
        tmux select-pane -t "$SESSION_NAME":1.1
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane 4 for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$SESSION_NAME":1.2
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 4 ]; then
        echo "Adding pane 5 for ${AGENTS_ARRAY[3]}..."
        tmux select-pane -t "$SESSION_NAME":1.3
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}"
    fi
    echo "Adding pane 6 (root)..."
    tmux select-pane -t "$SESSION_NAME":1.4
    tmux split-window -v -t "$SESSION_NAME" -c "$REPO_ROOT"
else
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -h -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
        tmux resize-pane -t "$SESSION_NAME":0.1 -y "${TOP_RIGHT_HEIGHT}%"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$SESSION_NAME":1.1
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
    if [ $TOTAL -ge 4 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[3]}..."
        tmux select-pane -t "$SESSION_NAME":1.2
        tmux split-window -v -t "$SESSION_NAME" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
fi

echo ""
echo "✅ Started $TOTAL agents in tmux session: $SESSION_NAME"

if [ "$DETACHED" = true ]; then
    echo "📌 Running in detached mode"
    echo "💡 Attach with: tmux attach-session -t $SESSION_NAME"
else
    echo "📍 Attaching to session..."
    tmux attach-session -t "$SESSION_NAME"
fi
