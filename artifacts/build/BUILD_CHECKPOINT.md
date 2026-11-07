# Build checkpoint — superseded by `FINAL_BLOCKED.md` (VM jobs stopped 2026-11-07)

## Still running (coordinator: do not duplicate make)

| PID | Command |
|-----|---------|
| 188761–188762 | `proot` → `make CitiTest -j1 config=release` |
| 12198 | `node ext/native-doc-tooling/index.js ext/native-decls/` |
| (tmux) | `wait_native_doc_and_codegen.sh` blocked on PID 12198 |

See `artifacts/build/RUNNING_PROCESSES.md` and `make_cititest_proot.log` tail.

## Artifacts produced

| Artifact | Status |
|----------|--------|
| `code/bin/server/linux/release/FXServer` | **NOT BUILT** |
| `code/bin/server/linux/release/CitiTest` | **in progress** |
| `ext/natives/inp/natives_cfx.lua` | **placeholder 15 B — not CI-equivalent** |

## Natives / codegen (blocking baseline parity)

1. **libclang pipeline on host** is the supported public path (`run_native_doc_host.sh`).
2. `index.js` parses ~850 files under `ext/native-decls/`; after **>70 min** still no `natives_test.json` in cwd (see `/proc/12198/cwd`).
3. Until `natives_cfx.lua` is multi-kB, **`SKIP_NATIVES` / placeholder output does not count** as CI baseline.

**After index exits:** `wait_native_doc_and_codegen.sh` → `FORCE_NATIVES=1 run_natives_codegen_host.sh`.

## FXServer next step (no second compiler)

When **both** (a) PID 188762 exited and (b) real `natives_cfx.lua`:

```bash
/workspace/artifacts/build/make_fxserver_proot_continue.sh
```

Uses existing object tree (`make FXServer -j1`, **no clean**).

Fresh CI-equivalent tree (parent box): `JOB_SLOTS=1 run_proot_server_build.sh` only **after** natives pipeline OK.

## proot stability

- `make -j4` → compiler SIGSEGV (documented earlier).
- `make -j1` in proot **works but slow** (~40+ min still in vendor/server graph for CitiTest).

## Environment recommendation if this VM stalls

Use GitLab **docker-builder** flow (`code/tools/ci/build_server_docker_alpine.sh`) on a runner with **native proot** (not nested QEMU) and **8+ CPU**; or dedicated bare-metal Alpine 3.16 with same APK repos. Cloud nested proot + `make -j1` is **throughput-limited**, not fundamentally unbuildable.

## Benchmark / performance claims

**Unmet** — no baseline vs patched FXServer artifact trials; microbench remains non-evidence.

## Pool-buffer regression tests

Extended `code/tests/server/TestEnetUvDatagram.cpp` (backlog boundary, drain recycle, payload bytes). Runs when CitiTest links; **not executed** in this checkpoint.
