#!/bin/sh

C=lamp-latex-1

# Remove abusive large files.
find /var/lib/docker/volumes/lamp_storage/_data \
  -type f -size +50M -print -delete 2>/dev/null || true

# If Docker cannot inspect the container right now, do NOT restart it.
N=$(docker exec "$C" sh -c 'ps | wc -l' 2>/dev/null) || exit 0

case "$N" in
    ''|*[!0-9]*) exit 0 ;;
esac

if [ "$N" -gt 140 ]; then
    echo "$(date -Is) restarting $C: process_count=$N"
    docker restart "$C" >/dev/null
fi
