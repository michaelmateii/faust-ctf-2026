# FAUST CTF 2026 — Solo Attack-Defense Write-up

This repository documents my participation in **FAUST CTF 2026** as a solo player.

The focus was not only on collecting flags, but on learning the full attack-defense workflow:

- operating four live services
- understanding checker behavior
- patching vulnerabilities without breaking availability
- reverse-engineering opponent services
- automating exploitation
- handling rotating flag IDs
- defending against active resource-exhaustion attacks
- building reusable offensive and defensive tooling

## Services

| Service | Main work |
|---|---|
| Alf | Arbitrary file read, checker ID mapping, Flask session forgery, live flag harvesting, defensive archive validation |
| Lamp | XeLaTeX exploitation research, active resource-exhaustion defense, worker limiting, watchdogs, firewall connlimits |
| Interstellar Mission Control | Exploit development around multiple checker/storage paths |
| Rufflecopter | Receipt decoding, PostgREST analysis, login behavior research, Tulip traffic-analysis investigation |

## Main offensive result: Alf

The strongest exploit chain was against Alf.

Two flag types were identified.

### Type 0

```text
arbitrary file read
→ recover Flask secret
→ forge Flask-Login session for checker-created user UUID
→ request /translation_history
→ extract flag
```

### Type 1

Checker flag IDs mapped directly to per-user project files:

```text
/app/data/<FLAG_ID>/flag/flag.typ
```

This made it possible to retrieve flags directly through the file-read primitive.

A live harvester was later built to:

```text
refresh teams.json
→ detect current flag IDs
→ target known-vulnerable teams
→ extract fresh flags
→ submit immediately
→ deduplicate previously harvested IDs
```

This was necessary because flags expired quickly and large batch scans often produced `OLD` submissions.

See:

- [`alf/README.md`](alf/README.md)
- [`alf/exploits/`](alf/exploits/)

## Main defensive incident: Lamp

Lamp used XeLaTeX and became the largest availability problem during the event.

Observed failure modes included:

```text
Memory cgroup out of memory
Killed process ... (xelatex)
fork(): Resource temporarily unavailable
connection reset by peer
```

Mitigations developed during the competition included:

- Docker memory/PID limits
- global XeLaTeX worker slots
- request timeouts
- signal-safe cleanup
- queue tuning
- PID/process guards
- oversized-file cleanup
- IPv6 connection limiting with `connlimit`

See:

- [`lamp/README.md`](lamp/README.md)
- [`lamp/defense/`](lamp/defense/)

## Repository structure

```text
alf/
  defense/
  exploits/

lamp/
  defense/
  exploits/

imc/
  exploits/

rufflecopter/

docs/
```

## Key lessons

### 1. Attack-defense is mostly an automation problem

Finding one working exploit manually is only the beginning.

The useful pipeline is:

```text
understand checker state
→ identify vulnerability
→ map flag IDs
→ automate exploitation
→ deduplicate
→ submit immediately
→ adapt to patches
```

### 2. Checker behavior is extremely valuable

Testing against my own service revealed how flag IDs mapped to users and files.

That directly enabled the most successful offensive path.

### 3. Partial patches are dangerous

Some teams patched generic reads such as:

```text
/etc/hostname
/proc/self/environ
/app/src/...
```

while current checker files under:

```text
/app/data/<FLAG_ID>/flag/flag.typ
```

remained accessible.

### 4. Availability and security can conflict

Defensive changes that were too aggressive sometimes hurt checker availability.

Every mitigation had to be tested against legitimate service flows.

### 5. Flag freshness matters

Late in the event, immediate submission was significantly more effective than collecting large batches first.

## Technologies used

- Linux
- Docker / Docker Compose
- Bash
- Python
- Flask
- PostgreSQL
- PostgREST
- Rust service analysis
- IPv6 networking
- WireGuard
- ip6tables
- XeLaTeX / TeX
- HTTP debugging
- attack-defense automation

## Notes

This repository contains sanitized competition tooling and documentation.

Raw flags, live credentials, checker data, VPN configuration, and other private competition artifacts were deliberately excluded.

## Documentation

- [`docs/postmortem.md`](docs/postmortem.md)
- [`docs/timeline.md`](docs/timeline.md)
- [`docs/architecture.md`](docs/architecture.md)

## License

Code and documentation authored by me are released under the [MIT License](LICENSE).

Some files preserve or derive from FAUST CTF 2026 challenge source for defensive patch comparisons and research documentation. Those files remain subject to the original authors' copyright and licensing terms. See [NOTICE.md](NOTICE.md).

## Disclaimer

This repository contains sanitized artifacts from FAUST CTF 2026 for educational and portfolio purposes. Raw flags, live credentials, VPN configuration, checker runtime data, and other sensitive competition artifacts have been excluded.
