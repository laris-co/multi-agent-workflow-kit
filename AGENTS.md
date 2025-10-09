# Multi-Agent Worktree Notes

This repository uses Git worktrees so every agent (human or automated) works in
its own directory and branch. The assignments are defined in
`.agents/agents.yaml`. Each entry creates:

- a branch named `agents/<agent-name>`
- a working directory under `agents/<agent-name>/`

Use `git worktree list` to inspect the current setup. Do **not** switch an agent
worktree back to `main`; only the repository root should operate on the `main`
branch.

Coordinate through normal GitHub pull requests: merge work from
`agents/<agent-name>` into `main` only after explicit review/approval.

**Scratch Space**
- Use the repository-level `.tmp/` directory for throwaway builds and test artifacts; it is pre-created and listed in `.gitignore`, so anything placed there stays out of version control.
- This repo already contains the toolkit assets under `.agents/` and `agents/`; do not edit or depend on those directories directly. Instead, spin up test installs inside `.tmp/` when you need to validate changes.

## UV/UVX Development Workflow

This project uses [UV](https://docs.astral.sh/uv/) for Python package management and execution. UV is configured via:
- `uv.toml` - UV configuration (cache, Python preferences)
- `.python-version` - Python version specification (3.12)
- `pyproject.toml` - Project metadata and UV tool settings

### Testing Local Changes

When testing local changes to the toolkit, use `uvx` with the local package:

```bash
# Test from repository root (use absolute path or .)
uvx --no-cache --from . multi-agent-kit init --force-assets

# Or with explicit path
uvx --no-cache --from /path/to/multi-agent-workflow-kit multi-agent-kit init --force-assets
```

### Common UV Commands

```bash
# Build the package
uv build

# Run with specific Python version
uvx --python 3.12 --from . multi-agent-kit init

# Install from Git (for end users)
uvx --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@main multi-agent-kit init

# Install from specific version/tag
uvx --from git+https://github.com/laris-co/multi-agent-workflow-kit.git@v0.2.5-alpha multi-agent-kit init
```

### UV Cache Management

UV caches are stored in `.uv-cache/` (gitignored). To clear cache:

```bash
# Clear UV cache
rm -rf .uv-cache/

# Use --no-cache flag to bypass cache
uvx --no-cache --from . multi-agent-kit init
```

## 🔴 Critical Safety Rules

### Repository Usage
-   **NEVER create issues/PRs on upstream**

### Command Usage
-   **NEVER use `-f` or `--force` flags with any commands.**
-   Always use safe, non-destructive command options.
-   If a command requires confirmation, handle it appropriately without forcing.

### Git Operations
-   Never use `git push --force` or `git push -f`.
-   Never use `git checkout -f`.
-   Never use `git clean -f`.
-   Always use safe git operations that preserve history.
-   **⚠️ NEVER MERGE PULL REQUESTS WITHOUT EXPLICIT USER PERMISSION**
-   **Never use `gh pr merge` unless explicitly instructed by the user**
-   **Always wait for user review and approval before any merge**
-   Before you go through the commit -> push -> PR flow, run `gh auth status` to confirm the GitHub CLI is connected; use `gh auth login` if it is not.

### File Operations
-   Never use `rm -rf` - use `rm -i` for interactive confirmation.
-   Always confirm before deleting files.
-   Use safe file operations that can be reversed.

### Package Manager Operations
-   Never use `[package-manager] install --force`.
-   Never use `[package-manager] update` without specifying packages.
-   Always review lockfile changes before committing.

### General Safety Guidelines
-   Prioritize safety and reversibility in all operations.
-   Ask for confirmation when performing potentially destructive actions.
-   Explain the implications of commands before executing them.
-   Use verbose options to show what commands are doing.
