# Chapter 2 — Docker Networking

**Volume:** Docker

**Prerequisites:** Chapter 1 – Docker Fundamentals

**Estimated Study Time:** 1–2 Hours

**Difficulty:** Beginner

**Project Milestone:** Connecting the Node.js backend to MongoDB using Docker Compose networking.

**Status:** ✅ Completed

---

# Objective

Understand how containers communicate with one another, why Docker networking exists, and how service discovery enables applications to communicate without relying on IP addresses.

Rather than memorizing commands, this chapter focuses on the engineering principles behind container networking.

---

# The Problem

Modern applications rarely consist of a single service.

Our Expense Tracker application contains two independent services:

* Node.js Backend
* MongoDB Database

Although they run in separate containers, they must communicate reliably.

Without networking, the backend cannot store or retrieve data from the database.

---

# Core Concepts

## Docker Networks

Docker creates isolated virtual networks that allow containers to communicate securely.

When services are launched with Docker Compose, they are automatically attached to the same network unless configured otherwise.

This enables communication without exposing every service to the outside world.

---

## Service Discovery

One of Docker's most powerful features is automatic service discovery.

Instead of connecting to MongoDB using an IP address, our backend connects using:

```text
mongodb
```

Docker automatically resolves this service name to the correct container.

This makes applications portable and removes the need to hardcode network addresses.

---

## Why `localhost` Doesn't Work

One of the biggest misconceptions when learning Docker is assuming that `localhost` refers to another container.

Inside a container:

```text
localhost
```

always means:

> **This container.**

Therefore:

Backend Container

↓

localhost

↓

Backend Container

It never points to MongoDB.

To communicate with MongoDB, the backend must use Docker's internal DNS and the service name defined in Docker Compose.

---

## Internal vs External Communication

There are two different communication paths in Docker.

### Internal Communication

Backend

↓

MongoDB

This communication happens entirely inside Docker's private network.

No published ports are required.

---

### External Communication

User

↓

Host Machine

↓

Backend Container

This communication requires published ports.

Example:

```yaml
ports:
  - "3000:3000"
```

This allows browsers, Postman, and curl to communicate with the backend.

---

# Architecture Diagram

```text
                 User
                   │
                   ▼
         localhost:3000
                   │
                   ▼
        Backend Container
                   │
      mongodb:27017
                   │
                   ▼
        MongoDB Container
```

Notice that MongoDB is never accessed directly by the user.

Only the backend communicates with the database.

---

# Questions We Asked

### Why can't I use `localhost` to connect to MongoDB?

Because every container has its own isolated network namespace.

`localhost` always points back to the current container.

---

### Why does `mongodb` work?

Because Docker Compose automatically creates an internal DNS entry using the service name.

---

### Why expose port 3000 but not MongoDB?

Users interact with the application—not the database.

Keeping MongoDB inside Docker's internal network improves both architecture and security.

---

### Why not connect using container IP addresses?

Container IP addresses can change whenever containers are recreated.

Service names remain stable and are therefore the recommended approach.

---

# Experiments We Performed

During this milestone we intentionally explored Docker networking.

We:

* Connected the backend to MongoDB using the service name.
* Investigated why `localhost` failed.
* Observed successful communication through Docker's internal DNS.
* Confirmed that Docker automatically manages service discovery.
* Discussed why users should never connect directly to the database.

---

# Observations

Through experimentation we observed:

* Every container has its own `localhost`.
* Docker automatically provides DNS resolution.
* Service names are far more reliable than container IP addresses.
* Published ports are only necessary for external access.

---

# Lessons Learned

* Containers communicate through Docker networks.
* Service names should always be preferred over IP addresses.
* Internal networking and external networking serve different purposes.
* Good architecture exposes only the services that users actually need.

---

# Common Mistakes

Common mistakes include:

* Using `localhost` between containers.
* Hardcoding container IP addresses.
* Publishing unnecessary ports.
* Exposing databases directly to users.
* Assuming all services should be publicly accessible.

---

# Best Practices

* Use Docker service names for container communication.
* Publish only required ports.
* Keep databases on internal networks.
* Let Docker manage service discovery.
* Design applications so users interact only with the application layer.

---

# Beyond This Chapter

Networking allows containers to communicate.

The next step is understanding how containers preserve data.

This leads naturally into **Docker Volumes**, where we'll learn why containers are disposable but application data should not be.

---

# If I Were Interviewed

### Question

Why can't Docker containers communicate using `localhost`?

### Common Wrong Answer

> Docker doesn't allow containers to use localhost.

### Correct Answer

Every Docker container has its own isolated network namespace. Inside a container, `localhost` refers only to that container. Docker Compose provides an internal DNS service that allows containers to communicate using service names such as `mongodb`, eliminating the need for fixed IP addresses.

---

# Engineer's Takeaways

* Every container owns its own network namespace.
* `localhost` always means "this container."
* Docker networking is based on service discovery rather than fixed IP addresses.
* Good architecture minimizes the number of publicly exposed services.
* Understanding Docker networking makes Kubernetes networking much easier to learn later.

---

# Commands Used

```bash
docker network ls
```

Lists Docker networks.

---

```bash
docker network inspect <network-name>
```

Displays details about a Docker network and the containers attached to it.

---

```bash
docker-compose up
```

Creates the application network (if it doesn't already exist) and attaches all services to it.

---

# References

* Docker Networking Documentation
* Docker Compose Networking Documentation
