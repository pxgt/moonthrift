# Maintenance and release evidence

Historical evidence verified on 2026-09-28. This ledger ties source commits
to public CI, releases, and the registry. Phase 6 is prepared as `0.3.1` in
[Issue #41](https://github.com/pxgt/moonthrift/issues/41). For its publication
status and exact source commit, use the
[v0.3.1 Release](https://github.com/pxgt/moonthrift/releases/tag/v0.3.1),
[Mooncakes 0.3.1](https://mooncakes.io/docs/Xpeng/moonthrift@0.3.1), and
dereference the annotated tag. A `moon.mod` version alone is not publication
evidence.

## Published releases

The historical `v` tags below are annotated. The commit column is the tag's dereferenced
source commit (`git rev-parse 'vX.Y.Z^{}'`), not the tag object's SHA. The
corresponding `moon.mod` at each commit declares that same version.

| Version | Source commit | CI on that commit | Public artifacts |
| --- | --- | --- | --- |
| `0.1.0` | `d445864363f9e972a6a65566a8432418b9557f89` | [success](https://github.com/pxgt/moonthrift/actions/runs/35091007421) | [Mooncakes](https://mooncakes.io/docs/Xpeng/moonthrift@0.1.0), [GitHub Release](https://github.com/pxgt/moonthrift/releases/tag/v0.1.0) |
| `0.2.0` | `a0a30ae2f586c8e149245edd5606981cba64618c` | [success](https://github.com/pxgt/moonthrift/actions/runs/35503641455) | [Mooncakes](https://mooncakes.io/docs/Xpeng/moonthrift@0.2.0), [GitHub Release](https://github.com/pxgt/moonthrift/releases/tag/v0.2.0) |
| `0.3.0` | `0cfae581e39a2438b33995537c0d7a3c32930898` | [success](https://github.com/pxgt/moonthrift/actions/runs/36088294413) | [Mooncakes](https://mooncakes.io/docs/Xpeng/moonthrift@0.3.0), [GitHub Release](https://github.com/pxgt/moonthrift/releases/tag/v0.3.0) |

The Mooncakes entries report the matching version, Apache-2.0 license, and
GitHub repository via `moon view Xpeng/moonthrift@<version>`. The independently
resolved [consumer module](../examples/mooncakes_consumer/moon.mod)
intentionally pins `0.3.0` as a backward-compatibility regression; its
[test](../examples/mooncakes_consumer/main_wbtest.mbt) parses IDL
and uses both codecs. The [release checklist](release-checklist.md) records
the publication gates and the 0.3.0 Mooncakes build check.

Reproduce the release identity from a fresh clone:

```sh
git fetch --tags
git cat-file -t v0.3.0
git rev-parse 'v0.3.0^{}'
git show v0.3.0:moon.mod
moon view Xpeng/moonthrift@0.3.0
moon -C examples/mooncakes_consumer tree
moon -C examples/mooncakes_consumer test --target all --deny-warn --warn-list +73-79
```

The first command requires repository access, `moon view` requires the
registry, and the last two commands run from the current repository's
Phase 6 checkout on a host with the native compiler and Node.js available.
For the historical source tests, use a **separate clone**
detached at the tag and the commands in [verification.md](verification.md);
do not switch a working checkout with uncommitted changes. For `0.3.1`, also
test a fresh, separate consumer pinned to `Xpeng/moonthrift@0.3.1`. A
successful registry lookup or tag alone does not establish that a new `main`
commit was published.

## Phase 6 development trace

| Work | Issue and merged PR | Main commit | Main CI |
| --- | --- | --- | --- |
| Core coverage floor | [#29](https://github.com/pxgt/moonthrift/issues/29), [#30](https://github.com/pxgt/moonthrift/pull/30) | `80ec514859b48897871762f3ffb36133521b9496` | [success](https://github.com/pxgt/moonthrift/actions/runs/36091346754) |
| Fixed-seed property and malformed-input corpus | [#31](https://github.com/pxgt/moonthrift/issues/31), [#32](https://github.com/pxgt/moonthrift/pull/32) | `65de1d5bf2e39dbcd34f8e4244a7a5ae592bf8a6` | [success](https://github.com/pxgt/moonthrift/actions/runs/36093334298) |
| Parser and protocol benchmarks | [#33](https://github.com/pxgt/moonthrift/issues/33), [#34](https://github.com/pxgt/moonthrift/pull/34) | `7e5f14e7b2336689975b8871ef7592ab486141f9` | [success](https://github.com/pxgt/moonthrift/actions/runs/36094505242) |
| Multi-file service and published-package consumer | [#35](https://github.com/pxgt/moonthrift/issues/35), [#36](https://github.com/pxgt/moonthrift/pull/36) | `a150200d947d29122802d4f67ba92c7bc35307fb` | [success](https://github.com/pxgt/moonthrift/actions/runs/36096189877) |
| API and release documentation | [#37](https://github.com/pxgt/moonthrift/issues/37), [#38](https://github.com/pxgt/moonthrift/pull/38) | `2abc6495ce5735e278f7d9c1013265b53c0c7018` | [success](https://github.com/pxgt/moonthrift/actions/runs/36393251471) |

Each PR preserves the implementation review and branch checks; the linked
main run verifies the merged commit. The current measured core line coverage
is 2102/2366 (88.84%) under
`python tools/check_core_coverage.py --minimum 85`. The
[fuzz corpus](verification.md#deterministic-fuzz-and-property-corpus),
[benchmark baseline](benchmarks.md), and
[service tutorial](multifile-service-tutorial.md) document what those gates
exercise and what they do not.

Open maintenance work includes
[derived-method warning 079](https://github.com/pxgt/moonthrift/issues/13);
`--warn-list +73-79` is the documented temporary exception. The broader
[roadmap Issue #2](https://github.com/pxgt/moonthrift/issues/2) and
[award roadmap](award-roadmap.md) retain deferred feature scope.

## Next release discipline

Do not infer publication of `0.3.1` or a future `0.4.0` from the `main` tree.
A release
requires a reviewed version/changelog change, green PR and exact main-commit
CI, packaging, publication under the intended Mooncakes account, a successful
registry build, an annotated tag pointing at the published source commit, a
GitHub Release, and a fresh consumer dependency check. Record the resulting
commit, CI run, Mooncakes page, and tag in the GitHub Release and its tracking
Issue. The prior [0.3.0 checklist](release-checklist.md) is a concrete example.
