# Build checkpoint (updated 2026-11-07 UTC)

## Completed
- **Submodules:** `git submodule update --init --recursive` → **0 missing** (`submodule_init.log`).
- **Alpine rootfs:** 3.16.5 minirootfs + Cfx APK mirrors (`proot_prepare.log`, packages ~1.37 GiB).
- **premake5 (musl):** built with `clang -j1` inside proot (`premake_clang_build.log`); gcc premake build **ICE** in proot.
- **NativesServer.h (host):** generated via `run_natives_codegen_host.sh` (59160 bytes); `natives_cfx.lua` is **placeholder** until `run_native_doc_host.sh` completes (libclang + index.js).
- **CitiTest in proot:** `make CitiTest -j1` progresses past **tbb** with venv; log `make_cititest_proot.log` (in progress or see tail).

## Blockers hit (exact)
| Issue | Command / URL | Error |
|-------|----------------|-------|
| premake gcc in proot | `make -j4` in premake-src | `cc: internal compiler error: Segmentation fault` |
| Node + bind-mount | `node yarn_cli.js` on `/src/...` | `ENOENT` for `yarn_cli.js` (shell `test -f` OK) |
| Parallel make in proot | `make -j4 config=release` | `Segmentation fault` in fmtlib/boost |
| natives_cfx.lua | `native-doc-tooling/index.js` | needs `libclang.so` in CWD + long parse |
| Full FXServer binary | — | **Not produced yet** |

## Paths when build succeeds
- `code/bin/server/linux/release/FXServer`
- Staging (CI script): `/opt/cfx-server/` inside proot (not packaged to tarball in this VM run)

## Reproduce (sanctioned)
```bash
/workspace/artifacts/build/run_proot_prepare.sh
/workspace/artifacts/build/proot_prepare_tail.sh
# premake clang build: see premake_clang_build.log one-liner in BUILD_CHECKPOINT history
JOB_SLOTS=1 /workspace/artifacts/build/run_proot_server_build.sh
```

**PR remains experimental / not production-ready.**
