#!/bin/sh
# VM/proot wrapper: lua native codegen without native-doc-gen Node step (bind-mount + musl node ENOENT).
set -xe
JOB_SLOTS=${JOB_SLOTS:-1}
. /root/py-venv/bin/activate

if [ "$SKIP_NATIVES" != "" ]; then
	echo "SKIP_NATIVES set; assuming NativesServer.h generated on host"
elif [ "$SKIP_NATIVES" == "" ]; then
	cd /src/ext/natives
	gcc -O2 -shared -fpic -o cfx.so -I/usr/include/lua5.3/ lua_cfx.c
	mkdir -p inp out
	curl --http1.1 -sLo inp/natives_global.lua https://static.cfx.re/natives/natives.lua
	mkdir -p /opt/cfx-server/citizen/scripting/lua/ /opt/cfx-server/citizen/scripting/v8/
	lua5.3 codegen.lua inp/natives_global.lua native_lua server >/src/code/components/citizen-scripting-lua/include/NativesServer.h
	lua5.3 codegen.lua inp/natives_global.lua lua server >/opt/cfx-server/citizen/scripting/lua/natives_server.lua
	lua5.3 codegen.lua inp/natives_global.lua js server >/opt/cfx-server/citizen/scripting/v8/natives_server.js
	lua5.3 codegen.lua inp/natives_global.lua dts server >/opt/cfx-server/citizen/scripting/v8/natives_server.d.ts
	cat >/src/code/client/clrcore/NativesServer.cs <<'EOF'
#if IS_FXSERVER
using ContextType = CitizenFX.Core.fxScriptContext;

namespace CitizenFX.Core.Native
{
EOF
	lua5.3 codegen.lua inp/natives_global.lua enum server >>/src/code/client/clrcore/NativesServer.cs
	lua5.3 codegen.lua inp/natives_global.lua cs server >>/src/code/client/clrcore/NativesServer.cs
	cat >>/src/code/client/clrcore/NativesServer.cs <<'EOF'
}
#endif
EOF
	lua5.3 codegen.lua inp/natives_global.lua cs_v2 server >/src/code/client/clrcore-v2/Native/NativesServer.cs
	lua5.3 codegen.lua inp/natives_global.lua rpc server >/opt/cfx-server/citizen/scripting/rpc_natives.json
	lua5.3 codegen.lua inp/natives_global.lua pointer_args server >/src/code/components/citizen-scripting-core/src/NativeTypesServer.h
fi

cd /src/code
premake5 gmake2 --game=server --cc=clang --dotnet=msnet
cd build/server/linux
export CFLAGS="-fno-plt"
export CXXFLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR -Wno-deprecated-declarations -Wno-invalid-offsetof -fno-plt"
export LDFLAGS="-Wl,--build-id -fuse-ld=lld"
if [ ! -z "$CI_BRANCH" ] && [ ! -z "$CI_BUILD_NUMBER" ]; then
	echo '#pragma once' >/src/code/shared/cfx_version.h
	gitDescription="$CI_BRANCH $CI_BUILD_NUMBER linux"
	echo '#define GIT_DESCRIPTION "'$gitDescription'"' >>/src/code/shared/cfx_version.h
	echo '#define GIT_TAG "'$CI_BUILD_NUMBER'"' >>/src/code/shared/cfx_version.h
	echo '#define BUILD_ID "cfx-'$CI_PIPELINE_ID'"' >>/src/code/shared/cfx_version.h
fi
if [ "${CONTINUE_BUILD:-}" = "1" ]; then
	make FXServer -j${JOB_SLOTS} config=release
else
	make clean
	make clean config=release
	make FXServer -j${JOB_SLOTS} config=release
fi
