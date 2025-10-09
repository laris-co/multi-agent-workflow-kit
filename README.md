# Multi-Agent Worktree Kit

> **⚠️ Proof of Concept - Early Development Stage**
>
> This project is currently a **proof of concept** exploring multi-agent workflows with AI coding assistants. It's actively evolving and may have rough edges. We're experimenting with patterns for coordinating multiple AI agents on the same codebase.
>
> **We welcome your help!** PRs, issues, and discussions are highly encouraged. If you have ideas for improving agent coordination, workflow patterns, or have encountered interesting use cases, please share them.
>
> [![GitHub issues](https://img.shields.io/github/issues/laris-co/multi-agent-workflow-kit)](https://github.com/laris-co/multi-agent-workflow-kit/issues)
> [![GitHub pull requests](https://img.shields.io/github/issues-pr/laris-co/multi-agent-workflow-kit)](https://github.com/laris-co/multi-agent-workflow-kit/pulls)
> [![GitHub discussions](https://img.shields.io/github/discussions/laris-co/multi-agent-workflow-kit)](https://github.com/laris-co/multi-agent-workflow-kit/discussions)

**Orchestrate parallel AI agents in isolated git worktrees with shared tmux visibility.**

This toolkit solves the coordination problem of running multiple AI coding agents simultaneously: each agent gets its own git branch and workspace (via `git worktree`), while you supervise all of them in a single tmux session with curated layouts.

## Why Use This?

**The Problem**: Running multiple AI agents on the same codebase creates chaos—they conflict on branches, overwrite each other's changes, and you lose track of who's doing what.

**The Solution**: This kit provides:
- **Isolation**: Each agent works in its own worktree (separate directory + branch)
- **Visibility**: All agents visible in one tmux session with split-screen layouts
- **Consistency**: Shared scripts and conventions prevent common mistakes
- **Portability**: Drop into any repo or use as a template

## Quick Start

```bash
# Bootstrap everything in one command (installs toolkit, creates worktrees, launches tmux)
# Using latest stable release:
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main \
  multi-agent-kit init --prefix demo

# Or using alpha release (v0.2.0-alpha):
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@v0.2.0-alpha \
  multi-agent-kit init --prefix demo

# Configure your agents
$EDITOR .agents/agents.yaml

# Re-run setup to provision any new agents
maw install
```

**What you get:**
- `.agents/` directory with scripts and configuration
- `.envrc` with `maw` helper commands
- `agents/` directory with worktrees (gitignored)
- Active tmux session with all agents ready

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| `git` | ≥ 2.5 | Worktree support |
| `tmux` | ≥ 3.2 | Terminal multiplexing |
| `yq` | latest | YAML parsing for agents.yaml |
| `direnv` | latest | *Optional:* Auto-load env per worktree |
| `gh` | latest | *Optional:* GitHub CLI for convenience |

> The setup script auto-installs TPM (Tmux Plugin Manager) if missing.

## Core Concepts

### Git Worktrees
Each agent operates in a **worktree**—a separate directory linked to a unique branch. Changes in one worktree don't affect others until you explicitly merge.

```
repo/                  ← main worktree (branch: main)
agents/
  ├── 1/              ← worktree (branch: agents/1)
  ├── 2/              ← worktree (branch: agents/2)
  └── 3/              ← worktree (branch: agents/3)
```

### Tmux Layouts
Pre-configured **profiles** organize agent panes:

**Profile 0** (default): Three horizontal panes stacked
```
┌──────────────────────────────┐
│         Agent 1 (top)        │
├──────────────────────────────┤
│       Agent 2 (middle)       │
├──────────────────────────────┤
│        Root (bottom)         │
└──────────────────────────────┘
```

**Profile 1**: Left column + stacked right
```
┌──────────┬───────────────────┐
│          │     Agent 2       │
│ Agent 1  ├───────────────────┤
│ (left)   │     Agent 3       │
│          ├───────────────────┤
│          │   Root (main)     │
└──────────┴───────────────────┘
```

See `.agents/profiles/` for all 6 layout options.

### Agent Configuration
Edit `.agents/agents.yaml` to define agents:

```yaml
agents:
  1:
    branch: agents/1
    worktree_path: agents/1
    model: sonnet
    description: "Backend API development"

  2:
    branch: agents/2
    worktree_path: agents/2
    model: opus
    description: "Frontend React components"
```

## Installation & Setup

### Option 1: One-Shot Bootstrap (Recommended)

```bash
# Clone or navigate to your repo
cd your-project

# Run init with custom prefix
# Using main (stable):
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main \
  multi-agent-kit init --prefix sprint

# Or using v0.2.0-alpha (latest features):
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@v0.2.0-alpha \
  multi-agent-kit init --prefix sprint

# This will:
# - Copy toolkit assets (.agents/, .envrc, etc.)
# - Create worktrees from agents.yaml
# - Launch tmux session in background
# - Show you how to attach
```

**Init Options:**
- `--prefix <name>`: Session name becomes `ai-<repo>-<name>`
- `--skip-setup`: Only launch tmux (skip worktree creation)
- `--setup-only`: Only create worktrees (don't launch tmux)
- `--force-assets`: Overwrite existing toolkit files

**Attaching to Session:**
```bash
# After init, attach with:
tmux attach-session -t ai-<repo-name>
# Or use the helper:
maw attach
```

### Option 2: Manual Installation

```bash
# 1. Install toolkit assets
maw install
# or: .agents/scripts/setup.sh

# 2. Edit agent configuration
$EDITOR .agents/agents.yaml

# 3. Create worktrees
maw install  # re-run to sync changes

# 4. Launch tmux session
maw start profile0
# or: .agents/scripts/start-agents.sh profile0
```

### Enable direnv (Recommended)

```bash
# In main repo
direnv allow

# In each agent worktree
cd agents/1 && direnv allow
cd agents/2 && direnv allow
```

This activates the `maw` command wrapper and sets `CODEX_HOME` for shared state.

## Daily Workflow

### Starting & Stopping

```bash
# Start session with profile
maw start profile1

# Attach to running session
maw attach

# Kill session
maw kill
```

### Working with Agents

```bash
# Navigate to agent worktree
cd agents/1

# Check agent's branch
git branch --show-current  # → agents/1

# Make changes, commit
git add .
git commit -m "Add user authentication"

# Sync with main
maw sync  # merges main into current agent branch
```

### Syncing Worktrees

The `maw sync` command (or `/maw.sync` slash command in Claude) intelligently syncs:
- **On main branch**: Runs `git pull --ff-only origin main`
- **On agents/* branch**: Runs `git merge main` (fast-forward from local main)

```bash
# From main worktree
cd /path/to/main
maw sync  # pulls from origin

# From agent worktree
cd agents/1
maw sync  # merges local main
```

### Broadcasting Commands

```bash
# Send command to all agent panes
maw send "git status"
maw send "git pull"

# Or use the script directly
.agents/scripts/send-commands.sh "npm test"
```

### Managing Agents

```bash
# List current agents
maw agents list

# Create new agent
maw agents create 4 -m claude-opus

# Remove agent worktree
maw remove 3
```

## Configuration

### Agent Registry: `agents.yaml`

```yaml
agents:
  1:
    branch: agents/1                # Git branch name
    worktree_path: agents/1         # Directory under agents/
    model: claude-sonnet-4          # Model identifier (informational)
    description: "Core backend"     # Purpose (optional)
```

After editing, run `maw install` to sync worktrees.

### Tmux Profiles

Profiles live in `.agents/profiles/profileN.sh`:

| Profile | Layout | Best For |
|---------|--------|----------|
| `profile0` | Top + split bottom | 2-3 agents, one dominant |
| `profile1` | Left column + stacked right | Primary/secondary split |
| `profile2` | Top row + full-width bottom | Pair programming style |
| `profile3` | Single full-width top | Focus mode |
| `profile4` | Three-pane | Small team |
| `profile5` | Six-pane dashboard | Full visibility |

Customize by editing the profile files—adjust pane sizes, commands, or layouts.

### Session Naming

Control session names via `--prefix` or `SESSION_PREFIX`:

```bash
# Default: ai-<repo-name>
maw start profile0

# Custom: ai-<repo-name>-sprint
maw start profile0 --prefix sprint

# Change base prefix globally
export SESSION_PREFIX=research
maw start profile0  # → research-<repo-name>
```

## Repository Layout

```
.agents/                     # Toolkit directory (committed)
├── agents.yaml              # Agent registry
├── scripts/
│   ├── setup.sh             # Bootstrap worktrees + tmux plugins
│   ├── start-agents.sh      # Launch tmux session
│   ├── attach.sh            # Attach to session
│   ├── agents.sh            # Manage worktrees
│   ├── send-commands.sh     # Broadcast to panes
│   ├── kill-all.sh          # Terminate sessions
│   ├── remove.sh            # Delete worktrees
│   └── uninstall.sh         # Remove toolkit assets
├── profiles/                # Tmux layouts (profile0-5)
└── config/
    └── tmux.conf            # Tmux configuration with plugins

agents/                      # Agent worktrees (gitignored)
├── .gitignore               # Ignores all contents
├── 1/                       # Worktree for agent 1
├── 2/                       # Worktree for agent 2
└── 3/                       # Worktree for agent 3

.envrc                       # Direnv config (maw helpers, CODEX_HOME)
.codex/                      # Codex CLI workspace (shared across worktrees)
├── .gitignore               # Excludes runtime state
├── README.md                # Workspace documentation
└── prompts/                 # Shared prompt templates

.gitignore                   # Excludes agents/, local files, etc.
AGENTS.md                    # Conventions for human+AI collaboration
docs/                        # Architecture, operations, testing guides
```

## `maw` Command Reference

The direnv hook provides a unified `maw` wrapper:

```bash
maw install          # Run setup.sh (provision worktrees)
maw start <profile>  # Launch tmux session
maw attach           # Attach to running session
maw agents <cmd>     # Manage worktrees (list, create, remove)
maw send "<cmd>"     # Broadcast command to all panes
maw hey <agent> <msg> # Send message to specific agent
maw direnv           # Run 'direnv allow' in repo root and all agent worktrees
maw catlab           # Download CLAUDE.md guidelines from catlab gist
maw version          # Show toolkit version information
maw kill             # Terminate session
maw remove <agent>   # Delete agent worktree
maw uninstall        # Remove toolkit from repo
maw warp <target>    # Navigate to agent worktree or root
```

**Examples:**
```bash
# Start with custom prefix
maw start profile1 --prefix hackathon

# Navigate to agent worktree
maw warp 2

# Send message to specific agent
maw hey 1 "analyse this codebase"
maw hey 2 "create a plan for feature X"
maw hey root "git status"

# Configure direnv in all worktrees (run before starting tmux)
maw direnv

# Download CLAUDE.md guidelines
maw catlab
maw catlab --force  # Overwrite existing file

# Return to main
maw warp root

# Uninstall (dry run first)
maw uninstall --dry-run
maw uninstall
```

## Claude Slash Commands

When working in Claude Code, use these custom commands:

### `/maw.sync`
Sync current worktree with main branch (context-aware).

### `/maw.hey`
Send a message to a specific agent in the tmux session.

**Examples:**
```bash
/maw.hey 1 analyse this repository structure
/maw.hey 2 create a plan for the auth feature
/maw.hey root git status
/maw.hey all git pull  # broadcast to all agents
```

**Special targets:**
- `root` - Main worktree pane
- `all` - Broadcast to all agent panes
- Agent names: `1`, `2`, `backend-api`, etc.

### `/maw.codex` (legacy)
Send prompt to agent in pane 1. **Note:** Use `/maw.hey 1 <message>` for more flexibility.

## Advanced Usage

### Using as a Template

```bash
# Create new project from template
gh repo create my-project --template laris-co/multi-agent-workflow-kit --private --clone
cd my-project
maw install
```

### Adding as a Submodule

```bash
git submodule add https://github.com/laris-co/multi-agent-workflow-kit.git .agents-toolkit
cp .agents-toolkit/.agents .
cp .agents-toolkit/.envrc .
direnv allow
```

### Custom Profiles

Create `.agents/profiles/custom.sh`:

```bash
#!/bin/bash
PROFILE_NAME="custom"

layout_custom() {
    local session=$1
    local window=$2

    # Your custom tmux layout commands here
    tmux split-window -v -t "$session:$window"
    tmux select-layout -t "$session:$window" even-horizontal
}
```

Then: `maw start custom`

### Integration with CI/CD

Ensure agent branches fast-forward to main before merging:

```yaml
# .github/workflows/check-merge.yml
name: Check Agent Merges
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Verify fast-forward merge
        run: |
          git merge-base --is-ancestor ${{ github.event.pull_request.base.sha }} ${{ github.sha }}
```

## Troubleshooting

### Session Already Exists

```bash
# List sessions
tmux list-sessions

# Kill specific session
maw kill --prefix <suffix>

# Or kill all matching sessions
tmux kill-session -t ai-repo-name
```

### Worktree Creation Fails

```bash
# Check for existing worktrees
git worktree list

# Remove stale worktree
git worktree remove agents/1 --force

# Prune stale references
git worktree prune

# Re-run setup
maw install
```

### Direnv Not Loading

```bash
# Allow in main repo
direnv allow

# Allow in each agent worktree
cd agents/1 && direnv allow
cd agents/2 && direnv allow

# Check if direnv is working
direnv status
```

### `maw` Command Not Found

```bash
# Ensure direnv is allowed
direnv allow

# Manual load (bash)
source .envrc

# Manual load (zsh)
. .envrc

# Or use scripts directly
.agents/scripts/start-agents.sh profile0
```

### Merge Conflicts in Agent Worktrees

```bash
cd agents/1

# Sync with main
git fetch origin main:main  # update local main
git merge main              # merge into agent branch

# Resolve conflicts
git status
# ... resolve files ...
git add .
git commit
```

### TPM Plugins Not Loading

```bash
# Install TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Inside tmux, press: prefix + I (capital i)
# Default prefix is Ctrl+a (configured in tmux.conf)
```

## Documentation

Deep dives and operational guides:

- **[Architecture](docs/architecture.md)**: Design principles, strengths, risks, integrations
- **[Operations Checklist](docs/operations-checklist.md)**: Launch/teardown procedures
- **[Testing Guide](docs/testing.md)**: Smoke tests before releases
- **[Branching Strategy](docs/branching-strategy.md)**: RRR workflow (Route, Release, Repair)
- **[AGENTS.md](AGENTS.md)**: Conventions for human+AI collaboration

## Contributing

Contributions welcome! Open an issue or PR for:
- New tmux profiles
- Improved agent coordination scripts
- CI/CD integration examples
- Bug fixes or documentation improvements

**Before submitting:**
1. Test with `docs/testing.md` smoke tests
2. Update relevant documentation
3. Follow existing code style

## License

[Add your license here]

---

**Pro Tips:**
- Use `maw warp` to quickly jump between worktrees
- Configure agent-specific `.envrc` files for custom env vars
- Leverage `maw send` for coordinated git operations across agents
- Create custom slash commands in `.claude/commands/` for your workflow
- Export conversation logs from `.codex/` to review agent decision-making

<img width="2202" height="1132" alt="Multi-agent tmux session with split panes" src="https://github.com/user-attachments/assets/6c422b36-fdcf-46db-937d-f6ec8e995ec9" />
