#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

usage() {
    cat <<USAGE
Usage: .agents/scripts/uninstall.sh [options]

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
if command -v tmux >/dev/null 2>&1; then
    TMUX_AVAILABLE=true
else
    TMUX_AVAILABLE=false
fi

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
    ".agents/config/tmux.conf"
    ".envrc"
    "MAW-AGENTS.md"
)
CLAUDE_FILES=(
    ".claude/commands/maw.agents-create.md"
    ".claude/commands/maw.codex.md"
    ".claude/commands/maw.codex.sh"
    ".claude/commands/maw.hey.md"
    ".claude/commands/maw.hey.sh"
    ".claude/commands/maw-issue.md"
    ".claude/commands/maw-issue.sh"
    ".claude/commands/maw.sync.md"
    ".claude/commands/maw.sync.sh"
    ".claude/commands/maw.zoom.md"
    ".claude/commands/maw.zoom.sh"
    ".claude/commands/maw.issue.md"
    ".claude/commands/maw.issue.sh"
    ".claude/.gitignore"
)
CODEX_FILES=(
    ".codex/prompts/README.md"
    ".codex/.gitignore"
    ".codex/README.md"
)

SELF_PATH=".agents/scripts/uninstall.sh"

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
        log "Dry run: would kill tmux sessions before uninstalling:" >&2
        echo "$sessions" >&2
        return
    fi

    log "🛑 Stopping tmux sessions before uninstall..."
    while IFS= read -r session; do
        [ -z "$session" ] && continue
        tmux kill-session -t "$session" 2>/dev/null || true
    done <<<"$sessions"
    log "✅ tmux sessions stopped (if any were running)."
}

kill_agent_sessions

PREVIEW=("${TARGET_DIRS[@]}" "${TARGET_FILES[@]}" "${CLAUDE_FILES[@]}" ${CODEX_FILES[@]+"${CODEX_FILES[@]}"} ".codex/prompts/maw*.md" "$SELF_PATH")

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

REMOVE_SCRIPT="$AGENT_ROOT/scripts/remove.sh"
if [ -f "$REMOVE_SCRIPT" ] && [ -d "$REPO_ROOT/.agents" ]; then
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute maw remove --force to clean up agent worktrees and branches."
    else
        if command -v yq >/dev/null 2>&1; then
            log "Running maw remove --force to remove agent worktrees and branches..."
            if ! "$REMOVE_SCRIPT" --force; then
                warn "maw remove --force exited with an error; check agent branches manually."
            fi
        else
            warn "Skipping agent clean-up because 'yq' is not available; remove agent branches manually if needed."
        fi
    fi
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

if [ ${#CODEX_FILES[@]} -gt 0 ]; then
    for codex_file in "${CODEX_FILES[@]}"; do
        remove_path "$codex_file"
    done
fi

# Remove maw*.md files from .codex/prompts/
CODEX_PROMPTS_DIR="$REPO_ROOT/.codex/prompts"
if [ -d "$CODEX_PROMPTS_DIR" ]; then
    for maw_prompt in "$CODEX_PROMPTS_DIR"/maw*.md; do
        if [ -f "$maw_prompt" ]; then
            rel_path=".codex/prompts/$(basename "$maw_prompt")"
            remove_path "$rel_path"
        fi
    done
fi

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
    cleanup_dir_if_empty ".codex/prompts"
    cleanup_dir_if_empty ".codex"
    cleanup_dir_if_empty "agents"
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
