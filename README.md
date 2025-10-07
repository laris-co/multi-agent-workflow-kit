# Multi-Agent Workflow Kit

Reusable toolkit for running parallel AI agents with git worktrees and tmux. It packages scripts, profiles, and conventions that give every agent its own branch while keeping supervision in one tmux session.

## Highlights
- **Isolation**: dedicated worktrees (`git worktree`) let each agent commit without branch juggling.
- **Visibility**: curated tmux layouts keep every shell in sight for fast coordination.
- **Consistency**: shared scripts enforce naming, directory structure, and safe defaults.
- **Portability**: drop the toolkit into any repo or use this project as a template/submodule.

## Quick Start
```bash
# Clone and enter the toolkit
gh repo clone laris-co/multi-agent-workflow-kit
cd multi-agent-workflow-kit

# One-shot bootstrap (installs toolkit assets, setup, and tmux launch)
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main \
  multi-agent-kit init --prefix demo

# The init flow prompts you to commit the installed assets before worktrees are created.

# Configure your agents
$EDITOR .agents/agents.yaml

# Provision worktrees + install tmux plugins (manual alternative)
# Requires at least one commit in the repository. If none exist, the
# setup script exits early and prints these commands for you to run:
# git add .agents/ agents/ && git commit -m "Initial toolkit commit"
.agents/scripts/setup.sh

# Launch the session manually (profile0 = top with split bottom row, profile1 = left column + stacked right)
.agents/scripts/start-agents.sh profile0

> **Profile0 default:** top pane spans the upper half; bottom row splits into left/right panes.
>
> ```
> ┌──────────────────────────────┐
> │            Pane0             │ ← agent 1
> ├──────────────┬───────────────┤
> │    Pane1     │     Pane2     │
> │  agent 2     │  agent 3/root │
> └──────────────┴───────────────┘
> ```
> Adjust `BOTTOM_HEIGHT` or `BOTTOM_RIGHT_WIDTH` in `profile0.sh` to change proportions.

### uvx Entry Point Options
The `multi-agent-kit init` command accepts the same layout options as the shell scripts:

```bash
# Skip setup if agents are already provisioned
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main \
  multi-agent-kit init --skip-setup profile2

# Launch detached session with a custom prefix
uvx --no-cache --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main \
  multi-agent-kit init --prefix hackathon --detach
```

Use `--setup-only` to prepare worktrees without starting tmux. The first run copies toolkit assets and `.agents/config/tmux.conf` into the current repository; pass `--force-assets` to overwrite those files if you need to refresh them.

To uninstall the toolkit assets from a repo, run `maw-uninstall --dry-run` (or `.agents/scripts/uninstall.sh --dry-run`) to preview the changes and then `maw-uninstall` when you're ready. The script only deletes the bundled `.claude` command files, leaving any other Claude content untouched. Pass `--remove-agents` if you also want to delete the `agents/` worktree folder (after you've cleaned it up).

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
AGENTS.md                 # worktree/branch conventions for human + AI collaborators
.agents/                   # Toolkit directory (committed to git)
├── agents.yaml            # agent registry (edit me)
├── scripts/
│   ├── agents.sh          # create/list/remove worktrees
│   ├── setup.sh           # bootstrap tmux plugins + agents
│   ├── start-agents.sh    # tmux launcher with layout profiles
│   ├── send-commands.sh   # broadcast commands to panes
│   └── kill-all.sh        # kill sessions by prefix
├── profiles/              # tmux layout recipes
│   ├── profile0.sh        # top pane + bottom left/right split (default)
│   ├── profile1.sh        # 2×2 grid with left column dominant
│   ├── profile2.sh        # top row 2 agents + bottom full-width root
│   ├── profile3.sh        # top-full layout
│   ├── profile4.sh        # three-pane layout
│   └── profile5.sh        # six-pane dashboard

agents/                    # Agent worktrees (fully gitignored)
├── .gitignore             # Ignores all contents
├── 1-agent/               # Worktree for agent 1
├── 2-agent/               # Worktree for agent 2
└── 3-agent/               # Worktree for agent 3

.envrc                     # direnv hook adding script aliases and PATH entries; run `direnv allow` here and inside each agents/* worktree
.claude/                   # Claude workspace shared by tracked commands
├── commands/              # Custom slash commands for Claude
│   ├── maw-agents-create.md     # Agent creation command (/maw-agents-create)
│   ├── maw-codex.md            # Codex integration command (/maw-codex)
│   ├── maw-codex.sh            # Shell helper backing the codex command
│   ├── maw-sync.md             # Sync helper for main/agents worktrees (/maw-sync)
│   └── maw-sync.sh             # Shell helper implementing sync rules

.agents/config/tmux.conf   # curated tmux config with TPM + power theme
/.codex/                   # Codex CLI workspace; .envrc points CODEX_HOME here automatically
├── .gitignore             # Ignore runtime state but keep prompt templates tracked
├── README.md              # Explains how the Codex workspace is used
└── prompts/               # Shared Codex prompt templates
    ├── README.md
    ├── analysis.md
    └── handoff.md
docs/                      # deep dives and checklists
```

### Claude Slash Commands
- `/maw-sync` — syncs the active worktree: pulls `origin/main` when on `main`, or merges local `main` into `agents/*` worktrees.
- `/maw-codex` — sends a prompt to the Codex agent pane (requires running tmux session).

## Operating Model
1. Define each agent in `.agents/agents.yaml` (branch + worktree path pointing into `agents/`).
2. Run `.agents/scripts/setup.sh` after edits to sync worktrees and ensure dependencies.
3. Start the tmux session with `.agents/scripts/start-agents.sh <profile> [--prefix <suffix>]`.
4. Use `.agents/scripts/send-commands.sh` to broadcast helpful commands (`git status`, `ls`).
5. Stop active sessions via `.agents/scripts/kill-all.sh --prefix <suffix>` when done.

Session names follow `ai-<repo-name>` by default. Provide `--prefix sprint` to spawn `ai-<repo-name>-sprint`. You can also export `SESSION_PREFIX` to change the base prefix (e.g., `export SESSION_PREFIX=research`).

> Tip: Allow direnv (`direnv allow`) to expose a `maw` helper so you can run `maw install`, `maw start`, `maw remove`, and `maw uninstall` without remembering the underlying scripts. The legacy `maw-*` aliases remain available for muscle memory.

> _Brand new repo?_ The `init` command now offers to create an empty `Initial commit` if Git history is missing, or run `git commit --allow-empty -m "Initial commit"` yourself before provisioning agents.

> _Ignoring `.agents/`?_ The installer adds `.agents/` to `.gitignore` and skips auto-committing the toolkit; remove that entry and `git add -f .agents` if you prefer to track it.

## Documentation
- `docs/architecture.md` — architecture, strengths, risks, and integration ideas.
- `docs/operations-checklist.md` — launch/teardown guardrails for reliable runs.
- `docs/testing.md` — smoke-test routine before shipping updates or releases.
- `docs/branching-strategy.md` — RRR (Route, Release, Repair) cheat sheet for
  keeping work flowing through `development` before it reaches `main`.

## Extending the Kit
- Pair the toolkit with your governance/constitution doc so agents share common rules.
- Build CI checks that ensure agent branches fast-forward to `main` before merging.
- Add health monitors (tmux resurrect, notifications) to alert when panes exit unexpectedly.

Contributions welcome—open an issue/PR in this repo with enhancements that make multi-agent collaboration smoother.


<img width="2202" height="1132" alt="image" src="https://github.com/user-attachments/assets/6c422b36-fdcf-46db-937d-f6ec8e995ec9" />
