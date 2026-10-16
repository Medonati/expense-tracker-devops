# Volume 6 — Kubernetes & Container Orchestration

## Overview

This volume documents the practical deployment, management, scaling, networking, and troubleshooting of the Expense Tracker application using Kubernetes.

Building on the earlier Docker, CI/CD, artifact management, Terraform, and application integration work, this volume moves the application from container-based deployment toward orchestration with Kubernetes.

The focus is not only on applying Kubernetes manifests, but also on understanding desired state, observing controller behaviour, conducting controlled failure experiments, and using evidence to investigate application and cluster problems.

## Learning Objectives

This volume explores how to:

- Explain Kubernetes architecture, including clusters, control plane components, worker nodes, Pods, Deployments, and ReplicaSets.
- Deploy the Expense Tracker backend and frontend workloads using Kubernetes.
- Use Services and Kubernetes DNS for stable application communication.
- Manage application configuration with ConfigMaps and Secrets.
- Introduce persistent storage for MongoDB using PersistentVolumes and PersistentVolumeClaims.
- Configure Ingress and hostname-based HTTP routing.
- Scale workloads, perform rolling updates, and roll back unsuccessful deployments.
- Configure CPU and memory requests and limits.
- Use startup, readiness, and liveness probes to manage application startup and health.
- Investigate failures using `kubectl`, application logs, Kubernetes events, resource observations, and controlled experiments.

## Application Architecture

The existing Expense Tracker application consists of a React frontend served by Nginx, a Node.js backend, and a MongoDB database.

The Kubernetes lab uses Minikube to explore how these components are deployed and managed as Kubernetes workloads. Container images are distributed through Amazon Elastic Container Registry (Amazon ECR).

```text
                  Client
                    |
                    v
             Nginx Ingress
                    |
                    v
             Frontend Service
                    |
                    v
            Frontend Deployment
                    |
                    v
             React / Nginx
                    |
                    v
              Backend Service
                    |
                    v
            Backend Deployment
                    |
                    v
             Node.js / Express
                    |
                    v
             MongoDB Service
                    |
                    v
                MongoDB
                    |
                    v
             Persistent Storage
```

The diagram represents the application's logical traffic and workload relationships. The exact external access path depends on the Minikube Ingress configuration used in the lab.

## Milestone Documentation

### Foundations and Architecture

- [Performance and Capacity Experiment](01-Performance-and-Capacity-Experiment.md) — Controlled workload experiments and observations about response time, throughput, and capacity.
- [Kubernetes Fundamentals and Architecture](02-Kubernetes-Fundamentals-and-Architecture.md) — Why Kubernetes, orchestration, desired state, reconciliation, self-healing, and core architecture concepts.
- [Kubernetes Fundamentals and Architecture — Part 2](02-Kubernetes-Fundamentals-and-Architecture%20part%202.md) — Cluster concepts, control plane and worker nodes, Pods, namespaces, `kubectl`, and Minikube troubleshooting.

### Workload Deployment and Networking

- [Deploying the Backend](03-Kubernetes-Deploying-the-Backend.md) — Backend Deployments, ReplicaSets, Pods, image configuration, and workload management.
- [Services and Networking](04-Kubernetes-Services-and-Networking.md) — Stable Service endpoints, selectors, ports, service discovery, and Kubernetes DNS.
- [Frontend and Nginx on Kubernetes](05-Frontend-and-Nginx-on-Kubernetes.md) — Deploying the frontend and configuring Nginx within the Kubernetes application architecture.
- [Configuration, Secrets and Persistent Storage](06-Kubernetes-Configuration-Secrets-and-Persistent-Storage.md) — ConfigMaps, Secrets, MongoDB persistence, and recovery experiments.
- [Ingress and External Access](07-Kubernetes-Ingress-and-External-Access.md) — Nginx Ingress Controller, hostname-based routing, and external HTTP access.

### Reliability, Resources and Application Health

- [Scaling, Rolling Updates and Failure Experiments](08-Scaling-Rolling-Updates-and-Failure-Experiments.md) — Replica management, rolling updates, rollbacks, and image-pull failure experiments.
- [Resource Requests, Limits and Scheduling](09-Resource-Requests-Limits-and-Scheduling.md) — CPU and memory requests, limits, scheduling decisions, and workload resource configuration.
- [Probes and Application Health](10-Probes-and-Application-Health.md) — Startup, readiness, and liveness probes, application health endpoints, and investigation of repeated backend restarts.

## Practical Engineering Lessons

The practical work emphasised several important operational principles:

1. **Desired state matters:** Kubernetes controllers continuously reconcile the observed state with the state declared in workload specifications.
2. **Services provide stable access:** Applications should communicate through stable Service identities rather than relying on temporary Pod IP addresses.
3. **Configuration and data have different lifecycles:** ConfigMaps and Secrets separate runtime configuration from workload definitions, while persistent storage addresses database data retention.
4. **Rollouts require verification:** A successful manifest application is not sufficient evidence that an application is healthy. Deployment status, Pod readiness, events, and application responses must also be checked.
5. **Health probes must reflect application behaviour:** Startup, readiness, and liveness probes serve different purposes and should be configured accordingly.
6. **Troubleshooting requires evidence:** Container exit codes, probe failures, Kubernetes events, application logs, and node-level observations must be interpreted together. A symptom alone does not always establish its root cause.
7. **Resource decisions require context:** Requests, limits, scheduling constraints, workload behaviour, and the capacity of the underlying environment all influence application reliability.

## Lab Environment

The practical exercises used:

- Kubernetes through Minikube.
- `kubectl` for inspecting and managing Kubernetes resources.
- Amazon ECR-hosted container images.
- The Expense Tracker React/Nginx frontend.
- The Node.js/Express backend.
- MongoDB with Kubernetes configuration and persistent storage.
- Kubernetes Deployments, ReplicaSets, Services, ConfigMaps, Secrets, PersistentVolumes, PersistentVolumeClaims, Ingress, and health probes.

The environment was a learning lab. Its observed performance and reliability should not be interpreted as a production capacity benchmark or proof of production readiness.

## Outcome

Volume 6 brings the Expense Tracker project into Kubernetes orchestration and records the associated implementation, verification, troubleshooting, and failure experiments.

The resulting documentation provides a practical reference for understanding how Kubernetes manages application workloads, network access, configuration, storage, scaling, resource allocation, and application health.

**Next stage:** Volume 7 — Monitoring & Observability, following the established DevOps mentorship roadmap.