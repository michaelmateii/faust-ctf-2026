# Interstellar Mission Control

## Overview

This directory contains exploit research and tooling developed for the **Interstellar Mission Control** service during FAUST CTF 2026.

IMC remained comparatively stable during my run and did not become the main scoring path, but several exploit ideas were investigated around different checker/storage behaviors.

---

## Exploit scripts

### `imc_store0.py`

Research targeting one checker/storage path.

### `imc_store1.py`

Research targeting a second storage/checker path.

### `imc_crew.py`

Research focused on crew-related state and retrieval behavior.

### `imc_nullship.py`

Research around edge cases involving ship state / null-like values.

---

## Why this service was deprioritized

During the competition, Alf produced a much stronger return on time spent.

Once Alf had a confirmed exploit and could be automated, continued deep IMC work had a lower expected scoring value.

This is one of the areas I would revisit after the competition to determine whether:

- the checker model exposed a stronger mapping
- one of the partial exploit paths could have been made reliable
- additional local service analysis would have produced a direct flag path

---

## Main lessons

- attack-defense prioritization matters as much as exploit quality
- promising research branches should be preserved even if they are not completed
- checker/storage mapping should be performed early for every service
- incomplete exploit scripts can still be useful post-event for reconstructing hypotheses and test methodology

---

## Files

```text
imc/
├── README.md
└── exploits/
    ├── imc_crew.py
    ├── imc_nullship.py
    ├── imc_store0.py
    └── imc_store1.py
```
