# FAUST CTF 2026 — Architecture Notes

## Competition network

The vulnbox participated in the FAUST IPv6 network through WireGuard.

Relevant ranges:

```text
fd66:666::/32
fd66:777::/32
```

Our team service host:

```text
fd66:666:721::2
```

The FAUST submission host was reachable over the competition VPN.

---

## Vulnbox

The competition environment ran inside a Proxmox VM.

Approximate resources:

```text
4 vCPU
8 GiB RAM
40 GiB disk
```

The vulnbox hosted all challenge services through Docker Compose.

---

## Service map

```text
                    FAUST IPv6 network
                           │
                    fd66:666:721::2
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
        Alf              Lamp         Rufflecopter
       :1986             :1337            :35244
          │                │                 │
      Flask app          socat           Rust service
          │                │                 │
      PostgreSQL         XeLaTeX          PostgREST
                                             │
                                         PostgreSQL

                   Interstellar Mission Control
                              :8080
```

---

# Alf architecture

## Application

Alf used:

```text
Flask
Flask-Login
SQLAlchemy
PostgreSQL
Typst
```

Core concepts:

```text
User
Translation
Project directory
Uploaded .typ/.tar
Generated PDF
```

Per-user project data lived under:

```text
/app/data/<USER_ID>/
```

### Security boundary

The intended security boundary was that uploaded project content should remain inside its own project directory.

The attack path broke this boundary through archive/file handling.

### Type 0 flag path

Logical flow:

```text
checker creates user
→ checker stores flag in user-visible translation state
→ flag ID corresponds to victim user
```

Exploitation:

```text
read Flask secret
→ forge session for victim
→ access translation history
```

### Type 1 flag path

Logical storage:

```text
/app/data/<USER_UUID>/flag/flag.typ
```

The checker flag ID was enough to derive the exact file path.

---

# Lamp architecture

## Network layer

Public TCP:

```text
:1337
```

`socat` accepted IPv6 connections and forked an entrypoint process.

Simplified:

```text
client
  ↓
socat
  ↓
entrypoint.sh
  ↓
XeLaTeX
  ↓
HTTP-like response
```

## Supporting services

Lamp also used:

```text
MariaDB
Redis
cleanup container
```

## Failure mode

Each incoming request could result in expensive XeLaTeX execution.

Under concurrency:

```text
many connections
→ many entrypoint processes
→ many XeLaTeX processes
→ high CPU/memory
→ PID pressure
→ OOM/fork failures
```

## Defensive architecture

Mitigations added layers:

```text
ip6tables connlimit
        ↓
socat
        ↓
queue / global worker slots
        ↓
timeout
        ↓
XeLaTeX
```

Additional guards monitored:

```text
process count
large temporary files
container health
```

---

# Rufflecopter architecture

Rufflecopter used:

```text
Rust application
PostgREST
PostgreSQL
```

Public service:

```text
:35244
```

Internal API patterns included:

```text
/users
/rents
/tokens
/valid_tokens
```

The application queried PostgREST rather than talking directly to PostgreSQL.

Relevant user flows:

```text
register
login
rent
garage
receipts
```

Receipt data could contain encoded flag material.

---

# Tulip discovery

During offensive scanning, port 3000 was exposed on some remote teams.

On team 856 it served a Tulip traffic-analysis frontend.

Tulip architecture:

```text
browser frontend
→ /api/*
→ authenticated traffic-analysis backend
```

Observed API concepts included:

```text
services
traffic
requests
search
flow
download
```

Authentication supported API-key/Bearer-token mechanisms.

No token was recovered.

---

# Interstellar Mission Control

IMC exposed:

```text
:8080
```

The service remained comparatively stable during the event.

Several exploit scripts were built around checker/storage behavior, but it did not become the main scoring path.

---

# Operational architecture

The practical workflow used three parallel roles:

```text
Terminal 1: defense / service health
Terminal 2: exploit research
Terminal 3: live harvesting / submission
```

This separation became important late in the event.

The Alf live harvester continued collecting and submitting flags while Lamp defense and Rufflecopter research happened independently.

---

# Post-event repository architecture

The public repository intentionally separates:

```text
exploit code
defensive patches
incident-response scripts
documentation
```

Raw runtime artifacts remain private.

Excluded from the public repository:

```text
flags
checker data
teams.json snapshots
VPN configuration
submission logs
live credentials
full Docker inspection dumps
raw service logs
```

This keeps the public project useful for portfolio/review purposes without exposing unnecessary competition data.
