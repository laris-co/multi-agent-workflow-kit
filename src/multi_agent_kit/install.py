from __future__ import annotations

from dataclasses import dataclass
import shutil
from importlib import resources as importlib_resources
from importlib.abc import Traversable
from pathlib import Path
from typing import Iterator

ASSET_PACKAGE = "multi_agent_kit"
ASSET_ROOT_NAME = "assets"
ITEM_MAP = (
    (".agents", ".agents"),    # Toolkit files go to .agents/
    ("agents", "agents"),      # Gitignore-only directory for worktrees
    (".claude", ".claude"),    # Claude commands and configuration
    (".codex", ".codex"),      # Codex CLI prompts and cache scaffolding
    (".envrc", ".envrc"),  # direnv hook for tmux config
    ("AGENTS.md", "AGENTS.md"),  # Guide for human/AI collaborators
)


@dataclass(frozen=True)
class CopyPlan:
    source: Traversable
    destination: Path


class AssetInstaller:
    def __init__(self, target: Path, force: bool = False) -> None:
        self.target = target
        self.force = force

    def ensure_assets(self) -> list[Path]:
        written: list[Path] = []
        for source_name, dest_name in ITEM_MAP:
            # Special handling for agents directory
            if source_name == "agents" and dest_name == "agents":
                # Create agents directory with minimal .gitignore
                destination = self.target / dest_name
                destination.mkdir(parents=True, exist_ok=True)
                gitignore = destination / ".gitignore"
                if not gitignore.exists() or self.force:
                    gitignore.write_text("# Ignore all agent worktrees\n*\n!.gitignore\n")
                    written.append(gitignore)
            else:
                source = self._asset_root().joinpath(source_name)
                destination = self.target / dest_name
                self._copy(source, destination, written)
        self._ensure_root_gitignore(written)
        return written

    def _asset_root(self) -> Traversable:
        return importlib_resources.files(ASSET_PACKAGE).joinpath(ASSET_ROOT_NAME)

    def _copy(self, source: Traversable, destination: Path, written: list[Path]) -> None:
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            # Handle directory with children
            try:
                for child in source.iterdir():
                    self._copy(child, destination / child.name, written)
            except (AttributeError, NotImplementedError):
                # Some Traversable implementations don't support iterdir on certain directories
                pass
            return

        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists() and not self.force:
            return

        with importlib_resources.as_file(source) as src_path:
            shutil.copy2(src_path, destination)
        written.append(destination)

    def _ensure_root_gitignore(self, written: list[Path]) -> None:
        gitignore_path = self.target / ".gitignore"
        marker = "# Added by Multi-Agent Workflow Kit"
        ignore_lines = ["/.agents/", ".claude/settings.local.json"]

        try:
            existing = gitignore_path.read_text()
        except FileNotFoundError:
            content = marker + "\n" + "\n".join(ignore_lines) + "\n"
            gitignore_path.write_text(content)
            written.append(gitignore_path)
            return

        lines = [line.strip() for line in existing.splitlines()]

        append_lines = [entry for entry in ignore_lines if entry not in lines]

        if not append_lines:
            return

        append_text = ""
        if not existing.endswith("\n"):
            append_text += "\n"
        if marker not in existing:
            append_text += f"\n{marker}\n"
        append_text += "\n".join(append_lines) + "\n"

        gitignore_path.write_text(existing + append_text)
        written.append(gitignore_path)


def missing_assets(target: Path) -> Iterator[str]:
    for _, dest_name in ITEM_MAP:
        if not (target / dest_name).exists():
            yield dest_name
