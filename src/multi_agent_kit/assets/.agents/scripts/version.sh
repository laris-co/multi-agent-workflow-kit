#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)

# Try to get version from git tag
VERSION=""
if command -v git >/dev/null 2>&1 && [ -d "$REPO_ROOT/.git" ]; then
    # Get latest tag
    VERSION=$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")

    # If no tag, try to get commit hash
    if [ -z "$VERSION" ]; then
        COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "")
        if [ -n "$COMMIT" ]; then
            VERSION="dev-$COMMIT"
        fi
    fi
fi

# Prefer package markers for packaged installs
if [[ -z "$VERSION" || "$VERSION" == dev-* ]]; then
    VERSION_FILE="$AGENT_ROOT/VERSION"
    if [ -f "$VERSION_FILE" ]; then
        VERSION=$(head -n1 "$VERSION_FILE" | tr -d '\r')
    fi
fi

if [[ -z "$VERSION" || "$VERSION" == dev-* ]] && [ -f "$REPO_ROOT/pyproject.toml" ]; then
    VERSION=$(grep -E '^[[:space:]]*version[[:space:]]*=' "$REPO_ROOT/pyproject.toml" \
        | head -n1 \
        | sed -E 's/^[^"]*"([^"]+)".*/\1/' \
        || echo "")
fi

# Fallback version
if [ -z "$VERSION" ]; then
    VERSION="unknown"
fi

echo "Multi-Agent Workflow Kit"
echo ""
echo "Repository: https://github.com/Soul-Brews-Studio/multi-agent-workflow-kit"
echo "Gist: https://gist.github.com/nazt/3f9188eb0a5114fffa5d8cb4f14fe5a4"
echo ""
echo "Version: $VERSION"
