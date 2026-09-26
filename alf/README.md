# Alf

## Overview

Alf was the most successful offensive target during my FAUST CTF 2026 run.

The service combined:

- Flask
- Flask-Login
- SQLAlchemy
- PostgreSQL
- Typst
- file upload and conversion

Two different checker flag patterns were identified and exploited.

---

## Type 0 exploit

The first flag type could be reached through an authenticated user's translation history.

The exploit chain was:

```text
arbitrary file read
→ recover Flask secret
→ forge Flask session cookie
→ impersonate checker-created victim user
→ GET /translation_history
→ extract flag
```

The relevant session structure was:

```python
{
    "_user_id": VICTIM_ID,
    "_fresh": True,
}
```

The Flask signing serializer was used locally to generate a valid session cookie.

This allowed authenticated access as the victim user without knowing that user's password.

---

## Type 1 exploit

The second flag type was stored directly in a per-user project directory.

The checker flag ID mapped to:

```text
/app/data/<FLAG_ID>/flag/flag.typ
```

This meant the same file-read primitive could be used directly against the checker-generated file.

No session forgery was required.

---

## Why checker mapping mattered

The most useful discovery came from comparing current checker flag IDs against the local service state.

That revealed:

- checker-created users
- user UUIDs
- translation ownership
- filesystem project paths
- the direct relationship between Type 1 IDs and `/app/data/<UUID>/flag/`

This made exploitation much more reliable than generic probing.

---

## Partial patches observed

A major lesson was that some teams patched obvious proof-of-concept targets while leaving the real checker path accessible.

For example:

```text
/etc/hostname              patched
/proc/self/environ         patched
/app/src/...               patched
/app/data/<FLAG_ID>/...    still readable
```

For attack-defense, testing the actual protected resource was therefore more useful than testing a generic file.

---

## Exploit tooling

### `alf_probe.sh`

Generic remote file-read probe.

Used to:

- register
- log in
- upload a crafted project/archive
- trigger conversion
- classify the result
- extract readable content

Observed result classes included:

```text
VULNERABLE
PATCHED
DOWN
NONPDF
ERROR500
```

### `alf_read.sh`

Earlier direct file-read helper.

Useful during initial manual testing.

### `alf_type0_sweep.sh`

Automates the Type 0 chain:

```text
recover secret
→ forge victim session
→ fetch translation history
→ extract flags
```

### `alf_type1_sweep.sh`

Targets known-vulnerable teams using current Type 1 flag IDs.

### `alf_type1_allteams.sh`

Broader discovery scanner used to find teams that still exposed current checker files.

### `alf_live_loop.sh`

Late-game live harvester.

It:

1. refreshes `teams.json`
2. obtains current flag IDs
3. skips already-seen IDs
4. probes selected teams
5. extracts `FAUST_Q1...`
6. submits immediately
7. records state for later cycles

This was the most effective scoring automation once flag lifetime became the main constraint.

---

## Defensive patch

The service accepted uploaded `.typ` and `.tar` files.

The archive-handling path was hardened by validating tar members before extraction.

The defensive version rejects:

- absolute paths
- `..` traversal
- symbolic links
- hard links

Relevant comparison files:

```text
defense/main.py.vulnerable
defense/main.py
```

The goal was to stop archive-based escape while preserving normal `.typ` and ordinary tar project conversion.

---

## Main lessons

- inspect local checker state before attacking remotely
- map flag IDs to actual storage objects
- test the real checker path after competitors begin patching
- automate immediately after the first reliable exploit
- submit flags as soon as they are recovered
- cache seen IDs to avoid wasting time on duplicates
- use short failure timeouts late in the competition

---

## Files

```text
alf/
├── README.md
├── defense/
│   ├── main.py
│   └── main.py.vulnerable
└── exploits/
    ├── alf_live_loop.sh
    ├── alf_probe.sh
    ├── alf_read.sh
    ├── alf_type0_sweep.sh
    ├── alf_type1_allteams.sh
    └── alf_type1_sweep.sh
```
