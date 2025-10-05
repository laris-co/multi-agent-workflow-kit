#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REGISTRY="$SCRIPT_DIR/agents.yaml"
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
    agents/*|.agents/agents/*) : ;;
    *) echo "Error: worktree_path '$path' must start with agents/ or .agents/agents/" >&2; exit 1;;
  esac

  abs_path="$REPO_ROOT/$path"

  git -C "$REPO_ROOT" branch "$branch" 2>/dev/null || true
  mkdir -p "$(dirname "$abs_path")"

  if [ -d "$abs_path" ]; then
    echo "ℹ️  Agent already exists at $path"
  else
    git -C "$REPO_ROOT" worktree add "$abs_path" "$branch"
    echo "✅ Created $agent worktree at $path on branch $branch"
  fi
}

list() {
  echo "📋 Git worktrees:"
  git -C "$REPO_ROOT" worktree list
  echo ""
  local bases=("$REPO_ROOT/agents" "$SCRIPT_DIR/agents")
  for base in "${bases[@]}"; do
    if [ -d "$base" ]; then
      local label
      if [[ "$base" == "$REPO_ROOT/agents" ]]; then
        label="agents/"
      else
        label=".agents/agents/"
      fi
      echo "📤 Agents under $label"
      for d in "$base"/*; do
        if [ -d "$d" ]; then
          local branch
          branch=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
          printf "  %s [%s]\n" "${d#$REPO_ROOT/}" "$branch"
        fi
      done
      echo ""
    fi
  done
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
