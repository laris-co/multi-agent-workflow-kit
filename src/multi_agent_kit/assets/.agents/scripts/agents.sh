#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
REGISTRY="$AGENT_ROOT/agents.yaml"
cmd=${1:-}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: missing dependency '$1'" >&2; exit 1; }; }

read_yaml() {
  need yq
  yq "$1" "$REGISTRY"
}

create() {
  local agent=${1:?usage: $0 create <agent>}
  local branch path abs_path
  branch=$(read_yaml ".agents.$agent.branch")
  path=$(read_yaml ".agents.$agent.worktree_path")

  case "$path" in
    agents/*) : ;;
    *) echo "Error: worktree_path '$path' must start with agents/" >&2; exit 1;;
  esac

  abs_path="$REPO_ROOT/$path"

  if ! git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    cat <<'EOF'
⚠️  The current repository has no commits yet.
   Create an initial commit before running agent setup so Git worktrees have a base revision.
   For example:
     git commit --allow-empty -m "Initial commit"
EOF
    exit 1
  fi

  if ! git -C "$REPO_ROOT" rev-parse --verify "$branch" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" branch "$branch"
  fi
  mkdir -p "$(dirname "$abs_path")"

  if [ -d "$abs_path" ]; then
    echo "ℹ️  Agent already exists at $path"
  else
    # Check if worktree is stale and clean it up
    if git -C "$REPO_ROOT" worktree list | grep -q "$abs_path"; then
      echo "⚠️  Found stale worktree registration for $path, cleaning up..."
      git -C "$REPO_ROOT" worktree prune -v
    fi
    git -C "$REPO_ROOT" worktree add "$abs_path" "$branch"
    echo "✅ Created $agent worktree at $path on branch $branch"
  fi
}

list() {
  echo "📋 Git worktrees:"
  git -C "$REPO_ROOT" worktree list
  echo ""
  local base="$REPO_ROOT/agents"
  if [ -d "$base" ]; then
    echo "📤 Agents under agents/"
    for d in "$base"/*; do
      if [ -d "$d" ]; then
        local branch
        branch=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
        printf "  %s [%s]\n" "${d#$REPO_ROOT/}" "$branch"
      fi
    done
    echo ""
  fi
}

remove() {
  local agent=${1:?usage: $0 remove <agent>}
  local path abs_path
  path=$(read_yaml ".agents.$agent.worktree_path")
  abs_path="$REPO_ROOT/$path"

  if [ -d "$abs_path" ] && git -C "$REPO_ROOT" worktree list | grep -q "$abs_path"; then
    git -C "$REPO_ROOT" worktree remove "$abs_path" --force 2>/dev/null || true
    echo "✅ Removed worktree at $path"
  else
    echo "ℹ️  No worktree to remove at $path"
  fi
}

case "$cmd" in
  create) create "${2-}" ;;
  list)   list ;;
  remove) remove "${2-}" ;;
  *) echo "Usage: $0 {create|list|remove} [agent]" ;;
esac
