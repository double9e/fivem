#!/bin/bash
# Requires running authenticated FXServer (bench/start_server.sh). Localhost only. 3 rounds, order alternates per round.
cd "$(dirname "$0")/.."; OUT=results/http_runs.jsonl; : > $OUT; LOG=logs/server_$1.log
for r in 1 2 3; do for case in cache near list; do for c in 1 8 32; do
  [ $((r%2)) = 1 ] && o="base opt" || o="opt base"
  for v in $o; do
    while [ $(ss -tan | grep -c TIME-WAIT) -gt 8000 ]; do sleep 2; done
    h0=$(grep -ci hitch $LOG)
    res=$(python3 bench/loadgen.py http://127.0.0.1:30199/d9_bench/${case}_$v $c 8 2)
    h1=$(grep -ci hitch $LOG)
    echo "{\"round\":$r,\"case\":\"$case\",\"variant\":\"$v\",\"order\":\"$o\",\"hitch_lines\":$((h1-h0)),\"load1\":$(cut -d' ' -f1 /proc/loadavg),\"r\":$res}" >> $OUT
  done
  awk "BEGIN{exit !($(cut -d' ' -f1 /proc/loadavg)>14)}" && { echo stop: load; exit 2; }
done; done; done; echo DONE
