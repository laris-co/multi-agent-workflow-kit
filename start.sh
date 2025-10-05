#!/bin/bash
# Wrapper script to start multi-agent tmux session
# Usage: ./start.sh [profile] [--prefix name] [--detach|-d]
# Examples:
#   ./start.sh profile1
#   ./start.sh profile2 --prefix work
#   ./start.sh profile5 --detach
#   ./start.sh profile1 -d

# Check if any agents exist
AGENTS_DIR="$(pwd)/agents"

have_agents=false
if [ -d "$AGENTS_DIR" ] && [ -n "$(find "$AGENTS_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]; then
    have_agents=true
fi

if [ "$have_agents" = false ]; then
    echo "🔧 No agents found. Running setup..."
    agents/setup.sh
    echo ""
fi

agents/start-agents.sh "$@"
