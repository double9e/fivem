import json,statistics as S,collections,csv
rows=[json.loads(l) for l in open('results/http_runs.jsonl')]
rer=[json.loads(l) for l in open('results/http_runs_rerun.jsonl')]
bad={(j['round'],j['case'],j['r']['conc']) for j in rows if j['r']['dur_s']>9}
rows=[j for j in rows if (j['round'],j['case'],j['r']['conc']) not in bad]+rer
w=csv.writer(open('results/http_runs_final.csv','w'))
w.writerow(['round','case','variant','order','conc','dur_s','attempted','ok','non_ok','status','ok_rps','p50_ms','p95_ms','p99_ms','fx_cpu_pct_of_1core','fx_rss_max_mb','hitch_lines','keepalive_close_retries','rerun'])
d=collections.defaultdict(list)
for j in sorted(rows,key=lambda j:(j['case'],j['r']['conc'],j['round'],j['variant'])):
    r=j['r'];w.writerow([j['round'],j['case'],j['variant'],j['order'],r['conc'],r['dur_s'],r['attempted'],r['ok'],r['non_ok'],json.dumps(r['status']),r['ok_rps'],r['p50_ms'],r['p95_ms'],r['p99_ms'],r['fx_cpu_pct_of_1core'],r['fx_rss_max_mb'],j['hitch_lines'],r['keepalive_close_retries'],'rerun_reason' in j])
    d[(j['case'],r['conc'],j['variant'])].append(j)
out=[]
for case in['cache','near','list']:
  for c in[1,8,32]:
    b,o=d[(case,c,'base')],d[(case,c,'opt')]
    f=lambda L,k:[x['r'][k] for x in sorted(L,key=lambda x:x['round'])]
    br,orr=f(b,'ok_rps'),f(o,'ok_rps'); bm,om=S.median(br),S.median(orr)
    bp,op=f(b,'p99_ms'),f(o,'p99_ms')
    line=(f"{case:5} c={c:2} ok_rps base {br} (median {bm}) | opt {orr} (median {om}) | change {(om-bm)/bm*100:+.1f}% (denominator=base median {bm})\n"
          f"      p99 ms base {bp} -> opt {op} | cpu% base {f(b,'fx_cpu_pct_of_1core')} opt {f(o,'fx_cpu_pct_of_1core')} | non_ok base {sum(f(b,'non_ok'))} opt {sum(f(o,'non_ok'))} | hitch lines base {[x['hitch_lines'] for x in sorted(b,key=lambda x:x['round'])]} opt {[x['hitch_lines'] for x in sorted(o,key=lambda x:x['round'])]}")
    print(line); out.append(line)
open('results/http_summary.txt','w').write("\n".join(out)+"\n")
