# 📦 Volume 1 — Docker

> *The foundation of containerization, application packaging, networking, persistence, and operational health.*

---

# Overview

Volume 1 marks the beginning of the DevOps Engineering Handbook.

The goal of this volume was not simply to learn Docker commands, but to understand the engineering principles that make containerized applications reliable, portable, and reproducible.

Throughout this volume, the focus remained on understanding **why** Docker exists before learning **how** to use it.

Every concept was reinforced through implementation, experimentation, observation, and documentation.

---

# Learning Objectives

By the end of this volume, I aimed to:

* Understand the problems Docker was created to solve.
* Learn the difference between Docker images and containers.
* Build and run a multi-container application using Docker Compose.
* Understand container networking and service discovery.
* Persist database data using Docker Volumes.
* Implement application health and readiness endpoints.
* Develop an engineering mindset based on reasoning rather than memorization.

---

# Chapters

| Chapter | Topic                | Status |
| ------- | -------------------- | :----: |
| 01      | Docker Fundamentals  |    ✅   |
| 02      | Docker Networking    |    ✅   |
| 03      | Docker Volumes       |    ✅   |
| 04      | Docker Health Checks |    ✅   |

---

# Skills Gained

By completing this volume, I can confidently:

* Build Docker images using a Dockerfile.
* Understand Docker image layers and layer caching.
* Create and manage containers.
* Build multi-container applications using Docker Compose.
* Configure environment variables.
* Map host and container ports.
* Use Docker's internal networking and service discovery.
* Persist database data with Docker Volumes.
* Implement and verify liveness and readiness endpoints.
* Troubleshoot common Docker issues through experimentation.
* Think about containerized applications from an engineering perspective.

---

# Engineering Principles Learned

This volume established several principles that will guide every future milestone.

* Understand before automating.
* Verify before assuming.
* Build confidence through experimentation.
* Containers are disposable.
* Data should outlive containers.
* Running is not the same as Ready.
* Infrastructure consumes operational truth exposed by the application.
* Every technology exists to solve an engineering problem.

---

# Experiments Performed

Learning was driven by experimentation rather than memorization.

Experiments included:

* Building Docker images from scratch.
* Exploring Docker layer caching.
* Investigating build context.
* Using `.dockerignore` to optimize builds.
* Connecting containers through Docker networking.
* Understanding why `localhost` does not work between containers.
* Using service discovery with Docker Compose.
* Persisting MongoDB data using a named volume.
* Intentionally stopping MongoDB to observe application behaviour.
* Comparing `/health` and `/ready` responses during failure scenarios.

These experiments transformed theoretical concepts into practical engineering understanding.

---

# Final Architecture

The completed architecture for Volume 1 is shown below.

📍 **See:** `images/project-architecture-v1.png`

This architecture represents the state of the project after completing the Docker milestone.

---

# Reflection

This volume concluded with a personal reflection documenting:

* Initial assumptions.
* Mindset shifts.
* Engineering habits developed.
* Lessons learned.
* Growth throughout the Docker journey.

📍 **See:** `reflection.md`

---

# Files Included

```text
Volume-1-Docker/
│
├── README.md
├── images/
│   └── project-architecture-v1.png
│
├── 01-docker-fundamentals.md
├── 02-docker-networking.md
├── 03-docker-volumes.md
├── 04-docker-healthchecks.md
└── reflection.md
```

---

# Completion Summary

**Volume:** Docker

**Status:** ✅ Completed

**Application Stack:**

* Node.js
* Express
* MongoDB
* Docker
* Docker Compose

**Features Implemented:**

* Multi-container application
* Docker networking
* Named volumes
* Liveness endpoint (`/health`)
* Readiness endpoint (`/ready`)
* Docker health monitoring

---

# Next Volume

## 🚀 Volume 2 — Continuous Integration

The next stage of the journey focuses on automating software delivery.

Topics include:

* Why Continuous Integration exists.
* The evolution of software delivery.
* Jenkins architecture.
* Building the first CI pipeline.
* Pipeline stages.
* Docker image automation.
* Build artifacts.
* CI/CD best practices.

As with every previous milestone, the focus will begin with the engineering problem before introducing the technology.

---

# Mentor's Note

Docker was the first tool explored during this mentorship, but it was never the primary objective.

The real objective was to begin developing the mindset of an engineer who understands systems before automating them.

This volume established the foundation upon which every future topic—Continuous Integration, Kubernetes, Monitoring, Terraform, and AWS—will build.

The journey continues.
