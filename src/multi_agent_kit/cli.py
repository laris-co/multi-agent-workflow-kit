from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

REQUIRED_BINARIES = ("git", "tmux", "yq")


class BootstrapError(RuntimeError):
    """Raised when the bootstrap flow cannot proceed."""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="multi-agent-kit",
        description="Bootstrap the Multi-Agent Workflow Kit using uvx.",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser(
        "init",
        help="Run setup and start the tmux session in a single step.",
    )
    init_parser.add_argument(
        "profile",
        nargs="?",
        default="profile1",
        help="Layout profile to use (defaults to profile1).",
    )
    init_parser.add_argument(
        "--prefix",
        dest="prefix",
        help="Optional session suffix passed to .agents/start-agents.sh.",
    )
    init_parser.add_argument(
        "--detach",
        action="store_true",
        help="Run tmux session in detached mode.",
    )
    init_parser.add_argument(
        "--skip-setup",
        action="store_true",
        help="Skip running .agents/setup.sh (assumes agents already provisioned).",
    )
    init_parser.add_argument(
        "--setup-only",
        action="store_true",
        help="Run setup and exit without launching tmux.",
    )

    return parser.parse_args(argv)


def ensure_binaries() -> None:
    missing = [binary for binary in REQUIRED_BINARIES if shutil.which(binary) is None]
    if missing:
        raise BootstrapError(
            "Missing required command(s): " + ", ".join(missing)
        )


def repo_root() -> Path:
    cwd = Path.cwd()
    agents_dir = cwd / ".agents"
    if not agents_dir.is_dir():
        raise BootstrapError(
            f"Expected to find .agents/ in {cwd}. Run multi-agent-kit from the repository root."
        )
    return cwd


def run_script(script: Path, *args: str) -> None:
    if not script.exists():
        raise BootstrapError(f"Script not found: {script}")

    result = subprocess.run(
        ["bash", str(script), *args],
        cwd=script.parent,
        check=False,
    )
    if result.returncode != 0:
        raise BootstrapError(f"Command failed: {script} {' '.join(args)}")


def handle_init(args: argparse.Namespace) -> None:
    ensure_binaries()
    root = repo_root()

    setup_script = root / ".agents" / "setup.sh"
    start_script = root / ".agents" / "start-agents.sh"

    if args.skip_setup and args.setup_only:
        raise BootstrapError("--setup-only already implies running setup; do not combine with --skip-setup")

    if not args.skip_setup:
        run_script(setup_script)
        if args.setup_only:
            return
    elif args.setup_only:
        raise BootstrapError("--setup-only requires running setup (omit --skip-setup)")

    start_args: list[str] = [args.profile]
    if args.prefix:
        start_args.extend(["--prefix", args.prefix])
    if args.detach:
        start_args.append("--detach")

    run_script(start_script, *start_args)


def main(argv: list[str] | None = None) -> None:
    try:
        args = parse_args(argv)
        if args.command == "init":
            handle_init(args)
        else:
            raise BootstrapError(f"Unknown command: {args.command}")
    except BootstrapError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Interrupted", file=sys.stderr)
        sys.exit(130)


if __name__ == "__main__":
    main(sys.argv[1:])
