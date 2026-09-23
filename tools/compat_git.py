"""Compare a schema directory with its committed Git baseline.

The Git snapshot is materialized outside the repository so uncommitted files
and credentials are never copied into the baseline. Only .thrift files under
the selected repository-relative directory are extracted.
"""

from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent


def git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, check=False
    )
    if result.returncode:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(message or f"git {args[0]} failed")
    return result.stdout


def schema_directory(value: str, repo: Path) -> PurePosixPath:
    path = PurePosixPath(value.replace("\\", "/"))
    if path.is_absolute() or not path.parts or any(
        part in ("", ".", "..") or ":" in part for part in path.parts
    ):
        raise ValueError("--schema-dir must be a repository-relative directory")
    if not (repo / Path(*path.parts)).is_dir():
        raise ValueError(f"schema directory does not exist: {value}")
    return path


def materialize_baseline(
    repo: Path, commit: str, directory: PurePosixPath, target: Path
) -> None:
    names = git(repo, "ls-tree", "-r", "-z", "--name-only", commit, "--", str(directory))
    prefix = directory.parts
    for name in names.split(b"\0"):
        if not name:
            continue
        repo_path = PurePosixPath(name.decode("utf-8"))
        if repo_path.parts[: len(prefix)] != prefix or repo_path.suffix != ".thrift":
            continue
        relative = repo_path.parts[len(prefix) :]
        if not relative or any(part in ("", ".", "..") for part in relative):
            raise ValueError(f"unsafe Git tree path: {repo_path}")
        destination = target.joinpath(*relative)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(git(repo, "show", f"{commit}:{repo_path}"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT, help="Git repository to compare")
    parser.add_argument("--base-ref", required=True, help="Git commit or ref")
    parser.add_argument("--schema-dir", required=True, help="repo-relative directory")
    parser.add_argument("--policy", choices=("backward", "forward", "full"), default="backward")
    parser.add_argument("--format", choices=("text", "json", "markdown", "github"), default="text")
    parser.add_argument("--suppress", action="append", default=[], metavar="MTHC###")
    parser.add_argument("--report", help="write report to this file")
    args = parser.parse_args()
    try:
        repo = args.repo.resolve(strict=True)
        directory = schema_directory(args.schema_dir, repo)
        commit = git(repo, "rev-parse", "--verify", f"{args.base_ref}^{{commit}}")
        commit_id = commit.decode("ascii").strip()
        with tempfile.TemporaryDirectory(prefix="moonthrift-baseline-") as temp:
            baseline = Path(temp)
            materialize_baseline(repo, commit_id, directory, baseline)
            command = [
                "moon", "run", "cmd/main", "--target", "native", "--frozen",
                "--warn-list", "+73-79", "--", "compat",
                "--policy", args.policy, "--format", args.format,
            ]
            for code in args.suppress:
                command.extend(("--suppress", code))
            if args.report:
                command.extend(("--report", args.report))
            current = str(directory) if repo == ROOT else str(repo / Path(*directory.parts))
            command.extend((str(baseline), current))
            return subprocess.run(command, cwd=ROOT, check=False).returncode
    except (OSError, UnicodeError, ValueError) as error:
        print(f"moonthrift Git baseline: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
