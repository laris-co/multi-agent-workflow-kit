# Multi-Agent Workflow Kit

Reusable toolkit for running parallel AI agents with git worktrees and tmux. It packages scripts, profiles, and conventions that give every agent its own branch while keeping supervision in one tmux session.

## Highlights
- **Isolation**: dedicated worktrees (`git worktree`) let each agent commit without branch juggling.
- **Visibility**: curated tmux layouts keep every shell in sight for fast coordination.
- **Consistency**: shared scripts enforce naming, directory structure, and safe defaults.
- **Portability**: drop the `.agents/` folder into any repo or use this project as a template/submodule.

## Quick Start
```bash
# Clone and enter the toolkit
gh repo clone laris-co/multi-agent-workflow-kit
cd multi-agent-workflow-kit

# Configure your agents
$EDITOR .agents/agents.yaml

# Provision worktrees + install tmux plugins
.agents/setup.sh

# Launch the session (profile1 = balanced grid)
.agents/start-agents.sh profile1
```

## Prerequisites
| Tool | Purpose |
|------|---------|
| `git` ≥ 2.5 | worktree support |
| `tmux` ≥ 3.2 | terminal multiplexer |
| `yq` | parses `agents.yaml` |
| `direnv` (optional) | auto-load repo env inside panes |
| `gh` (optional) | convenience for cloning / automation |

> The setup script installs TPM (Tmux Plugin Manager) under `~/.tmux/plugins/tpm` if it is missing.

## Repository Layout
```
.agents/
├── agents.yaml            # agent registry (edit me)
├── agents.sh              # create/list/remove worktrees
├── setup.sh               # bootstrap tmux plugins + agents
├── start-agents.sh        # tmux launcher with layout profiles
├── send-commands.sh       # broadcast commands to panes
├── kill-all.sh            # kill sessions by prefix
├── profiles/              # tmux layout recipes
│   ├── profile1.sh        # default 2×2 grid
│   ├── profile2.sh        # full-left layout
│   ├── profile3.sh        # top-full layout
│   ├── profile4.sh        # three-pane layout
│   └── profile5.sh        # six-pane dashboard
└── agents/                # populated worktrees (gitignored)

.tmux.conf                 # curated tmux config with TPM + power theme
docs/                      # deep dives and checklists
```

## Operating Model
1. Define each agent in `.agents/agents.yaml` (branch + worktree path).
2. Run `.agents/setup.sh` after edits to sync worktrees and ensure dependencies.
3. Start the tmux session with `.agents/start-agents.sh <profile> [--prefix <suffix>]`.
4. Use `.agents/send-commands.sh` to broadcast helpful commands (`git status`, `ls`).
5. Stop active sessions via `.agents/kill-all.sh --prefix <suffix>` when done.

Session names follow `ai-<repo-name>` by default. Provide `--prefix sprint` to spawn `ai-<repo-name>-sprint`. You can also export `SESSION_PREFIX` to change the base prefix (e.g., `export SESSION_PREFIX=research`).

## Documentation
- `docs/architecture.md` — architecture, strengths, risks, and integration ideas.
- `docs/operations-checklist.md` — launch/teardown guardrails for reliable runs.

## Extending the Kit
- Pair the toolkit with your governance/constitution doc so agents share common rules.
- Build CI checks that ensure agent branches fast-forward to `main` before merging.
- Add health monitors (tmux resurrect, notifications) to alert when panes exit unexpectedly.

Contributions welcome—open an issue/PR in this repo with enhancements that make multi-agent collaboration smoother.
