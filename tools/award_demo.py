"""Run the short, deterministic MoonThrift judging demonstration."""

from __future__ import annotations

import difflib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "examples/multifile/directory.thrift"
GENERATED = ROOT / "examples/generated_directory/model.mbt"
EXPECTED_RPC = (
    "Binary/memory: user 7 = Ada",
    "Binary/framed: user 7 = Ada",
    "Compact/memory: user 7 = Ada",
    "Compact/framed: user 7 = Ada",
)
EXPECTED_CONSUMER = (
    "Mooncakes 0.3.0: parsed 1 definition; "
    "Binary and Compact round trips passed"
)


def run(label: str, *args: str, expected_code: int = 0) -> str:
    print(f"[{label}] {' '.join(args)}", flush=True)
    result = subprocess.run(
        args,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != expected_code:
        raise RuntimeError(
            f"{label}: expected exit {expected_code}, got {result.returncode}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result.stdout.strip()


def require(label: str, output: str, expected: str) -> None:
    if expected not in output:
        raise RuntimeError(
            f"{label}: missing expected output {expected!r}\nactual:\n{output}"
        )


def main() -> None:
    if shutil.which("moon") is None:
        raise RuntimeError("moon is not on PATH; install the MoonBit toolchain")

    version = run("toolchain", "moon", "version", "--all")
    print(version.splitlines()[0])

    checked = run(
        "IDL + includes",
        "moon", "run", "cmd/main", "--target", "native",
        "--warn-list", "+73-79", "--", "check", SCHEMA,
    )
    require("IDL + includes", checked, "OK: 2 document(s), 4 definition(s)")
    print(checked)

    inspected = run(
        "linked schema",
        "moon", "run", "cmd/main", "--target", "native",
        "--warn-list", "+73-79", "--", "inspect", SCHEMA,
    )
    for item in ("service Directory", "typedef UserId", "struct User"):
        require("linked schema", inspected, item)
    print("Directory links UserId and User from common/types.thrift")

    with tempfile.TemporaryDirectory(prefix="moonthrift-demo-") as temp:
        generated = Path(temp) / "directory.generated.mbtx"
        run(
            "generate typed MoonBit",
            "moon", "run", "cmd/main", "--target", "native",
            "--warn-list", "+73-79", "--", "generate", SCHEMA,
            str(generated),
        )
        run("format generated source", "moon", "fmt", str(generated))
        actual = generated.read_text(encoding="utf-8")
        expected = GENERATED.read_text(encoding="utf-8")
        if actual != expected:
            diff = "".join(
                list(
                    difflib.unified_diff(
                        expected.splitlines(keepends=True),
                        actual.splitlines(keepends=True),
                        fromfile=str(GENERATED),
                        tofile=str(generated),
                    )
                )[:80]
            )
            raise RuntimeError("generated model differs from checked-in source:\n" + diff)
    print("Generated model matches examples/generated_directory/model.mbt")

    rpc = run(
        "typed Binary + Compact RPC",
        "moon", "run", "examples/directory_demo", "--target", "wasm-gc",
        "--warn-list", "+73-79",
    )
    if tuple(rpc.splitlines()) != EXPECTED_RPC:
        raise RuntimeError(f"unexpected RPC transcript:\n{rpc}")
    print(rpc)

    compatibility = run(
        "schema evolution",
        "moon", "run", "cmd/main", "--target", "native",
        "--warn-list", "+73-79", "--", "diff",
        "examples/tutorial.thrift", "examples/tutorial-v2.thrift",
        expected_code=3,
    )
    require("schema evolution", compatibility, "breaking[MTHC104]")
    require("schema evolution", compatibility, "breaking[MTHC101]")
    print("Breaking field-type and removed-definition changes detected")

    tree = run(
        "published dependency",
        "moon", "-C", "examples/mooncakes_consumer", "tree",
    )
    require("published dependency", tree, "Xpeng/moonthrift@0.3.0")
    consumer = run(
        "independent Mooncakes consumer",
        "moon", "-C", "examples/mooncakes_consumer", "run", ".",
        "--target", "wasm-gc", "--warn-list", "+73-79",
    )
    require("independent Mooncakes consumer", consumer, EXPECTED_CONSUMER)
    print(consumer)
    print("PASS: source workflow and published-package consumer")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"DEMO FAILED: {error}", file=sys.stderr)
        raise SystemExit(1) from error
