#!/usr/bin/env bash
set -euo pipefail
ROOT=/workspace
LOG="$ROOT/artifacts/build/server_build_baseline.log"
JOB_SLOTS="${JOB_SLOTS:-1}"
export CI_BRANCH="${CI_BRANCH:-cursor/fxserver-core-net-recv-0ea9}"
export CI_BUILD_NUMBER="${CI_BUILD_NUMBER:-local-0}"
export CI_PIPELINE_ID="${CI_PIPELINE_ID:-0}"
export JOB_SLOTS
# Baseline: build at HEAD without flipping commits (parent compares patch separately)
exec > >(tee "$LOG") 2>&1
echo "=== FXServer baseline build start $(date -u +%Y-%m-%dT%H:%M:%SZ) jobs=$JOB_SLOTS sha=$(git -C "$ROOT" rev-parse HEAD) ==="
if [ ! -s "$ROOT/code/components/citizen-scripting-lua/include/NativesServer.h" ]; then
  /bin/bash "$ROOT/artifacts/build/run_natives_codegen_host.sh" | tee -a "$ROOT/artifacts/build/natives_codegen_host.log"
fi
export SKIP_NATIVES=1
sudo env JOB_SLOTS="$JOB_SLOTS" SKIP_NATIVES=1 CI_BRANCH="$CI_BRANCH" CI_BUILD_NUMBER="$CI_BUILD_NUMBER" CI_PIPELINE_ID="$CI_PIPELINE_ID" \
  proot \
  -b /dev:/dev \
  -b /sys:/sys \
  -b /proc:/proc \
  -b /tmp:/tmp \
  -b "$ROOT":/src \
  -b /root:/root \
  -R "$ROOT/alpine-build/rootfs" \
  /bin/sh /src/artifacts/build/build_server_proot_alpine_vm.sh
echo "=== build finished $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
if [ -f "$ROOT/code/bin/server/linux/release/FXServer" ]; then
  sha256sum "$ROOT/code/bin/server/linux/release/FXServer" | tee "$ROOT/artifacts/build/FXServer.baseline.sha256"
  ls -la "$ROOT/code/bin/server/linux/release/" | tee "$ROOT/artifacts/build/release_dir_listing.txt"
fi
