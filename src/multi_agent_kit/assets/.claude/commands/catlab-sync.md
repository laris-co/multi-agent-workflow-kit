---
description: Sync the current worktree with main-aware rules
argument-hint: (no args)
allowed-tools:
  - Bash(.claude/commands/catlab-sync.sh:*)
---

Goal: Keep local worktrees aligned with `main` without relying on remote fetches inside agent directories.

Inputs:
- none — run the command without arguments.

Behavior:
1) Verify the working tree is clean; abort if there are staged or unstaged changes.
2) If the active branch is `main`, run `git pull --ff-only origin main`.
3) If the active branch matches `agents/*`, run `git merge main` to fast-forward from the shared local branch.
4) For any other branch, stop and explain that no sync was performed.

Shell template:

```bash
.claude/commands/catlab-sync.sh "$@"
```

Usage examples:
- `/catlab-sync` (from the main worktree)
- `/catlab-sync` (from an agent worktree such as `agents/1-agent`)

Notes:
- Requires a clean working tree. Commit, stash, or discard changes before rerunning.
- Assumes the repository uses `main` as its primary branch and agent branches follow the `agents/<name>` convention.
- In agent worktrees, the merge references the local `main` branch so changes staged in another worktree are immediately visible.
