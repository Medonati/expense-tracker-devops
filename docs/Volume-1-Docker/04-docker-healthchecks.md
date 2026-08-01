# Chapter 4 — Docker Health Checks

**Volume:** Docker

**Prerequisites:** Docker Fundamentals, Docker Networking

**Estimated Study Time:** 2–3 Hours

**Difficulty:** Intermediate

**Project Milestone:** Implementing liveness and readiness monitoring

**Status:** ✅ Completed

---

# Objective

Understand how infrastructure determines whether an application is alive, healthy, and ready to serve user requests.

---

# The Problem

A running container does not necessarily mean a healthy application.

An application may still be running while:

* its database is unavailable,
* requests are failing,
* or users cannot use the service.

Infrastructure requires a reliable way to determine application health.

---

# Core Concepts

## Health Checks

Docker periodically executes a command inside a container.

If the command succeeds, the container is considered healthy.

If repeated checks fail, Docker marks it as unhealthy.

---

## Liveness

Question answered:

**"Is the application process alive?"**

Our implementation:

`GET /health`

Returns HTTP 200 when the Express application is running.

---

## Readiness

Question answered:

**"Can the application currently serve user requests?"**

Our implementation:

`GET /ready`

Checks:

`mongoose.connection.readyState`

Returns:

* HTTP 200 when connected.
* HTTP 503 when disconnected.

---

## Startup vs Runtime Failure

One of the biggest lessons from this milestone.

Startup failure:

Application cannot initialize.

Recommended behaviour:

Fail fast.

Runtime failure:

Application loses a dependency after startup.

Recommended behaviour:

Remain alive while attempting recovery.

---

# Architecture Diagram

Docker

↓

GET /health

↓

Express

↓

200 OK

---

Docker

↓

GET /ready

↓

Express

↓

Mongoose Connection State

↓

200 or 503

---

# Questions We Asked

### Should the developer or the DevOps engineer implement `/health`?

The application team defines what "healthy" means.

Infrastructure consumes that information.

---

### Why doesn't Docker use `/ready`?

Docker Compose provides a single health check.

Kubernetes separates liveness and readiness into independent probes.

---

### What happens if MongoDB stops?

This question led to one of the most valuable experiments in the project.

---

# Experiments We Performed

We intentionally stopped MongoDB.

Observed:

`/health`

↓

UP

`/ready`

↓

NOT READY

This demonstrated that:

* the application process was still alive,
* but it could no longer serve requests.

---

# Observations

Running and Ready are different operational states.

Liveness and Readiness answer different engineering questions.

Infrastructure decisions should be based on the appropriate endpoint.

---

# Lessons Learned

* Running ≠ Healthy.
* Healthy ≠ Ready.
* Docker checks liveness.
* Kubernetes distinguishes liveness from readiness.
* Failure experiments provide stronger understanding than successful deployments.

---

# Common Mistakes

* Assuming a running container is healthy.
* Treating readiness as liveness.
* Restarting healthy applications because a dependency failed.

---

# Best Practices

* Keep `/health` lightweight.
* Use `/ready` for dependency validation.
* Test failure scenarios intentionally.
* Verify behaviour rather than assuming it.

---

# Beyond This Chapter

Kubernetes expands these ideas using:

* livenessProbe
* readinessProbe
* startupProbe

Understanding Docker health checks makes Kubernetes probes intuitive.

---

# If I Were Interviewed

**Question**

What is the difference between liveness and readiness?

**Common Wrong Answer**

"They both check if the application is running."

**Correct Answer**

Liveness determines whether the application process should be restarted.

Readiness determines whether traffic should be routed to the application.

---

# Engineer's Takeaways

* Healthy systems are observable.
* Operational endpoints are part of application design.
* Production systems should be tested under failure conditions.
* Never assume successful startup guarantees continuous availability.

---

# Commands Used

`curl http://localhost:3000/health`

Tests liveness.

`curl http://localhost:3000/ready`

Tests readiness.

`docker inspect backend`

Displays container health information.

---

# References

* Docker Health Check Documentation
* Mongoose Connection State Documentation
