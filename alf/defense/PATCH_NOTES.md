# Alf Defense — Patch Notes

## Vulnerability

Alf accepted uploaded `.typ` and `.tar` files and extracted tar archives into a per-user project directory before rendering `main.typ`.

The vulnerable implementation relied on normal archive extraction without sufficiently constraining archive members.

This created a path traversal / link-following risk where a malicious archive could cause the service to read files outside the intended project directory.

That primitive later became important offensively because it could expose sensitive files such as the Flask secret or checker-created files.

---

## Vulnerable version

See:

```text
main.py.vulnerable
```

The vulnerable behavior extracted the uploaded archive and then opened:

```text
<project_path>/main.typ
```

without fully validating archive members first.

---

## Patched version

See:

```text
main.py
```

The archive is inspected before extraction.

The defensive checks reject:

### Absolute paths

Example:

```text
/etc/passwd
```

Rejected because:

```python
member_path.is_absolute()
```

### Parent traversal

Example:

```text
../../secret
```

Rejected when:

```python
".." in member_path.parts
```

### Symbolic links

Rejected with:

```python
member.issym()
```

### Hard links

Rejected with:

```python
member.islnk()
```

---

## Why link rejection mattered

Even if the archive member path itself is safe, a symbolic or hard link can redirect later file access outside the intended extraction root.

Because the service later reads and rewrites `main.typ`, allowing links would preserve an escape path even after simple traversal checks were added.

---

## Validation

After patching, I tested both expected and malicious behavior.

### Normal `.typ`

A normal Typst document still rendered successfully.

### Normal tar project

A tar containing a regular:

```text
main.typ
```

continued to produce a PDF.

### Symlink tar

A tar containing:

```text
main.typ -> content.typ
```

was rejected.

This confirmed that the patch blocked link-based archive abuse without breaking normal archive conversion.

---

## Security property after patch

The intended invariant became:

```text
every extracted archive member must represent a normal path
inside the project directory and must not redirect through links
```

The patch did not attempt to redesign the application. It was intentionally narrow so that checker-compatible behavior would remain intact.

---

## Attack-defense lesson

A good patch in an attack-defense CTF must satisfy both:

```text
close exploit
AND
preserve checker functionality
```

A broad change that simply disabled archive conversion would likely have harmed service availability.

This patch instead targeted the dangerous archive semantics while preserving expected uploads.
