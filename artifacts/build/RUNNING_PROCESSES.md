# Process state (auto snapshot; check `date -u` on read)

| PID | Role | Notes |
|-----|------|--------|
| 188761 | proot wrapper | `make CitiTest -j1` in Alpine rootfs — **do not start second make** |
| 188762 | make | parent of compile graph for CitiTest |
| 12198 | node | `native-doc-tooling/index.js` (libclang parse) — single instance after dedupe |
| 188757 | bash | parent of proot CitiTest one-shot |

Stopped duplicate: **45631** (second index.js).

Logs: `artifacts/build/make_cititest_proot.log`, `artifacts/build/native_doc_host.log`
