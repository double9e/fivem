#!/usr/bin/env bash
set -euo pipefail
ROOT=/workspace
cd "$ROOT/ext/natives"
gcc -O2 -shared -fpic -o cfx.so -I/usr/include/lua5.3/ lua_cfx.c
mkdir -p inp out
if [ -s "$ROOT/code/components/citizen-scripting-lua/include/NativesServer.h" ] && [ "${FORCE_NATIVES:-}" != 1 ]; then
  echo "NativesServer.h present; skip codegen"
  exit 0
fi
if [ ! -f inp/natives_global.lua ]; then
  curl --http1.1 -sLo inp/natives_global.lua https://static.cfx.re/natives/natives.lua
fi
/usr/bin/lua5.3 -e "assert(loadfile('inp/natives_global.lua'))" 

gen() {
  /usr/bin/lua5.3 codegen.lua inp/natives_global.lua "$@"
}

gen native_lua server >"$ROOT/code/components/citizen-scripting-lua/include/NativesServer.h"
gen pointer_args server >"$ROOT/code/components/citizen-scripting-core/src/NativeTypesServer.h"
gen cs_v2 server >"$ROOT/code/client/clrcore-v2/Native/NativesServer.cs"
{
  echo '#if IS_FXSERVER'
  echo 'using ContextType = CitizenFX.Core.fxScriptContext;'
  echo ''
  echo 'namespace CitizenFX.Core.Native'
  echo '{'
  gen enum server
  gen cs server
  echo '}'
  echo '#endif'
} >"$ROOT/code/client/clrcore/NativesServer.cs"

echo "ok NativesServer.h=$(wc -c <"$ROOT/code/components/citizen-scripting-lua/include/NativesServer.h") bytes"
