#!/usr/bin/env bash
set -euo pipefail
ROOT=/workspace
LOG="$ROOT/artifacts/build/proot_prepare.log"
JOB_SLOTS="${JOB_SLOTS:-4}"
exec > >(tee "$LOG") 2>&1
echo "=== proot_prepare start $(date -u +%Y-%m-%dT%H:%M:%SZ) JOB_SLOTS=$JOB_SLOTS ==="
sudo proot \
  -b /dev:/dev \
  -b /sys:/sys \
  -b /proc:/proc \
  -b /tmp:/tmp \
  -b "$ROOT":/src \
  -b /root:/root \
  -R "$ROOT/alpine-build/rootfs" \
  /bin/sh -c "export JOB_SLOTS=$JOB_SLOTS; /bin/sh /src/alpine-build/proot_prepare.sh"
echo "=== proot_prepare done $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
