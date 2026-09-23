# Schema compatibility in CI

MoonThrift checks Thrift schema evolution without requiring a network runtime.
The comparison core is portable MoonBit; the native CLI reads files, while
`tools/compat_git.py` extracts a committed Git baseline into a temporary
directory. No Git worktree files are modified by the comparison.

## Policies and exit behavior

- `backward` (default): compare old to new and reject changes that prevent a
  new reader from handling the old schema under MoonThrift's rule set.
- `forward`: compare new to old; useful when old consumers must accept data
  produced by the new schema.
- `full`: require both directions to pass. Findings explicitly identify their
  direction and are ordered backward first, forward second.

The CLI returns 0 for a passing policy, 3 for breaking findings, and 1 for
invalid input or other errors. The `moon run` launcher may collapse a child's
nonzero code to 1; CI should test for success versus failure, not an exact
nonzero value. The direct native executable preserves exit code 3.

```sh
moon run cmd/main --target native -- compat \
  --policy backward --format json \
  examples/compatibility/before examples/compatibility/after

moon run cmd/main --target native -- compat \
  --policy full --format markdown --report compatibility.md \
  old-schemas new-schemas

python tools/compat_git.py --base-ref main --schema-dir schemas \
  --policy backward --format github
```

File pairs and directory trees are supported. Directory comparison matches
`.thrift` files by relative path, recursively, in sorted order. A file present
on only one side is compared with an empty schema. `include` resolution for a
directory snapshot requires referenced `.thrift` files to live within that
directory; choose a parent `--schema-dir` if the includes span subdirectories.
Invalid schemas fail before the compatibility result is produced.

Text is for local inspection; JSON has stable keys (`policy`, `blocked`,
`findings`) and each finding records direction, source, code, severity, symbol
path, and message. Markdown is suited to a PR summary or saved artifact.
`github` writes workflow command annotations; errors mark breaking rules,
warnings mark advisory rules, and notices mark compatible changes. Removed
symbols have no reliable new-file line, so annotations omit line numbers.

`--suppress MTHC106` can be repeated for a deliberate exception, but a
suppressed finding no longer blocks CI. Review the rule and record the reason
in the PR; avoid broad, permanent suppressions. The original `diff` command
remains available for simple directional inspection.

## Reusable workflow

Copy [the sample workflow](../examples/compatibility-ci.yml) into a schema
repository. It checks out the full Git history, installs MoonBit, checks out
MoonThrift, and compares the PR's schema tree with the exact base commit.
Set `--schema-dir` to the repository-relative root of the Thrift sources and
pin MoonThrift to a reviewed commit or tag. The workflow fails a PR when a
breaking finding is present. GitHub annotations point to the checked-out
schema files; full JSON or Markdown reports can be generated with `--report`.

For another repository, pass `--repo /path/to/repo` to the Git adapter. It
uses Git object IDs and `git show` without checking out the baseline, so it
also works when a PR branch has uncommitted work. Run
`python tools/test_compat_cli.py` to exercise file/directory reports, policy
behavior, suppression, annotations, and an external temporary Git repository.
