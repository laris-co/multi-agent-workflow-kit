#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$SCRIPT_DIR"
AGENTS_DIR="$REPO_ROOT/.agents"
AGENTS_YAML="$AGENTS_DIR/agents.yaml"

usage() {
    cat <<USAGE
Usage: ./remove.sh [options] [agent...]

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

removed_any=false
skipped_any=false
for agent in "${SELECTED_AGENTS[@]}"; do
    path=$(get_worktree_path "$agent")
    abs="$REPO_ROOT/$path"

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
        continue
    fi

    if [ "$was_dirty" = true ] && [ "$FORCE" = false ]; then
        printf '%s ... dirty (skipped; use --force)\n' "$agent"
        skipped_any=true
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
