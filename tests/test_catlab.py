from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest


SCRIPT_SOURCE = Path(__file__).resolve().parents[1] / "src/multi_agent_kit/assets/.agents/scripts/catlab.sh"


@pytest.mark.skipif(shutil.which("curl") is None, reason="curl is required for catlab script tests")
def test_catlab_downloads_from_custom_url(tmp_path: Path) -> None:
    script_dir = tmp_path / ".agents" / "scripts"
    script_dir.mkdir(parents=True)

    target_script = script_dir / "catlab.sh"
    target_script.write_bytes(SCRIPT_SOURCE.read_bytes())
    target_script.chmod(0o755)

    custom_source = tmp_path / "custom_claude.md"
    custom_content = "Custom CLAUDE guidelines\n"
    custom_source.write_text(custom_content)

    url = custom_source.resolve().as_uri()

    result = subprocess.run(
        [str(target_script), "--url", url],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr

    written_path = tmp_path / "CLAUDE.md"
    assert written_path.is_file()
    assert written_path.read_text() == custom_content
    assert "custom gist URL" in result.stdout
    assert url in result.stdout
