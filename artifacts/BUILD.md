# Reproducible build notes — FXServer Linux @ 5c3065c26

## Pinned source
```bash
git clone https://github.com/double9e/fivem.git
cd fivem
git checkout 5c3065c261fb3ba82032fee6803f247198fec221
```

## Official Linux artifact path (reference binary, not built here)
```
https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/38435-5c3065c261fb3ba82032fee6803f247198fec221/fx.tar.xz
sha256: 1b58507f68086ca3578c187f31e7b4a2259b7192d76b0c80cfc1af682fdf2be9
```

## Supported source build (from repo CI)
See `code/tools/ci/build_server_proot_alpine.sh`:
```sh
premake5 gmake2 --game=server --cc=clang --dotnet=msnet
cd build/server/linux
export CFLAGS="-fno-plt"
export CXXFLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_AUTO_PTR -Wno-deprecated-declarations -Wno-invalid-offsetof -fno-plt"
export LDFLAGS="-Wl,--build-id -fuse-ld=lld"
make -j24 config=release
# output: ../../../../bin/server/linux/release/FXServer
```

Requires Alpine proot image, Cfx APK repositories, full `git submodule update --init --recursive`, mono 5.16, v8, natives codegen step (top of script).

## Attempt on this VM (Ubuntu 24.04)
```bash
# premake (downloaded binary)
curl -sL -o /tmp/pm.tgz https://github.com/premake/premake-core/releases/download/v5.0.0-beta2/premake-5.0.0-beta2-linux.tar.gz
mkdir -p /tmp/premake && tar -xzf /tmp/pm.tgz -C /tmp/premake

cd code
git -C .. submodule update --init vendor/msgpack-c
/tmp/premake/premake5 gmake2 --game=server --cc=clang   # OK

cd build/server/linux
make CitiTest -j4 config=release   # FAIL — see build_cititest_attempt.log
```

### Blockers observed
1. **~150 git submodules** still at `-` (uninitialized) in a shallow clone
2. **Toolchain mismatch**: premake defaults to `clang` but Ubuntu image lacks complete libc++ headers for vendor/catch2 (`type_traits` not found)
3. **No Alpine/Cfx package mirror** on VM — cannot reproduce musl-linked production `FXServer` without `build_server_docker_alpine.sh` infrastructure
4. **No FX license** in environment — cannot authenticate official artifact for integration tests (by design)

## Patch build (after full environment exists)
Build twice at same SHA:
- baseline: `git checkout 5c3065c26` → release make
- candidate: branch with `EnetUv.cpp` pool-retain patch → same flags

Compare SHA256 of `FXServer` and `.so` via `sha256sum` after build.
