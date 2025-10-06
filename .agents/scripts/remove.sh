#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
AGENTS_DIR="$AGENT_ROOT"
AGENTS_YAML="$AGENTS_DIR/agents.yaml"

usage() {
    cat <<USAGE
Usage: .agents/scripts/remove.sh [options] [agent...]

Remove agent worktrees defined in .agents/agents.yaml.

Options:
  -f, --force    Force removal even if worktrees have uncommitted changes.
  -n, --dry-run  Show planned removals without deleting anything.
  -h, --help     Show this help message.

Without any agent arguments, all agents defined in agents.yaml are removed.
USAGE
}

abort() {
    echo "Error: $1" >&2
    exit 1
}

require_file() {
    if [ ! -e "$1" ]; then
        abort "$2"
    fi
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        abort "Required command '$1' not found in PATH."
    fi
}

require_file "$AGENTS_DIR" "Toolkit not installed. Run: uvx multi-agent-kit init"
require_file "$AGENTS_YAML" "Missing $AGENTS_YAML"
require_cmd git
require_cmd yq
if command -v tmux >/dev/null 2>&1; then
    TMUX_AVAILABLE=true
else
    TMUX_AVAILABLE=false
fi

FORCE=false
DRY_RUN=false
REQUESTED_AGENTS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                REQUESTED_AGENTS+=("$1")
                shift
            done
            ;;
        -*)
            abort "Unknown option: $1"
            ;;
        *)
            REQUESTED_AGENTS+=("$1")
            shift
            ;;
    esac
done

ALL_AGENTS=()
while IFS= read -r agent_name; do
    [ -n "$agent_name" ] && ALL_AGENTS+=("$agent_name")
done < <(yq -r '.agents | keys[]?' "$AGENTS_YAML" 2>/dev/null || true)

if [ "${#ALL_AGENTS[@]}" -eq 0 ]; then
    abort "No agents defined in $AGENTS_YAML"
fi

SELECTED_AGENTS=()

contains_agent() {
    local needle=$1
    local candidate
    if [ ${#SELECTED_AGENTS[@]} -eq 0 ]; then
        return 1
    fi
    for candidate in "${SELECTED_AGENTS[@]}"; do
        if [ "$candidate" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

kill_agent_sessions() {
    if [ "$TMUX_AVAILABLE" = false ]; then
        return
    fi

    local base_prefix="${SESSION_PREFIX:-ai}"
    local dir_name
    dir_name=$(basename "$REPO_ROOT")
    local pattern="${base_prefix}-${dir_name}"

    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${pattern}" || true)
    if [ -z "$sessions" ]; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "🛈 Dry run: would kill tmux sessions before removing worktrees:" >&2
        echo "$sessions" >&2
        return
    fi

    echo "🛑 Stopping tmux sessions before removing worktrees..."
    while IFS= read -r session; do
        [ -z "$session" ] && continue
        tmux kill-session -t "$session" 2>/dev/null || true
    done <<<"$sessions"
    echo "✅ tmux sessions stopped (if any were running)."
}

select_agent() {
    local agent=$1
    local path
    path=$(yq -r ".agents.\"$agent\".worktree_path // \"\"" "$AGENTS_YAML")
    if [ -z "$path" ]; then
        abort "Agent '$agent' is not defined in agents.yaml"
    fi
    if ! contains_agent "$agent"; then
        SELECTED_AGENTS+=("$agent")
    fi
}

if [ "${#REQUESTED_AGENTS[@]}" -eq 0 ]; then
    for agent in "${ALL_AGENTS[@]}"; do
        select_agent "$agent"
    done
else
    for agent in "${REQUESTED_AGENTS[@]}"; do
        select_agent "$agent"
    done
fi

get_worktree_path() {
    local agent=$1
    yq -r ".agents.\"$agent\".worktree_path // \"\"" "$AGENTS_YAML"
}

get_branch_name() {
    local agent=$1
    yq -r ".agents.\"$agent\".branch // \"\"" "$AGENTS_YAML"
}

branch_in_use() {
    local branch=$1
    git -C "$REPO_ROOT" worktree list --porcelain \
        | awk '/^branch /{print $2}' \
        | sed 's#^refs/heads/##' \
        | grep -Fx "$branch" >/dev/null 2>&1
}

declare -a PROCESSED_BRANCHES=()

branch_already_processed() {
    local target=$1
    if [ ${#PROCESSED_BRANCHES[@]} -eq 0 ]; then
        return 1
    fi
    local existing
    for existing in "${PROCESSED_BRANCHES[@]}"; do
        if [ "$existing" = "$target" ]; then
            return 0
        fi
    done
    return 1
}

mark_branch_processed() {
    PROCESSED_BRANCHES+=("$1")
}

describe_branch_action() {
    local agent=$1
    local branch=$2
    if [ -z "$branch" ] || [ "$branch" = "main" ]; then
        return
    fi
    if branch_already_processed "$branch"; then
        return
    fi
    mark_branch_processed "$branch"
    if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$branch" >/dev/null; then
        printf '%s ... branch %s not found (nothing to delete)\n' "$agent" "$branch"
        return
    fi
    if branch_in_use "$branch"; then
        printf '%s ... branch %s still attached to another worktree (would skip)\n' "$agent" "$branch"
        return
    fi
    if [ "$FORCE" = true ]; then
        printf '%s ... would delete branch %s (--force)\n' "$agent" "$branch"
    else
        printf '%s ... would delete branch %s (if fully merged)\n' "$agent" "$branch"
    fi
}

delete_branch_if_possible() {
    local agent=$1
    local branch=$2
    if [ -z "$branch" ] || [ "$branch" = "main" ]; then
        return
    fi
    if branch_already_processed "$branch"; then
        return
    fi
    mark_branch_processed "$branch"
    if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$branch" >/dev/null; then
        return
    fi
    if branch_in_use "$branch"; then
        printf '%s ... branch %s still attached to another worktree (skipped)\n' "$agent" "$branch"
        return
    fi
    if [ "$FORCE" = true ]; then
        if git -C "$REPO_ROOT" branch -D "$branch" >/dev/null 2>&1; then
            printf '%s ... deleted branch %s (--force)\n' "$agent" "$branch"
        else
            printf '%s ... failed to delete branch %s (--force)\n' "$agent" "$branch"
        fi
    else
        if git -C "$REPO_ROOT" branch -d "$branch" >/dev/null 2>&1; then
            printf '%s ... deleted branch %s\n' "$agent" "$branch"
        else
            printf '%s ... branch %s not fully merged (use --force to delete)\n' "$agent" "$branch"
        fi
    fi
}

has_uncommitted_changes() {
    local worktree=$1
    if [ ! -d "$worktree" ]; then
        return 1
    fi
    if ! git -C "$worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi
    local status
    status=$(git -C "$worktree" status --porcelain)
    [ -n "$status" ]
}

is_registered_worktree() {
    local abs=$1
    git -C "$REPO_ROOT" worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | grep -Fx "$abs" >/dev/null 2>&1
}

declare -a DIRTY_AGENTS=()
for agent in "${SELECTED_AGENTS[@]}"; do
    path=$(get_worktree_path "$agent")
    abs="$REPO_ROOT/$path"
    if has_uncommitted_changes "$abs"; then
        DIRTY_AGENTS+=("$agent")
    fi
done

is_dirty_agent() {
    local target=$1
    if [ ${#DIRTY_AGENTS[@]} -eq 0 ]; then
        return 1
    fi
    for dirty in "${DIRTY_AGENTS[@]}"; do
        if [ "$dirty" = "$target" ]; then
            return 0
        fi
    done
    return 1
}

kill_agent_sessions

removed_any=false
skipped_any=false
for agent in "${SELECTED_AGENTS[@]}"; do
    path=$(get_worktree_path "$agent")
    abs="$REPO_ROOT/$path"
    branch=$(get_branch_name "$agent")

    was_dirty=false
    if is_dirty_agent "$agent"; then
        was_dirty=true
    fi

    registered=false
    if is_registered_worktree "$abs"; then
        registered=true
    fi

    exists_dir=false
    if [ -d "$abs" ]; then
        exists_dir=true
    fi

    if [ "$DRY_RUN" = true ]; then
        if [ "$was_dirty" = true ]; then
            if [ "$FORCE" = true ]; then
                printf '%s ... dirty (would remove with --force)\n' "$agent"
            else
                printf '%s ... dirty (would skip; use --force)\n' "$agent"
                skipped_any=true
            fi
        elif [ "$registered" = true ]; then
            printf '%s ... clean (would remove worktree)\n' "$agent"
        elif [ "$exists_dir" = true ]; then
            printf '%s ... clean (would remove directory cleanup)\n' "$agent"
        else
            printf '%s ... clean (no worktree found)\n' "$agent"
        fi
        describe_branch_action "$agent" "$branch"
        continue
    fi

    if [ "$was_dirty" = true ] && [ "$FORCE" = false ]; then
        printf '%s ... dirty (skipped; use --force)\n' "$agent"
        skipped_any=true
        delete_branch_if_possible "$agent" "$branch"
        continue
    fi

    if [ "$registered" = true ]; then
        if [ "$FORCE" = true ]; then
            git -C "$REPO_ROOT" worktree remove "$abs" --force >/dev/null 2>&1
        else
            git -C "$REPO_ROOT" worktree remove "$abs" >/dev/null 2>&1
        fi

        if [ ! -d "$abs" ]; then
            if [ "$was_dirty" = true ]; then
                printf '%s ... removed (forced dirty worktree)\n' "$agent"
            else
                printf '%s ... removed (worktree)\n' "$agent"
            fi
            removed_any=true
        else
            printf '%s ... failed to remove worktree (%s)\n' "$agent" "$path"
        fi
    elif [ "$exists_dir" = true ]; then
        rm -rf "$abs"
        if [ ! -d "$abs" ]; then
            printf '%s ... removed (directory cleanup)\n' "$agent"
            removed_any=true
        else
            printf '%s ... failed to remove directory (%s)\n' "$agent" "$path"
        fi
    else
        printf '%s ... clean (no worktree found)\n' "$agent"
    fi

    if [ -d "$abs" ]; then
        printf 'Warning: directory %s still exists after removal attempt\n' "$path" >&2
    fi

    delete_branch_if_possible "$agent" "$branch"
done

if [ "$DRY_RUN" = true ]; then
    if [ "$skipped_any" = true ] && [ "$FORCE" = false ]; then
        echo "Dry run complete; dirty worktrees would be skipped without --force."
    else
        echo "Dry run complete; no changes were made."
    fi
    exit 0
fi

if [ "$removed_any" = true ]; then
    git -C "$REPO_ROOT" worktree prune -v >/dev/null
    echo "Pruned stale worktree references"
fi

if [ "$skipped_any" = true ] && [ "$FORCE" = false ]; then
    echo "Skipped worktrees remain; re-run with --force to remove them."
fi
