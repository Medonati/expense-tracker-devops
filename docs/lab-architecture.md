# DevOps Lab Architecture

## Overview

This document describes the architecture of my local DevOps learning environment. Rather than being a collection of unrelated tools, the lab is intentionally designed to simulate a real-world DevOps platform where each service has a clearly defined purpose and integrates with the others.

The objective is to learn engineering principles before automation, ensuring every technology introduced into the lab solves a specific problem.

---

# Lab Philosophy

This lab follows a number of engineering principles that guide every design decision.

## Understand Before Automating

> "I can't automate what I don't understand."

Automation should always come after understanding the underlying engineering process.

---

## Prefer Consistency Over Cleverness

Configuration should be intuitive.

Whenever possible:

- Standard ports remain standard.
- Host ports mirror guest ports.
- Directory structures remain predictable.
- Infrastructure should be easy to reason about.

---

## Treat Servers as Disposable

Operating systems and applications can always be rebuilt.

Persistent data cannot.

Backups should prioritize application state rather than software installations.

---

## Verify Before Assuming

Before making infrastructure changes:

- Inspect the current state.
- Verify assumptions.
- Understand dependencies.
- Apply the change.
- Validate the outcome.

---

# Lab Environment

| Component | Technology |
|----------|------------|
| Host Operating System | Windows 11 |
| Virtualization | VirtualBox |
| Provisioning | Vagrant |
| Guest Operating System | Ubuntu 22.04 LTS |

---

# Current Architecture

```
                        Windows Host
                        ─────────────

             ┌─────────────────────────────┐
             │                             │
             ▼                             ▼

      localhost (80)                localhost:3000
             │                             │
             ▼                             ▼
      Apache Web Server          Expense Tracker API

                    ┌─────────────────────────┐
                    │                         │
                    ▼                         ▼

             localhost:8080           localhost:2222
                    │                         │
                    ▼                         ▼
                 Jenkins                  SSH Access

────────────────────────────────────────────────────────────

                    Ubuntu DevOps Lab

        Apache (80)

        Jenkins (8080)

        Expense Tracker Backend (3000)

        Docker Engine

        MongoDB (Docker)

```

---

# Network Port Mapping

| Service | Guest Port | Host Port | Purpose |
|----------|-----------:|----------:|---------|
| SSH | 22 | 2222 | Ubuntu administration |
| Apache | 80 | 80 | Web server |
| Expense Tracker Backend | 3000 | 3000 | REST API |
| Jenkins | 8080 | 8080 | Continuous Integration |

---

# Current Services

## Apache

Purpose

- Web server experimentation
- Learning Apache fundamentals
- Future reverse proxy demonstrations
- Comparison with Nginx

---

## Docker

Purpose

- Application containerization
- Container networking
- Volume management
- Health checks
- Image creation

---

## Expense Tracker Backend

Technology

- Node.js
- Express

Purpose

- Primary learning application
- Docker demonstrations
- Jenkins pipeline demonstrations
- CI/CD experiments

---

## MongoDB

Purpose

- Application database
- Docker networking demonstrations
- Readiness and health check demonstrations
- Persistent storage demonstrations

---

## Jenkins

Purpose

- Continuous Integration
- Build automation
- Pipeline orchestration
- Docker image automation
- Future deployment automation

---

# Repository Structure

```
expense-tracker-devops/

├── app/
│   └── backend/
│
├── docker/
│
├── docs/
│   ├── architecture.md
│   ├── docker-fundamentals.md
│   ├── docker-networking.md
│   ├── docker-volumes.md
│   ├── docker-healthchecks.md
│   └── lab-architecture.md
│
├── kubernetes/
│
├── terraform/
│
└── README.md
```

---

# Engineering Decisions

## Port Standardization

The lab intentionally mirrors guest ports to host ports whenever possible.

Examples

```
80    → 80

3000  → 3000

8080  → 8080
```

This minimizes cognitive overhead and simplifies troubleshooting.

Ports are only remapped when a genuine conflict exists.

---

## Linux Service Management

Applications are treated as Linux services.

Current services include:

- Apache
- Jenkins
- SSH

Service health is verified using:

```
systemctl
ss
ps
journalctl
```

rather than relying solely on web interfaces.

---

## Persistent Data

The lab distinguishes between:

### Stateless Components

- Ubuntu installation
- Jenkins package
- Java
- Docker installation
- Node.js installation

These can always be recreated.

### Stateful Components

- MongoDB data
- Jenkins Home (`/var/lib/jenkins`)
- Application data

These require backup and protection.

---

# Operational Workflow

Before introducing a new service into the lab:

1. Understand the engineering problem.
2. Verify current system state.
3. Check listening ports.
4. Check host port availability.
5. Configure networking.
6. Document the service.
7. Verify functionality.

---

# Lab Evolution

## Volume 1

Completed

- Ubuntu DevOps Lab
- Docker
- Docker Compose
- Docker Networking
- Docker Volumes
- Docker Health Checks
- Health Endpoint
- Readiness Endpoint
- Git Milestone (v1.0-docker)

---

## Volume 2

Current

- Continuous Integration Concepts
- Jenkins Fundamentals
- Linux Service Management
- Jenkins Runtime
- Jenkins Filesystem
- Jenkins Architecture

---

## Future Volumes

- Jenkins Pipelines
- SonarQube
- Nexus Repository
- Nginx
- Prometheus
- Grafana
- Kubernetes
- Helm
- Terraform
- AWS
- GitOps
- ArgoCD

---

# Guiding Principles

> I can't automate what I don't understand.

> Treat servers as disposable. Treat data as precious.

> Prefer consistency over cleverness.

> Verify before assuming.

> Understand the engineering problem before learning the tool.

> Every technology added to the lab must have a clear purpose.
