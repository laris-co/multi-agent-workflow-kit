# Multi-Agent Worktree Kit

**Orchestrate parallel AI agents in isolated git worktrees with shared tmux visibility.**

Run multiple AI coding agents simultaneously without chaos. Each agent gets its own git branch and workspace (via `git worktree`), while you supervise all of them in a single tmux session.

[![GitHub issues](https://img.shields.io/github/issues/laris-co/multi-agent-worktree-kit)](https://github.com/laris-co/multi-agent-worktree-kit/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/laris-co/multi-agent-worktree-kit)](https://github.com/laris-co/multi-agent-worktree-kit/pulls)
[![GitHub discussions](https://img.shields.io/github/discussions/laris-co/multi-agent-worktree-kit)](https://github.com/laris-co/multi-agent-worktree-kit/discussions)

> **⚠️ Proof of Concept - Early Development Stage**
>
> This project is currently a **proof of concept** exploring multi-agent workflows with AI coding assistants. It's actively evolving and may have rough edges. We're experimenting with patterns for coordinating multiple AI agents on the same codebase.
>
> **We welcome your help!** PRs, issues, and discussions are highly encouraged. If you have ideas for improving agent coordination, workflow patterns, or have encountered interesting use cases, please share them.

## Quick Start

**Prerequisites**: `git` (≥2.5), `tmux` (≥3.2), `yq`, `uvx`

```bash
# Navigate to your project
cd your-project

# Bootstrap everything in one command
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-worktree-kit.git@main \
  multi-agent-kit init --prefix demo

# Activate the environment
source .envrc

# Attach to your multi-agent session
maw attach
```

**That's it!** You now have:
- 3 agent worktrees ready to use
- A tmux session with all agents visible
- `maw` commands available for managing agents

**Next steps**:
- Edit `.agents/agents.yaml` to configure your agents
- Run `maw install` to provision any new agents
- Use `maw hey <agent> <message>` to send tasks to agents

## How It Works

Each agent gets its own **git worktree** (separate directory + branch). You see all agents in one **tmux session** with split panes.

```
repo/                  ← main worktree (branch: main)
agents/
  ├── 1/              ← agent 1 (branch: agents/1)
  ├── 2/              ← agent 2 (branch: agents/2)
  └── 3/              ← agent 3 (branch: agents/3)
```

**Tmux Layout** (default profile):
```
┌──────────────────────────────┐
│         Agent 1 (top)        │
├──────────────────────────────┤
│       Agent 2 (middle)       │
├──────────────────────────────┤
│        Root (bottom)         │
└──────────────────────────────┘
```

## Essential Commands

```bash
# Start/stop
maw attach          # Attach to running session
maw kill            # Stop session

# Send tasks to agents
maw hey 1 "add user authentication"
maw hey 2 "write tests for auth"
maw send "git status"  # broadcast to all

# Focus and zoom
maw zoom 1          # Toggle zoom for agent 1
maw zoom root       # Toggle zoom for root pane

# Sync with main branch
maw sync            # smart sync (context-aware)

# Navigate between worktrees
maw warp 1          # jump to agent 1
maw warp root       # jump to main

# Manage agents
maw agents list     # show all agents
maw remove 3        # delete agent 3
```

## Configuration

Edit `.agents/agents.yaml` to configure your agents:

```yaml
agents:
  1:
    branch: agents/1
    worktree_path: agents/1
    model: claude-sonnet-4
    description: "Core backend"
```

After editing, run `maw install` to sync worktrees.

## Documentation

- **[Architecture](docs/architecture.md)**: Design principles and integration patterns
- **[Operations Checklist](docs/operations-checklist.md)**: Launch/teardown procedures
- **[Testing Guide](docs/testing.md)**: Smoke tests before releases
- **[Branching Strategy](docs/branching-strategy.md)**: RRR workflow (Route, Release, Repair)
- **[AGENTS.md](AGENTS.md)**: Conventions for human+AI collaboration

---

# Reference

## Full Command List

```bash
# Setup
maw install          # Provision worktrees from agents.yaml
maw direnv           # Enable direnv in all worktrees

# Session management
maw start <profile>  # Launch tmux session
maw attach           # Attach to running session
maw kill             # Terminate session

# Agent communication
maw hey <agent> <msg> # Send message to specific agent
maw send "<cmd>"     # Broadcast command to all panes
maw zoom <agent>     # Toggle zoom for agent pane

# Agent management
maw agents list      # List all agents
maw agents create N  # Create new agent
maw remove <agent>   # Delete agent worktree

# Navigation
maw warp <target>    # Navigate to worktree (agent number or 'root')

# Utilities
maw sync             # Smart git sync (context-aware)
maw catlab           # Download CLAUDE.md guidelines
maw version          # Show toolkit version
maw uninstall        # Remove toolkit from repo
```

## Claude Slash Commands

In Claude Code, use these commands:

- `/maw.sync` - Sync current worktree with main
- `/maw.hey <agent> <message>` - Send message to specific agent
- `/maw.zoom <agent>` - Toggle zoom for agent pane

## Tmux Profiles

6 pre-configured layouts available:

| Profile | Layout | Best For |
|---------|--------|----------|
| `profile0` | Top + split bottom | 2-3 agents, one dominant |
| `profile1` | Left column + stacked right | Primary/secondary split |
| `profile2` | Top row + full-width bottom | Pair programming style |
| `profile3` | Single full-width top | Focus mode |
| `profile4` | Three-pane | Small team |
| `profile5` | Six-pane dashboard | Full visibility |

Use: `maw start profile1`

## Advanced Topics

<details>
<summary><strong>Installation Options</strong></summary>

### Using Specific Version

```bash
# Use v0.2.0-alpha (latest features)
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-worktree-kit.git@v0.2.0-alpha \
  multi-agent-kit init --prefix demo
```

### Manual Installation

```bash
# 1. Install toolkit assets
maw install

# 2. Edit agent configuration
$EDITOR .agents/agents.yaml

# 3. Launch tmux session
maw start profile0
```

### Using as Template

```bash
gh repo create my-project --template laris-co/multi-agent-worktree-kit --private --clone
cd my-project
maw install
```

</details>

<details>
<summary><strong>Custom Tmux Profiles</strong></summary>

Create `.agents/profiles/custom.sh`:

```bash
#!/bin/bash
PROFILE_NAME="custom"

layout_custom() {
    local session=$1
    local window=$2

    tmux split-window -v -t "$session:$window"
    tmux select-layout -t "$session:$window" even-horizontal
}
```

Use: `maw start custom`

</details>

<details>
<summary><strong>Session Naming</strong></summary>

```bash
# Default: ai-<repo-name>
maw start profile0

# Custom: ai-<repo-name>-sprint
maw start profile0 --prefix sprint

# Change base prefix
export SESSION_PREFIX=research
maw start profile0  # → research-<repo-name>
```

</details>

## Troubleshooting

<details>
<summary><strong>Session Already Exists</strong></summary>

```bash
tmux list-sessions
maw kill --prefix <suffix>
```

</details>

<details>
<summary><strong>Worktree Creation Fails</strong></summary>

```bash
git worktree list
git worktree remove agents/1 --force
git worktree prune
maw install
```

</details>

<details>
<summary><strong>maw Command Not Found</strong></summary>

```bash
direnv allow
# Or manually: source .envrc
```

</details>

<details>
<summary><strong>Merge Conflicts</strong></summary>

```bash
cd agents/1
git fetch origin main:main
git merge main
# Resolve conflicts, then:
git add . && git commit
```

</details>

## Contributing

Contributions welcome! See [Testing Guide](docs/testing.md) for smoke tests.

---

<img width="2202" height="1132" alt="Multi-agent tmux session with split panes" src="https://github.com/user-attachments/assets/6c422b36-fdcf-46db-937d-f6ec8e995ec9" />
