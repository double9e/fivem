#!/usr/bin/env python3
# correctness: base vs opt bodies must match for same id (requests back-to-back; state mutates every 100ms so tiny race possible -> retry once)
import urllib.request,json,sys
B="http://127.0.0.1:30199/d9_bench/"
g=lambda p: urllib.request.urlopen(B+p,timeout=5).read()
out={}
for case in ["cache","near","list"]:
    mism=0
    for i in range(1,3001,15):
        ok=False
        for t in range(3):
            a=g(f"{case}_base?id={i}"); b=g(f"{case}_opt?id={i}")
            if a==b: ok=True;break
        mism+= not ok
    out[case]={"checked":200,"mismatch_after_retry":mism,"sample":g(f"{case}_opt?id=7")[:80].decode()}
print(json.dumps(out,ensure_ascii=False))
