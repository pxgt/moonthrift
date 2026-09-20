# Contributing

Issues and focused pull requests are welcome. Before opening a change, run:

```sh
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73-79
moon test --target all --deny-warn --warn-list +73-79
```

Keep public APIs documented, add black-box tests for observable behavior, and
include a fixture or specification citation for wire-format changes. Generated
interfaces (`pkg.generated.mbti`) are committed and must match the source.

Contributions certify that the submitter has the right to provide the work
under Apache-2.0. Please report security issues through the private process in
[SECURITY.md](SECURITY.md), not a public issue.
