# Lamp

## Overview

Lamp was the most demanding defensive service during my FAUST CTF 2026 run.

The public service used XeLaTeX to process incoming requests. Under hostile concurrency, this became an expensive execution path and repeatedly pushed the container into CPU, memory, and PID exhaustion.

The work in this directory documents both:

- offensive research against Lamp
- defensive incident response and hardening

---

## Failure mode

The public listener used `socat`, which spawned request handlers that eventually executed XeLaTeX.

Simplified flow:

```text
client
→ socat
→ entrypoint.sh
→ XeLaTeX
→ response
```

Under attack:

```text
many connections
→ many entrypoint processes
→ many XeLaTeX processes
→ high CPU
→ memory pressure
→ PID exhaustion
→ failed forks / resets / OOM kills
```

Observed errors included:

```text
Memory cgroup out of memory
Killed process ... (xelatex)
fork(): Resource temporarily unavailable
can't fork: Resource temporarily unavailable
connection reset by peer
```

---

## Defensive mitigations

Several layers were added iteratively.

### Docker resource limits

Memory and PID limits were introduced and tuned.

A late working configuration was approximately:

```text
memory: 3 GiB
PID limit: 128
restart policy: unless-stopped
```

The exact values changed during testing because limits that were too strict hurt legitimate checker traffic.

---

## Global XeLaTeX slots

The request entrypoint was modified to allow only a small number of concurrent XeLaTeX jobs.

Slot directories were used under `/tmp`:

```text
/tmp/lamp-xelatex-slot1
/tmp/lamp-xelatex-slot2
/tmp/lamp-xelatex-slot3
```

Each slot tracked ownership and age.

This limited the number of expensive workers independently of raw incoming connection count.

---

## Rendering timeout

XeLaTeX execution was bounded with:

```bash
timeout -k 1 3   stdbuf -o0 xelatex -8bit --shell-escape /srv/main.tex
```

This prevented individual render jobs from running indefinitely.

---

## Signal cleanup fix

The original cleanup behavior used a combined trap:

```sh
trap cleanup EXIT HUP INT TERM
```

This was replaced with explicit terminating handlers:

```sh
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
```

This reduced temporary-directory and slot-cleanup races under load.

Compare:

```text
defense/entrypoint.original.sh
defense/entrypoint.sh
```

---

## Queue tuning

Requests that could not immediately acquire a worker slot were queued briefly.

This exposed an operational trade-off:

```text
queue too short
→ legitimate requests receive 503

queue too long
→ too many waiting processes accumulate
```

Several thresholds were tested during the event.

---

## Watchdogs

The final defensive setup included several helper scripts.

### `lamp-space-guard.sh`

Removed oversized files from Lamp storage and temporary directories.

### `lamp-health-guard.sh`

Monitored service health and process count.

### `lamp-pid-guard.sh`

Restarted the container when process count approached the configured PID ceiling.

### `lamp-firewall-guard.sh`

Maintained network-side connection limiting.

---

## IPv6 connection limiting

A dedicated firewall chain was introduced:

```text
LAMP_GUARD
```

attached to:

```text
DOCKER-USER
```

The rules limited excessive concurrent connections to the Lamp service while allowing established traffic.

Representative late-game limits were around:

```text
per-source concurrent connections > 6 → reject
global concurrent connections > 12    → reject
```

This materially reduced abusive connection pressure.

---

## Redis helper

The Redis helper was also modified with an absolute timeout to prevent helper processes from leaking indefinitely.

Compare:

```text
defense/redis.original.sh
defense/redis.sh
```

---

## Offensive tooling

The `exploits/` directory preserves the progression of Lamp research.

The files currently retain their original competition names:

```text
lamp.py
lamp2.py
lamp3.py
lamp4.py
lamp5.py
lamp_probe.py
lamp_scan.py
lamp_scan2.py
```

They are intentionally preserved as working competition artifacts rather than rewritten after the fact.

---

## Defensive validation

After multiple hardening iterations, normal service flows again completed successfully, including:

```text
REGISTER 200
LOGIN 200
ADD 302
TICK 302
```

The main operational lesson was that a defense could not be judged only by whether it blocked abusive traffic. It also had to preserve checker-compatible behavior.

---

## Main lessons

- expensive worker processes need explicit concurrency control
- application limits and network limits solve different parts of the problem
- watchdogs are useful but can become harmful if they restart too aggressively
- resource limits must be validated against legitimate checker traffic
- signal handling matters under sustained concurrency
- availability defense can consume more competition time than exploitation

---

## Files

```text
lamp/
├── README.md
├── defense/
│   ├── docker-compose.original.yml
│   ├── docker-compose.yml
│   ├── entrypoint.original.sh
│   ├── entrypoint.sh
│   ├── redis.original.sh
│   ├── redis.sh
│   └── guards/
│       ├── lamp-firewall-guard.sh
│       ├── lamp-health-guard.sh
│       ├── lamp-pid-guard.sh
│       └── lamp-space-guard.sh
└── exploits/
    ├── lamp.py
    ├── lamp2.py
    ├── lamp3.py
    ├── lamp4.py
    ├── lamp5.py
    ├── lamp_probe.py
    ├── lamp_scan.py
    └── lamp_scan2.py
```
