# gladiaio/wandb

Gladia's build of [wandb](https://github.com/wandb/wandb): upstream releases with a security floor on
wandb-core (the Go binary in the wheel), for images whose scan gate (fixable HIGH / CRITICAL) would
otherwise need exceptions while upstream has not released the fix.

- `main` mirrors `wandb/wandb` `main`, synced every day.
- `gladia` (default branch) holds the build: `patch.sh` (the floor: Go toolchain and Go modules) and
  `.github/workflows/release.yml`.
- Every day the workflow takes the latest upstream release, applies `patch.sh`, builds the Linux wheels
  (manylinux x86_64 and aarch64, as upstream's release does), fails if Trivy still finds a fixable HIGH or
  CRITICAL vulnerability in them, and publishes them as the GitHub release `v<version>-gladia.<REV>`
  (wheels and `SHA256SUMS`). The package version is `<version>+gladia.<REV>`.

Install (pin the sha256 from the release's `SHA256SUMS`):

    uv pip install "wandb @ https://github.com/gladiaio/wandb/releases/download/v0.30.0-gladia.1/wandb-0.30.0+gladia.1-py3-none-manylinux_2_28_x86_64.whl"

New finding in wandb-core: add the floor to `patch.sh`, bump `REV` in the workflow, run it
(`gh workflow run release.yml -R gladiaio/wandb`). Once upstream ships the fix itself, `patch.sh` changes
nothing and the build is upstream's code with our version label.
