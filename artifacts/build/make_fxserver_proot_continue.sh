#!/usr/bin/env bash
# Continue existing object tree: FXServer only, -j1, no make clean. Run after active make exits.
set -euo pipefail
ROOT=/workspace
LOG="$ROOT/artifacts/build/make_fxserver_proot.log"
exec >>"$LOG" 2>&1
echo "=== FXServer continue $(date -u +%Y-%m-%dT%H:%M:%SZ) sha=$(git -C "$ROOT" rev-parse HEAD) ==="

if pgrep -f 'make CitiTest -j1 config=release' >/dev/null || pgrep -f 'make FXServer -j1 config=release' >/dev/null; then
  echo "ERROR: another make still running; abort"
  exit 1
fi

if [ ! -s "$ROOT/ext/natives/inp/natives_cfx.lua" ] || [ "$(wc -c <"$ROOT/ext/natives/inp/natives_cfx.lua")" -lt 1000 ]; then
  echo "ERROR: natives_cfx.lua not CI-ready; run wait_native_doc_and_codegen.sh first"
  exit 1
fi

sudo env JOB_SLOTS=1 \
  proot \
  -b /dev:/dev \
  -b /proc:/proc \
  -b /tmp:/tmp \
  -b "$ROOT":/src \
  -b /root:/root \
  -R "$ROOT/alpine-build/rootfs" \
  /bin/sh -c '. /root/py-venv/bin/activate && cd /src/code/build/server/linux && make FXServer -j1 config=release'

if [ -f "$ROOT/code/bin/server/linux/release/FXServer" ]; then
  sha256sum "$ROOT/code/bin/server/linux/release/FXServer" | tee "$ROOT/artifacts/build/FXServer.baseline.sha256"
  ls -la "$ROOT/code/bin/server/linux/release/FXServer"
fi
echo "=== FXServer continue end $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
