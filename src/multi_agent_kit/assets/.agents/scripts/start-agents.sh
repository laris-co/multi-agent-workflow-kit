#!/bin/bash
# Start multiple AI agents in tmux panes (mouse-friendly + resizable)

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
PROFILES_DIR="$AGENT_ROOT/profiles"
AGENTS_DIR="$REPO_ROOT/agents"

mkdir -p "$AGENTS_DIR"

CUSTOM_PREFIX=""
PROFILE="profile0"
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

DEFAULT_TMUX_CONF="$AGENT_ROOT/config/tmux.conf"

if [ -n "${TMUX_CONF:-}" ] && [ -f "$TMUX_CONF" ]; then
    tmux source-file "$TMUX_CONF" 2>/dev/null || true
elif [ -f "$DEFAULT_TMUX_CONF" ]; then
    tmux source-file "$DEFAULT_TMUX_CONF" 2>/dev/null || true
elif [ -f "$REPO_ROOT/.tmux.conf" ]; then
    tmux source-file "$REPO_ROOT/.tmux.conf" 2>/dev/null || true
fi

AGENTS=$(cd "$AGENTS_DIR" && /bin/ls -d */ 2>/dev/null | sed 's#/##' | tr '\n' ' ')
if [ -z "$AGENTS" ]; then
    echo "⚠️  No agent worktrees detected in $AGENTS_DIR"
    echo "Run .agents/scripts/setup.sh or .agents/scripts/agents.sh create <name> first."
    exit 1
fi

if ! git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "❌ Repository has no commits yet."
    echo "   Create an initial commit before starting agents, for example:"
    echo "   git commit --allow-empty -m \"Initial commit\""
    exit 1
fi

# Run direnv allow before creating tmux session
if command -v direnv >/dev/null 2>&1 && [ "${SKIP_DIRENV_ALLOW:-}" != "1" ]; then
    DIRENV_SCRIPT="$SCRIPT_DIR/direnv-allow.sh"
    if [ -f "$DIRENV_SCRIPT" ]; then
        echo "🔧 Configuring direnv in all worktrees..."
        "$DIRENV_SCRIPT" || true
        echo ""
    fi
fi

direnv_broadcast() {
    if [ "${SKIP_DIRENV_ALLOW:-}" = "1" ]; then
        return
    fi
    if ! command -v direnv >/dev/null 2>&1; then
        return
    fi

    local panes
    panes=$(tmux list-panes -s -t "$SESSION_NAME" -F "#{pane_id}" 2>/dev/null || true)
    if [ -z "$panes" ]; then
        return
    fi

    echo "🔐 Running 'direnv allow' in each tmux pane..."
    while IFS= read -r pane_id; do
        [ -z "$pane_id" ] && continue
        tmux send-keys -t "$pane_id" "direnv allow >/dev/null 2>&1 || true" C-m
    done <<<"$panes"
}

BASE_PREFIX=${SESSION_PREFIX:-ai}
DIR_NAME=$(basename "$REPO_ROOT")
SESSION_EXISTS=false

if [ -n "$CUSTOM_PREFIX" ]; then
    SESSION_NAME="${CUSTOM_PREFIX}-${BASE_PREFIX}-${DIR_NAME}"
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
        if [ -t 0 ]; then
            read -r -p "❓ Attach to existing session? [y/N]: " attach_choice
            case "$attach_choice" in
                [yY][eE][sS]|[yY])
                    echo "📍 Attaching to existing session..."
                    tmux attach-session -t "$SESSION_NAME"
                    ;;
                *)
                    echo "⚪ Leaving session running; not attaching."
                    ;;
            esac
        else
            echo "📍 Attaching to existing session..."
            tmux attach-session -t "$SESSION_NAME"
        fi
    fi
    exit 0
fi

tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

AGENTS_ARRAY=($AGENTS)
TOTAL=${#AGENTS_ARRAY[@]}

# Always start all panes in root directory
echo "Starting session in root directory..."
tmux new-session -d -s "$SESSION_NAME" -c "$REPO_ROOT"

WINDOW_INDEX=$(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}" | head -1)
# Get pane-base-index from the window (falls back to global default)
PANE_BASE=$(tmux show-window-options -t "$SESSION_NAME":"$WINDOW_INDEX" -v pane-base-index 2>/dev/null)
if [ -z "$PANE_BASE" ]; then
    PANE_BASE=$(tmux show-window-options -gv pane-base-index 2>/dev/null)
fi
if [ -z "$PANE_BASE" ]; then
    PANE_BASE=0
fi
pane_ref() {
    local offset=$1
    local pane_index=$((PANE_BASE + offset))
    printf '%s:%s.%s' "$SESSION_NAME" "$WINDOW_INDEX" "$pane_index"
}
tmux select-window -t "$SESSION_NAME":"$WINDOW_INDEX"

if [ "$LAYOUT_TYPE" = "three-horizontal" ]; then
    # Profile 0: Three horizontal panes stacked vertically (all agents, no root)
    # Pane 0 (top): Agent 1
    # Pane 1 (middle): Agent 2
    # Pane 2 (bottom): Agent 3
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane 1 (middle)..."
        tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${MIDDLE_HEIGHT:-33}"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane 2 (bottom)..."
        tmux select-pane -t "$(pane_ref 1)"
        tmux split-window -v -t "$(pane_ref 1)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-50}"
    fi

    if [ $TOTAL -gt 3 ]; then
        echo "⚠️  profile0 shows only 3 agent panes. Additional agents will not open panes: ${AGENTS_ARRAY[@]:3}" >&2
    fi
elif [ "$LAYOUT_TYPE" = "two-pane" ]; then
    echo "Adding bottom pane..."
    tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-50}"

    if [ $TOTAL -gt 2 ]; then
        echo "⚠️  two-pane layout shows only two panes. Additional agents will not open panes: ${AGENTS_ARRAY[@]:2}" >&2
    fi
elif [ "$LAYOUT_TYPE" = "two-pane-bottom-right" ]; then
    echo "Adding bottom-left pane..."
    tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-50}"

    tmux select-pane -t "$(pane_ref 1)"
    echo "Adding bottom-right pane..."
    tmux split-window -h -t "$(pane_ref 1)" -c "$REPO_ROOT" -p "${BOTTOM_RIGHT_WIDTH:-50}"

    if [ $TOTAL -gt 3 ]; then
        echo "⚠️  profile0 shows only three panes. Additional agents will not open panes: ${AGENTS_ARRAY[@]:3}" >&2
    fi
elif [ "$LAYOUT_TYPE" = "three-pane" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding right pane..."
        tmux split-window -h -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding bottom-left pane..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-30}"
    fi
elif [ "$LAYOUT_TYPE" = "top-full" ]; then
    if [ $TOTAL -ge 2 ]; then
        echo "Adding bottom-left pane..."
        tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-30}"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding bottom-right pane..."
        tmux split-window -h -t "$(pane_ref 1)" -c "$REPO_ROOT" -p "${BOTTOM_RIGHT_WIDTH:-50}"
    fi
elif [ "$LAYOUT_TYPE" = "full-left" ]; then
    echo "Adding pane 2 (top-right)..."
    tmux split-window -h -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "$RIGHT_WIDTH"

    echo "Adding pane 3 (middle-right)..."
    tmux select-pane -t "$(pane_ref 1)"
    tmux split-window -v -t "$(pane_ref 1)" -c "$REPO_ROOT" -p "$TOP_RIGHT_HEIGHT"
elif [ "$LAYOUT_TYPE" = "six-pane" ]; then
    if [ $TOTAL -ge 1 ]; then
        echo "Adding pane 2..."
        tmux split-window -h -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "$RIGHT_WIDTH"
    fi
    if [ $TOTAL -ge 2 ]; then
        echo "Adding pane 3..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 3 ]; then
        echo "Adding pane 4..."
        tmux select-pane -t "$(pane_ref 1)"
        tmux split-window -v -t "$(pane_ref 1)" -c "$REPO_ROOT" -p "$TOP_RIGHT_HEIGHT"
    fi
    if [ $TOTAL -ge 4 ]; then
        echo "Adding pane 5..."
        tmux select-pane -t "$(pane_ref 2)"
        tmux split-window -v -t "$(pane_ref 2)" -c "$REPO_ROOT"
    fi
    echo "Adding pane 6..."
    tmux select-pane -t "$(pane_ref 3)"
    tmux split-window -v -t "$(pane_ref 3)" -c "$REPO_ROOT"
else
    echo "Adding bottom pane..."
    tmux split-window -v -t "$(pane_ref 0)" -c "$REPO_ROOT" -p "${BOTTOM_HEIGHT:-30}"
    if [ $TOTAL -ge 2 ]; then
        echo "Adding right pane..."
        tmux select-pane -t "$(pane_ref 0)"
        tmux split-window -h -t "$(pane_ref 0)" -c "$REPO_ROOT" -p 50
    fi
fi

auto_warp_panes() {
    echo "🚀 Auto-warping panes to agent directories..."
    echo "   AGENTS_ARRAY: ${AGENTS_ARRAY[@]}"

    local pane_index=0
    local agent_index=0

    # Get list of pane IDs
    local panes
    panes=$(tmux list-panes -s -t "$SESSION_NAME" -F "#{pane_index}" 2>/dev/null || echo "")

    # Detect actual PANE_BASE from the first pane index
    local first_pane=$(echo "$panes" | head -1)
    if [ -n "$first_pane" ]; then
        PANE_BASE="$first_pane"
    else
        PANE_BASE=0
    fi
    echo "   PANE_BASE detected: $PANE_BASE"

    if [ -z "$panes" ]; then
        echo "⚠️  No panes found to warp"
        return
    fi

    # Warp each pane to its corresponding agent directory
    # Note: maw command is available from root's .envrc (loaded via direnv_broadcast)
    for pane_index in $panes; do
        local target_pane
        # Use pane_index directly since it's already the actual tmux pane index
        target_pane="${SESSION_NAME}:${WINDOW_INDEX}.${pane_index}"

        # Determine which agent this pane corresponds to
        if [ "$LAYOUT_TYPE" = "six-pane" ]; then
            # six-pane: pane 0 is root, panes 1-4 are agents 0-3, pane 5 is root
            if [ "$pane_index" -eq 0 ] || [ "$pane_index" -eq 5 ]; then
                # Keep root panes in root
                continue
            else
                # Panes 1-4 map to agents 0-3
                agent_index=$((pane_index - 1))
            fi
        elif [ "$LAYOUT_TYPE" = "two-pane" ] && [ "$TOTAL" -lt 2 ]; then
            # two-pane with only 1 agent: pane 0 is agent, pane 1 is root
            if [ "$pane_index" -eq 0 ]; then
                agent_index=0
            else
                continue
            fi
        else
            # Most layouts including three-horizontal: pane N corresponds to agent (N - PANE_BASE)
            agent_index=$((pane_index - PANE_BASE))
        fi

        # Check if we have an agent for this index
        if [ "$agent_index" -ge "$TOTAL" ]; then
            continue
        fi

        local agent_name="${AGENTS_ARRAY[$agent_index]}"
        local agent_dir="$AGENTS_DIR/$agent_name"

        if [ -d "$agent_dir" ]; then
            echo "  📍 Pane $pane_index → Agent $agent_name (index=$agent_index)"
            echo "     Sending to $target_pane: ORIG_PWD=\"\$PWD\" && cd \"$REPO_ROOT\" && source .envrc && cd \"\$ORIG_PWD\" && maw warp \"$agent_name\""
            tmux send-keys -t "$target_pane" "ORIG_PWD=\"\$PWD\" && cd \"$REPO_ROOT\" && source .envrc && cd \"\$ORIG_PWD\" && maw warp \"$agent_name\"" C-m
        else
            echo "  ⚠️ Directory not found: $agent_dir"
        fi
    done

    echo "✅ Auto-warp complete"
}

reload_tmux_conf_across_panes() {
    local conf_path
    if [ -n "${TMUX_CONF:-}" ] && [ -f "$TMUX_CONF" ]; then
        conf_path="$TMUX_CONF"
    elif [ -f "$DEFAULT_TMUX_CONF" ]; then
        conf_path="$DEFAULT_TMUX_CONF"
    else
        conf_path="$REPO_ROOT/.tmux.conf"
    fi
    if [ ! -f "$conf_path" ]; then
        return
    fi

    tmux source-file "$conf_path" 2>/dev/null || true

    while IFS= read -r pane_id; do
        tmux send-keys -t "$pane_id" "tmux" Space "source-file" Space "$conf_path" C-m
    done < <(tmux list-panes -s -t "$SESSION_NAME" -F "#{pane_id}" 2>/dev/null || true)
}

# Give shells time to initialize before sending commands
# Prevents escape sequences from appearing literally in the last pane
sleep 0.5

reload_tmux_conf_across_panes
direnv_broadcast

# Wait for direnv_broadcast commands to complete before warping
sleep 1

auto_warp_panes

echo ""
echo "✅ Started $TOTAL agents in tmux session: $SESSION_NAME"

if [ "$DETACHED" = true ]; then
    echo "📌 Running in detached mode"
    echo "💡 Attach with: tmux attach-session -t $SESSION_NAME"
else
    echo "📍 Attaching to session..."
    tmux attach-session -t "$SESSION_NAME"
fi
