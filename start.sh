#!/bin/bash
# Wrapper script to start multi-agent tmux session
# Usage: ./start.sh [profile] [--prefix name] [--detach|-d]
# Examples:
#   ./start.sh profile1
#   ./start.sh profile2 --prefix work
#   ./start.sh profile5 --detach
#   ./start.sh profile1 -d

# Check if any agents exist, if not run setup
if [ -z "$(git worktree list | grep '.agents/agents/')" ]; then
    echo "🔧 No agents found. Running setup..."
    .agents/setup.sh
    echo ""
fi

.agents/start-agents.sh "$@"