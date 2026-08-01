# DevOps Engineering Handbook — Project State

> **Current Volume:** Volume 1 – Docker (Completed)

**Last Updated:** End of Docker Fundamentals Milestone

---

# Development Environment

This project is developed and tested inside a dedicated DevOps laboratory rather than directly on the host machine.

## Host Machine

* Operating System: Windows 10 (64-bit)
* RAM: 8 GB
* Hypervisor: Oracle VirtualBox
* Development Tool: Vagrant

---

## Virtual Machine

* Operating System: Ubuntu 22.04 LTS (Jammy Jellyfish)
* Hostname: `devops-lab`
* Primary User: `vagrant`

The virtual machine serves as the primary development environment to closely resemble a real Linux server.

---

## Development Stack

### Version Control

* Git
* GitHub (SSH Authentication)

### Containerization

* Docker Engine
* Docker Compose

### Backend

* Node.js 22
* Express.js

### Database

* MongoDB 4.4
* Mongoose ODM

### Development Tools

* curl
* npm
* Bash
* VS Code

---

# Current Project Architecture

```text
                    User
                      │
                      ▼
              localhost:3000
                      │
                      ▼
            Backend Container
                      │
             Docker Network
                      │
                      ▼
            MongoDB Container
                      │
                      ▼
              Docker Volume
```

---

# Repository Philosophy

This repository is intentionally designed as more than a software project.

It serves simultaneously as:

* A production-oriented DevOps project.
* A personal engineering handbook.
* A troubleshooting knowledge base.
* An interview preparation resource.
* A record of engineering decisions and experiments.

Every milestone includes:

* Understanding the problem.
* Implementing the solution.
* Testing through experimentation.
* Engineering documentation.
* Version control.

This ensures that both the implementation and the reasoning behind it are preserved.

---

# Engineering Principles

Throughout this project the following principles guide every technical decision.

* Understand before automating.
* Verify before assuming.
* Failure is a learning opportunity.
* Build for reproducibility.
* Containers are disposable.
* Data should outlive containers.
* Infrastructure should observe applications.
* Every tool must solve a real engineering problem before it is introduced.

---

# Current Progress

## ✅ Volume 1 — Docker

Completed Chapters

* Chapter 1 — Docker Fundamentals
* Chapter 2 — Docker Networking
* Chapter 3 — Docker Volumes
* Chapter 4 — Docker Health Checks

---

## 🔄 Next Volume

### Volume 2 — Continuous Integration

Topics planned include:

* Why Continuous Integration exists.
* The evolution of software delivery.
* Jenkins architecture.
* Building the first CI pipeline.
* Pipeline stages.
* Automated builds.
* Docker image creation.
* Artifacts.
* Pipeline best practices.

---

# Long-Term Roadmap

After Jenkins, the project will continue through:

* Kubernetes
* Monitoring
* Infrastructure as Code (Terraform)
* AWS Deployment
* Production-grade DevOps practices

Each volume builds upon the previous one.

Nothing is introduced without first understanding the engineering problem it solves.

---

# Mentor's Note

The objective of this project is not to collect tools.

The objective is to develop the ability to reason about systems.

Every experiment, implementation, failure, and architectural decision contributes toward becoming a DevOps engineer capable of designing, operating, and troubleshooting production systems with confidence.
