# gladiaio/wandb

Gladia's build of [wandb](https://github.com/wandb/wandb): upstream `main` with a security floor on
wandb-core (the Go binary in the wheel), for images whose scan gate (fixable HIGH / CRITICAL) would
otherwise need exceptions while upstream has not released the fix.

- `main` mirrors `wandb/wandb` `main`, synced every day.
- `gladia` (default branch) holds the build: `patch.sh` (the floor: Go toolchain and Go modules) and
  `.github/workflows/release.yml`.
- Every day (02:41 UTC) the workflow syncs `main`, then, when `main` or `patch.sh` changed since the
  latest release, applies `patch.sh` to `main`, builds the Linux wheels (manylinux x86_64 and aarch64,
  as upstream's release does), fails if Trivy still finds a fixable HIGH or CRITICAL vulnerability in
  them, and publishes them as a new GitHub release, marked Latest.
- A failed run (sync conflict, build, Trivy gate) publishes nothing, so the latest release stays the last
  good one, and opens or comments on the issue "Sync and release failed".

## The release contract

gladia-enterprise's inference images (`inference/docker/security_floor.sh`, the Baseten Truss) install
the **latest release**, with no pin. They rely on this:

- Version `<main's __version__>+gladia.<YYYYMMDD>` (`.2`, `.3`… for another build the same UTC day), tag
  `v<version with + as ->`, e.g. `v0.30.1.dev1-gladia.20261015`. A release is never replaced.
- Assets: one wheel per arch, `wandb-<version>-py3-none-manylinux_2_28_<x86_64|aarch64>.whl`, and
  `SHA256SUMS` (`sha256sum` format, one line per wheel).
- The release marked Latest is the newest one that passed the build and the Trivy gate (never a
  prerelease, though main's version is a `.dev` one).
- The notes end with `source: main=<sha> patch=<patch.sh blob sha>`: the workflow builds again only when
  one of them changes (or with `force`).

Install by hand: resolve the latest tag (`https://github.com/gladiaio/wandb/releases/latest` redirects to
it), check the wheel against that release's `SHA256SUMS`, then `uv pip install --no-deps <wheel>`.

Rolling back a bad release: delete it (`gh release delete <tag> --cleanup-tag -R gladiaio/wandb`) or
mark the previous one Latest (`gh release edit <tag> --latest`). An image build can pin one with
`WANDB_RELEASE=<tag>` (gladia-enterprise `inference/docker/build_unified.sh`).

Token scopes: the workflow is read-only by default. The `build` job runs upstream `main`'s build code
(hatch hooks, Go, Rust, an import of the wheel), so it gets no write scope and its checkouts persist no
credentials; only `sync`, `release` (which only scans and uploads the wheels) and `notify` write.

New finding in wandb-core: add the floor to `patch.sh` and merge it: the next run (or
`gh workflow run release.yml -R gladiaio/wandb`) builds a new release. Once upstream `main` carries the
fix itself, `patch.sh` changes nothing and the build is upstream's code with our version label.
