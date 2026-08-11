# 03 — Docker Artifacts

## Overview

This document captures the transition from Jenkins performing Continuous Integration to Jenkins producing and publishing a Docker artifact.

The objective was to understand how a Docker image moves through the CI pipeline and how a container registry provides a central location for storing and distributing that artifact.

The Expense Tracker backend is currently the primary workload used throughout this phase of the DevOps project.

---

## Pipeline Evolution

The Jenkins pipeline initially focused on validating the application:

```text
Install Dependencies
        ↓
Verify Environment
        ↓
Validate Source
        ↓
Run Tests
```

Docker was then introduced as the artifact creation mechanism:

```text
Install Dependencies
        ↓
Verify Environment
        ↓
Validate Source
        ↓
Run Tests
        ↓
Build Docker Image
        ↓
Verify Docker Artifact
```

The pipeline has now evolved further:

```text
Install Dependencies
        ↓
Verify Environment
        ↓
Validate Source
        ↓
Run Tests
        ↓
Build Docker Image
        ↓
Verify Docker Artifact
        ↓
Authenticate with Docker Hub
        ↓
Push Docker Image
```

---

## Local Docker Artifact

The Docker image is first created on the machine running Jenkins.

For this project:

```text
medonati/expense-tracker-backend:1.0.0
```

The `docker build` operation does not automatically upload the image to Docker Hub.

It creates the image in the local Docker Engine.

```text
Jenkins VM
└── Docker Engine
      └── medonati/expense-tracker-backend:1.0.0
```

This distinction is important:

> Building an image and publishing an image are two separate operations.

---

## Docker Image Reference

The image reference follows this general structure:

```text
[registry]/[namespace]/[repository]:[tag]
```

For this project:

```text
docker.io/medonati/expense-tracker-backend:1.0.0
```

Docker Hub is Docker's default registry, so the registry hostname can be omitted:

```text
medonati/expense-tracker-backend:1.0.0
```

This is the image reference used by the Jenkins pipeline.

### Components

```text
medonati
    ↓
Docker Hub namespace

expense-tracker-backend
    ↓
Repository

1.0.0
    ↓
Image tag
```

---

## Why the Namespace Matters

The initial image was:

```text
expense-tracker-backend:1.0.0
```

When Jenkins attempted to push this image, Docker interpreted it as:

```text
docker.io/library/expense-tracker-backend:1.0.0
```

The push failed because the repository did not belong to the `medonati` namespace.

The Jenkinsfile was corrected to use:

```text
medonati/expense-tracker-backend:1.0.0
```

Docker could then resolve the destination as:

```text
docker.io/medonati/expense-tracker-backend:1.0.0
```

This successfully targeted the Docker Hub repository created for the project.

---

## Authentication

Jenkins requires authentication before it can push an image to Docker Hub.

A Docker Hub Personal Access Token was created with:

```text
Read & Write
```

permissions.

The token was not stored inside the Jenkinsfile.

Instead, it was stored securely in the Jenkins Credentials Store using:

```text
Credential ID:
dockerhub-credentials
```

The Jenkins pipeline retrieves the credential only when the Docker push stage executes.

Conceptually:

```text
Docker Hub PAT
      ↓
Jenkins Credentials Store
      ↓
dockerhub-credentials
      ↓
Jenkins Pipeline
      ↓
docker login
```

---

## Authentication vs Authorization

During the first push attempt, Jenkins successfully authenticated:

```text
Login Succeeded
```

However, the image was still named:

```text
expense-tracker-backend:1.0.0
```

Docker attempted to push to:

```text
docker.io/library/expense-tracker-backend
```

The push was rejected.

This demonstrated the difference between authentication and authorization.

### Authentication

Answers:

> Who are you?

```text
docker login
        ↓
medonati
        ↓
Authentication successful
```

### Authorization

Answers:

> Are you allowed to perform this operation on this repository?

The wrong repository caused the authorization failure.

After changing the image name to:

```text
medonati/expense-tracker-backend:1.0.0
```

the push succeeded.

---

## Jenkins Push Stage

The pipeline uses Jenkins credential binding:

```groovy
withCredentials([
    usernamePassword(
        credentialsId: 'dockerhub-credentials',
        usernameVariable: 'DOCKER_USERNAME',
        passwordVariable: 'DOCKER_PASSWORD'
    )
]) {
    sh '''
        echo "$DOCKER_PASSWORD" | docker login \
            --username "$DOCKER_USERNAME" \
            --password-stdin

        docker push ${IMAGE_NAME}:${IMAGE_TAG}
    '''
}
```

The important security decisions are:

* Docker Hub credentials are stored in Jenkins.
* The Personal Access Token is not committed to Git.
* The Jenkinsfile references the credential ID rather than the secret itself.
* `--password-stdin` is used for Docker authentication.
* The credential is available only within the required pipeline scope.

---

## Build vs Login vs Push

Three separate operations are involved:

### 1. Build

```bash
docker build
```

Creates the image locally.

### 2. Login

```bash
docker login
```

Authenticates the user with the registry.

It does not upload the image.

### 3. Push

```bash
docker push medonati/expense-tracker-backend:1.0.0
```

Transfers the locally built image to Docker Hub.

The complete flow is:

```text
docker build
      ↓
Local Docker Image
      ↓
docker login
      ↓
Authenticated Registry Connection
      ↓
docker push
      ↓
Docker Hub
```

---

## Successful Artifact

The final artifact is:

```text
medonati/expense-tracker-backend:1.0.0
```

The Jenkins pipeline reported:

```text
✅ Docker image pushed successfully.
🎉 Jenkins pipeline completed successfully.
```

The image was independently verified in the Docker Hub repository.

```text
Docker Hub
└── medonati
    └── expense-tracker-backend
        └── 1.0.0
```

This confirms that Jenkins successfully:

1. Validated the application.
2. Ran automated tests.
3. Built the Docker image.
4. Verified the Docker artifact.
5. Authenticated with Docker Hub.
6. Published the image.
7. Produced a remotely accessible container artifact.

---

## Key Lessons

### 1. Build does not mean Push

A Docker image can exist locally without existing in a registry.

### 2. The image name matters

```text
expense-tracker-backend:1.0.0
```

and:

```text
medonati/expense-tracker-backend:1.0.0
```

represent different repository destinations.

### 3. Credentials do not determine the image destination

The image name identifies the repository.

The credentials establish whether Jenkins is allowed to push there.

### 4. Docker Hub is a registry

It provides centralized storage and distribution for Docker images.

### 5. Jenkins is now producing a distributable artifact

The pipeline has moved beyond simply saying:

> "The code works."

It can now produce:

> "Here is the tested Docker artifact that can be retrieved and deployed elsewhere."

---

## Current Architecture

```text
GitHub
   │
   ▼
Jenkins
   │
   ├── Install Dependencies
   ├── Validate Source
   ├── Run Tests
   │
   ▼
Docker Build
   │
   ▼
Local Docker Image
   │
   ▼
Docker Hub Authentication
   │
   ▼
Docker Push
   │
   ▼
Docker Hub
   │
   └── medonati/expense-tracker-backend:1.0.0
```

---

## What's Next?

The next milestone is:

**Artifact Management & Versioning**

The goal will be to move beyond simply producing:

```text
1.0.0
```

and understand how artifacts are versioned, traced back to source code, identified by builds, and managed throughout their lifecycle.
