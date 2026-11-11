# Distribution follow-up, 2026-11-11

This note separates source compatibility maintenance from historical binary
distribution. It is not a blanket license-compliance determination.

## Source and fixture review

The maintenance changes consist of MoonBit source, generated MoonBit source,
interfaces, tests, CI and documentation. No third-party executable was added.
The `interop/fixtures/python_fixtures.mbt` byte strings are serialized protocol
values, not encoded programs. The original `interop/python/reference.py`
generator and schema inputs were reviewed; Apache Thrift Python 0.24.0 rebuilt
and verified all 18 fixtures on 2026-11-11. See `THIRD_PARTY.md`.

The visible Git history contains source/configuration/documentation blobs;
the reviewed encoded byte arrays are protocol test cases. No Git LFS pointer
or nested binary archive was found in the checked source. This does not audit
every external package mirror or binary distribution.

## Existing Linux packages: unresolved distribution materials

The default branch's separate `linux-packages.yml` statically links the CLI
and uploads deb, rpm, Arch and Alpine packages. Its `linuxpkg.json` installs
only the executable, README and this project's root Apache-2.0 license.

The existing [run 39818698386](https://github.com/pxgt/moonthrift/actions/runs/39818698386)
has artifacts `packages-amd64` (12443836269) and `packages-arm64`
(12442679457). The amd64 artifact was downloaded for local review only.
The deb, APK and Arch archive inventories confirm that the only installed
documentation is README and the root copyright file; no component-specific
notice or corresponding-source material is included there. The downloaded
files have these SHA-256 digests:

| File | SHA-256 |
| --- | --- |
| `moonthrift_0.4.0-1_amd64.deb` | `09e83c50be5a59f2a8aa97726b41a0cd10f2a9f586f462e7cd23849fa64d0eca` |
| `moonthrift-0.4.0-1-x86_64.pkg.tar.zst` | `77245daae57584c8fea5ee8d85dc9328b41c49a155620bff15979bf6218a782c` |
| `moonthrift-0.4.0-1.x86_64.rpm` | `cfadc403142efe4524ed0870867d7dd16d11d12bdde1f271f7ef84c23f54036a` |
| `moonthrift-0.4.0-r1.amd64.apk` | `58e8937beb1ea441f43fcb914042ede76561de41cd2d67ed97e1b95fe0da2c5b` |

The existing local branch `ci/linuxpkg-0.5.1-notices` at `10b8bfd` proposes
additional notices and glibc sources, but is not in default-branch `main`.
It has been preserved, not silently treated as an accepted or sufficient fix.

Before another binary-package upload, inventory the actual linked components
and exact versions, preserve their licenses/notices, and verify the applicable
source and build/relinking materials against their actual upstream licenses.
Review the arm64 packages and any public package repositories separately.
Then assess existing artifacts and offer a documented remediation plan.
This maintenance run neither uploads new Linux packages nor deletes old
artifacts, rewrites history, moves tags, or withdraws published packages.

GitHub releases `v0.4.0` and MoonCov `v0.1.1` had no attached assets when
queried on 2026-11-11; that fact does not establish the state of separate CI
artifacts or the linuxpkg-hosted package repositories.
