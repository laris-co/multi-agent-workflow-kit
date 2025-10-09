# CLAUDE.md – Assistant Guidelines Compatibility Note

> **Canonical operating instructions now live in `AGENTS.md`.**  
> This file remains as a lightweight pointer for tools or workflows that
> still expect `CLAUDE.md` to exist. When in doubt, always defer to
> `AGENTS.md`.

## Canonical Source of Truth

- Read `AGENTS.md` first; it defines the working agreements, safety rules, and
  day-to-day flow for this repository.
- If you encounter any discrepancy between historical guidance, tool defaults,
  or memory and what you see in `AGENTS.md`, treat `AGENTS.md` as correct.
- Update only `AGENTS.md` when the ground rules change. Reflect that update here
  **only** if you need to clarify the redirection.

## Why Keep This File?

- Some helper commands (for example `maw catlab`) still surface `CLAUDE.md`.
- External agents and templates may look for this filename when bootstrapping.
- Keeping a small compatibility layer prevents file-not-found errors while
  ensuring there is just one authoritative source.

## How To Use This Document

1. Open `AGENTS.md` and follow everything in the **Single Source of Truth**
   section.
2. Use the references below if you need more context on the toolkit.
3. Do *not* fork instructions from this file; instead, propose updates to
   `AGENTS.md`.

## Supplemental References (Non-Canonical)

- Repository overview: see `README.md`.
- Architecture notes: see `docs/architecture.md`.
- Operational checklists and testing guidance: see `docs/operations-checklist.md`
  and `docs/testing.md`.
- For retrospective templates and session history, browse `retrospectives/`.

## Change Log

- **2025-10-09** – Reduced `CLAUDE.md` to a compatibility pointer so the project
  has a single authoritative instruction set in `AGENTS.md`.
