#!/bin/sh

TMPDIR="$(mktemp -d)" || exit 1
SLOT=""
HAVE_SLOT=0

cleanup() {
    rm -f "$TMPDIR/redisout.tex" "$TMPDIR/redisout" 2>/dev/null || true

    if [ "$HAVE_SLOT" = "1" ] && [ -n "$SLOT" ]; then
        rm -rf "$SLOT" 2>/dev/null || true
    fi

    rm -rf "$TMPDIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

cd "$TMPDIR" || exit 1

export TMPDIR
export TEXINPUTS="${TEXINPUTS}:/srv"
export max_print_line=2147483647
export openout_any=a

# Two global XeLaTeX slots.
# An abandoned slot is NOT immediately recycled when its shell dies:
# XeLaTeX descendants may still be alive until timeout kills them.
i=0

while [ "$HAVE_SLOT" = "0" ]; do
    NOW="$(date +%s)"

    for candidate in /tmp/lamp-xelatex-slot1 /tmp/lamp-xelatex-slot2 /tmp/lamp-xelatex-slot3; do
        if mkdir "$candidate" 2>/dev/null; then
            SLOT="$candidate"
            echo "$$" >"$SLOT/pid"
            echo "$NOW" >"$SLOT/born"
            HAVE_SLOT=1
            break
        fi

        # Reclaim only slots old enough that a 12s+1s worker must be dead.
        if [ -f "$candidate/born" ]; then
            BORN="$(cat "$candidate/born" 2>/dev/null)"
            case "$BORN" in
                ''|*[!0-9]*) ;;
                *)
                    AGE=$((NOW - BORN))
                    if [ "$AGE" -gt 6 ]; then
                        rm -rf "$candidate" 2>/dev/null || true
                    fi
                    ;;
            esac
        fi
    done

    [ "$HAVE_SLOT" = "1" ] && break

    i=$((i + 1))

    # Allow ~12 seconds of queueing.
    if [ "$i" -ge 60 ]; then
        printf 'HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
        exit 75
    fi

    sleep 0.05
done

timeout -k 1 6 \
    stdbuf -o0 xelatex -8bit --shell-escape /srv/main.tex \
    >"$TMPDIR/xelatex.out" 2>&1

RC=$?

tail -n +8 "$TMPDIR/xelatex.out" 2>/dev/null || true

exit "$RC"
