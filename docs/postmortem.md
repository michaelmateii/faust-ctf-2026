# FAUST CTF 2026 — Postmortem

## Overview

I participated in **FAUST CTF 2026** as a solo player in an attack-defense format.

The event required me to operate and defend four live services while simultaneously analyzing opponent services, understanding checker behavior, exploiting vulnerabilities, collecting flags, and preserving availability.

The four services were:

- Alf
- Interstellar Mission Control
- Lamp
- Rufflecopter

The strongest offensive result came from **Alf**, while the largest defensive workload came from **Lamp**.

---

## What I achieved

### Offensive

The main successful offensive chain was against Alf.

I identified two useful flag-storage patterns:

#### Type 0

```text
arbitrary file read
→ recover Flask secret
→ forge Flask session
→ impersonate checker-created user
→ request /translation_history
→ extract flag
```

#### Type 1

Checker flag IDs mapped directly to:

```text
/app/data/<FLAG_ID>/flag/flag.typ
```

This allowed the same arbitrary-file-read primitive to recover flags directly.

I then built automation around this:

```text
refresh teams.json
→ fetch current flag IDs
→ target known-vulnerable teams
→ extract flags
→ deduplicate
→ submit immediately
```

This was important because flags expired quickly and batch collection often resulted in `OLD` submissions.

---

## Alf: key lessons

### Checker behavior matters

The most important offensive insight came from looking at my own service first.

By correlating current flag IDs with local users, database rows, and files, I learned how checker state was represented.

That transformed the problem from:

```text
"find a generic vulnerability"
```

into:

```text
"find the exact protected object associated with this checker flag ID"
```

That was much more effective.

### Partial patches are not enough

Several teams appeared patched when probing generic paths such as:

```text
/etc/hostname
/proc/self/environ
/app/src/...
```

but the actual checker path:

```text
/app/data/<FLAG_ID>/flag/flag.typ
```

was still readable.

This showed that a defensive fix should be tested against the real protected resource, not only against a proof-of-concept path.

---

## Lamp: defensive incident

Lamp became the most time-consuming defensive problem.

The service used XeLaTeX and was repeatedly pushed into resource exhaustion.

Observed failures included:

```text
Memory cgroup out of memory
Killed process ... (xelatex)
fork(): Resource temporarily unavailable
connection reset by peer
```

At peak load, the container reached high CPU usage, memory pressure, and PID exhaustion.

### Mitigations

I iteratively introduced:

- Docker memory limits
- Docker PID limits
- global XeLaTeX worker slots
- rendering timeouts
- queue limits
- signal-safe cleanup
- process watchdogs
- oversized-file cleanup
- IPv6 connection limiting with `connlimit`

The most useful architectural lesson was that **application-level worker limiting and network-level connection limiting were both needed**.

Application-only controls still allowed too many queued processes.

Network-only controls did not prevent expensive individual requests.

---

## Rufflecopter

Rufflecopter was investigated in depth but did not become a reliable scoring path.

Areas explored included:

- PostgREST-style internal API behavior
- login parameter pollution
- user/session handling
- rental receipts
- receipt decoding
- exposed port 3000 on other teams
- Tulip traffic-analysis UI

The most interesting late discovery was an exposed Tulip frontend on another team.

Its API was protected by an API token and no hard-coded token was recovered in time.

Given the remaining competition time, abandoning this branch and returning focus to Alf was the correct decision.

---

## Interstellar Mission Control

Several exploit scripts were developed for IMC around different checker/storage paths.

However, it did not become the primary scoring path.

Compared with Alf, the time-to-reliable-flag ratio was worse.

This is an area I would revisit after the event to understand whether a stronger exploit path was missed.

---

## What worked well

### 1. Investigating my own service first

This was the single most productive habit.

It revealed:

- checker-created users
- flag-ID mappings
- filesystem paths
- database relationships
- timing behavior

### 2. Turning manual exploitation into automation

The offensive process improved dramatically once I stopped manually probing individual teams and built a live harvester.

### 3. Using aggressive timeouts late in the event

A failed request in a few seconds was better than allowing one slow target to consume the lifetime of several fresh flags.

### 4. Keeping defense and offense separate

Using separate terminals for:

- service health
- exploit development
- live harvesting

made it easier to continue scoring while debugging defense.

---

## What I would improve

### 1. Automate earlier

The main Alf exploit was valuable enough that I should have automated it as soon as the first manual flag worked.

### 2. Reduce defensive over-tuning

Lamp consumed a large amount of time.

Once a mitigation reached “good enough” availability, I should have spent less time repeatedly tuning PID thresholds, worker counts, and queue durations.

### 3. Prioritize actual checker paths earlier

Generic probes were useful for discovery but became misleading once teams began partially patching.

### 4. Keep an exploit ledger

A simple live table such as:

```text
team | service | current status | exploit | last success | timeout
```

would have reduced repeated work.

### 5. Log accepted submissions from the start

The final logs were useful, but a cleaner structured log from the beginning would make post-event analysis much easier.

---

## Operational lessons

Attack-defense CTFs are not primarily about finding one clever bug.

They reward an operational loop:

```text
understand
→ exploit
→ automate
→ monitor
→ adapt
→ submit
→ preserve availability
```

The difficult part is balancing:

- offense
- defense
- service uptime
- exploit reliability
- flag freshness
- time

---

## Result

The visible scoreboard gain near the end of the event was approximately **18 points**.

The raw Alf submission log contains many accepted `OK` responses, so accepted flag count and visible scoreboard points should be treated as separate metrics.

For a final public write-up, I would report:

- official final rank
- official final score
- accepted flag count
- number of successfully exploited teams

only after verifying them from the official scoreboard/logs.

---

## Biggest takeaway

The strongest technical result was completing the full attack-defense lifecycle on Alf:

```text
understand service
→ inspect checker state
→ identify vulnerability
→ reproduce locally
→ exploit remotely
→ classify flag types
→ automate collection
→ submit live flags
→ adapt to partial patches
```

Lamp provided the complementary defensive experience:

```text
detect resource exhaustion
→ identify bottleneck
→ add limits
→ validate legitimate traffic
→ monitor under attack
→ tune without breaking availability
```

That combination made the event much more valuable than a normal jeopardy-style CTF.
