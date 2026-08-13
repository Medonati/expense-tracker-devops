# DevOps Learning Roadmap

## Expense Tracker DevOps Project

This roadmap defines the progression of the Expense Tracker DevOps mentorship project.

The objective is not simply to learn individual tools, but to progressively build an understanding of how software moves from source code to a tested, secured, versioned, deployable, monitored application.

The roadmap is intentionally incremental. Each major phase builds on concepts established in the previous phase.

---

# Roadmap

```text
Application Understanding
        │
        ▼
Docker Fundamentals
        │
        ▼
Docker Compose
        │
        ▼
Jenkins CI
        │
        ▼
Container Registry
        │
        ▼
Artifact Management & Versioning
        │
        ▼
Container Image Security
        │
        ▼
Terraform
        │
        ▼
AWS Infrastructure
        │
        ▼
Continuous Delivery
        │
        ▼
Frontend Integration
        │
        ▼
Kubernetes
        │
        ▼
Monitoring & Observability
        │
        ▼
GitOps
        │
        ▼
Production-like DevOps Pipeline
```

---

# Phase 1 — Application Understanding

### Objective

Understand the application before automating it.

### Focus

* Application structure
* Backend architecture
* Frontend architecture
* Node.js runtime
* MongoDB integration
* Environment configuration
* Health and readiness endpoints
* Application startup
* Local development workflow

### Status

✅ Completed / ongoing reference

The backend is currently being used as the primary workload for the DevOps pipeline.

---

# Phase 2 — Docker Fundamentals

### Objective

Understand containerization before integrating Docker into CI/CD.

### Focus

* Images vs containers
* Dockerfile
* Build context
* `.dockerignore`
* Image layers
* `CMD` vs `ENTRYPOINT`
* `npm install` vs `npm ci`
* Development vs production images
* Multi-stage builds
* Docker networking
* Docker volumes
* Container configuration
* Environment-specific configuration
* Docker image optimization
* Container healthchecks

### Documentation

```text
docs/Volume-1-Docker/
```

### Status

✅ Completed

---

# Phase 3 — Docker Compose

### Objective

Understand how multiple application services are orchestrated locally.

### Focus

* Docker Compose
* Services
* Networks
* Volumes
* Environment variables
* Backend/database communication
* Local multi-container development
* Service dependencies

### Status

🟡 Completed / foundation established

---

# Phase 4 — Jenkins Continuous Integration

### Objective

Automate application validation and artifact creation.

### Focus

* Jenkins architecture
* Jenkins administration
* Jenkins tools
* Pipeline as Code
* Jenkinsfile
* Pipeline from SCM
* Dependency installation
* Source validation
* Automated testing
* Jenkins/Docker integration
* Linux permissions
* Docker daemon access

### Current Pipeline

```text
Install Dependencies
        │
Verify Environment
        │
Validate Source
        │
Run Tests
        │
Build Docker Image
        │
Verify Docker Artifact
        │
Push Docker Image
```

### Status

🚧 In progress

### Current milestone

**Jenkins → Docker Hub artifact publishing**

---

# Phase 5 — Container Registry

### Objective

Move Docker artifacts from the Jenkins host into a centralized registry.

### Focus

* What a container registry is
* Docker Hub
* Repository namespaces
* Image naming
* Authentication
* Personal Access Tokens
* Jenkins Credentials Store
* `docker login`
* `docker push`
* `docker pull`

### Current Repository

```text
medonati/expense-tracker-backend
```

### Target Artifact

```text
medonati/expense-tracker-backend:1.0.0
```

### Status

🚧 In progress

---

# Phase 6 — Artifact Management & Versioning

### Objective

Understand how build artifacts are identified, tracked, promoted, and retained.

### Focus

* Image tags
* Semantic versioning
* Build numbers
* Git commit SHA tags
* Immutable artifacts
* `latest` and its limitations
* Artifact traceability
* Image promotion
* Registry lifecycle
* Reproducible builds
* Artifact retention

### Example

```text
medonati/expense-tracker-backend:1.0.0
medonati/expense-tracker-backend:1.0.1
medonati/expense-tracker-backend:42
medonati/expense-tracker-backend:a91f3bc
```

### Status

⏳ Upcoming

---

# Phase 7 — Container Image Security

### Objective

Ensure container images are not only functional but also secure enough to progress toward deployment.

### Focus

* Vulnerability scanning
* Base image vulnerabilities
* npm dependency vulnerabilities
* Image security
* Minimal base images
* Non-root containers
* Security gates in CI
* Supply-chain security
* Scan-before-push strategy

### Expected Pipeline Evolution

```text
Validate
    ↓
Test
    ↓
Build
    ↓
Scan
    ↓
Push
```

### Status

⏳ Upcoming

---

# Phase 8 — Terraform

### Objective

Manage infrastructure as code rather than creating infrastructure manually.

### Focus

* Terraform fundamentals
* Providers
* Resources
* Variables
* Outputs
* State
* Data sources
* Dependencies
* Terraform workflow
* Modules
* Terraform and Git
* Terraform validation
* Terraform planning
* Terraform CI integration

### Status

⏳ Upcoming

---

# Phase 9 — AWS Infrastructure

### Objective

Use Terraform to provision and manage cloud infrastructure.

### Focus

* AWS IAM
* VPC
* Networking
* Compute
* Storage
* Security groups
* Load balancing
* AWS architecture
* Infrastructure cost awareness

### Constraint

AWS Free Tier usage will be treated as a project constraint.

Resources will be selected carefully and unnecessary infrastructure will be avoided.

### Status

⏳ Upcoming

---

# Phase 10 — Continuous Delivery

### Objective

Extend CI from artifact creation into controlled deployment.

### Focus

* Build → Test → Scan → Push → Deploy
* Deployment environments
* Configuration management
* Secrets
* Deployment verification
* Health checks
* Readiness checks
* Rollbacks
* Deployment strategies

### Status

⏳ Upcoming

---

# Phase 11 — Frontend Integration

### Objective

Bring the frontend into the established CI/CD architecture.

### Focus

* Frontend build process
* Frontend dependencies
* Frontend testing
* Frontend Docker image
* Backend/frontend networking
* Multi-application Jenkins pipelines
* Separate frontend and backend artifacts

### Expected Architecture

```text
Expense Tracker
│
├── Backend
│      ↓
│   Backend Image
│
└── Frontend
       ↓
    Frontend Image
```

### Status

⏳ Upcoming

The frontend is intentionally being introduced after the backend pipeline is stable.

---

# Phase 12 — Kubernetes

### Objective

Deploy and orchestrate containerized workloads.

### Focus

* Kubernetes architecture
* Pods
* Deployments
* Services
* ConfigMaps
* Secrets
* Health probes
* Resource requests and limits
* Scaling
* Rolling deployments
* Networking
* Kubernetes configuration

### Expected Architecture

```text
Container Registry
       │
       ├── Backend Image
       │
       └── Frontend Image
               │
               ▼
          Kubernetes
```

### Status

⏳ Upcoming

---

# Phase 13 — Monitoring & Observability

### Objective

Understand how to observe application and infrastructure behavior after deployment.

### Focus

* Application health
* Container health
* Kubernetes health
* Logs
* Metrics
* Resource utilization
* Alerts
* Failure investigation
* Application performance
* Observability

### Observability Model

```text
Application
    │
    ├── Logs
    ├── Metrics
    └── Health
          │
          ▼
    Observability
```

### Status

⏳ Upcoming

---

# Phase 14 — GitOps

### Objective

Introduce declarative, Git-driven deployment and infrastructure management.

### Focus

* Desired state
* Declarative configuration
* Git as source of truth
* Automated reconciliation
* Deployment synchronization
* GitOps workflows

### Expected Model

```text
Developer
    │
    ▼
Git
    │
    ▼
Desired State
    │
    ▼
GitOps Controller
    │
    ▼
Kubernetes
```

### Status

⏳ Upcoming

---

# Final Architecture

The long-term objective is to evolve the project toward a production-like DevOps workflow.

```text
                         Developer
                             │
                             ▼
                          GitHub
                             │
                ┌────────────┴────────────┐
                │                         │
           Application              Infrastructure
                │                         │
                ▼                         ▼
             Jenkins                  Terraform
                │                         │
        ┌───────┴────────┐                ▼
        │                │               AWS
     Backend          Frontend            │
        │                │                │
        └───────┬────────┘                │
                ▼                         │
          Docker Images                  │
                │                         │
                ▼                         │
        Container Registry                │
                │                         │
                └──────────┬──────────────┘
                           ▼
                      Kubernetes
                           │
                           ▼
                 Monitoring &
                 Observability
                           │
                           ▼
                        GitOps
```

---

# Current Position

```text
Application Understanding       ✅
Docker Fundamentals             ✅
Docker Compose                  ✅
Jenkins CI                      🚧
Container Registry              🚧
Artifact Versioning             ⏳
Image Security                  ⏳
Terraform                       ⏳
AWS Infrastructure              ⏳
Continuous Delivery             ⏳
Frontend Integration             ⏳
Kubernetes                      ⏳
Monitoring & Observability      ⏳
GitOps                          ⏳
```

## Immediate Next Steps

```text
1. Push backend image to Docker Hub
2. Verify artifact in Docker Hub
3. Document registry milestone
4. Learn artifact versioning
5. Implement image security scanning
6. Document the security milestone
7. Begin Terraform
```

---

# Learning Principle

The project follows an incremental engineering approach:

```text
Learn
  ↓
Understand
  ↓
Build
  ↓
Test
  ↓
Troubleshoot
  ↓
Capture Evidence
  ↓
Document
  ↓
Commit
  ↓
Tag Major Milestone
  ↓
Move Forward
```

The objective is not to rush through tools.

The objective is to understand **why each component exists, how it interacts with the rest of the system, and what problem it solves**.
