"""End-to-end smoke tests for compatibility reporting and Git baselines."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
BEFORE = "examples/compatibility/before"
AFTER = "examples/compatibility/after"
MOON = ["moon", "run", "cmd/main", "--target", "native", "--frozen", "--warn-list", "+73-79", "--", "compat"]


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=False)


def verify() -> None:
    backward = run(*MOON, "--format", "json", BEFORE, AFTER)
    assert backward.returncode != 0, backward
    result = json.loads(backward.stdout)
    assert result == {
        "policy": "backward",
        "blocked": True,
        "findings": [{
            "direction": "backward",
            "source": f"{AFTER}/api.thrift",
            "code": "MTHC106",
            "kind": "breaking",
            "path": "Account.id#1",
            "message": "field became required",
        }],
    }, result

    executable_dir = ROOT / "_build" / "native" / "debug" / "build" / "cmd" / "main"
    executable = next(
        (path for path in (executable_dir / "main.exe", executable_dir / "main") if path.is_file()),
        None,
    )
    assert executable is not None, "native CLI executable was not built"
    direct = run(str(executable), "compat", BEFORE, AFTER)
    assert direct.returncode == 3, direct

    forward = run(*MOON, "--policy", "forward", BEFORE, AFTER)
    assert forward.returncode == 0, forward
    assert "forward: passed (0 finding(s))" in forward.stdout, forward.stdout

    suppressed = run(*MOON, "--suppress", "MTHC106", BEFORE, AFTER)
    assert suppressed.returncode == 0, suppressed
    assert "backward: passed (0 finding(s))" in suppressed.stdout, suppressed.stdout

    annotations = run(*MOON, "--format", "github", BEFORE, AFTER)
    assert annotations.returncode != 0, annotations
    assert f"::error file={AFTER}/api.thrift,title=MTHC106::" in annotations.stdout

    with tempfile.TemporaryDirectory(prefix="moonthrift-report-") as temp:
        report = Path(temp) / "report.md"
        markdown = run(*MOON, "--format", "markdown", "--report", str(report), BEFORE, AFTER)
        assert markdown.returncode != 0, markdown
        assert "| examples/compatibility/after/api.thrift | backward | breaking | MTHC106 |" in report.read_text(encoding="utf-8")

    baseline = run(sys.executable, "tools/compat_git.py", "--base-ref", "HEAD", "--schema-dir", "examples/multifile", "--format", "json")
    assert baseline.returncode == 0, baseline
    assert json.loads(baseline.stdout)["blocked"] is False, baseline.stdout

    with tempfile.TemporaryDirectory(prefix="moonthrift-schema-repo-") as temp:
        repo = Path(temp)
        schemas = repo / "schemas"
        schemas.mkdir()
        schema = schemas / "account.thrift"
        schema.write_text("struct Account { 1: optional i64 id }\n", encoding="utf-8")
        assert run("git", "-C", str(repo), "init", "-q").returncode == 0
        assert run("git", "-C", str(repo), "add", ".").returncode == 0
        committed = run("git", "-C", str(repo), "-c", "user.name=MoonThrift Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "baseline")
        assert committed.returncode == 0, committed
        schema.write_text("struct Account { 1: required i64 id }\n", encoding="utf-8")
        external = run(sys.executable, "tools/compat_git.py", "--repo", str(repo), "--base-ref", "HEAD", "--schema-dir", "schemas", "--format", "json")
        assert external.returncode != 0, external
        external_report = json.loads(external.stdout)
        assert external_report["blocked"] is True, external_report
        assert external_report["findings"][0]["code"] == "MTHC106", external_report


if __name__ == "__main__":
    verify()
    print("compatibility CLI and Git baseline smoke tests passed")
