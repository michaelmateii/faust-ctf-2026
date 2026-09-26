# FAUST CTF 2026 — Timeline

This timeline summarizes the main technical milestones from the event.

Times are approximate and focus on significant decisions rather than every individual command.

---

## Pre-event preparation

Before the competition:

- provisioned the FAUST testbox VM on Proxmox
- configured SSH access
- configured the FAUST WireGuard VPN
- verified IPv6 connectivity
- confirmed access to the submission host
- confirmed all service containers were running
- disabled password-based SSH login

---

## Early competition phase

### Service triage

Initial focus was understanding:

- Alf
- Lamp
- Rufflecopter
- Interstellar Mission Control

The first priority was to keep services available while identifying obvious attack surfaces.

### Alf

Inspected:

- Flask application structure
- PostgreSQL schema
- file conversion workflow
- user/project storage
- cleanup behavior
- tar extraction

A tar-based file-read path became the main Alf research direction.

### Lamp

Observed XeLaTeX as the central execution component.

Resource exhaustion rapidly became a major issue.

---

## Mid competition — Alf breakthrough

### Checker mapping

On the local Alf instance:

- current checker flag IDs were compared against database users
- user UUIDs were correlated with project directories
- Type 1 IDs were found to map directly to:

```text
/app/data/<UUID>/flag/flag.typ
```

This became the strongest direct exploit path.

### Type 0 path

Remote arbitrary file read exposed a Flask secret.

That enabled:

```text
forge Flask session
→ impersonate checker-created user
→ request /translation_history
→ recover flag
```

### First successful remote flags

Multiple remote teams were found vulnerable.

Broad scans identified teams including:

```text
228
290
495
639
750
763
774
865
```

Not all remained vulnerable for the full event.

---

## Mid competition — Lamp availability incident

Lamp entered repeated failure states.

Symptoms included:

```text
OOM kills
PID exhaustion
fork failures
connection resets
```

### First mitigations

Added:

- Docker memory limits
- PID limits
- XeLaTeX timeouts
- global worker slots

### Cleanup problems

Signal handling and temporary-directory cleanup caused races.

The trap logic was changed from:

```text
trap cleanup EXIT HUP INT TERM
```

to explicit exit-on-signal handlers.

### Queue tuning

Queue thresholds were adjusted several times.

Trade-off observed:

```text
short queue → legitimate 503s
long queue  → process buildup
```

### Watchdogs

Created:

- space guard
- health guard
- PID guard

### Firewall controls

Added an IPv6 `LAMP_GUARD` chain.

Connection limiting reduced abusive concurrent traffic.

---

## Late competition — Alf automation

Manual Alf exploitation was converted into a live harvesting loop.

The loop:

1. refreshed `teams.json`
2. fetched current Type 1 IDs
3. skipped already-seen IDs
4. probed known-vulnerable teams
5. extracted current flags
6. submitted immediately

### Problems discovered

- disappearing teams caused `KeyError`
- old IDs were retried after restarts
- long probe timeouts caused flag expiry
- broad target sets reduced scoring efficiency

### Optimizations

The late-game target list was narrowed to the most productive teams.

Timeouts were reduced.

Immediate submission became the default.

---

## Late competition — Rufflecopter/Tulip branch

Scanned for exposed port 3000.

Found:

```text
team 115
team 856
```

Team 115 reset HTTP requests.

Team 856 exposed a Tulip web interface.

Frontend analysis revealed:

- API routes
- download endpoint
- traffic-analysis features
- token-based API authentication

No usable API token was recovered.

The branch was abandoned to preserve time for Alf.

---

## Final minutes

### Defense

Verified own service ports remained reachable.

### Offense

Kept the Alf live harvester running in a separate terminal.

Accepted flags continued to appear late in the event.

### Documentation

Preserved:

- exploit scripts
- Lamp guard scripts
- pre-patch backups
- submission logs
- service logs
- final Docker state
- firewall state
- network state
- database schema
- service source trees

---

## Post-event

Created a 1.9 GB private archive containing:

```text
/root/faust/
/srv/alf/
/srv/lamp/
/srv/rufflecopter/
/srv/interstellar-mission-control/
```

Transferred it off the VM with SCP.

Verified integrity using SHA-256.

Then created a sanitized public repository containing:

- exploit scripts
- before/after defensive patches
- Lamp guards
- documentation
- no raw flags
- no VPN secrets
- no live credentials
- no checker runtime data
