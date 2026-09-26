#!/bin/sh

# Put an absolute lifetime on the Redis helper as a second safety net.
if [ "$1" != "__worker" ]; then
    exec timeout -k 1 7 "$0" __worker
fi

PARENT="$PPID"

(
    while [ -p redisout.tex ] && kill -0 "$PARENT" 2>/dev/null; do
        timeout 1 cat redisout.tex 2>/dev/null || true
    done
) | nc redis 6379
