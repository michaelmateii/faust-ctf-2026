# Lamp Defense — Patch Notes

## Incident summary

Lamp suffered repeated resource-exhaustion failures centered around XeLaTeX execution.

The core problem was not a single crash bug. It was an operational amplification path:

```text
incoming TCP connection
→ socat forks
→ request handler starts
→ XeLaTeX executes
→ expensive CPU/memory usage
```

Under enough concurrency, the container accumulated many active or waiting processes and eventually hit memory and PID limits.

Observed symptoms included:

```text
Memory cgroup out of memory
Killed process ... (xelatex)
fork(): Resource temporarily unavailable
can't fork: Resource temporarily unavailable
connection reset by peer
```

The final defense therefore used several layers.

---

# 1. Docker resource controls

Compare:

```text
docker-compose.original.yml
docker-compose.yml
```

Resource limits were introduced and tuned during the event.

A late working configuration used approximately:

```text
memory: 3 GiB
PID limit: 128
restart policy: unless-stopped
```

These values changed while balancing resilience against legitimate checker traffic.

## Why this was necessary

Without a memory ceiling, enough XeLaTeX workers could pressure the entire vulnbox.

Without a PID ceiling, process accumulation could continue until the service or host became unable to fork.

These controls limited blast radius, but they were not sufficient by themselves.

---

# 2. Global XeLaTeX worker slots

Compare:

```text
entrypoint.original.sh
entrypoint.sh
```

A global slot mechanism was introduced using directories under `/tmp`:

```text
/tmp/lamp-xelatex-slot1
/tmp/lamp-xelatex-slot2
/tmp/lamp-xelatex-slot3
```

A request had to acquire a slot before starting XeLaTeX.

Each slot stored metadata such as:

```text
pid
born timestamp
```

This prevented every accepted connection from immediately becoming an expensive XeLaTeX process.

---

# 3. Rendering timeout

XeLaTeX was bounded with:

```bash
timeout -k 1 3   stdbuf -o0 xelatex -8bit --shell-escape /srv/main.tex
```

This gave each render a short hard lifetime.

The additional kill delay ensured that a worker that ignored the first termination signal would still be force-killed.

---

# 4. Queue control

Requests that could not acquire a slot immediately were allowed to wait briefly.

The queue threshold was tuned several times.

This revealed a direct trade-off:

```text
queue too short
→ checker / legitimate requests receive 503

queue too long
→ many waiting processes accumulate
```

The correct value was therefore operational rather than purely security-driven.

---

# 5. Signal-safe cleanup

The earlier entrypoint used:

```sh
trap cleanup EXIT HUP INT TERM
```

Under load, cleanup races produced errors involving missing temporary directories and stale slot state.

The handler was changed to:

```sh
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
```

The key change was that signal handlers now clean up and terminate explicitly instead of returning into interrupted script execution.

---

# 6. Redis helper timeout

Compare:

```text
redis.original.sh
redis.sh
```

The Redis helper was wrapped in an absolute timeout.

This reduced the risk of helper processes surviving longer than their parent request path.

The helper also checked parent liveness while handling the Redis FIFO.

---

# 7. Watchdog scripts

Located under:

```text
guards/
```

## `lamp-space-guard.sh`

Deletes oversized files from persistent Lamp storage and temporary directories.

Goal:

```text
prevent disk/tmp abuse from becoming an availability issue
```

## `lamp-health-guard.sh`

Monitors process count and service health.

It was useful during incident response, but overly aggressive restart behavior had to be avoided.

## `lamp-pid-guard.sh`

Restarts the container when process count approaches the configured ceiling.

This acted as a last-resort recovery layer.

## `lamp-firewall-guard.sh`

Maintains network-side protections for the Lamp port.

---

# 8. IPv6 connection limiting

A custom chain was added:

```text
LAMP_GUARD
```

and attached through:

```text
DOCKER-USER
```

The rules eventually allowed established traffic while limiting excessive new connections.

Representative late-game limits were approximately:

```text
per-source concurrent connections > 6 → reject
global concurrent connections > 12    → reject
```

This reduced connection pressure before requests reached `socat` and XeLaTeX.

---

# Defense layering

The final model was effectively:

```text
IPv6 connlimit
      ↓
socat
      ↓
short queue
      ↓
global XeLaTeX slots
      ↓
hard timeout
      ↓
XeLaTeX
```

with Docker resource controls and watchdogs around the entire service.

---

# Why multiple layers were needed

Each control solved a different failure mode.

### Docker limits only

Would contain damage but still allow repeated OOM/PID failures.

### Worker slots only

Would limit XeLaTeX concurrency but still allow excessive queued request processes.

### Firewall only

Would reduce connection floods but not expensive individual requests.

### Watchdog only

Would recover the service, but frequent restarts could themselves reduce checker availability.

Together, the layers were much more effective.

---

# Validation

After the defensive changes, normal service flows again completed successfully.

Representative health sequence:

```text
REGISTER 200
LOGIN 200
ADD 302
TICK 302
```

This was critical because the objective was not simply to stop attackers.

The service still had to remain checker-compatible.

---

# Main lessons

- concurrency must be controlled before expensive subprocess creation
- network and application limits complement each other
- resource ceilings protect the host but do not replace application hardening
- cleanup behavior matters under concurrency
- defensive restarts should be a last resort
- every security change needs a functional health test
- in attack-defense, availability is part of security
