#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

GIST_URL="https://gist.githubusercontent.com/nazt/3f9188eb0a5114fffa5d8cb4f14fe5a4/raw"
TARGET_FILE="$REPO_ROOT/CLAUDE.md"

usage() {
    cat <<USAGE
Usage: catlab.sh [options]

Download CLAUDE.md guidelines from catlab gist to repository root.

Options:
  -f, --force    Overwrite existing CLAUDE.md file
  -h, --help     Show this help message

Example:
  maw catlab
  maw catlab --force
USAGE
}

FORCE=false

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
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

# Check if file already exists
if [ -f "$TARGET_FILE" ] && [ "$FORCE" = false ]; then
    echo "Error: CLAUDE.md already exists at $TARGET_FILE" >&2
    echo "Use --force to overwrite" >&2
    exit 1
fi

# Download the file
echo "📥 Downloading CLAUDE.md from catlab gist..."

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$GIST_URL" -o "$TARGET_FILE"; then
        echo "✅ CLAUDE.md created at: $TARGET_FILE"
        echo ""
        echo "💡 Next steps:"
        echo "   1. Review the guidelines: cat CLAUDE.md"
        echo "   2. Commit to repository: git add CLAUDE.md && git commit -m 'docs: add CLAUDE.md guidelines'"
    else
        echo "Error: Failed to download from $GIST_URL" >&2
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q "$GIST_URL" -O "$TARGET_FILE"; then
        echo "✅ CLAUDE.md created at: $TARGET_FILE"
        echo ""
        echo "💡 Next steps:"
        echo "   1. Review the guidelines: cat CLAUDE.md"
        echo "   2. Commit to repository: git add CLAUDE.md && git commit -m 'docs: add CLAUDE.md guidelines'"
    else
        echo "Error: Failed to download from $GIST_URL" >&2
        exit 1
    fi
else
    echo "Error: Neither curl nor wget is available" >&2
    echo "Please install curl or wget to use this command" >&2
    exit 1
fi
