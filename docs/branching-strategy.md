# Branching Strategy: RRR Cheat Sheet

Keep production (`main`) squeaky clean by remembering three R's—**Route, Release,
Repair**—all of which orbit the `development` branch.

## Route (everyday feature work)
- Branch off `development`.
- Sync with `development` frequently.
- Return via pull request into `development` with checks + reviews.

## Release (promoting to production)
- Validate deploys from `development`.
- Open the release PR **from `development` to `main`** only when green.
- Tag the new production commit on `main` once merged.

## Repair (hotfixes without chaos)
- Start urgent fixes from `main` for fast turnaround.
- After deploying, merge the hotfix branch into `development` and rerun checks.
- Promote `development` back to `main` so staging catches up.

## Agent Branches (`agents/*`)

When using the Multi-Agent Workflow Kit, agent branches follow a parallel pattern:

**Agent Workflow:**
- Agent branches (e.g., `agents/1-agent`, `agents/2-agent`) live in worktrees under `agents/`
- Each agent syncs with `main` (or `development`) using `maw sync` to fast-forward merge
- Agent work merges into `main` (or `development`) via standard PR process
- Agent branches are long-lived per session but disposable between initiatives

**Integration Points:**
- If using RRR: agents sync with `development` and PR into `development`
- If direct to main: agents sync with `main` and PR into `main` (requires fast-forward merge)
- Use `/maw-sync` slash command or `maw sync` to keep agent worktrees current

**Best Practice:**
- Keep agent branches scoped to a single feature or task
- Merge agent work frequently to avoid drift
- Archive agent branches after completion: `maw remove <agent-name>`

## Guardrails
- Protect `main` and `development` from direct pushes.
- Disable force pushes on both branches so history is never rewritten.
- Enforce that all release PRs into `main` originate from `development`.
- For repos using agent workflows: configure branch protection to require linear history (no merge commits) if needed.
- Keep this RRR mnemonic in onboarding docs so nobody shortcuts the flow.

## Simplified Model (No Development Branch)

If your repository doesn't use a `development` branch:
- **Route**: Branch directly from `main`, PR back to `main`
- **Release**: Tag `main` when ready to deploy
- **Repair**: Hotfix from `main`, merge back to `main`
- **Agents**: Sync with `main` using `maw sync`, PR to `main` when complete

This model works well for smaller projects or when continuous deployment from `main` is acceptable.
