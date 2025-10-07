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

## Guardrails
- Protect `main` and `development` from direct pushes.
- Disable force pushes on both branches so history is never rewritten.
- Enforce that all release PRs into `main` originate from `development`.
- Keep this RRR mnemonic in onboarding docs so nobody shortcuts the flow.
