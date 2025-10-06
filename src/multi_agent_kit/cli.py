from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from .install import AssetInstaller, missing_assets

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
        default="profile0",
        help="Layout profile to use (defaults to profile0).",
    )
    init_parser.add_argument(
        "--prefix",
        dest="prefix",
        help="Optional session suffix passed to .agents/scripts/start-agents.sh.",
    )
    init_parser.add_argument(
        "--detach",
        action="store_true",
        help="Run tmux session in detached mode.",
    )
    init_parser.add_argument(
        "--skip-setup",
        action="store_true",
        help="Skip running .agents/scripts/setup.sh (assumes agents already provisioned).",
    )
    init_parser.add_argument(
        "--setup-only",
        action="store_true",
        help="Run setup and exit without launching tmux.",
    )
    init_parser.add_argument(
        "--force-assets",
        action="store_true",
        help="Overwrite bundled toolkit files when installing into the target repo.",
    )

    return parser.parse_args(argv)


def ensure_binaries() -> None:
    missing = [binary for binary in REQUIRED_BINARIES if shutil.which(binary) is None]
    if missing:
        raise BootstrapError(
            "Missing required command(s): " + ", ".join(missing)
        )


def repo_root() -> Path:
    return Path.cwd()


def ensure_git_repo(root: Path) -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        if prompt_yes_no("No Git repository detected. Initialize one now? [y/N] "):
            init_cmd = subprocess.run(["git", "init"], cwd=root, check=False)
            if init_cmd.returncode != 0:
                raise BootstrapError("Failed to initialize Git repository")
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                raise BootstrapError("Unable to determine Git repository root after initialization")
        else:
            raise BootstrapError(
                "This command must be run inside a Git repository. "
                "Run 'git init' or switch to an existing repo first."
            )

    toplevel = Path(result.stdout.strip()).resolve()
    cwd_resolved = root.resolve()
    if cwd_resolved != toplevel:
        if prompt_yes_no(
            f"Detected Git repo at '{toplevel}'. Change working directory to it now? [y/N] "
        ):
            os.chdir(toplevel)
            return toplevel
        raise BootstrapError(
            "Detected Git repository at '{}' but the tool was invoked inside '{}'\n"
            "Run the init command from the repository root.".format(toplevel, cwd_resolved)
        )
    return toplevel


def prompt_yes_no(message: str) -> bool:
    try:
        answer = input(message).strip().lower()
    except EOFError:
        return False
    return answer in {"y", "yes"}


def maybe_commit_assets(root: Path, written: list[Path]) -> None:
    rel_paths = sorted({str(path.relative_to(root)) for path in written}) if written else []

    if not rel_paths:
        return

    ignored_assets = detect_ignored_paths(root, rel_paths)

    print("ℹ️  Toolkit assets installed:")
    for path in rel_paths:
        print(f"   • {path}")

    if ignored_assets:
        print("   These files are normally ignored; staging will use 'git add -f'.")

    if prompt_yes_no("Commit these assets now? [y/N] "):
        add_cmd = ["git", "add", "-f", "--", *rel_paths]
        add_proc = subprocess.run(add_cmd, cwd=root, check=False)
        if add_proc.returncode == 0:
            commit_cmd = [
                "git",
                "commit",
                "-m",
                "Add multi-agent toolkit assets",
            ]
            commit_proc = subprocess.run(commit_cmd, cwd=root, check=False)
            if commit_proc.returncode == 0:
                print("✅  Staged and committed toolkit assets.")
                return
            print("⚠️  git commit failed; staged files remain. Commit manually.")
        else:
            print("⚠️  git add failed; no changes were staged.")

    print("ℹ️  Commit manually with:")
    print("   git add -- " + " ".join(rel_paths))
    print("   git commit -m \"Add multi-agent toolkit assets\"")


def detect_ignored_paths(root: Path, rel_paths: list[str]) -> list[str]:
    if not rel_paths:
        return []

    proc = subprocess.run(
        ["git", "check-ignore", "--stdin"],
        cwd=root,
        capture_output=True,
        text=True,
        input="\n".join(rel_paths) + "\n",
        check=False,
    )

    if proc.returncode == 0:
        return [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    if proc.returncode == 1:
        return []

    raise BootstrapError(
        "Failed to inspect ignored toolkit assets: " + (proc.stderr.strip() or "unknown error")
    )


def ensure_initial_commit(root: Path) -> None:
    head_check = subprocess.run(
        ["git", "rev-parse", "--verify", "HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )

    if head_check.returncode == 0:
        return

    print("⚠️  Repository has no commits yet.")
    if not prompt_yes_no("Create an empty initial commit now? [y/N] "):
        raise BootstrapError(
            "Repository must have at least one commit before provisioning agents. "
            "Run 'git commit --allow-empty -m \"Initial commit\"' and retry."
        )

    commit_result = subprocess.run(
        ["git", "commit", "--allow-empty", "-m", "Initial commit"],
        cwd=root,
        check=False,
    )

    if commit_result.returncode != 0:
        raise BootstrapError("Failed to create empty initial commit")

    print("✅  Created empty initial commit")


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
    ensure_git_repo(root)

    missing = list(missing_assets(root))
    installer = AssetInstaller(root, force=args.force_assets)
    written: list[Path] = []
    if missing or args.force_assets:
        written = installer.ensure_assets()
        if written:
            print("📦 Installed toolkit assets:")
            for path in written:
                print(f"  {path.relative_to(root)}")
        elif args.force_assets:
            print("⚠️  No assets overwritten (files identical or missing in package)")
    maybe_commit_assets(root, written)
    ensure_initial_commit(root)

    setup_script = root / ".agents" / "scripts" / "setup.sh"
    start_script = root / ".agents" / "scripts" / "start-agents.sh"

    if not setup_script.exists() or not start_script.exists():
        raise BootstrapError("Toolkit assets missing; ensure .agents/ scripts are available.")

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
