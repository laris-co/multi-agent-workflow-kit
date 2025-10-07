#!/usr/bin/env bash
set -euo pipefail

# Delete local chore/* branches that are fully merged into main.

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

while IFS= read -r branch; do
  branch=${branch##* }
  branch=${branch#* }
  if git merge-base --is-ancestor "$branch" main; then
    git branch -d "$branch"
    merged+=("$branch")
  else
    skipped+=("$branch")
  fi
done < <(git branch --list 'chore/*')

if ((${#merged[@]})); then
  printf '✅ Deleted merged chore branches:\n'
  printf '  - %s\n' "${merged[@]}"
else
  echo "ℹ️  No chore branches were deleted."
fi

if ((${#skipped[@]})); then
  printf '\n⚠️  Skipped branches not merged into main:\n'
  printf '  - %s\n' "${skipped[@]}"
  echo "Use git branch -D <branch> only if you accept losing that history."
fi

