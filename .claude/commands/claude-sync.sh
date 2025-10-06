#!/bin/bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not inside a Git repository."
    exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
status_output=$(git status --porcelain)

if [[ -n "$status_output" ]]; then
    echo "❌ Working tree has uncommitted changes. Commit, stash, or clean them before syncing."
    exit 1
fi

if [[ "$branch" == "main" ]]; then
    echo "📍 On main branch. Pulling latest from origin/main (fast-forward only)..."
    git pull --ff-only origin main
    echo "✅ main is up to date with origin/main."
elif [[ "$branch" == agents/* ]]; then
    if ! git show-ref --verify --quiet refs/heads/main; then
        echo "❌ Local main branch not found. Sync main worktree first."
        exit 1
    fi
    echo "📍 On agent branch '$branch'. Merging local main into this worktree..."
    git merge main
    echo "✅ Agent branch '$branch' now includes the latest local main."
else
    echo "⚠️ Branch '$branch' is not 'main' or an 'agents/*' worktree branch. No sync performed."
    echo "   Run this command from the main worktree or an agents/<name> worktree."
    exit 1
fi
