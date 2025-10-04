# Operations Checklist

Repeat these steps when launching or retiring a multi-agent tmux session.

## Before Launch
- [ ] Update `.agents/agents.yaml` with the current roster and branches.
- [ ] Run `.agents/agents.sh list` to confirm every branch/worktree pair looks correct.
- [ ] `git status` from the repo root to verify a clean state before agents start working.
- [ ] Verify dependencies: `tmux -V`, `yq --version`, `direnv --version` (if used).
- [ ] Export `SESSION_PREFIX` if you need a custom namespace (e.g., `export SESSION_PREFIX=research`).
- [ ] Communicate session name and profile choice to collaborators.

## Launch Sequence
1. `.agents/setup.sh` (first run or whenever `agents.yaml` changes).
2. `.agents/start-agents.sh profile1 --prefix <suffix?>`.
3. In each pane, run the agent-specific bootstrap (install deps, load env vars, etc.).
4. Capture a quick note or screenshot of the layout for later retrospectives (optional).

## During Operation
- [ ] Use `.agents/send-commands.sh` to broadcast `git status`, `ls`, or health checks.
- [ ] Keep panes scoped to their worktree roots; avoid crossing into other repos.
- [ ] Document major decisions in `reports/`, `research/`, or `retrospectives/` directories.
- [ ] Watch for stalled prompts/errors—tmux makes it easy to spot blocked agents.
- [ ] Commit early and often; coordinate pushes through review/automation.

## Wrap-Up
- [ ] `.agents/kill-all.sh --prefix <suffix?>` to close active sessions.
- [ ] `git worktree prune` and remove unused agent definitions from `agents.yaml`.
- [ ] Archive outputs (reports, notes) where the next agents can find them.
- [ ] Run a retrospective capturing wins, gaps, and follow-up actions.
- [ ] Tag this toolkit snapshot or branch it if you plan to reuse the configuration elsewhere.
