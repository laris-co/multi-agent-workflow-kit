---
description: Sync the current worktree with main-aware rules
argument-hint: (no args)
allowed-tools:
  - Bash(.claude/commands/maw.sync.sh:*)
---

## Agent Identity Awareness

**Before running this command, know who you are:**

```bash
# Check your identity
pwd                        # Your current path
git branch --show-current  # Your current branch
```

**Expected identity:**
- **Main Agent** (root): `path/to/repo` + branch `main`
- **Agent 1**: `path/to/repo/agents/1` + branch `agents/1`
- **Agent 2**: `path/to/repo/agents/2` + branch `agents/2`
- **Agent N**: `path/to/repo/agents/N` + branch `agents/N`

## Sync Workflow

### If You Are Main Agent (root worktree, on `main` branch):

**Your job:** Pull latest changes from remote repository

```bash
/maw.sync
# Runs: git pull --ff-only origin main
```

**What happens:**
- Pulls from `origin/main` (remote)
- Updates local `main` branch
- Fast-forward only (safe merge)

### If You Are Agent 1, 2, 3, etc. (in `agents/*` worktree):

**Your job:** Merge latest changes from local `main` branch

```bash
/maw.sync
# Runs: git merge main
```

**What happens:**
- Merges local `main` into your agent branch
- Gets all changes that main agent pulled
- Keeps your work on top of latest main

## Complete Multi-Agent Sync Flow

**Step 1: Main Agent syncs first**
```bash
# In root worktree (main branch)
/maw.sync
# ✅ main is up to date with origin/main
```

**Step 2: All other agents sync**
```bash
# In each agent worktree (agents/* branch)
/maw.sync
# ✅ Agent branch now includes latest local main
```

## GitHub Flow Integration

After syncing and making changes:

**1. Sync before work:**
```bash
/maw.sync
```

**2. Make changes and commit:**
```bash
git add .
git commit -m "feat: your changes"
```

**3. Sync before push:**
```bash
/maw.sync
```

**4. Push your branch:**
```bash
git push origin $(git branch --show-current)
```

**5. Create PR:**
```bash
gh pr create --base main --head $(git branch --show-current) \
  --title "Your PR title" \
  --body "Description"
```

**6. After PR merges, main agent pulls:**
```bash
# In root worktree
/maw.sync
```

**7. All agents sync again:**
```bash
# In each agent worktree
/maw.sync
```

## Shell Template

```bash
.claude/commands/maw.sync.sh "$@"
```

## Prerequisites

- Clean working tree (no uncommitted changes)
- On `main` or `agents/*` branch
- For agent sync: local `main` must exist

## Troubleshooting

**"Working tree has uncommitted changes"**
```bash
git add . && git commit -m "WIP"
# Or: git stash
```

**"Local main branch not found"**
```bash
# Sync main worktree first
cd /path/to/repo && /maw.sync
# Then sync agent
cd agents/1 && /maw.sync
```

## Quick Reference

```
┌─────────────────────────────────────────────────────┐
│ WHO AM I?                                           │
├─────────────────────────────────────────────────────┤
│ pwd                      → Check path               │
│ git branch --show-current → Check branch           │
├─────────────────────────────────────────────────────┤
│ SYNC RULES                                          │
├─────────────────────────────────────────────────────┤
│ main branch      → git pull --ff-only origin main   │
│ agents/* branch  → git merge main                   │
└─────────────────────────────────────────────────────┘
```
