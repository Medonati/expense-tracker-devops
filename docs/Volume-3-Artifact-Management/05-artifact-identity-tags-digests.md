# 05 — Artifact Identity: Tags, Digests & Immutability

## Objective

Understand how Docker identifies artifacts and why tags and digests serve different purposes in artifact management and deployment.

## Tag vs Image ID vs Digest

A Docker image can be referenced using a human-friendly tag:

```text
medonati/expense-tracker-backend:1.0.3
````

The local Docker image also has an image ID:

```text
sha256:c52677...
```

The registry provides a content-addressed digest:

```text
medonati/expense-tracker-backend@sha256:c52677...
```

The tag and digest can resolve to the same artifact, but they represent it differently:

```text
:1.0.3
   ↓
human-friendly version reference

@sha256:...
   ↓
exact content-addressed artifact
```

## Useful Commands

Inspect the image ID:

```bash
docker inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{.Id}}'
```

Inspect the registry digest:

```bash
docker inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{json .RepoDigests}}'
```

Retrieve the digest directly:

```bash
docker image inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{index .RepoDigests 0}}'
```

Verify that a tag and digest resolve to the same image:

```bash
docker image inspect \
  medonati/expense-tracker-backend@sha256:<digest> \
  --format '{{.RepoTags}}'
```

## Immutability

A Docker tag is a movable reference. For example:

```text
:1.0.3
   ↓
Image A
```

The tag could later be moved to:

```text
:1.0.3
   ↓
Image B
```

A digest instead identifies the exact image content.

Therefore:

* **Tags** are convenient for release and human-readable versioning.
* **Digests** are useful for pinning an exact artifact and improving deployment reproducibility.

## Artifact Traceability

Our pipeline now has multiple connected identities:

```text
Git tag
   ↓
Git commit SHA
   ↓
Jenkins build
   ↓
Docker image tag
   ↓
Docker image metadata
   ↓
Registry digest
```

The Git commit is also stored in the Docker image metadata, allowing the built artifact to be traced back to its source revision.

## Key Lesson

A tag tells us **which version we intend to reference**.

A digest tells us **exactly which artifact we are referencing**.

For reproducible deployments, immutable digest references provide stronger artifact identity than relying on a tag alone.