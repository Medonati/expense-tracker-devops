# Expense Tracker DevOps

A hands-on Cloud & DevOps engineering project built around a real Node.js/MongoDB application.

This repository documents the progression from containerizing an application to building CI/CD workflows, managing software artifacts, provisioning AWS infrastructure with Terraform, and deploying a full-stack application to AWS.

The project is intentionally built as more than a collection of tools. It is a practical engineering portfolio, troubleshooting record, and documentation of the decisions, experiments, failures, and solutions encountered throughout the journey.

---

## 🎯 Project Objective

The goal is to understand how application delivery and infrastructure work together across the DevOps lifecycle:

```text
Application
    ↓
Containerization
    ↓
Continuous Integration
    ↓
Artifact Management
    ↓
Infrastructure as Code
    ↓
AWS Infrastructure
    ↓
Application Deployment
    ↓
Kubernetes
    ↓
Monitoring
    ↓
GitOps
```

Each stage is approached through hands-on implementation, testing, troubleshooting, and documentation.

---

## 🏗️ Current Architecture

The project has evolved into a containerized full-stack application consisting of:

```text
                    GitHub
                       │
                       ▼
                    Jenkins
                       │
              Build / Test / Release
                       │
                       ▼
                 Amazon ECR
                       │
              Versioned Images
                       │
                       ▼
                  AWS EC2
                       │
                 Docker Compose
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      Frontend      Backend      MongoDB
       Nginx       Node.js       Database
          │            │
          └────── API ─┘
```

AWS infrastructure is managed with Terraform, while the application is packaged and distributed as Docker images.

---

# 🚀 What Has Been Built

## 🐳 Containerization

The application has been containerized using Docker and Docker Compose.

Work includes:

- Docker fundamentals
- Container networking
- Persistent volumes
- Health checks
- Docker build optimization
- Multi-container application workflows
- Frontend and backend containerization
- Production-oriented frontend builds with Nginx

**Explore:**

- [Docker Volume](docs/Volume-1-Docker/README.md)
- [Docker Architecture](docs/Volume-1-Docker/architecture.md)
- [Docker Build Optimization](docs/Volume-1-Docker/05-docker-build-optimization.md)

---

## 🔄 Jenkins & CI/CD

Jenkins is used to automate application validation, Docker image creation, and release workflows.

The CI/CD work includes:

- Jenkins architecture and administration
- Pipeline as Code
- Automated testing
- Docker artifact creation
- GitHub webhook integration
- Tag-based release workflows
- Docker image publishing
- ECR-based image distribution
- Build metadata and release traceability

**Explore:**

- [Jenkins Volume](docs/Volume-2-Jenkins/README.md)
- [Continuous Integration](docs/Volume-2-Jenkins/01-continuous-integration.md)
- [GitHub Webhooks & Tag Releases](docs/Volume-2-Jenkins/04-github-webhooks-and-tag-releases.md)
- [Pipeline Evolution](docs/Volume-2-Jenkins/pipeline-evolution.md)

---

## 📦 Artifact Management

The project treats Docker images as versioned, traceable software artifacts rather than disposable build outputs.

Topics covered include:

- Image optimization
- Container image security
- Vulnerability remediation
- Tags vs digests
- Artifact identity
- Traceability and provenance
- Registry distribution
- Artifact lifecycle and cleanup

**Explore:**

- [Artifact Management](docs/Volume-3-Artifact-Management/README.md)
- [Image Optimization](docs/Volume-3-Artifact-Management/02-docker-image-optimization.md)
- [Container Image Security](docs/Volume-3-Artifact-Management/03-container-image-security.md)
- [Artifact Identity: Tags & Digests](docs/Volume-3-Artifact-Management/05-artifact-identity-tags-digests.md)
- [Traceability & Provenance](docs/Volume-3-Artifact-Management/06-artifact-traceability-and-provenance.md)
- [Registry & Distribution](docs/Volume-3-Artifact-Management/07-artifact-registry-and-distribution.md)

---

## 🏗️ Infrastructure as Code with Terraform

Terraform is used to define and manage AWS infrastructure as code.

The project includes practical work with:

- Terraform providers
- Variables and outputs
- Resource lifecycle
- Data sources
- Reusable modules
- Terraform state
- Remote state
- State locking
- Workspaces
- Validation and formatting
- IAM
- AWS networking
- EC2
- Security groups
- Amazon ECR
- Application deployment

**Explore:**

- [Terraform / Infrastructure as Code](docs/Volume-4-Infrastructure-as-Code/README.md)
- [Terraform AWS Lab](docs/Volume-4-Infrastructure-as-Code/13-Terraform-AWS-Git-Lab-From-Local-IaC-to-Real-Cloud-Infrastructure.md)
- [IAM & Least Privilege](docs/Volume-4-Infrastructure-as-Code/14-terraform-iam-least-privilege-aws-execution.md)
- [AWS VPC & Subnet](docs/Volume-4-Infrastructure-as-Code/15-terraform-aws-vpc-subnet.md)
- [AWS EC2](docs/Volume-4-Infrastructure-as-Code/17-terraform-aws-compute-ec2.md)
- [Security Groups](docs/Volume-4-Infrastructure-as-Code/18-terraform-aws-security-groups.md)
- [Application Deployment](docs/Volume-4-Infrastructure-as-Code/19-terraform-aws-application-deployment.md)
- [ECR + EC2 Deployment](docs/Volume-4-Infrastructure-as-Code/21-terraform-aws-ec2-ecr-application-deployment.md)

---

## ☁️ AWS Infrastructure & Deployment

The project includes hands-on AWS infrastructure provisioned with Terraform.

Resources include:

- Amazon VPC
- Public subnet
- Internet Gateway
- Route tables
- Security groups
- EC2
- IAM roles and instance profiles
- Amazon S3
- Amazon ECR

The application is deployed to EC2 using versioned container images distributed through ECR.

**Explore the AWS implementation:**

- [AWS Infrastructure Documentation](docs/Volume-4-Infrastructure-as-Code/README.md)
- [AWS Application Deployment](docs/Volume-4-Infrastructure-as-Code/19-terraform-aws-application-deployment.md)
- [ECR + EC2 Deployment](docs/Volume-4-Infrastructure-as-Code/21-terraform-aws-ec2-ecr-application-deployment.md)
- [Runtime Configuration & CI/CD Deployment](docs/Volume-4-Infrastructure-as-Code/22-terraform-aws-runtime-configuration-cicd-deployment.md)

---

## 🖥️ Full-Stack Application Integration

The project was extended from a backend application into a complete full-stack system.

The stack now includes:

- React frontend
- Nginx
- Node.js / Express backend
- MongoDB
- Docker
- Docker Compose
- Amazon ECR
- Jenkins
- AWS EC2

The frontend is built as a production-ready static application and served through Nginx, with API requests reverse-proxied to the backend container.

**Explore:**

- [Frontend & Full-Stack Integration](docs/Volume-5-Frontend-and-Full-Stack-Integration/README.md)
- [Frontend Foundation & Local Integration](docs/Volume-5-Frontend-and-Full-Stack-Integration/01-Frontend-Foundation-and-Local-Full-Stack-Integration.md)
- [Frontend Containerization](docs/Volume-5-Frontend-and-Full-Stack-Integration/02-Frontend-Containerization.md)
- [Frontend + Backend Integration](docs/Volume-5-Frontend-and-Full-Stack-Integration/03-frontend-backend-integration.md)
- [Container Registry & Release Distribution](docs/Volume-5-Frontend-and-Full-Stack-Integration/04-container-registry-and-release-distribution.md)
- [End-to-End Application Deployment](docs/Volume-5-Frontend-and-Full-Stack-Integration/05-end-to-end-application-deployment.md)

---

# ☸️ Kubernetes

Kubernetes is the current orchestration stage of the DevOps project.

Hands-on work is currently focused on applying Kubernetes concepts to the containerized application and building the orchestration layer on top of the Docker and AWS foundation already established.

Kubernetes deployment manifests and supporting configuration will be added to the repository as this milestone is completed.

**Current status:** 🔄 In progress

---

# 📊 Monitoring & Observability

Monitoring and observability are part of the project's planned evolution.

The repository contains the monitoring area for the upcoming implementation.

**Current status:** 🔄 Upcoming

---

# 🔁 GitOps & Production-Like Delivery

The longer-term roadmap extends the project toward:

- GitOps
- Continuous Delivery
- Monitoring and observability
- Production-like DevOps workflows
- End-to-end deployment automation

These stages will be added progressively rather than presented as completed work before implementation.

**Current status:** 🔵 Planned

---

# 📚 Documentation & Engineering Journal

One of the core goals of this repository is to preserve the reasoning behind the implementation.

The documentation includes:

- Technical explanations
- Architecture decisions
- Hands-on experiments
- Troubleshooting
- Failure analysis
- Configuration decisions
- Lessons learned
- Volume completion notes
- Engineering reflections

### Documentation Index

**[📖 Open the full documentation index →](docs/README.md)**

Additional project-level references:

- [Project State](docs/00-project-state.md)
- [DevOps Roadmap](docs/DEVOPS-ROADMAP.md)
- [Lab Architecture](docs/lab-architecture.md)
- [Mentorship Handoff](docs/MENTOR-HANDOFF.md)

---

# 🗂️ Repository Structure

```text
expense-tracker-devops/
│
├── app/
│   ├── backend/                 # Node.js / Express application
│   └── frontend/                # React application
│
├── docker/
│   ├── backend/                 # Backend container configuration
│   └── frontend/                # Frontend / Nginx container configuration
│
├── docker-compose/              # Compose configurations
│
├── terraform/                   # Infrastructure as Code
│
├── kubernetes/                  # Kubernetes implementation
│
├── monitoring/                  # Monitoring and observability
│
├── scripts/                     # Automation and utility scripts
│
├── deploy/                      # Deployment-related configuration
│
├── docs/                        # Engineering documentation and experiments
│
├── Jenkinsfile                  # Jenkins CI pipeline
├── Jenkinsfile.ecr              # ECR release/deployment pipeline
│
└── README.md                    # Project entry point
```

---

# 🧠 Engineering Philosophy

This project follows a reasoning-first approach:

- **Understand before automating.**
- **Verify before assuming.**
- **Use failure as a learning opportunity.**
- **Build for reproducibility.**
- **Treat infrastructure as code.**
- **Make artifacts traceable.**
- **Document the reasoning, not just the commands.**
- **Introduce technology to solve an engineering problem.**

The objective is not to collect DevOps tools.

The objective is to develop the ability to **build, troubleshoot, automate, and reason about systems.**

---

# 🛣️ DevOps Roadmap

The project is being developed incrementally across the following stages:

```text
01  Application Foundation
02  Containerization
03  CI / Jenkins
04  Artifact Management
05  Infrastructure as Code
06  Cloud Infrastructure
07  Continuous Delivery
08  Application Integration
09  Kubernetes              ← Current focus
10  Monitoring & Observability
11  GitOps
12  Production-Like DevOps Pipeline
```

Progress is documented in the repository rather than treated as a checklist of tools.

---

## 📌 Portfolio Note

This repository is actively developed.

Completed work is documented and committed as milestones, while upcoming capabilities are clearly identified as in progress or planned.

For a deeper look at the engineering work, start with the **[documentation index](docs/README.md)** and then explore the individual volume READMEs and implementation notes.
