# Architecture Overview

The multi-agent workflow combines git worktrees with tmux so that each agent receives:
- an isolated working directory tied to a dedicated branch, and
- a tmux pane anchored in that directory for real-time supervision.

```
Main repository (.git)
    ├── source files
    └── agents/
          ├── 1-agent/ (worktree → branch agents/1-agent)
          ├── 2-agent/ (worktree → branch agents/2-agent)
          └── 3-agent/ (worktree → branch agents/3-agent)

.tmux session
    ├── pane: agent 1 shell (cd agents/1-agent)
    ├── pane: agent 2 shell (cd agents/2-agent)
    └── pane: shared tools / orchestration
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Worktree registry | `.agents/agents.yaml` | Maps agent names to branches and worktree paths |
| Worktree manager | `.agents/scripts/agents.sh` | Creates/list/removes worktrees using the registry |
| Bootstrapper | `.agents/scripts/setup.sh` | Installs TPM, provisions worktrees from registry |
| Tmux launcher | `.agents/scripts/start-agents.sh` | Spins up layouts, naming sessions consistently |
| Layout profiles | `.agents/profiles/*.sh` | Parameterized pane geometries |
| Broadcast helper | `.agents/scripts/send-commands.sh` | Sends commands to each pane |
| Cleanup utility | `.agents/scripts/kill-all.sh` | Kills tmux sessions with shared prefix |
| Shared config | `.agents/config/tmux.conf` | Mouse support, theming, plugin config |

## Workflow
1. **Registry first** – define the agents, branches, and paths.
2. **Provision** – `scripts/setup.sh` creates branches/worktrees and ensures tmux plugins.
3. **Launch** – `scripts/start-agents.sh` reads the registry, builds a pane layout, and names the session `ai-<repo>-<suffix?>`.
4. **Operate** – agents work in their panes; supervisors monitor output, broadcast commands, or open additional panes.
5. **Tear down** – `scripts/kill-all.sh` or `git worktree remove` resets the environment when the effort completes.

## Strengths
- **Isolation**: each agent has a branch + working directory with zero branch switching.
- **Observability**: tmux panes expose command history for every agent in one screen.
- **Consistency**: enforced directory structure and naming reduce coordination mistakes.
- **Speed**: new agents can be provisioned quickly via `scripts/agents.sh create`.

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Pane crash or accidental exit | Add tmux-resurrect / continuum or extend the toolkit with a watchdog script. |
| Disk usage from many worktrees | Prune inactive branches (`git worktree prune`) and archive old agents. |
| Conflicting edits across agents | Pair the toolkit with a constitution that assigns ownership and requires communication. |
| Secrets leaking into worktrees | Keep credentials in env vars or secret managers; never commit generated configs with secrets. |
| Session naming collisions | Use `--prefix` or `SESSION_PREFIX` to namespace sessions per team or initiative. |

## Integration Tips
- Store shared docs (constitutions, safety rules, checklists) alongside the toolkit so every agent inherits them automatically.
- Combine with automated planners or task generators that output into dedicated panes to keep reasoning visible.
- For larger teams, consider a dashboard that reads `tmux list-clients` / `git status` across panes to surface stalled agents.

## Next Improvements
- Script to bootstrap new repositories (copy toolkit assets + `.agents/config/tmux.conf`).
- Optional CI workflow verifying agent branches fast-forward to `main` before merging.
- Health monitor service that alerts when an agent pane exits unexpectedly.
