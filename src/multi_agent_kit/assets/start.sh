#!/bin/bash
set -euo pipefail

# Simple wrapper for .agents/scripts/start-agents.sh
# Default to profile0 if no arguments provided

# Check if .agents exists
if [ ! -d ".agents" ]; then
    echo "❌ Toolkit not installed. Run: uvx multi-agent-kit init"
    exit 1
fi

# Default to profile0 if no arguments
SCRIPT_PATH=".agents/scripts/start-agents.sh"

if [ ! -x "$SCRIPT_PATH" ]; then
    echo "❌ Missing $SCRIPT_PATH. Run: uvx multi-agent-kit init"
    exit 1
fi

if [ $# -eq 0 ]; then
    exec "$SCRIPT_PATH" profile0
else
    exec "$SCRIPT_PATH" "$@"
fi
