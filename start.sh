#!/bin/bash
# Wrapper script to start multi-agent tmux session
# Usage: ./start.sh [profile] [--prefix name] [--detach|-d]
# Examples:
#   ./start.sh profile1
#   ./start.sh profile2 --prefix work
#   ./start.sh profile5 --detach
#   ./start.sh profile1 -d

# Check if any agents exist (supporting both legacy and new locations)
ROOT_AGENTS_DIR="$(pwd)/agents"
LEGACY_AGENTS_DIR="$(pwd)/.agents/agents"

have_agents=false
for dir in "$ROOT_AGENTS_DIR" "$LEGACY_AGENTS_DIR"; do
    if [ -d "$dir" ] && [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]; then
        have_agents=true
        break
    fi
done

if [ "$have_agents" = false ]; then
    echo "🔧 No agents found. Running setup..."
    .agents/setup.sh
    echo ""
fi

.agents/start-agents.sh "$@"
