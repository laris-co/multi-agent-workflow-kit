# Agent Sync Workflow Guide

## Agent Identity Awareness

### Know Who You Are

Every agent should start by identifying their context:

```bash
# Check your current path
pwd

# Check your current branch
git branch --show-current

# Check your worktree location
git worktree list
```

**Agent Identity Pattern:**
- **Main Agent** (root): Works in main worktree, on `main` branch
- **Agent 1, 2, 3, etc**: Works in `agents/1`, `agents/2`, etc., on `agents/1`, `agents/2` branches

### Quick Identity Check

```bash
# Run this to see who you are:
echo "Path: $PWD"
echo "Branch: $(git branch --show-current)"
```

**Expected outputs:**
- Main agent: `Path: /path/to/repo` + `Branch: main`
- Agent 1: `Path: /path/to/repo/agents/1` + `Branch: agents/1`
- Agent 2: `Path: /path/to/repo/agents/2` + `Branch: agents/2`

---

## Sync Workflow

### Rule 1: Main Agent Syncs from Remote

**Main agent** (working in root directory on `main` branch):

```bash
# Step 1: Check you're on main
git branch --show-current  # Should show: main

# Step 2: Sync with remote
/maw.sync
# OR
maw sync

# This runs: git pull --ff-only origin main
```

**What happens:**
- Pulls latest changes from `origin/main`
- Fast-forward only (safe merge)
- Updates the local `main` branch

### Rule 2: Agent N Syncs from Local Main

**Agent 1, 2, 3, etc** (working in `agents/N` directory on `agents/N` branch):

```bash
# Step 1: Check you're on agent branch
git branch --show-current  # Should show: agents/1 (or agents/2, etc.)

# Step 2: Sync with local main
/maw.sync
# OR
maw sync

# This runs: git merge main
```

**What happens:**
- Merges the local `main` branch into your agent branch
- Gets all the latest changes that main agent pulled
- Your agent branch is now up to date

---

## Complete Sync Workflow (Multi-Agent Coordination)

### Scenario: Main agent pulled new changes, all agents need to sync

**Step 1: Main Agent Syncs (Root)**

```bash
# In main worktree (root)
pwd                        # /path/to/repo
git branch --show-current  # main

# Pull latest from remote
/maw.sync
# ✅ main is up to date with origin/main
```

**Step 2: Agent 1 Syncs**

```bash
# In agents/1 worktree
pwd                        # /path/to/repo/agents/1
git branch --show-current  # agents/1

# Merge local main
/maw.sync
# ✅ Agent branch 'agents/1' now includes the latest local main
```

**Step 3: Agent 2 Syncs**

```bash
# In agents/2 worktree
pwd                        # /path/to/repo/agents/2
git branch --show-current  # agents/2

# Merge local main
/maw.sync
# ✅ Agent branch 'agents/2' now includes the latest local main
```

**Step 4: Agent 3 Syncs**

```bash
# In agents/3 worktree
pwd                        # /path/to/repo/agents/3
git branch --show-current  # agents/3

# Merge local main
/maw.sync
# ✅ Agent branch 'agents/3' now includes the latest local main
```

---

## GitHub Flow: Branch, Push, PR

### For Agent Worktrees (agents/1, agents/2, etc.)

After making changes and syncing, follow GitHub flow:

#### Step 1: Verify Your Changes

```bash
# Check status
git status

# Review changes
git diff

# See commit history
git log --oneline -5
```

#### Step 2: Ensure Clean State

```bash
# Make sure all changes are committed
git status  # Should show "nothing to commit, working tree clean"

# If you have uncommitted changes:
git add .
git commit -m "Your commit message"
```

#### Step 3: Sync Before Push

```bash
# Always sync before pushing to avoid conflicts
/maw.sync

# This ensures you have latest main changes merged
```

#### Step 4: Push Your Branch

```bash
# Push your agent branch to remote
git push origin $(git branch --show-current)

# Or explicitly:
# For agent 1:
git push origin agents/1

# For agent 2:
git push origin agents/2
```

#### Step 5: Create Pull Request

```bash
# Using GitHub CLI
gh pr create --base main --head $(git branch --show-current) \
  --title "Your PR title" \
  --body "## Summary
- Change 1
- Change 2

## Testing
- [ ] Tested locally
- [ ] All tests pass
"

# OR: Open browser to create PR manually
gh pr create --web
```

#### Step 6: After PR is Merged

```bash
# Switch to main worktree (use main agent or root pane)
cd /path/to/repo  # Or: maw warp root

# Pull the merged changes
git pull origin main

# OR use sync
/maw.sync
```

Then all other agents can sync again to get the merged changes:

```bash
# In each agent worktree:
/maw.sync
```

---

## Common Workflows

### Workflow 1: Agent Implements Feature

**Agent 1 perspective:**

```bash
# 1. Know who you are
pwd                        # /path/to/repo/agents/1
git branch --show-current  # agents/1

# 2. Sync before starting
/maw.sync

# 3. Make changes
# ... code changes ...

# 4. Commit changes
git add .
git commit -m "feat: implement authentication"

# 5. Sync again (in case main changed)
/maw.sync

# 6. Push to remote
git push origin agents/1

# 7. Create PR
gh pr create --base main --head agents/1 \
  --title "feat: implement authentication" \
  --body "Implemented user authentication with JWT"
```

### Workflow 2: Main Agent Updates Dependencies

**Main agent perspective (root):**

```bash
# 1. Know who you are
pwd                        # /path/to/repo
git branch --show-current  # main

# 2. Pull latest
/maw.sync

# 3. Update dependencies
npm update  # or: pip install -U, etc.

# 4. Commit
git add package-lock.json  # or: requirements.txt, etc.
git commit -m "chore: update dependencies"

# 5. Push
git push origin main

# 6. Notify all agents to sync
# Use /maw.hey to tell agents:
/maw.hey all "sync with main - dependencies updated"
```

**Each agent then runs:**

```bash
/maw.sync
```

### Workflow 3: Parallel Feature Development

**Setup:**
- Agent 1: Working on auth feature (`agents/1`)
- Agent 2: Working on API endpoints (`agents/2`)
- Agent 3: Working on frontend (`agents/3`)

**Each agent independently:**

```bash
# Sync
/maw.sync

# Work
# ... make changes ...

# Commit
git add .
git commit -m "feat: <feature>"

# Sync again
/maw.sync

# Push
git push origin $(git branch --show-current)

# PR
gh pr create --base main --head $(git branch --show-current)
```

**After any PR merges:**

```bash
# Main agent pulls
cd /path/to/repo
/maw.sync

# All other agents sync
/maw.sync  # (from each agent worktree)
```

---

## Sync Command Reference

### `/maw.sync` Behavior

**On `main` branch:**
```bash
git pull --ff-only origin main
```
- Pulls from remote
- Fast-forward only (safe)
- Updates local main

**On `agents/*` branch:**
```bash
git merge main
```
- Merges local main into agent branch
- Gets latest main changes
- May create merge commit if needed

**On other branches:**
- Error: No sync performed
- Must be on `main` or `agents/*` branch

### Prerequisites

- **Clean working tree**: No uncommitted changes
- **On correct branch**: `main` or `agents/*`
- **Local main exists**: For agent syncs

---

## Troubleshooting

### "Working tree has uncommitted changes"

```bash
# Option 1: Commit them
git add .
git commit -m "WIP: work in progress"

# Option 2: Stash them
git stash

# Then sync
/maw.sync

# Option 3: Restore stash
git stash pop
```

### "Local main branch not found"

```bash
# Sync main worktree first
cd /path/to/repo  # Or: maw warp root
/maw.sync

# Then sync agent
cd agents/1  # Or: maw warp 1
/maw.sync
```

### Merge Conflicts During Sync

```bash
# After /maw.sync shows conflict
git status  # See conflicted files

# Resolve conflicts in editor
vim <conflicted-file>

# Mark as resolved
git add <conflicted-file>

# Complete merge
git commit

# Or abort
git merge --abort
```

### Not on main or agents/* branch

```bash
# Check current branch
git branch --show-current

# Switch to correct branch
git checkout main         # For main agent
git checkout agents/1     # For agent 1
```

---

## Best Practices

### 1. Always Know Your Identity

Start every session by checking:
- Your current path
- Your current branch

### 2. Sync Before Work

Before starting new work:
```bash
/maw.sync
```

### 3. Sync Before Push

Before pushing:
```bash
/maw.sync
git push origin $(git branch --show-current)
```

### 4. Main Agent Pulls, Agents Merge

- **Main agent**: Pulls from remote (`origin/main`)
- **Other agents**: Merge from local (`main`)

### 5. Commit Often

Small, focused commits are easier to sync and merge:
```bash
git add .
git commit -m "feat: small focused change"
```

### 6. Use Descriptive Branches

Agent branches follow convention:
- `agents/1` - Agent 1
- `agents/2` - Agent 2
- `agents/backend-api` - Backend API agent

### 7. Clean Working Tree

Keep working tree clean:
- Commit work in progress
- Or stash if needed
- Never sync with uncommitted changes

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│ AGENT IDENTITY                                              │
├─────────────────────────────────────────────────────────────┤
│ pwd                     → See current path                  │
│ git branch --show-current → See current branch             │
├─────────────────────────────────────────────────────────────┤
│ SYNC WORKFLOW                                               │
├─────────────────────────────────────────────────────────────┤
│ Main Agent:  /maw.sync  → git pull --ff-only origin main   │
│ Agent 1-N:   /maw.sync  → git merge main                   │
├─────────────────────────────────────────────────────────────┤
│ GITHUB FLOW                                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. /maw.sync            → Sync before work                  │
│ 2. <make changes>       → Code your feature                 │
│ 3. git add . && commit  → Commit changes                    │
│ 4. /maw.sync            → Sync before push                  │
│ 5. git push origin HEAD → Push to remote                    │
│ 6. gh pr create         → Create pull request               │
└─────────────────────────────────────────────────────────────┘
```
