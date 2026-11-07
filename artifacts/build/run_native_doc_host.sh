#!/usr/bin/env bash
set -euo pipefail
ROOT=/workspace
export OS=Linux
export NODE="${NODE:-node}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:/usr/lib/llvm-18/lib"
cd "$ROOT/ext/native-doc-tooling"
if [ ! -d node_modules ]; then
  npm install --ignore-scripts
  (cd node_modules/libclang && npm rebuild)
fi
mkdir -p "$ROOT/ext/native-doc-gen/out" "$ROOT/ext/natives/inp"
cd "$ROOT/ext/native-doc-gen/out"
ln -sf /usr/lib/llvm-18/lib/libclang.so.18 libclang.so 2>/dev/null || ln -sf /usr/lib/llvm-18/lib/libclang.so.1 libclang.so
"$NODE" "$ROOT/ext/native-doc-tooling/index.js" "$ROOT/ext/native-decls/"
NODE_PATH="$ROOT/ext/native-doc-tooling/node_modules/" \
  "$NODE" "$ROOT/ext/native-doc-tooling/build-template.js" lua CFX \
  >"$ROOT/ext/natives/inp/natives_cfx.lua"
test -s "$ROOT/ext/natives/inp/natives_cfx.lua"
echo "natives_cfx.lua bytes=$(wc -c <"$ROOT/ext/natives/inp/natives_cfx.lua")"
