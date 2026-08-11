# Volume 2 – Jenkins CI

## Overview

This volume documents my journey of learning Jenkins as a Continuous Integration (CI) platform.

The focus is on understanding how Jenkins automates software validation, how pipelines are designed, how failures are investigated, and how CI pipelines can produce deployable artifacts.

Unlike traditional tutorials, this documentation captures both the implementation and the engineering decisions made throughout the learning process.

---

## What I Learned

* Jenkins architecture and core components
* Continuous Integration fundamentals
* Pipeline Jobs vs Freestyle Jobs
* Jenkins Tool Management
* Pipeline as Code
* Jenkinsfiles
* Jenkins Pipeline from SCM
* Dependency installation
* Source validation
* Automated testing
* Jenkins/Docker integration
* Docker artifact creation
* Docker image verification
* Docker Hub authentication
* Jenkins Credentials Store
* Docker image publishing
* Authentication vs authorization
* Reading and troubleshooting pipeline logs

---

## Pipeline Overview

```text
Developer
    │
    ▼
GitHub Repository
    │
    ▼
Jenkins Pipeline
    │
    ├── Install Dependencies
    ├── Verify Environment
    ├── Validate Source
    ├── Run Tests
    ├── Build Docker Image
    ├── Verify Docker Artifact
    ├── Authenticate with Docker Hub
    └── Push Docker Image
              │
              ▼
Docker Hub
              │
              ▼
medonati/expense-tracker-backend:1.0.0
```

---

## Repository Structure

```text
Volume-2-Jenkins/
├── README.md
├── 01-continuous-integration.md
├── 02-automated-testing.md
├── 03-docker-artifacts.md
├── first-pipeline.md
├── troubleshooting.md
└── images/
```

---

## Progress

✅ Jenkins Installation
✅ Jenkins Administration
✅ Jenkins Tool Management
✅ First Pipeline
✅ Pipeline from SCM
✅ Continuous Integration
✅ Automated Testing
✅ Jenkins Docker Access
✅ Docker Build Stage
✅ Docker Artifact Verification
✅ Docker Hub Repository
✅ Docker Hub Credentials
✅ Docker Image Push
⏳ Artifact Management & Versioning
⏳ Image Security Scanning
⏳ Continuous Delivery
⏳ Deployment

---

## Current Artifact

```text
medonati/expense-tracker-backend:1.0.0
```

The image is successfully published to Docker Hub by Jenkins.

---

## Key Takeaways

CI is about validating code automatically before integration.

Automation should be based on a process that is already understood manually.

Jenkins plugins extend Jenkins capabilities, but understanding the underlying process is more important than relying on plugins as black boxes.

Build failures are opportunities to improve the pipeline.

Credentials should be managed securely and should never be committed to source control.

A Docker image can be built locally without being published to a registry.

A registry provides centralized storage and distribution for container artifacts.

The image name identifies the intended repository, while credentials provide authentication and authorization.

Pipeline configuration should eventually be stored alongside the application code.

The goal of CI is not simply to produce a successful build, but to produce a reliable and traceable artifact that can progress toward deployment.
