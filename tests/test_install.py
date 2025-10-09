from __future__ import annotations

from pathlib import Path

import pytest

from multi_agent_kit.install import AssetInstaller, missing_assets


def test_installer_creates_assets(tmp_path: Path) -> None:
    installer = AssetInstaller(tmp_path)
    assert list(missing_assets(tmp_path)) == [".agents", "agents", ".tmux.conf"]

    written = installer.ensure_assets()
    assert (tmp_path / ".agents").is_dir()
    assert (tmp_path / "agents").is_dir()
    assert not (tmp_path / "agents" / ".gitignore").exists()
    assert (tmp_path / ".tmux.conf").is_file()
    assert written  # some files were copied

    # second run without force should not rewrite files
    written_again = installer.ensure_assets()
    assert written_again == []
    assert list(missing_assets(tmp_path)) == []


def test_force_overwrites(tmp_path: Path) -> None:
    installer = AssetInstaller(tmp_path)
    installer.ensure_assets()

    target_conf = tmp_path / ".tmux.conf"
    target_conf.write_text("user modified")

    force_installer = AssetInstaller(tmp_path, force=True)
    written = force_installer.ensure_assets()
    assert target_conf.read_text() != "user modified"
    assert target_conf.is_file()
    assert written  # at least one file rewritten

    # ensure missing_assets still empty
    assert list(missing_assets(tmp_path)) == []


def test_agents_gitignore_opt_in(tmp_path: Path) -> None:
    create_installer = AssetInstaller(tmp_path, create_agents_gitignore=True)
    create_installer.ensure_assets()
    gitignore_path = tmp_path / "agents" / ".gitignore"
    assert gitignore_path.is_file()

    # Running again without the option should remove the file (for backwards compatibility)
    default_installer = AssetInstaller(tmp_path)
    default_installer.ensure_assets()
    assert not gitignore_path.exists()
