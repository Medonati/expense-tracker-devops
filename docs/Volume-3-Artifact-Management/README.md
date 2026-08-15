# Volume 3 — Artifact Management

## Overview

This volume focuses on managing Docker artifacts throughout their lifecycle — from building and optimizing images to securing, versioning, distributing, tracing, and eventually cleaning them up.

The goal is to move beyond simply knowing Docker commands and understand the reasoning behind artifact-management decisions in a real DevOps workflow.

## What We Covered

### 01 — Artifact Management

Introduced container images as build artifacts and established the importance of treating artifacts as versioned, identifiable outputs of the CI/CD process.

### 02 — Docker Image Optimization

Compared standard Node.js images with slim variants and examined how base-image selection affects image size.

We learned that image optimization is a trade-off involving:

- Image size
- Security surface
- Compatibility
- Build requirements
- Operational needs

### 03 — Container Image Security

Introduced image vulnerability scanning using Trivy and examined vulnerabilities originating from both the operating-system layer and Node.js dependencies.

### 04 — Vulnerability Remediation

Used Trivy results to identify vulnerable dependencies and applied targeted dependency upgrades.

Remediation was followed by testing and another security scan to verify improvement.

### 05 — Artifact Identity: Tags & Digests

Explored the difference between mutable image tags and immutable content digests.

Tags provide human-friendly versioning:

```text
1.0.3
````

while digests provide content-based identity:

```text
sha256:...
```

We also connected image metadata with Git commits to improve artifact traceability.

### 06 — Artifact Traceability & Provenance

Added OCI metadata to images, including:

* Build timestamp
* Git revision
* Application version

We verified that the image's Git revision matched the Git tag used to build the release.

This established a connection between:

```text
Git Commit
    ↓
Docker Image
    ↓
Release Version
```

### 07 — Artifact Registry & Distribution

Used Docker Hub as the artifact registry.

We demonstrated:

```text
Build
  ↓
Push
  ↓
Registry
  ↓
Pull
```

The image was removed locally and pulled again from Docker Hub. Its digest and OCI metadata were verified after the pull.

We also introduced registry authentication and authorization.

### 08 — Artifact Lifecycle & Cleanup

Examined Docker storage using:

```bash
docker system df
docker system df -v
```

We investigated:

* Images
* Shared and unique image layers
* Build cache
* Anonymous volumes
* Named persistent volumes

Cleanup was performed selectively rather than using broad destructive pruning.

MongoDB volumes were preserved because they contained persistent data, while unused anonymous volumes were removed after verification.

## Key Principles

### Build Once, Distribute the Artifact

The same built artifact should be promoted across environments rather than rebuilding independently.

### Tags Are Convenient; Digests Are Immutable

Use meaningful version tags for humans while understanding that digests provide stronger artifact identity.

### Security Is Part of the Build Process

Images should be scanned and vulnerabilities should be evaluated and remediated before release.

### Traceability Matters

A production image should be traceable back to the source code and release that produced it.

### Optimize Deliberately

Smaller images can reduce storage, transfer time, and attack surface, but image selection must consider compatibility and operational requirements.

### Cleanup Requires Context

Not everything Docker reports as reclaimable should be deleted.

Consider:

* Rollback requirements
* Build cache
* Temporary artifacts
* Persistent application data
* Storage constraints

## Volume Architecture

The artifact lifecycle explored in this volume can be summarized as:

```text
              Git Repository
                    │
                    ▼
                 Jenkins
                    │
                    ▼
              Docker Build
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
       Security            Metadata
        Scan              & Versioning
          │                   │
          └─────────┬─────────┘
                    ▼
             Docker Image
                    │
                    ▼
              Docker Registry
                    │
                    ▼
          Deployment Environment
                    │
                    ▼
             Retain / Cleanup
```

## Outcome

By the end of this volume, the focus has moved from:

> "How do I build a Docker image?"

to:

> "How do I manage a Docker artifact throughout its lifecycle?"

The artifact is now treated as a controlled, versioned, traceable, security-checked, distributable component of the CI/CD pipeline.