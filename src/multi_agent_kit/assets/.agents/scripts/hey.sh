#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

show_usage() {
    cat <<'USAGE'
Usage: hey.sh <agent> <message>
       hey.sh --list
       hey.sh --map

Send a message to a specific agent in the tmux session.

Arguments:
  <agent>     Agent name (e.g., 1, 2, backend-api) or special target (root, all)
  <message>   Message to send to the agent

Options:
  --list      List available agents
  --map       Show agent to pane mapping

Examples:
  hey.sh 1 "analyse this repository"
  hey.sh 2 "create a plan for auth feature"
  hey.sh root "git status"
  hey.sh all "git pull"
USAGE
}

list_agents() {
    local agents_dir="$REPO_ROOT/agents"

    echo "📋 Available agents:"
    if [[ -d "$agents_dir" ]]; then
        local agents=($(cd "$agents_dir" && ls -d */ 2>/dev/null | sed 's#/##' | sort))
        if [[ ${#agents[@]} -gt 0 ]]; then
            for agent in "${agents[@]}"; do
                echo "  - $agent"
            done
        else
            echo "  (no agents found)"
        fi
    else
        echo "  (agents directory not found)"
    fi
    echo ""
    echo "Special targets:"
    echo "  - root  (main worktree pane)"
    echo "  - all   (broadcast to all agents)"
}

show_map() {
    local agents_dir="$REPO_ROOT/agents"
    local agents=($(cd "$agents_dir" && ls -d */ 2>/dev/null | sed 's#/##' | sort))

    echo "📊 Agent to pane mapping:"
    for i in "${!agents[@]}"; do
        echo "  Agent '${agents[$i]}' → pane $i (agents/${agents[$i]})"
    done

    # Try to find root pane
    if [[ -n "${SESSION_NAME:-}" ]] && [[ -n "${WINDOW_INDEX:-}" ]]; then
        local root_pane=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_INDEX" -F "#{pane_index} #{pane_current_path}" 2>/dev/null | \
            grep "$REPO_ROOT\$" | cut -d' ' -f1 || echo "unknown")
        echo "  Root           → pane $root_pane (main worktree)"
    else
        echo "  Root           → (session not detected)"
    fi
}

send_message() {
    local pane=$1
    local text=$2

    tmux send-keys -t "$pane" "$text"
    sleep 0.05
    tmux send-keys -t "$pane" Enter
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

case "$1" in
    --list|-l)
        list_agents
        exit 0
        ;;
    --map|-m)
        show_map
        exit 0
        ;;
    --help|-h)
        show_usage
        exit 0
        ;;
esac

AGENT_TARGET=$1
shift
MESSAGE="$*"

if [[ -z "$MESSAGE" ]]; then
    echo "❌ Error: No message provided"
    echo ""
    show_usage
    exit 1
fi

# Find tmux session
DIR_NAME=$(basename "$REPO_ROOT")
BASE_PREFIX=${SESSION_PREFIX:-ai}
SESSION_NAME=""

# Try exact match first
if tmux has-session -t "${BASE_PREFIX}-${DIR_NAME}" 2>/dev/null; then
    SESSION_NAME="${BASE_PREFIX}-${DIR_NAME}"
else
    # Look for sessions with custom suffix
    MATCHING_SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${BASE_PREFIX}-${DIR_NAME}" || true)
    SESSION_COUNT=$(echo "$MATCHING_SESSIONS" | grep -c . || echo 0)

    if [[ $SESSION_COUNT -eq 1 ]]; then
        SESSION_NAME="$MATCHING_SESSIONS"
    elif [[ $SESSION_COUNT -gt 1 ]]; then
        echo "❌ Error: Multiple matching sessions found:"
        echo "$MATCHING_SESSIONS" | sed 's/^/  - /'
        echo ""
        echo "Please specify which session by setting SESSION_PREFIX"
        exit 1
    fi
fi

if [[ -z "$SESSION_NAME" ]]; then
    echo "❌ Error: No tmux session found matching '${BASE_PREFIX}-${DIR_NAME}*'"
    echo ""
    echo "Expected session name patterns:"
    echo "  - ${BASE_PREFIX}-${DIR_NAME}"
    echo "  - ${BASE_PREFIX}-${DIR_NAME}-<suffix>"
    echo ""
    echo "Make sure the tmux session is running (use 'maw start')"
    exit 1
fi

WINDOW_INDEX=$(tmux list-windows -t "$SESSION_NAME" -F "#{window_index}" | head -1)
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# Handle special targets
if [[ "$AGENT_TARGET" == "all" ]]; then
    echo "📢 Broadcasting to all agents: $MESSAGE"
    PANE_COUNT=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_INDEX" -F "#{pane_index}" | wc -l)

    for ((i=0; i<PANE_COUNT; i++)); do
        PANE_INDEX=$((PANE_BASE + i))
        TARGET_PANE="$SESSION_NAME:$WINDOW_INDEX.$PANE_INDEX"

        # Skip root pane (usually the last one)
        PANE_PATH=$(tmux display-message -t "$TARGET_PANE" -p "#{pane_current_path}" 2>/dev/null || echo "")
        if [[ "$PANE_PATH" == "$REPO_ROOT" ]]; then
            continue
        fi

        send_message "$TARGET_PANE" "$MESSAGE"
    done

    echo "✅ Broadcasted to all agent panes"
    exit 0
fi

if [[ "$AGENT_TARGET" == "root" ]] || [[ "$AGENT_TARGET" == "main" ]]; then
    # Find root pane by matching current path
    ROOT_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_INDEX" -F "#{pane_index} #{pane_current_path}" 2>/dev/null | \
        grep "$REPO_ROOT\$" | cut -d' ' -f1 || echo "")

    if [[ -z "$ROOT_PANE" ]]; then
        echo "❌ Error: Could not find root pane"
        exit 1
    fi

    TARGET_PANE="$SESSION_NAME:$WINDOW_INDEX.$ROOT_PANE"

    echo "📤 Sending to root pane: $MESSAGE"
    send_message "$TARGET_PANE" "$MESSAGE"

    echo "✅ Sent successfully"
    exit 0
fi

# Find agent by name
AGENTS_DIR="$REPO_ROOT/agents"
if [[ ! -d "$AGENTS_DIR" ]]; then
    echo "❌ Error: Agents directory not found: $AGENTS_DIR"
    exit 1
fi

AGENTS=($(cd "$AGENTS_DIR" && ls -d */ 2>/dev/null | sed 's#/##' | sort))

# Find agent index
PANE_INDEX=""
for i in "${!AGENTS[@]}"; do
    if [[ "${AGENTS[$i]}" == "$AGENT_TARGET" ]]; then
        PANE_INDEX=$((PANE_BASE + i))
        break
    fi
done

if [[ -z "$PANE_INDEX" ]]; then
    echo "❌ Error: Agent '$AGENT_TARGET' not found"
    echo ""
    echo "Available agents:"
    for agent in "${AGENTS[@]}"; do
        echo "  - $agent"
    done
    echo ""
    echo "Special targets: root, all"
    exit 1
fi

TARGET_PANE="$SESSION_NAME:$WINDOW_INDEX.$PANE_INDEX"

echo "📤 Sending to agent '$AGENT_TARGET' (pane $PANE_INDEX): $MESSAGE"
send_message "$TARGET_PANE" "$MESSAGE"

echo "✅ Sent successfully"
