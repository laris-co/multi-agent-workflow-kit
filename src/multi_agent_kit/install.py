from __future__ import annotations

from dataclasses import dataclass
import shutil
from importlib import resources as importlib_resources
from importlib.abc import Traversable
from pathlib import Path
from typing import Iterator

ASSET_PACKAGE = "multi_agent_kit"
ASSET_ROOT_NAME = "assets"
TOP_LEVEL_ITEMS = (".agents", ".tmux.conf")


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
        for name in TOP_LEVEL_ITEMS:
            source = self._asset_root().joinpath(name)
            destination = self.target / name
            self._copy(source, destination, written)
        return written

    def _asset_root(self) -> Traversable:
        return importlib_resources.files(ASSET_PACKAGE).joinpath(ASSET_ROOT_NAME)

    def _copy(self, source: Traversable, destination: Path, written: list[Path]) -> None:
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            for child in source.iterdir():
                self._copy(child, destination / child.name, written)
            return

        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists() and not self.force:
            return

        with importlib_resources.as_file(source) as src_path:
            shutil.copy2(src_path, destination)
        written.append(destination)


def missing_assets(target: Path) -> Iterator[str]:
    for name in TOP_LEVEL_ITEMS:
        if not (target / name).exists():
            yield name
