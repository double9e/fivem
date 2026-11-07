#!/usr/bin/env bash
# Wait for index.js (if running), run build-template, full host lua codegen (no placeholder).
set -euo pipefail
ROOT=/workspace
LOG="$ROOT/artifacts/build/natives_pipeline.log"
exec >>"$LOG" 2>&1
echo "=== wait_native_doc $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

INDEX_PID=$(pgrep -f 'native-doc-tooling/index.js /workspace/ext/native-decls' | head -1 || true)
if [ -n "$INDEX_PID" ]; then
  echo "waiting for index.js pid=$INDEX_PID"
  while kill -0 "$INDEX_PID" 2>/dev/null; do sleep 30; done
fi

# If index never ran, run it once with libclang in out/
if [ ! -f "$ROOT/ext/native-doc-gen/out/natives_test.json" ] && [ ! -f "$ROOT/ext/native-doc-gen/natives_cfx.json" ]; then
  "$ROOT/artifacts/build/run_native_doc_host.sh"
else
  echo "index outputs present; running build-template only"
  cp -L /usr/lib/llvm-18/lib/libclang.so.1 "$ROOT/ext/native-doc-gen/out/libclang.so"
  cd "$ROOT/ext/native-doc-gen/out"
  NODE_PATH="$ROOT/ext/native-doc-tooling/node_modules/" \
    node "$ROOT/ext/native-doc-tooling/build-template.js" lua CFX \
    >"$ROOT/ext/natives/inp/natives_cfx.lua"
fi

BYTES=$(wc -c <"$ROOT/ext/natives/inp/natives_cfx.lua")
echo "natives_cfx.lua bytes=$BYTES"
test "$BYTES" -gt 1000

FORCE_NATIVES=1 "$ROOT/artifacts/build/run_natives_codegen_host.sh"
echo "=== natives pipeline done $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
