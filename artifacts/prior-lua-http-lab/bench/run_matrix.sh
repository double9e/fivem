#!/bin/bash
# 3 rounds, interleaved base/opt with alternating order, nice'd, single process at a time
cd "$(dirname "$0")/.."; L=lua-5.4.7/src/lua; OUT=results/runs.jsonl; : > $OUT
for r in 1 2 3; do for N in 1000 3000; do for c in batch cache grid; do
  T=300; [ $c = grid ] && T=20
  if [ $((r%2)) = 1 ]; then order="base opt"; else order="opt base"; fi
  for v in $order; do echo "{\"round\":$r,\"order\":\"$order\",\"result\":$(nice -n 10 $L bench/bench.lua $c $v $N $T $((100+r)))}" >> $OUT; done
  load=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($load>12)}" && { echo "load $load too high, stop"; exit 2; }
done; done; done
