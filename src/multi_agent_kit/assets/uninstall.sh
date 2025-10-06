#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$SCRIPT_DIR"

usage() {
    cat <<USAGE
Usage: ./uninstall.sh [options]

Remove toolkit assets installed by multi-agent-kit.

Options:
  -f, --force             Skip confirmation prompts and override safe-guards.
  -n, --dry-run           Show what would be removed without deleting anything.
  --remove-agents         Remove the git worktree directory under agents/ (if safe).
  -h, --help              Show this help message.
USAGE
}

log() { printf '%s\n' "$1"; }
warn() { printf 'Warning: %s\n' "$1" >&2; }
abort() { printf 'Error: %s\n' "$1" >&2; exit 1; }

FORCE=false
DRY_RUN=false
REMOVE_AGENTS=false

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
        --remove-agents)
            REMOVE_AGENTS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            abort "Unknown option: $1"
            ;;
    esac
done

TARGET_DIRS=(
    ".agents"
)
TARGET_FILES=(
    ".tmux.conf"
    "start.sh"
    "remove.sh"
)
CLAUDE_FILES=(
    ".claude/commands/catlab-agents-create.md"
    ".claude/commands/catlab-codex.md"
    ".claude/commands/catlab-codex.sh"
)

SELF_PATH="uninstall.sh"

if [ ! -d "$REPO_ROOT/.agents" ]; then
    warn ".agents directory not found; toolkit may already be uninstalled."
fi

if [ "$REMOVE_AGENTS" = true ]; then
    AGENTS_DIR="$REPO_ROOT/agents"
    if [ -d "$AGENTS_DIR" ]; then
        MAP_RESULT="$(find "$AGENTS_DIR" -mindepth 1 \( ! -name '.gitignore' \) -print -quit 2>/dev/null || true)"
        if [ -n "$MAP_RESULT" ] && [ "$FORCE" = false ]; then
            warn "agents/ contains worktrees or files; skipping removal (use --force with --remove-agents to override)."
        else
            TARGET_DIRS+=("agents")
        fi
    elif [ "$FORCE" = true ]; then
        warn "agents/ directory not found (nothing to remove)."
    fi
fi

PREVIEW=("${TARGET_DIRS[@]}" "${TARGET_FILES[@]}" "${CLAUDE_FILES[@]}" "$SELF_PATH")

if [ "$DRY_RUN" = true ]; then
    log "Dry run: the following paths would be removed:"
else
    log "The following paths will be removed:"
fi
for target in "${PREVIEW[@]}"; do
    printf '  %s\n' "$target"
done

if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    printf 'Proceed? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) : ;;
        *)
            log "Aborted."
            exit 0
            ;;
    esac
fi

remove_path() {
    local rel=$1
    local abs="$REPO_ROOT/$rel"

    if [ ! -e "$abs" ]; then
        log "Skipping $rel (not found)"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "Would remove $rel"
        return
    fi

    if [ -d "$abs" ]; then
        rm -rf "$abs"
        log "Removed directory $rel"
    else
        rm -f "$abs"
        log "Removed file $rel"
    fi
}

for dir_target in "${TARGET_DIRS[@]}"; do
    remove_path "$dir_target"
done

for file_target in "${TARGET_FILES[@]}"; do
    remove_path "$file_target"
done

for claude_file in "${CLAUDE_FILES[@]}"; do
    remove_path "$claude_file"
done

cleanup_dir_if_empty() {
    local rel=$1
    local abs="$REPO_ROOT/$rel"
    if [ "$DRY_RUN" = true ]; then
        return
    fi
    if [ -d "$abs" ]; then
        if find "$abs" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
            return
        fi
        rmdir "$abs"
        log "Removed empty directory $rel"
    fi
}

if [ "$DRY_RUN" = false ]; then
    cleanup_dir_if_empty ".claude/commands"
    cleanup_dir_if_empty ".claude"
fi

if [ "$DRY_RUN" = true ]; then
    log "Would remove $SELF_PATH"
else
    if [ -e "$REPO_ROOT/$SELF_PATH" ]; then
        rm -f "$REPO_ROOT/$SELF_PATH"
        log "Removed file $SELF_PATH"
    fi
fi

if [ "$DRY_RUN" = false ]; then
    log "Uninstall complete."
else
    log "Dry run finished."
fi
