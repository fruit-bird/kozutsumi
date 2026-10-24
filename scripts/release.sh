#!/usr/bin/env bash
# Build kozutsumi for macOS + Linux (all common archs), package, and optionally publish.
#
#   scripts/release.sh                 build + package into dist/
#   scripts/release.sh --publish       also tag v<version>, push, and create a GitHub release (needs gh)
#   scripts/release.sh --targets a,b   only build the given targets
#
# Requirements: rustup, cargo-zigbuild + zig (Linux targets), gh (--publish).
# macOS targets are built natively, so they need a macOS host.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN=kozutsumi
DIST=dist

# Apple Silicon only; x86_64-apple-darwin (Intel) is intentionally not built.
MAC_TARGETS=(
  aarch64-apple-darwin
)
# musl => static binaries that run on any distro
LINUX_TARGETS=(
  x86_64-unknown-linux-musl
  aarch64-unknown-linux-musl
)

publish=0
targets=("${MAC_TARGETS[@]}" "${LINUX_TARGETS[@]}")

while [[ $# -gt 0 ]]; do
  case $1 in
    --publish) publish=1 ;;
    --targets) IFS=, read -r -a targets <<<"${2:?--targets needs a value}"; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "missing '$1'${2:+ ($2)}"; }

need cargo
need rustup
need tar

version=$(cargo metadata --no-deps --format-version 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["packages"][0]["version"])')
tag="v$version"
host_os=$(uname -s)

if (( publish )); then
  need gh "https://cli.github.com"
  [[ -z $(git status --porcelain) ]] || die "working tree dirty; commit first"
  git rev-parse "$tag" >/dev/null 2>&1 && die "tag $tag already exists; bump version in Cargo.toml"
fi

if printf '%s\n' "${targets[@]}" | grep -q linux; then
  need cargo-zigbuild "cargo install --locked cargo-zigbuild"
  need zig "brew install zig"
fi

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

rm -rf "$DIST"
mkdir -p "$DIST"

for target in "${targets[@]}"; do
  echo "==> $target"
  rustup target add "$target" >/dev/null

  case $target in
    *-apple-darwin)
      [[ $host_os == Darwin ]] || die "$target needs a macOS host"
      cargo build --release --locked --target "$target"
      ;;
    *-linux-*)
      cargo zigbuild --release --locked --target "$target"
      ;;
    *) die "unsupported target $target" ;;
  esac

  name="$BIN-$version-$target"
  stage="$DIST/$name"
  mkdir -p "$stage"
  cp "target/$target/release/$BIN" "$stage/"
  for f in README.md LICENSE*; do [[ -f $f ]] && cp "$f" "$stage/"; done
  tar -C "$DIST" -czf "$DIST/$name.tar.gz" "$name"
  rm -rf "$stage"
done

(cd "$DIST" && sha256 ./*.tar.gz | sed 's#\./##' > SHA256SUMS)
echo "==> artifacts in $DIST/"
ls -1 "$DIST"

if (( publish )); then
  echo "==> publishing $tag"
  git tag -a "$tag" -m "$tag"
  git push origin "$tag"
  gh release create "$tag" "$DIST"/*.tar.gz "$DIST/SHA256SUMS" \
    --title "$tag" --generate-notes
fi
