# Branching Strategy TL;DR

Keep production (`main`) pristine and route every change through the staging
branch (`development`). The bullets below capture the entire flow.

## Core Branches
- `main`: production-only, locked behind reviews + CI.
- `development`: staging/integration; only source for pull requests into `main`.

## Daily Work
1. Branch from `development` for features or fixes.
2. Rebase/merge from `development` often so releases stay smooth.
3. Open a pull request back into `development`; require checks + review.

## Release Rhythm
- Deploy and test from `development` until the build is stable.
- Cut a release PR **from `development` to `main`**; nothing else merges to
  `main`.
- Tag the commit on `main` after the release PR lands.

## Hotfixes (Still Flow Through `development`)
- Branch from `main` to ship the urgent fix.
- Once verified, merge that branch into `development` and run the same checks.
- Promote `development` back into `main` so production and staging match.

## Guardrails
- Protect both branches from direct pushes.
- Require release PRs into `main` to originate from `development`.
- Document this short flow in onboarding material so everyone follows it.
