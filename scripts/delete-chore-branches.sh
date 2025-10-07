#!/usr/bin/env bash
set -euo pipefail

# Delete local <prefix>/* branches that are fully merged into main.
# Usage: ./delete-chore-branches.sh [--force] [prefix ...]
# Defaults to the "chore" prefix when none are provided.

force_delete=false
declare -a prefixes=()

for arg in "$@"; do
  case "$arg" in
    --force)
      force_delete=true
      ;;
    *)
      prefixes+=("$arg")
      ;;
  esac
done

if ((${#prefixes[@]} == 0)); then
  prefixes=("chore")
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ $current_branch != "main" ]]; then
  echo "⚠️  Run this from main. Current branch: $current_branch" >&2
  exit 1
fi

if [[ -n $(git status --porcelain) ]]; then
  echo "⚠️  Working tree is dirty. Commit or stash before deleting branches." >&2
  exit 1
fi

merged=()
skipped=()
seen_branches=""

for prefix in "${prefixes[@]}"; do
  pattern=$prefix
  [[ $pattern == */* ]] || pattern+="/*"
  while IFS= read -r line; do
    branch=${line##* }
    branch=${branch#* }
    case " $seen_branches " in
      *" $branch "*)
        continue
        ;;
    esac
    seen_branches+="$branch "
    if git merge-base --is-ancestor "$branch" main; then
      git branch -d "$branch"
      merged+=("$branch")
    else
      skipped+=("$branch")
    fi
  done < <(git branch --list "$pattern")
done

if ((${#merged[@]})); then
  printf '✅ Deleted merged branches:\n'
  printf '  - %s\n' "${merged[@]}"
else
  echo "ℹ️  No branches were deleted."
fi

if ((${#skipped[@]})); then
  printf '\n⚠️  Skipped branches not merged into main:\n'
  printf '  - %s\n' "${skipped[@]}"
  if ! $force_delete; then
    echo "Use git branch -D <branch> only if you accept losing that history, or rerun with --force."
  fi
fi

if $force_delete && ((${#skipped[@]})); then
  echo
  read -r -p "Type DELETE to force-remove the branches above: " confirm
  if [[ $confirm == "DELETE" ]]; then
    for branch in "${skipped[@]}"; do
      git branch -D "$branch"
      echo "❌ Force-deleted $branch"
    done
  else
    echo "Aborted; no branches were force-deleted."
  fi
fi
