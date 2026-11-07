#!/usr/bin/env python3
"""Closed-loop HTTP load generator, localhost ONLY. usage: loadgen.py URL CONC SECONDS WARMUP
Counts: attempted, ok(200), non200 by status, timeouts, conn errors. Samples FXServer CPU/RSS from /proc."""
import asyncio,json,sys,time,urllib.parse,os,glob,collections
url,conc,dur,warm=sys.argv[1],int(sys.argv[2]),float(sys.argv[3]),float(sys.argv[4])
u=urllib.parse.urlparse(url); assert u.hostname in("127.0.0.1","localhost"),"local lab only"
TCK=os.sysconf('SC_CLK_TCK')
def fxpids(): return [p.split('/')[2] for p in glob.glob('/proc/[0-9]*/comm') if open(p).read().strip() in('FXServer','ld-musl-x86_64.')] 
def cpu_rss(pids):
    c=r=0
    for p in pids:
        try:
            f=open(f'/proc/{p}/stat').read().rsplit(')',1)[1].split(); c+=int(f[11])+int(f[12])
            r=max(r,int(open(f'/proc/{p}/statm').read().split()[1])*4096)
        except Exception: pass
    return c/TCK,r
lat=[];st=collections.Counter();att=0;rec=False;reconnects=0;ka_retries=[0]
async def read_resp(r):
    head=await r.readuntil(b"\r\n\r\n"); h=head.decode("latin1").lower()
    code=head[9:12].decode() if head.startswith(b"HTTP/1.") else "malformed"
    if "transfer-encoding: chunked" in h:
        body=b""
        while True:
            n=int((await r.readline()).strip(),16)
            if n==0: await r.readline(); break
            body+=await r.readexactly(n); await r.readline()
    else:
        import re; m=re.search(r"content-length: *(\d+)",h); body=await r.readexactly(int(m.group(1))) if m else b""
    return code
async def worker(i,stop):
    """persistent HTTP/1.1 keep-alive connection per worker (avoids client ephemeral-port/TIME_WAIT exhaustion seen with Connection: close)"""
    global att,reconnects;k=0;conn=None
    while time.monotonic()<stop:
        pid=(i+k*conc)%3000+1;k+=1;t=time.monotonic()
        try:
            for attempt in (0,1):
                if conn is None:
                    conn=await asyncio.wait_for(asyncio.open_connection(u.hostname,u.port),3); reconnects+=rec
                r,w=conn
                w.write(f"GET {u.path}?id={pid} HTTP/1.1\r\nHost: x\r\n\r\n".encode())
                try:
                    code=await asyncio.wait_for(read_resp(r),3); break
                except (asyncio.IncompleteReadError,ConnectionResetError) as e:
                    # FXServer closes idle-reused keep-alive sockets after a few requests (observed: 6); resend ONCE on a fresh socket, counted
                    if attempt==1 or (isinstance(e,asyncio.IncompleteReadError) and e.partial): raise
                    w.close(); conn=None; ka_retries[0]+=rec
        except asyncio.TimeoutError: code="timeout"
        except Exception: code="conn_error"
        if code not in("200",) and conn: conn[1].close(); conn=None
        if rec:
            att+=1; st[code]+=1
            if code=="200": lat.append((time.monotonic()-t)*1000)
    if conn: conn[1].close()
async def main():
    global rec
    await asyncio.gather(*[worker(i,time.monotonic()+warm) for i in range(conc)])
    pids=fxpids(); c0,_=cpu_rss(pids); rss=[]; rec=True; t0=time.monotonic()
    async def samp():
        while time.monotonic()<t0+dur: rss.append(cpu_rss(pids)[1]); await asyncio.sleep(0.5)
    await asyncio.gather(samp(),*[worker(i,t0+dur) for i in range(conc)])
    el=time.monotonic()-t0; c1,_=cpu_rss(pids)
    lat.sort(); q=lambda p: round(lat[min(len(lat)-1,int(p*len(lat)))],3) if lat else None
    print(json.dumps({"url":url,"conc":conc,"dur_s":round(el,3),"attempted":att,"ok":len(lat),"status":dict(st),"non_ok":att-len(lat),
      "ok_rps":round(len(lat)/el,1),"p50_ms":q(.5),"p95_ms":q(.95),"p99_ms":q(.99),"fx_cpu_pct_of_1core":round((c1-c0)/el*100,1),"fx_rss_max_mb":round(max(rss or [0])/2**20,1),"fx_pids":len(pids),"reconnects":reconnects,"keepalive_close_retries":ka_retries[0]}))
asyncio.run(main())
