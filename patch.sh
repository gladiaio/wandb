#!/usr/bin/env bash
# Applies Gladia's security floor to a wandb source tree (an upstream release tag) and stamps the
# version with a local label (0.30.0 -> 0.30.0+gladia.1). Run from the source root, Go on PATH.
#
# The floor: the Go toolchain wandb-core is built with (the `go` line of core/go.mod, which the
# release build downloads) and the Go modules it links, raised only when the tag is below them.
# Add a line here when an image scan flags a new fixable finding in wandb-core, then bump REV in
# .github/workflows/release.yml to rebuild the current release.
set -euo pipefail

LABEL="${1:?usage: patch.sh <local version label, e.g. gladia.1>}"
GO_MIN=1.27.2                       # CVE-2026-78667, CVE-2026-78669, CVE-2026-97031 (Go stdlib)
MODULES=(
    "golang.org/x/net@v0.60.0"      # CVE-2026-78669
)

# true when version $1 < version $2 (both without a leading v)
lt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }

cd core
have_go="$(go mod edit -json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Go"])')"
if lt "$have_go" "$GO_MIN"; then
    echo "go directive: $have_go -> $GO_MIN"
    go mod edit -go="$GO_MIN" -toolchain=none
fi
for spec in "${MODULES[@]}"; do
    mod="${spec%@*}" want="${spec#*@}"
    have="$(go list -m -f '{{.Version}}' "$mod")"
    if lt "${have#v}" "${want#v}"; then
        echo "$mod: $have -> $want"
        go get "$spec"
    fi
done
go mod tidy
cd ..

base="$(sed -n 's/^__version__ = "\(.*\)"$/\1/p' wandb/__init__.py)"
new="${base}+${LABEL}"
sed -i.bak "s/^__version__ = \"$base\"/__version__ = \"$new\"/" wandb/__init__.py
sed -i.bak "s/__version__: str = \"$base\"/__version__: str = \"$new\"/" wandb/__init__.pyi wandb/__init__.template.pyi
sed -i.bak "s/Version = \"$base\"/Version = \"$new\"/" core/internal/version/version.go
rm -f wandb/__init__.py.bak wandb/__init__.pyi.bak wandb/__init__.template.pyi.bak core/internal/version/version.go.bak
grep -q "\"$new\"" wandb/__init__.py core/internal/version/version.go
echo "version: $new"
