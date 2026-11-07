#!/bin/bash
# Key: bash-builtin printf -> RAM-only /dev/shm file mode 0600, deleted right after auth starts (max 15s). Never argv/disk. Output redacted before disk.
cd "$(dirname "$0")/../data"; umask 077; K=/dev/shm/d9lab_key_$$.cfg
printf 'set sv_licenseKey "%s"\n' "$FX_LICENSE" > $K
( for i in $(seq 30); do sleep 0.5; grep -q "Authenticating" ../logs/server_$1.log 2>/dev/null && break; done; rm -f $K ) &
sleep infinity | ../server/run.sh +exec $K +exec server.cfg 2>&1 | python3 ../bench/redact.py > ../logs/server_$1.log
rm -f $K
