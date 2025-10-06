#!/bin/bash
set -euo pipefail

# Simple wrapper for .agents/start-agents.sh
# Default to profile1 if no arguments provided

# Check if .agents exists
if [ ! -d ".agents" ]; then
    echo "❌ Toolkit not installed. Run: uvx multi-agent-kit init"
    exit 1
fi

# Default to profile1 if no arguments
if [ $# -eq 0 ]; then
    exec .agents/start-agents.sh profile1
else
    exec .agents/start-agents.sh "$@"
fi
