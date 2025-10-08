# Testing Checklist

Follow this routine before shipping changes to the Multi-Agent Workflow Kit or
cutting a release branch. The goal is to confirm that the packaged assets work
when installed through `uvx` and that the environment hooks behave as expected.

## 1. Build From Source
```bash
# From the repository root
uvx --from . multi-agent-kit --help
```
> Confirms the project builds locally and the entry point resolves.

## 2. Smoke-Test `uvx multi-agent-kit init`
```bash
tmpdir=$(mktemp -d)
pushd "$tmpdir"
git init -q
uvx --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@BRANCH multi-agent-kit init
```
- Replace `BRANCH` with the branch under test (e.g., `main`, `release/v0.1.9`).
- Expect a prompt to commit the installed assets; decline for the smoke test.
- Expect a prompt to create an empty `Initial commit` if the repository is brand
  new. The installer should exit gracefully after printing instructions.

Verify the following filesystem state inside the temporary repo:
- `.envrc` exists and contains the helper sourcing block.
- `.codex/README.md` exists and `CODEX_HOME` is set to that directory when
  `direnv` loads.
- `.codex/prompts/README.md` exists; generated files (`maw-*.md`, `analysis.md`,
  `handoff.md`) are excluded by `.codex/.gitignore`.
- `.claude/commands/` contains `maw-agents-create.md`, `maw-codex.md`, `maw-codex.sh`,
  `maw-sync.md`, and `maw-sync.sh`.
- `.gitignore` includes the injected Multi-Agent Kit section (excluding `agents/`,
  `.claude/commands/maw-*`, etc.) and preserves existing Claude overrides.

Cleanup the temporary directory afterwards:
```bash
popd
rm -rf "$tmpdir"
```

## 3. Direnv Reload & Command Availability
If you changed `.envrc` logic, run:
```bash
direnv reload
```
or re-enter the repo to confirm variables/aliases update without errors.

Verify `maw` command is available:
```bash
direnv allow
maw --help  # Should show usage with all subcommands
```

Test key commands:
```bash
maw agents list  # Should list configured agents from agents.yaml
type maw-start   # Should resolve to alias
type maw-attach  # Should resolve to alias
```

## 4. Regression Tests
- Run targeted scripts if your change touched them (e.g.,
  `.agents/scripts/setup.sh --help`).
- For Python logic, add or run unit tests under `tests/` when available.
- Test worktree creation: `maw install` (requires at least one commit).
- Test session lifecycle: `maw start profile0 --detach`, `maw attach`, `maw kill`.

Document the outcome of these steps in your PR description so reviewers know the
kit installs cleanly from the branch you're proposing.
