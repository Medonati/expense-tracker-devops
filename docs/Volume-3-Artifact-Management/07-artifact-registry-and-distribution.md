# 07 — Artifact Registry & Distribution

## Objective

Understand the role of a container registry in storing and distributing Docker artifacts, and how authentication and authorization control registry access.

## Registry Workflow

Our artifact flow is:

```text
GitHub
   ↓
Jenkins
   ↓
Docker Build
   ↓
Docker Image
   ↓
Docker Hub
   ↓
Deployment Environment
````

Jenkins builds the artifact, while the registry provides centralized storage and distribution.

Our Docker Hub repository is:

```text
medonati/expense-tracker-backend
```

with release tags such as:

```text
1.0.0
1.0.1
1.0.2
1.0.3
```

## Registry Distribution

The `1.0.3` image was removed locally and pulled again from Docker Hub:

```bash
docker pull medonati/expense-tracker-backend:1.0.3
```

Docker returned the same artifact digest:

```text
sha256:c52677f4b0bcb5950a601222851848fbe49f3cac3e268cbad1f6be926189c13a
```

This demonstrated:

```text
Build once
    ↓
Push to registry
    ↓
Store artifact
    ↓
Pull the same artifact
```

The image metadata was also preserved after the registry round trip:

```text
version  → 1.0.3
revision → 34729d8b82e3dda12030096dae05126480bac78e
created  → 2026-08-14T12:46:38Z
```

## OCI Image Structure

`docker manifest inspect` showed that the registry stores an OCI image index containing image manifests for specific platforms.

Our artifact included a:

```text
linux/amd64
```

manifest.

This introduced the concept that a registry can contain an image index rather than simply one flat image object.

## Authentication & Authorization

Registry access involves two separate concepts:

**Authentication** — Who are you?

**Authorization** — What are you allowed to do?

For example, a Jenkins identity may be authorized to:

```text
Pull images     ✓
Push images     ✓
Delete images   ✗
```

Jenkins therefore uses registry credentials when authenticating to Docker Hub before pushing release artifacts.

## Key Lesson

A container registry separates **artifact creation from artifact distribution**.

Jenkins builds the artifact once, the registry stores it, and deployment environments retrieve the same artifact rather than rebuilding the application independently.
