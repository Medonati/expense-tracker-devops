# 06 — Artifact Traceability & Provenance

## Objective

Understand how a Docker artifact can be traced back to the exact Git revision that produced it.

## Artifact Provenance

Our build process connects the source revision to the Docker artifact:

```text
Git tag
   ↓
Git commit SHA
   ↓
Jenkins build
   ↓
Docker build
   ↓
Image metadata
   ↓
Registry artifact
````

For release `v1.0.3`:

```text
Git tag:     v1.0.3
Git commit:  34729d8b82e3dda12030096dae05126480bac78e
Image tag:   1.0.3
```

The Git commit was passed into the Docker build as `GIT_COMMIT` and stored as an OCI image label.

## Verifying Provenance

The image metadata was inspected with:

```bash
docker inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{json .Config.Labels}}'
```

The image contained:

```text
org.opencontainers.image.version  → 1.0.3
org.opencontainers.image.revision → 34729d8b82e3dda12030096dae05126480bac78e
org.opencontainers.image.created   → 2026-08-14T12:46:38Z
```

The embedded revision was verified against Git:

```bash
git rev-parse 'v1.0.3^{}'
```

Both returned:

```text
34729d8b82e3dda12030096dae05126480bac78e
```

This confirmed that the Docker artifact was built from the commit referenced by `v1.0.3`.

## Current HEAD vs Release Revision

The repository later moved forward:

```text
v1.0.3 revision:
34729d8b...

Current HEAD:
20be296...
```

This is expected. The artifact retains the revision from which it was originally built rather than changing when the repository receives new commits.

## Key Lesson

Artifact provenance answers:

> **"Which source revision produced this artifact?"**

Embedding the Git commit, version, and build timestamp in the Docker image makes the artifact traceable and improves debugging, auditing, and release verification.
