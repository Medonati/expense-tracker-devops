# Chapter 01 – Docker Artifact Traceability

## Overview

After establishing the Jenkins pipeline and Docker image build process, the next objective was to understand how the Docker image produced by the pipeline can be treated as a reliable and traceable software artifact.

The focus of this milestone was not simply creating a Docker image, but understanding how an artifact can be identified, versioned, connected to the source code that produced it, and verified after the build.

The Expense Tracker project uses Docker images as its primary application artifact.

---

# Objectives

The objectives of this milestone were to:

* Understand Docker images as software artifacts.
* Understand the role of Docker BuildKit and Buildx.
* Connect Git release tags with Docker image versions.
* Capture the exact Git commit used to produce an artifact.
* Embed build metadata into the Docker image.
* Verify that the metadata inside the image matches the Jenkins build information.
* Establish artifact traceability from source code to Docker image.

---

# Docker Images as Artifacts

The application is packaged into a Docker image using the project's backend Dockerfile.

The Docker image represents a deployable version of the application.

The basic artifact flow is:

```text
Source Code
     │
     ▼
Jenkins Pipeline
     │
     ▼
Docker Build
     │
     ▼
Docker Image
     │
     ▼
Container Registry
````

The resulting image is versioned using Docker tags, for example:

```text
medonati/expense-tracker-backend:1.0.1
```

This allows different releases of the application to be identified and stored independently.

---

# Docker Image Versioning

The pipeline uses Git release tags to determine Docker image versions.

For example:

```text
Git release tag:
v1.0.3

Docker image tag:
1.0.3
```

The Jenkins pipeline removes the `v` prefix from the Git release tag before assigning the Docker image tag.

This creates a consistent relationship between a Git release and its Docker artifact.

```text
Git Tag
   │
   ▼
v1.0.3
   │
   ▼
Docker Image
   │
   ▼
1.0.3
```

---

# Authentication, Authorization and Artifact Identity

During the Docker registry workflow, we also distinguished between authentication and authorization and the identity of the artifact itself.

These concepts answer different questions:

| Concept | Question it answers |
|---|---|
| Authentication | Who are you? |
| Authorization | What are you allowed to do? |
| Artifact Identity | What artifact is this? |
| Traceability | Where did this artifact come from? |
| Integrity | Has this artifact been altered? |

For example, when Jenkins logs into Docker Hub, the credentials authenticate Jenkins to the registry.

Authorization then determines whether that authenticated identity has permission to perform an operation such as pushing an image to:

```text
medonati/expense-tracker-backend

Authentication
      ↓
Who is interacting with the registry?

Authorization
      ↓
What can that identity do?

Artifact Identity
      ↓
What image/version is this?

Traceability
      ↓
Which source commit produced it?

Integrity
      ↓
Has the artifact been changed?


# Git Commit Traceability

A version number identifies a release, but it does not provide the exact source-code identity of the artifact.

To solve this, Jenkins captures the Git commit SHA using:

```bash
git rev-parse HEAD
```

For the successful `v1.0.3` release, the commit was:

```text
34729d8b82e3dda12030096dae05126480bac78e
```

Jenkins therefore had access to three important pieces of release information:

```text
Git Tag:
v1.0.3

Docker Version:
1.0.3

Git Commit:
34729d8b82e3dda12030096dae05126480bac78e
```

This allows the Docker artifact to be traced back to the exact source-code commit that produced it.

---

# Docker Build Metadata

The Git commit, release version, and build timestamp were passed from Jenkins into the Docker build as build arguments.

The build used:

```text
VERSION
GIT_COMMIT
BUILD_DATE
```

These values were defined in the Dockerfile using:

```dockerfile
ARG VERSION
ARG GIT_COMMIT
ARG BUILD_DATE
```

The values were then stored in the Docker image using OCI image labels:

```dockerfile
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
```

This means the Docker image itself carries information about the build that produced it.

---

# Docker LABEL Syntax Challenge

An error was encountered while implementing the image metadata.

The initial configuration incorrectly repeated `LABEL` while using a line continuation:

```dockerfile
LABEL org.opencontainers.image.version="${VERSION}" \
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
LABEL org.opencontainers.image.created="${BUILD_DATE}"
```

Docker returned:

```text
Syntax error - can't find = in "LABEL".
Must be of the form: name=value
```

The issue was caused by the backslash.

A backslash tells Docker that the instruction continues on the next line. Therefore, the second `LABEL` was interpreted as part of the same instruction rather than as a new Docker instruction.

The corrected configuration was:

```dockerfile
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
```

This successfully allowed the image metadata to be created.

---

# Artifact Verification

After successfully building the corrected image, the artifact was independently inspected using:

```bash
docker inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{json .Config.Labels}}'
```

The resulting metadata was:

```json
{
  "org.opencontainers.image.created": "2026-08-14T12:46:38Z",
  "org.opencontainers.image.revision": "34729d8b82e3dda12030096dae05126480bac78e",
  "org.opencontainers.image.version": "1.0.3"
}
```

The values matched the information generated by Jenkins:

```text
Version:
1.0.3

Git Commit:
34729d8b82e3dda12030096dae05126480bac78e

Build Date:
2026-08-14T12:46:38Z
```

This confirmed that the metadata was successfully embedded into the Docker artifact.

---

# Artifact Traceability

The completed workflow can now be represented as:

```text
Git Release Tag
      │
      ▼
v1.0.3
      │
      ▼
Exact Git Commit
      │
      ▼
34729d8b...
      │
      ▼
Jenkins
      │
      ├── Version
      ├── Commit SHA
      └── Build Date
      │
      ▼
Docker Build
      │
      ▼
Docker Image
      │
      ├── Version
      ├── Git Revision
      └── Creation Date
```

The result is a traceable Docker artifact.

Given the image:

```text
medonati/expense-tracker-backend:1.0.3
```

we can determine:

* Which release it represents.
* Which Git commit produced it.
* When it was built.

---

# Challenges Encountered

The main challenges encountered during this milestone included:

* Understanding how Git tags relate to exact commits.
* Handling a failed release tag and moving the tag to the corrected commit.
* Resolving Docker `LABEL` syntax errors.
* Passing Git metadata from Jenkins into the Docker build.
* Verifying that the final Docker artifact contained the expected metadata.

---

# Results

At the completion of this milestone, Jenkins successfully:

* Identified the Git release tag.
* Determined the Docker image version.
* Captured the exact Git commit SHA.
* Passed build metadata into the Docker build.
* Built the versioned Docker image.
* Embedded OCI metadata into the image.
* Verified the resulting Docker artifact.

The final artifact was:

```text
medonati/expense-tracker-backend:1.0.3
```

with the corresponding source commit:

```text
34729d8b82e3dda12030096dae05126480bac78e
```

---

# Lessons Learned

* A Docker image is a software artifact produced by the build process.
* Artifact versioning makes different releases identifiable.
* A Git tag identifies a release, while a commit SHA identifies the exact source code.
* Build metadata can be embedded directly into a Docker image.
* OCI labels provide a standard way to store image metadata.
* Artifact verification should be performed rather than relying only on pipeline logs.
* Buildx provides additional BuildKit capabilities, but it does not mean every build must use `docker buildx build`.
* A traceable artifact makes it possible to determine exactly which source code produced a deployed image.

---

# Conclusion

This milestone established the foundation for Docker artifact management in the Expense Tracker project.

The pipeline no longer produces an anonymous Docker image. Each release artifact can now be associated with a specific application version, Git commit, and build timestamp.

This creates a clear relationship between source code and the artifact that will eventually be deployed:

```text
Source Code
     ↓
Git Commit
     ↓
Git Release
     ↓
Jenkins Build
     ↓
Docker Image
     ↓
Traceable Artifact
```

This foundation will allow future artifact management practices to build upon a reliable and identifiable Docker artifact.

````