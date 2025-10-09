#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

usage() {
    cat <<USAGE
Usage: direnv-allow.sh [options]

Run 'direnv allow' in repository root and all agent worktrees.
This should be run before starting a tmux session to ensure direnv
is properly configured in all directories.

Options:
  -h, --help         Show this help message

Example:
  maw direnv
  direnv-allow.sh
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
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

# Check if direnv is available
if ! command -v direnv >/dev/null 2>&1; then
    echo "Error: direnv is not installed" >&2
    echo "Install direnv first: https://direnv.net/docs/installation.html" >&2
    exit 1
fi

echo "🔧 Configuring direnv in repository and agent worktrees..."
echo ""

# Allow in main repo
if [ -f "$REPO_ROOT/.envrc" ]; then
    echo "📍 Repository root"
    direnv allow "$REPO_ROOT"
    echo "   ✅ direnv allowed"
else
    echo "📍 Repository root"
    echo "   ⚠️  No .envrc found (skipping)"
fi

# Get agents directory
AGENTS_DIR="$REPO_ROOT/agents"

if [ ! -d "$AGENTS_DIR" ]; then
    echo ""
    echo "ℹ️  No agents directory found"
    echo "   Run 'maw install' to create agent worktrees"
    exit 0
fi

# Allow in each agent worktree
AGENT_COUNT=0
for agent_dir in "$AGENTS_DIR"/*; do
    if [ -d "$agent_dir" ] && [ "$(basename "$agent_dir")" != ".*" ]; then
        AGENT_NAME=$(basename "$agent_dir")
        echo "📍 Agent worktree: agents/$AGENT_NAME"

        # Copy .envrc from repo root if it doesn't exist
        if [ ! -f "$agent_dir/.envrc" ] && [ -f "$REPO_ROOT/.envrc" ]; then
            cp "$REPO_ROOT/.envrc" "$agent_dir/.envrc"
            echo "   📄 Copied .envrc from repo root"
        fi

        if [ -f "$agent_dir/.envrc" ]; then
            direnv allow "$agent_dir"
            echo "   ✅ direnv allowed"
            AGENT_COUNT=$((AGENT_COUNT + 1))
        else
            echo "   ⚠️  No .envrc found (skipping)"
        fi
    fi
done

echo ""
if [ $AGENT_COUNT -gt 0 ]; then
    echo "✅ Configured direnv in repository root + $AGENT_COUNT agent worktree(s)"
else
    echo "✅ Configured direnv in repository root (no agent worktrees found)"
fi

echo ""
echo "💡 Next steps:"
echo "   → maw start profile0    # Start tmux session"
echo "   → maw attach            # Attach to session"
