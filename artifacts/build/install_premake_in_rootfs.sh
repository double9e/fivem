#!/usr/bin/env bash
# Install a prebuilt premake5 into the Alpine rootfs (skip building premake in proot; gcc ICE under proot here).
set -euo pipefail
ROOT=/workspace
PREMAKE_DIR="$ROOT/alpine-build/premake-bin"
mkdir -p "$PREMAKE_DIR" "$ROOT/alpine-build/rootfs/usr/local/bin"
curl -fsSL -o "$PREMAKE_DIR/premake.tgz" \
  https://github.com/premake/premake-core/releases/download/v5.0.0-beta2/premake-5.0.0-beta2-linux.tar.gz
tar -xzf "$PREMAKE_DIR/premake.tgz" -C "$PREMAKE_DIR"
install -m 0755 "$PREMAKE_DIR/premake5" "$ROOT/alpine-build/rootfs/usr/local/bin/premake5"
"$ROOT/alpine-build/rootfs/usr/local/bin/premake5" --version | tee "$ROOT/artifacts/build/premake_in_rootfs.version"
