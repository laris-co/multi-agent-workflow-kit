# Multi-Agent Workspace Toolkit

This directory ships with everything required to spin up dedicated git worktrees for each AI agent and attach them to a shared tmux session. Drop the folder into any repository (or use this project as a submodule) to get a standardized multi-agent environment.

## Prerequisites
- `git` with worktree support (2.5+)
- `tmux` 3.2+
- `yq` (YAML parsing for the setup script)
- Optional but recommended: `direnv`, TPM (Tmux Plugin Manager)

## Quick Start
```bash
# Clone the toolkit
gh repo clone Soul-Brews-Studio/multi-agent-workflow-kit
cd multi-agent-workflow-kit

# Optional: run the uvx bootstrap (setup + tmux launch)
uvx --from git+https://github.com/Soul-Brews-Studio/multi-agent-workflow-kit.git@main multi-agent-kit init

# Customize agent registry
cp .agents/agents.yaml .agents/agents.local.yaml   # optional snapshot
# Edit .agents/agents.yaml with your agent names / branches

# Create worktrees and install tmux plugins
.agents/setup.sh

# Launch tmux session (default layout = profile0)
.agents/start-agents.sh profile0

> **Profile0 default:** top pane spans the upper half; bottom row splits into left/right panes for the next two agents.
>
> ```
> ┌──────────────────────────────┐
> │            Pane0             │
> ├──────────────┬───────────────┤
> │    Pane1     │     Pane2     │
> └──────────────┴───────────────┘
> ```
> Tweak `BOTTOM_HEIGHT` / `BOTTOM_RIGHT_WIDTH` in `profiles/profile0.sh` to rebalance the grid.
```

## Common Commands
```bash
.agents/agents.sh create 1-agent         # create specific agent worktree
.agents/agents.sh list                   # list registered agents + branches
.agents/start-agents.sh profile2         # launch tmux with alternate layout
.agents/start-agents.sh profile0 --prefix work  # run a second session side-by-side
.agents/send-commands.sh --prefix work   # broadcast commands to panes in that session
.agents/kill-all.sh --prefix work        # cleanly stop all matching sessions
```

## `agents.yaml` Format
```yaml
agents:
  1-agent:
    branch: agents/1-agent
    worktree_path: agents/1-agent
    model: default
    description: Primary agent workspace
```
- `branch` will be created if it does not already exist.
- `worktree_path` must live under `agents/`.
- `model` and `description` are informational—use them to coordinate assignments.

## Layout Profiles
Profiles live under `.agents/profiles/` and can be customized or duplicated. Key layouts include:
- `profile0` – top pane with split bottom row (default)
- `profile1` – balanced 2×2 grid
- `profile2` – full-height left pane with three right-side stacks
- `profile3` – top pane covering full width, two panes below
- `profile4` – three-pane layout (left split into two)
- `profile5` – 6-pane dashboard (three rows × two columns)

To add new layouts, copy an existing profile and adjust the environment variables that control splits (see comments in each file).

## Session Naming Convention
- Default session name: `ai-<repo-name>`
- Provide `--prefix <prefix>` to run multiple sessions side-by-side: `<prefix>-ai-<repo-name>`
- Environment variable override: set `SESSION_PREFIX=research` before running the scripts to change the base prefix (e.g., `research-<repo-name>`).

## Cleanup & Maintenance
```bash
.agents/kill-all.sh                 # interactive kill for active sessions
.agents/agents.sh remove 1-agent    # tear down a single worktree
.git worktree prune                  # remove stale / deleted worktrees
```

## Project Structure
```
.agents/                   # Toolkit directory (committed to git)
├── agents.yaml            # registry (edit this first)
├── agents.sh              # create/list/remove worktrees
├── setup.sh               # bootstrap: tmux plugins + agents
├── start-agents.sh        # launch tmux session using profiles
├── send-commands.sh       # broadcast commands to panes
├── kill-all.sh            # stop sessions matching prefix
├── profiles/              # tmux layout definitions
│   ├── profile0.sh
│   ├── profile1.sh
│   ├── profile2.sh
│   ├── profile3.sh
│   ├── profile4.sh
│   └── profile5.sh

agents/                    # Worktrees directory (gitignored)
├── .gitignore             # Ignores everything
├── 1-agent/               # Agent 1 worktree
├── 2-agent/               # Agent 2 worktree
└── 3-agent/               # Agent 3 worktree
```

## Tips
- Install TPM (`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`) once per machine. `setup.sh` automates this when possible.
- Keep agent branches up to date with `git fetch` in each worktree; tmux panes show live output so conflicts are easy to spot.
- Pair the toolkit with a shared constitution or workflow doc so every agent follows the same safety rules.
