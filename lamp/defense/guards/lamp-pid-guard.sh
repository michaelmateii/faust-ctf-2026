#!/bin/sh

while sleep 2; do
    running=$(docker inspect -f '{{.State.Running}}' lamp-latex-1 2>/dev/null)

    [ "$running" = true ] || continue

    pids=$(docker inspect -f '{{.State.Pid}}' lamp-latex-1 2>/dev/null)
    [ -n "$pids" ] || continue

    count=$(docker exec lamp-latex-1 sh -c 'ps | wc -l' 2>/dev/null || echo 0)

    if [ "$count" -ge 115 ]; then
        printf '%s restart: process_count=%s\n' \
          "$(date -Is)" "$count" \
          >>/root/faust/lamp-pid-guard.log

        docker restart lamp-latex-1 >/dev/null 2>&1
        sleep 3
    fi
done
