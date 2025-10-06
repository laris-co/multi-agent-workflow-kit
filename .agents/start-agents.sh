#!/bin/bash
# Start multiple AI agents in tmux panes (mouse-friendly + resizable)

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PROFILES_DIR="$SCRIPT_DIR/profiles"
AGENTS_DIR="$REPO_ROOT/agents"

mkdir -p "$AGENTS_DIR"

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
SESSION_EXISTS=false

if [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}-${CUSTOM_PREFIX}"
else
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}"
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        SESSION_EXISTS=true
    fi
fi

if [ "$SESSION_EXISTS" = true ]; then
    echo "ℹ️ Session '$SESSION_NAME' already running"
    if [ "$DETACHED" = true ]; then
        echo "📌 Running in detached mode"
        echo "💡 Attach with: tmux attach-session -t $SESSION_NAME"
    else
        echo "📍 Attaching to existing session..."
        tmux attach-session -t "$SESSION_NAME"
    fi
    exit 0
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

WINDOW_INDEX=$(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}" | head -1)
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)
pane_ref() {
    local offset=$1
    local pane_index=$((PANE_BASE + offset))
    printf '%s:%s.%s' "$SESSION_NAME" "$WINDOW_INDEX" "$pane_index"
}
tmux select-window -t "$SESSION_NAME":"$WINDOW_INDEX"

if [ "$LAYOUT_TYPE" = "two-pane" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding bottom pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -v -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "${BOTTOM_HEIGHT:-50}"
    else
        echo "Adding bottom pane (repo root)..."
        tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-50}"
    fi

    if [ $TOTAL -gt 2 ]; then
        echo "⚠️  profile0 shows only two panes. Additional agents will not open panes: ${AGENTS_ARRAY[@]:2}" >&2
    fi
elif [ "$LAYOUT_TYPE" = "three-pane" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -h -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -v -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
elif [ "$LAYOUT_TYPE" = "top-full" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -v -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux split-window -h -t "$(pane_ref 1)" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_RIGHT_WIDTH:-50}"
    fi
elif [ "$LAYOUT_TYPE" = "full-left" ]; then
    echo "Adding pane 2 (top-right)..."
    if [ $TOTAL -ge 2 ]; then
        tmux split-window -h -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
    else
        tmux split-window -h -t "$(pane_ref 0)" -p "$RIGHT_WIDTH"
    fi

    echo "Adding pane 3 (middle-right)..."
    tmux select-pane -t "$(pane_ref 1)"
    if [ $TOTAL -ge 3 ]; then
        tmux split-window -v -t "$(pane_ref 1)" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "$TOP_RIGHT_HEIGHT"
    else
        tmux split-window -v -t "$(pane_ref 1)" -p "$TOP_RIGHT_HEIGHT"
    fi

    #echo "Adding pane 4 (bottom-right)..."
    #if [ $TOTAL -ge 4 ]; then
    #    tmux split-window -v -t "$(pane_ref 2)" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}" -p "${MIDDLE_RIGHT_HEIGHT:-50}"
    #else
    #    tmux split-window -v -t "$(pane_ref 2)" -p "${MIDDLE_RIGHT_HEIGHT:-50}"
    #fi
elif [ "$LAYOUT_TYPE" = "six-pane" ]; then
    if [ $TOTAL -ge 1 ]; then
        echo "Adding pane 2 for ${AGENTS_ARRAY[0]}..."
        tmux split-window -h -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[0]}" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane 3 for ${AGENTS_ARRAY[1]}..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -v -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane 4 for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$(pane_ref 1)"
        tmux split-window -v -t "$(pane_ref 1)" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 4 ]; then
        echo "Adding pane 5 for ${AGENTS_ARRAY[3]}..."
        tmux select-pane -t "$(pane_ref 2)"
        tmux split-window -v -t "$(pane_ref 2)" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}"
    fi
    echo "Adding pane 6 (root)..."
    tmux select-pane -t "$(pane_ref 3)"
    tmux split-window -v -t "$(pane_ref 3)" -c "$REPO_ROOT"
else
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[1]}..."
        tmux split-window -h -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[1]}" -p "$RIGHT_WIDTH"
        tmux resize-pane -t "$(pane_ref 1)" -y "${TOP_RIGHT_HEIGHT}%"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[2]}..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -v -t "$(pane_ref 0)" -c "$AGENTS_DIR/${AGENTS_ARRAY[2]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
    if [ $TOTAL -ge 4 ]; then
        echo "Adding pane for ${AGENTS_ARRAY[3]}..."
        tmux select-pane -t "$(pane_ref 1)"
        tmux split-window -v -t "$(pane_ref 1)" -c "$AGENTS_DIR/${AGENTS_ARRAY[3]}" -p "${BOTTOM_HEIGHT:-30}"
    fi
fi

reload_tmux_conf_across_panes() {
    local conf_path="${TMUX_CONF:-$REPO_ROOT/.tmux.conf}"
    if [ ! -f "$conf_path" ]; then
        return
    fi

    tmux source-file "$conf_path" 2>/dev/null || true

    while IFS= read -r pane_id; do
        tmux send-keys -t "$pane_id" "git" Space "merge" Space "--ff-only" Space "main" C-m
        tmux send-keys -t "$pane_id" "tmux" Space "source-file" Space "$conf_path" C-m
    done < <(tmux list-panes -s -t "$SESSION_NAME" -F "#{pane_id}" 2>/dev/null || true)
}

reload_tmux_conf_across_panes

echo ""
echo "✅ Started $TOTAL agents in tmux session: $SESSION_NAME"

if [ "$DETACHED" = true ]; then
    echo "📌 Running in detached mode"
    echo "💡 Attach with: tmux attach-session -t $SESSION_NAME"
else
    echo "📍 Attaching to session..."
    tmux attach-session -t "$SESSION_NAME"
fi
