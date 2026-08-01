# Docker Fundamentals

## Objective

This document explains the fundamental concepts of Docker, why it exists, the problems it solves, and how it was applied in this project. Rather than serving as a collection of commands, it documents the engineering decisions, experiments, and lessons learned while containerizing the Expense Tracker application.

---

# The Problem Docker Solves

Before Docker, applications were commonly deployed directly onto operating systems. This often introduced inconsistencies between development, testing, and production environments.

Common problems included:

* "It works on my machine."
* Missing software dependencies.
* Different operating system versions.
* Library conflicts.
* Difficult deployments.
* Inconsistent development environments.

Docker solves these problems by packaging an application together with everything it needs to run.

---

# What is Docker?

Docker is a containerization platform that allows applications to run inside isolated environments called **containers**.

A container packages:

* Application source code
* Runtime
* Libraries
* Dependencies
* Configuration

This allows the same application to run consistently regardless of the underlying operating system.

---

# Core Concepts

## Docker Engine

The Docker Engine is the software responsible for building, running, and managing containers.

It consists of:

* Docker Daemon
* Docker CLI
* Docker API

---

## Images

An image is a read-only blueprint used to create containers.

Characteristics:

* Immutable
* Versioned
* Portable
* Reusable

An image does not execute code by itself.

---

## Containers

A container is a running instance of an image.

Containers are:

* Isolated
* Lightweight
* Disposable
* Replaceable

Images are blueprints.

Containers are the running application.

---

## Dockerfile

A Dockerfile is a set of instructions describing how an image should be built.

Our backend Dockerfile performs the following tasks:

1. Uses the official Node.js image.
2. Sets a working directory.
3. Copies dependency files.
4. Installs dependencies.
5. Copies application source code.
6. Starts the application.

Each instruction creates a new Docker image layer.

---

## Layers

Docker images are built in layers.

Each instruction in a Dockerfile creates a new layer.

This makes Docker efficient because unchanged layers can be reused.

Example:

FROM node:22

↓

WORKDIR /app

↓

COPY package*.json

↓

RUN npm install

↓

COPY source code

If only the application code changes, Docker can reuse previous layers and rebuild only what changed.

---

## Build Context

The build context is the collection of files Docker can access during image creation.

We intentionally used a specific build context instead of blindly using the project root to reduce:

* Build time
* Image size
* Unnecessary files

One important lesson learned:

A smaller build context produces faster builds and cleaner images.

---

## .dockerignore

`.dockerignore` prevents unnecessary files from entering the build context.

Examples include:

* node_modules
* .git
* logs
* temporary files

Benefits:

* Faster builds
* Smaller images
* Better security
* Less network transfer

---

## Images vs Containers

Think of an image as an architectural blueprint.

Think of a container as the completed house built from that blueprint.

Multiple containers can be created from the same image.

Deleting a container does not delete the image.

---

## Container Lifecycle

Typical lifecycle:

Build Image

↓

Create Container

↓

Start Container

↓

Run Application

↓

Stop Container

↓

Remove Container

Containers are designed to be disposable.

The image remains unchanged.

---

## Development Workflow

Our workflow during development became:

Edit Code

↓

Build Image

↓

Start Containers

↓

Verify Application

↓

Commit Changes

↓

Push to GitHub

Understanding this lifecycle helped distinguish between:

* Source code
* Docker image
* Running container

---

# Experiments We Performed

During this milestone we intentionally explored Docker behaviour instead of relying on assumptions.

Experiments included:

* Understanding build context.
* Creating and using `.dockerignore`.
* Comparing cached builds with uncached builds.
* Verifying software inside a running container instead of assuming it existed.
* Investigating Docker Compose behaviour after rebuilding images.
* Observing how rebuilding affects containers.

These experiments strengthened our understanding far beyond simply following tutorials.

---

# Lessons Learned

* Never automate what you do not understand.
* Never assume software exists inside a container.
* Verify before making engineering decisions.
* Docker images are immutable.
* Containers are disposable.
* Build context directly affects image size and build speed.
* Dockerfiles describe how to build images, not how to run infrastructure.

---

# Common Mistakes

Common beginner mistakes include:

* Using an unnecessarily large build context.
* Forgetting `.dockerignore`.
* Confusing images with containers.
* Assuming rebuilding an image automatically updates running containers.
* Assuming every base image contains the same operating system tools.

---

# Best Practices

* Keep Dockerfiles simple.
* Use specific build contexts.
* Exclude unnecessary files.
* Leverage Docker layer caching.
* Verify assumptions through experimentation.
* Treat containers as disposable resources.

---

# Production Perspective

In production environments Docker rarely operates alone.

Containers are commonly managed by:

* Kubernetes
* Amazon ECS
* Docker Swarm

These platforms build upon the same Docker fundamentals covered in this document.

Understanding Docker first provides the foundation for learning container orchestration.

---

# Engineer's Takeaways

* Containers solve consistency problems, not application problems.
* Docker is a packaging and execution platform, not an application framework.
* Reproducibility is more valuable than convenience.
* Verification is better than assumption.
* Understanding the image lifecycle makes debugging significantly easier.
* Good DevOps engineers understand *why* Docker behaves the way it does—not just which commands to execute.
