# FINAL BLOCKED — Cloud VM build closure (2026-11-07 ~04:50 UTC)

All agent-started build/index/wait processes were **terminated** on this VM. Logs preserved under `artifacts/build/`.

## Core patch compile status (candidate `EnetUv.cpp`)

| Item | Result |
|------|--------|
| **Patch object compiled** | **YES** |
| Path | `code/build/server/linux/obj/Release/citizen-server-impl/EnetUv.o` |
| SHA-256 | `c3f214b56931fb8a1e408ea97a16c1388f6f2bfd89fa8fbf411e5dc42940d9c1` |
| Toolchain | Alpine/musl **clang** via proot (`make CitiTest -j1`, log `make_cititest_proot.log` line ~2549 `EnetUv.cpp`) |
| **FXServer binary** | **NO** — no `code/bin/server/linux/release/FXServer` |
| **CitiTest / regression binary** | **NO** — build stopped before link |
| **Catch2 `TestEnetUvDatagram` executed** | **NO** |

Conclusion: **network pool-buffer patch compiles** into `citizen-server-impl` on the sanctioned Alpine clang flags; **no linked artifact** and **no runtime/regression proof** on this VM.

## Native codegen (CI-equivalent) — FAILED

| Requirement | Status |
|-------------|--------|
| Real `ext/natives/inp/natives_cfx.lua` | **NO** (placeholder **15 bytes**) |
| `natives_test.json` from `index.js` | **NO** (never written in `ext/native-doc-gen/out/`) |

### Diagnosis (not “still waiting”)

1. Long-running `index.js` (**PID 12198**, ~74 min): **~1% CPU**, no output file; worker children intermittently failed **`libclang.so: cannot open shared object file`** when not started from `ext/native-doc-gen/out/` (`native_doc_host.log`).
2. **10 min retry** (`index_js_retry_600s.log`): libclang OK in `out/`; **fast crash** at native **4/889** — `AddConvarChangeListener.md` → `TypeError` in worker → parent **`write EPIPE`** (worker-farm + `process.exit(0)` on error in `index.js:38`).
3. **Cfx musl Node 12** (`cfx-content.akamaized.net/.../node-v12.22.12-linux-x64-musl.tar.gz`): **cannot execute** on Ubuntu glibc host (`required file not found`).
4. **Placeholder / `SKIP_NATIVES`** path explicitly **invalid** for baseline artifact claims.

**Pinned submodule revisions were not changed** for this diagnosis.

## FXServer link attempt (post-shutdown)

```
make FXServer -j1 config=release
→ make: *** No rule to make target 'FXServer'.  Stop.
```

(Log: `make_fxserver_6min.log`.) Premake output target is **`DuplicityMain`** (links to `FXServer` binary); agent used wrong make target in the timed retry. Full **DuplicityMain** release link never completed on this VM.

## proot / compiler environment (feasible alternatives)

| Route | Feasibility on this cloud VM |
|-------|------------------------------|
| Alpine rootfs + Cfx APK + `clang` premake (`artifacts/build/run_proot_prepare.sh`) | **Deps OK** |
| `make -j1` in proot | **Works** but **very slow**; **`-j4` SIGSEGV** |
| `make -j1` **CitiTest** | Partial compile only (killed); not the product target |
| **Official** `code/tools/ci/build_server_docker_alpine.sh` | **Supported** upstream; needs Docker/proot **on a glibc Linux runner without nested breakage**, not reimplemented here |
| **Native doc** `ext/native-doc-gen/build.sh` with **musl Node inside Alpine** (not host Node 22) | **Required** for CI-parity `natives_cfx.lua`; not completed here |

## Unmet user criteria (honest)

- [ ] Baseline **FXServer** artifact (same SHA, toolchain)
- [ ] Patched **FXServer** artifact
- [ ] Real **`natives_cfx.lua`** / full native codegen
- [ ] 3×3 artifact benchmark trials
- [ ] Executed `TestEnetUvDatagram` / protocol tests
- [ ] Licensed server runtime test on cloud VM (correctly **out of scope**)

## Reproducible logs (for export from this VM)

- `artifacts/build/make_cititest_proot.log`
- `artifacts/build/proot_prepare.log`, `premake_clang_build.log`
- `artifacts/build/index_js_retry_600s.log`, `native_doc_host.log`
- `artifacts/build/FINAL_BLOCKED.log` (terminate transcript)
- `artifacts/POOL_BUFFER_AUDIT.md`

## Source patch

Branch `cursor/fxserver-core-net-recv-0ea9`, PR `#1` (experimental, **not merged**).

Files: `code/components/citizen-server-impl/src/EnetUv.cpp`, `include/EnetUvDatagram.h`, `code/tests/server/TestEnetUvDatagram.cpp` (tests **not run**).

---

**No further unsupervised compile/index jobs remain on this VM.**
