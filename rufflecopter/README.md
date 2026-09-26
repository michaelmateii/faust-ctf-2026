# Rufflecopter

## Overview

Rufflecopter was a Rust-based service backed by PostgREST and PostgreSQL.

It was investigated through:

- login behavior
- internal PostgREST requests
- rental state
- receipts
- receipt decoding
- exposed remote port scanning
- an exposed Tulip traffic-analysis interface

No reliable flag-stealing chain was operationalized before the end of the event, but the investigation produced several useful architectural findings.

---

## Architecture

Observed structure:

```text
client
→ Rust application
→ PostgREST
→ PostgreSQL
```

Internal API-style requests included paths such as:

```text
/users
/rents
/tokens
/valid_tokens
```

This indicated that the application delegated much of its data access through PostgREST.

---

## Login / parameter pollution research

Duplicate login parameters were tested to understand how the application parsed values.

A representative pattern was:

```text
username=A
username=B
password=A_PASSWORD
```

The behavior suggested last-value-style handling for duplicate parameters.

This was explored as a possible authentication-confusion primitive, but it was not converted into a reliable flag-stealing exploit during the event.

---

## Rental / receipt flow

Relevant user-facing routes included:

```text
/garage
/rent
/receipts
```

Rental form fields included:

```text
firstname
lastname
startdate
enddate
comments
```

Receipts contained encoded visual data that could potentially carry flag material.

---

## Receipt decoder

`ruff_decode_receipt.py` was developed to decode receipt output once a valid `receiptcode` was available.

The unresolved challenge was obtaining other teams' useful receipt data reliably.

---

## Exposed port 3000 investigation

A scan for publicly reachable port 3000 found at least:

```text
team 115
team 856
```

Team 115 accepted TCP connections but reset HTTP requests.

Team 856 served a **Tulip** traffic-analysis frontend rather than PostgREST.

---

## Tulip investigation

The frontend exposed JavaScript references to functionality such as:

```text
/services
/flag_regex
/flow/<id>
/download/?file=
/to_pwn/<id>
/to_single_python_request
```

The corresponding API was protected by token-based authentication.

Supported token forms included:

```text
Authorization: Bearer <token>
X-API-Key: <token>
cookie tulip_api_key
?token=<token>
```

The frontend loaded tokens from:

```text
URL token
URL key
URL api_key
localStorage tulip_api_key
sessionStorage tulip_api_key
```

No hard-coded token was recovered.

Because the remaining competition time was short and Alf was already producing accepted flags, this branch was intentionally abandoned.

---

## Main lessons

- internal architecture can often be inferred from application traffic
- PostgREST changes the attack surface significantly
- exposed auxiliary tooling can be as interesting as the service itself
- traffic-analysis platforms are valuable targets only if their authentication boundary can be crossed
- late-game exploit research should be stopped when another path has clearly higher expected value

---

## Files

```text
rufflecopter/
├── README.md
└── ruff_decode_receipt.py
```
