# Operations Checklist

Repeat these steps when launching or retiring a multi-agent tmux session.

## Before Launch
- [ ] Update `.agents/agents.yaml` with the current roster and branches.
- [ ] Ensure the repo has at least one commit (`git log --oneline` or let `uvx multi-agent-kit init` create an empty `Initial commit`).
- [ ] Confirm `.gitignore` contains `.agents/` (added automatically during init).
- [ ] Run `.agents/scripts/agents.sh list` to confirm every branch/worktree pair looks correct.
- [ ] `git status` from the repo root to verify a clean state before agents start working.
- [ ] Verify dependencies: `tmux -V`, `yq --version`, `direnv --version` (if used).
- [ ] Export `SESSION_PREFIX` if you need a custom namespace (e.g., `export SESSION_PREFIX=research`).
- [ ] Communicate session name and profile choice to collaborators.

## Launch Sequence
1. `maw install` or `.agents/scripts/setup.sh` (first run or whenever `agents.yaml` changes).
2. `maw start profile0 --prefix <suffix?>` or `.agents/scripts/start-agents.sh profile0 --prefix <suffix?>` (swap the profile as needed).
3. `maw attach` to connect to the session (or skip with `--detach` flag in step 2).
4. In each pane, run the agent-specific bootstrap (install deps, load env vars, etc.).
5. Capture a quick note or screenshot of the layout for later retrospectives (optional).

## During Operation
- [ ] Use `maw send "<command>"` or `.agents/scripts/send-commands.sh` to broadcast `git status`, `ls`, or health checks.
- [ ] Keep panes scoped to their worktree roots; avoid crossing into other repos.
- [ ] Document major decisions in `reports/`, `research/`, or `retrospectives/` directories.
- [ ] Watch for stalled prompts/errors—tmux makes it easy to spot blocked agents.
- [ ] Commit early and often; coordinate pushes through review/automation.

## Wrap-Up
- [ ] `maw kill --prefix <suffix?>` or `.agents/scripts/kill-all.sh --prefix <suffix?>` to close active sessions.
- [ ] `git worktree prune` and remove unused agent definitions from `agents.yaml`.
- [ ] Run `maw remove <agent> --dry-run` (or `.agents/scripts/remove.sh --dry-run`) to tear down agent worktrees as needed.
- [ ] Run `maw uninstall --dry-run` before removing toolkit assets, then `maw uninstall` if the repo no longer needs them.
- [ ] Archive outputs (reports, notes) where the next agents can find them.
- [ ] Run a retrospective capturing wins, gaps, and follow-up actions.
- [ ] Tag this toolkit snapshot or branch it if you plan to reuse the configuration elsewhere.
