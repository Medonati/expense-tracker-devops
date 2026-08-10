# Volume 2 – Jenkins Continuous Integration

## Overview

This volume documents my journey of learning **Jenkins** as a Continuous Integration (CI) platform within my DevOps lab.

The goal is not only to build working pipelines, but to understand the engineering decisions behind them. Each milestone captures the implementation, troubleshooting process, architectural choices, and lessons learned while gradually evolving a simple Jenkins pipeline into one capable of producing deployable software artifacts.

---

# Learning Objectives

Throughout this volume I explored:

* Jenkins architecture and core components
* Continuous Integration (CI) principles
* Pipeline as Code
* Jenkins Tool Management
* Automated dependency installation
* Application validation
* Automated testing with Jest
* Docker artifact creation
* Docker artifact verification
* Pipeline troubleshooting and debugging
* CI pipeline evolution and design

---

# Current Pipeline

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
      └── Verify Docker Artifact
              │
              ▼
     Versioned Docker Artifact
```

---

# Repository Structure

```text
Volume-2-Jenkins/
├── README.md
├── 01-continuous-integration.md
├── 02-automated-testing.md
├── 03-docker-artifacts.md
├── architecture.md
├── reflection.md
└── images/
```

---

# Progress

* ✅ Jenkins Installation
* ✅ Jenkins Administration
* ✅ Jenkins Tool Management
* ✅ Pipeline as Code
* ✅ Pipeline from SCM
* ✅ Automated Dependency Installation
* ✅ Source Validation
* ✅ Automated Testing
* ✅ Docker Artifact Creation
* ✅ Docker Artifact Verification

### Upcoming Milestones

* ⏳ Image Security Scanning
* ⏳ Container Registry Integration
* ⏳ Image Versioning Strategy
* ⏳ Continuous Deployment
* ⏳ Kubernetes Deployment

---

# Key Takeaways

Throughout this volume I learned that:

* Continuous Integration is more than running builds—it produces trusted software artifacts.
* Pipelines should evolve incrementally, with each stage introducing a single new responsibility.
* Docker images become versioned build outputs that form the foundation of Continuous Delivery.
* Linux permissions are an important part of CI infrastructure, particularly when integrating Jenkins with Docker.
* Environment variables improve maintainability by centralizing pipeline configuration.
* Every engineering decision should be supported by documentation, evidence, and measurable outcomes.

---

# Volume Summary

At the completion of this volume, the Jenkins pipeline is capable of validating the application, executing automated tests, building a Docker image, and verifying that the artifact has been successfully created.

This establishes a strong Continuous Integration foundation for the next phase of the project: publishing artifacts to a container registry and automating deployments.
