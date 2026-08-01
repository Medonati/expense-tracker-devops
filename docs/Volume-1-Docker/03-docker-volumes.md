# Chapter 3 — Docker Volumes

**Volume:** Docker

**Prerequisites:** Docker Fundamentals, Docker Networking

**Estimated Study Time:** 1–2 Hours

**Difficulty:** Beginner

**Project Milestone:** Persisting MongoDB data using Docker Volumes

**Status:** ✅ Completed

---

# Objective

Understand why containers are disposable, why application data should not be, and how Docker Volumes provide persistent storage.

---

# The Problem

Containers are designed to be temporary.

If a MongoDB container is removed, everything stored inside its writable layer disappears.

For databases, this is unacceptable.

Application data must survive container recreation.

---

# Core Concepts

## Stateless vs Stateful Applications

A stateless application stores no important data inside the container.

Examples:

* Node.js API
* Nginx
* Web frontend

A stateful application stores important information that must survive restarts.

Examples:

* MongoDB
* PostgreSQL
* MySQL
* Redis (depending on configuration)

---

## Docker Volumes

A Docker Volume stores data outside the container's writable layer.

The volume belongs to Docker rather than the container itself.

When the container is removed, the data remains.

---

## Named Volumes

Our project uses a named volume for MongoDB.

Advantages:

* Persistent
* Managed by Docker
* Easy to back up
* Easy to reuse

---

# Architecture Diagram

Container

↓

Docker Volume

↓

Persistent Data

Even if the MongoDB container is recreated, the volume remains attached.

---

# Questions We Asked

### Why can't MongoDB store its data inside the container?

Because containers are disposable.

Deleting the container would also delete the database.

---

### Why use a named volume instead of a bind mount?

Named volumes are managed entirely by Docker and are generally preferred for databases in production-like environments.

---

### Why doesn't the backend need a volume?

The backend application is rebuilt from source code.

Its important asset is the code itself—not runtime-generated data.

---

# Experiments We Performed

* Configured MongoDB with a named volume.
* Recreated containers while preserving database storage.
* Discussed why backend code and database data have different persistence requirements.

---

# Observations

* Containers can safely be destroyed.
* Volumes continue to exist after container removal.
* Persistent storage is essential for databases.

---

# Lessons Learned

* Containers are temporary.
* Data is not.
* Persistent storage should be separated from application runtime.

---

# Common Mistakes

* Storing database data inside the container.
* Deleting volumes unintentionally.
* Confusing bind mounts with named volumes.

---

# Best Practices

* Use named volumes for databases.
* Back up persistent volumes regularly.
* Treat containers as replaceable resources.

---

# Beyond This Chapter

Persistent storage becomes even more important in Kubernetes, where Pods are also disposable. Kubernetes solves this using Persistent Volumes and Persistent Volume Claims.

---

# If I Were Interviewed

**Question**

Why should MongoDB use a Docker volume?

**Common Wrong Answer**

"So the container doesn't restart."

**Correct Answer**

A Docker volume separates persistent application data from the container lifecycle. Containers can be recreated while the database contents remain intact.

---

# Engineer's Takeaways

* Containers are ephemeral.
* Databases are not.
* Persistence belongs outside the container.
* Docker Volumes solve a storage problem—not a deployment problem.

---

# Commands Used

`docker volume ls`

Lists Docker volumes.

`docker volume inspect <volume>`

Displays information about a volume.

`docker volume rm <volume>`

Removes a Docker volume.

---

# References

* Docker Volumes Documentation
