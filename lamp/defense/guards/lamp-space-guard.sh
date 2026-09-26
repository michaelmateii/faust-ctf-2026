#!/bin/sh

find /var/lib/docker/volumes/lamp_storage/_data \
  -type f -size +20M \
  -print -delete 2>/dev/null

docker exec lamp-latex-1 sh -c '
find /tmp -type f -size +20M \
  -print -delete 2>/dev/null || true
'
