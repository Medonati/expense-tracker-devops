# Volume 5 — Frontend & Full-Stack Application Integration

## Overview

Volume 5 extends the Expense Tracker DevOps project from a backend-focused application into a complete full-stack application that can be built, containerized, distributed, and deployed as a working system.

The focus of this volume was not to become a frontend developer. Instead, the objective was to understand the frontend as a DevOps engineer:

* How a React application is structured
* How a frontend communicates with a backend API
* How environment variables influence frontend builds
* How a React application is converted into production-ready static assets
* How Nginx serves a frontend application
* How Nginx reverse-proxies API requests to a backend container
* How Docker containers communicate through service discovery
* How frontend and backend images are distributed through Amazon ECR
* How the same release artifacts can be deployed to AWS EC2
* How Docker Compose can coordinate the complete application stack
* How to verify the application from the browser through to the database

The volume follows the principle:

> **Make it work locally → understand it → containerize it → integrate it → distribute it → deploy it → verify it.**

---

## Engineering Goal

The goal was to evolve the application from a locally working backend into a deployable full-stack system.

The final deployment needed to provide:

* A React frontend
* An Nginx web server
* A Node.js/Express backend
* A MongoDB database
* Containerized application components
* Versioned Docker images
* Amazon ECR as the image registry
* Jenkins as the build and release mechanism
* AWS EC2 as the deployment environment
* Docker Compose for runtime orchestration
* Internal communication between application containers
* Public access through the frontend only

The intended request flow became:

```text
User Browser
     |
     | HTTP :80
     v
   Nginx
     |
     | /api/*
     v
 Backend :3000
     |
     | MongoDB protocol
     v
 MongoDB :27017
```

The CI/CD and distribution flow became:

```text
GitHub
   |
   v
Jenkins
   |
   | Build + Test
   | Docker Build
   v
Amazon ECR
   |
   | Pull versioned images
   v
AWS EC2
   |
   v
Docker Compose
   |
   +---- Frontend / Nginx
   +---- Backend
   +---- MongoDB
```

---

## Volume Structure

Volume 5 was completed through five milestones.

### Milestone 01 — Frontend Foundation & Local Full-Stack Integration

Established the React frontend and connected it to the existing backend API.

Key areas:

* React application structure
* Frontend routing
* API configuration
* Frontend environment variables
* Local frontend/backend communication
* CORS configuration
* Full-stack local testing

The local development architecture became:

```text
Browser
   |
   | :3001
   v
React Frontend
   |
   | HTTP API
   | :3000
   v
Node.js Backend
   |
   | MongoDB
   | :27017
   v
MongoDB
```

---

### Milestone 02 — Frontend Containerization

Containerized the React application using a multi-stage Docker build.

The build process uses Node.js to compile the React application and Nginx to serve the resulting production files.

Conceptually:

```text
React Source Code
       |
       v
Node.js Builder
       |
       | npm run build
       v
Production Build
       |
       v
Nginx Runtime Container
```

The multi-stage approach separates the build environment from the production runtime.

The resulting frontend container does not need Node.js to serve the compiled React application.

---

### Milestone 03 — Frontend + Backend Container Integration

Integrated the frontend and backend containers using Docker networking.

The frontend container uses Nginx as the public entry point and reverse proxy.

The Nginx configuration routes API requests internally:

```nginx
location /api/ {
    proxy_pass http://backend:3000;
}
```

This allows Nginx to communicate with the backend using the Docker Compose service name:

```text
backend
```

Docker's internal DNS resolves the service name to the backend container.

The browser therefore does not need direct access to port `3000`.

The final local container architecture became:

```text
                    Docker Network
------------------------------------------------
|                                              |
|  Browser                                     |
|     |                                        |
|     | :3001                                  |
|     v                                        |
|  Frontend / Nginx                            |
|     |                                        |
|     | backend:3000                            |
|     v                                        |
|  Backend                                     |
|     |                                        |
|     | mongodb:27017                           |
|     v                                        |
|  MongoDB                                     |
|                                              |
------------------------------------------------
```

---

### Milestone 04 — Container Registry & Release Distribution

Introduced Amazon Elastic Container Registry (ECR) as the container image registry.

Separate repositories were used for:

* Backend
* Frontend

The release process was designed around the principle:

> **Build once, deploy the same artifact.**

Jenkins builds the application images and pushes them to ECR.

A release is identified using version and commit tags.

Example:

```text
1.0.4
a432179
```

The same versioned images can then be pulled by the deployment environment.

This separates:

```text
Build
```

from:

```text
Deployment
```

and avoids rebuilding the application directly on the deployment server.

---

### Milestone 05 — End-to-End Application Deployment

The final milestone deployed the full application to an AWS EC2 instance.

The EC2 instance pulls the versioned application images from ECR and runs the application using Docker Compose.

The deployment architecture became:

```text
                         Internet
                            |
                            | HTTP :80
                            v
                    +---------------+
                    |   EC2 Ubuntu  |
                    |               |
                    | Docker Compose|
                    +-------+-------+
                            |
                  +---------+---------+
                  |                   |
                  v                   v
           +-------------+      +-------------+
           | Frontend    |      | Backend     |
           | Nginx :80   |----->| :3000       |
           +-------------+      +------+------+
                                       |
                                       v
                                +-------------+
                                | MongoDB     |
                                | :27017      |
                                +-------------+
```

Only the frontend is published to the EC2 host:

```text
80:80
```

The backend remains internal:

```text
3000/tcp
```

MongoDB also remains internal:

```text
27017/tcp
```

This establishes a simple application boundary:

```text
Internet
   |
   v
Nginx
   |
   +---- Frontend
   |
   +---- Backend
            |
            +---- MongoDB
```

---

## Production Frontend Architecture

The frontend uses an environment-specific API configuration.

For local development:

```text
REACT_APP_API_URL=http://localhost:3000
```

For the production build, the API base is intentionally empty so requests can use the same public origin:

```text
/api/...
```

Nginx then handles the internal routing.

This means the browser communicates with:

```text
http://<deployment-host>/api/...
```

rather than directly addressing:

```text
http://<deployment-host>:3000
```

This simplifies the public application boundary and keeps the backend port internal.

---

## Nginx Responsibilities

Nginx became an important part of the deployment architecture.

It performs two primary functions.

### 1. Serve the React Application

Nginx serves the static production files generated by the React build.

### 2. Reverse Proxy API Requests

Requests beginning with `/api/` are forwarded to the backend service.

```text
Browser
   |
   | /api/auth/login
   v
Nginx
   |
   | http://backend:3000
   v
Express Backend
```

Nginx also supports React client-side routing through:

```nginx
try_files $uri $uri/ /index.html;
```

This allows routes handled by React rather than physical files to resolve correctly.

---

## Docker Networking

One of the important concepts reinforced during this volume was the distinction between:

* Container ports
* Published host ports
* Internal Docker networking

For the local environment:

```text
Frontend: 3001 -> 80
Backend:  3000 -> 3000
MongoDB:  27017 -> 27017
```

For the EC2 deployment:

```text
Frontend: 80 -> 80
Backend:  3000/tcp internal
MongoDB:  27017/tcp internal
```

The backend does not need to expose its port publicly because Nginx can reach it through the Docker network.

The backend connects to MongoDB using:

```text
mongodb:27017
```

rather than:

```text
localhost:27017
```

because `localhost` inside a container refers to that same container.

---

## Container Registry Strategy

Amazon ECR is used as the release distribution point.

The process is:

```text
Source Code
    |
    v
Jenkins
    |
    +-- Test
    |
    +-- Build Backend Image
    |
    +-- Build Frontend Image
    |
    v
Amazon ECR
    |
    +-- Backend Image
    |
    +-- Frontend Image
    |
    v
EC2
```

This provides a clear separation between:

* Source control
* Continuous integration
* Artifact storage
* Runtime deployment

---

## AWS IAM Design

The EC2 instance uses an IAM role to authenticate to Amazon ECR.

The role provides only the permissions required for image retrieval:

* ECR authentication
* Image layer availability checks
* Image retrieval
* Downloading image layers

No static AWS access keys were configured on the EC2 instance.

This reinforced an important cloud security principle:

> **Use workload identity instead of embedding long-lived credentials where possible.**

A useful troubleshooting lesson came from testing an unauthorized `DescribeImages` operation. The command failed because that permission was intentionally not included in the EC2 role.

The important distinction was:

```text
Authentication
    ≠
Authorization
```

Successfully authenticating to AWS does not mean every AWS API operation is authorized.

---

## Deployment Verification

The deployment was verified at multiple levels rather than assuming that a successful `docker compose up` meant the application was working.

### Infrastructure Level

Verified:

```bash
docker compose -f deploy/docker-compose.yml ps
```

Expected services:

```text
frontend
backend
mongodb
```

### Backend Level

The backend health endpoint was tested from inside the container:

```text
/health
```

The backend returned:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

### Nginx Routing Level

API requests were sent through the public Nginx entry point.

A `404` response for a `GET` request to a POST-only endpoint was used as evidence that the request had successfully reached the Express backend rather than proving that the route itself existed for GET.

This reinforced the difference between:

```text
Routing works
```

and:

```text
The requested application operation is valid
```

### Application Level

The deployed application was tested through the browser.

The following were successfully verified:

* Application loads
* User registration works
* User login works
* Transactions can be created
* Backend communicates with MongoDB
* Frontend communicates with backend through Nginx

This provided end-to-end confirmation of the deployment.

---

## Important Troubleshooting Lessons

### EC2 Operating System Matters

The deployment instance was Ubuntu rather than Amazon Linux.

The correct SSH username was therefore:

```text
ubuntu
```

rather than:

```text
ec2-user
```

The lesson was to verify the AMI and AWS-provided connection instructions instead of assuming the username.

---

### Docker Compose Version Matters

The deployment environment initially did not have the modern Docker Compose plugin available.

Docker Compose V2 was installed and verified:

```bash
docker compose version
```

The project uses:

```bash
docker compose
```

rather than the older:

```bash
docker-compose
```

---

### MongoDB Shell Availability

The MongoDB container did not include `mongosh`.

The older MongoDB shell:

```bash
mongo
```

was available and used for database inspection.

The lesson was to verify what tooling actually exists inside an image rather than assuming the latest command is available.

---

### Local and EC2 Databases Are Different

The local development environment and EC2 deployment environment use different Docker hosts.

Therefore:

```text
Local mongo-data
```

and:

```text
EC2 mongo-data
```

are different volumes.

The EC2 deployment initially contained no application users because the local MongoDB data was never transferred to EC2.

Registering a new user through the deployed application confirmed that the EC2 database was functioning independently.

---

## Data Persistence

The MongoDB deployment uses a named Docker volume:

```yaml
volumes:
  mongo-data:
    name: mongo-data
```

Running:

```bash
docker compose down
```

removes the containers and network but does not remove the named volume by default.

Therefore application data can survive a normal Compose shutdown.

Removing the volume requires explicitly using:

```bash
docker compose down -v
```

This distinction is important because container lifecycle and data lifecycle are not the same thing.

---

## Security Boundary

The deployment intentionally avoids exposing internal services directly to the Internet.

Public:

```text
HTTP :80
```

Internal:

```text
Backend :3000
MongoDB :27017
```

The intended traffic flow is:

```text
Internet
    |
    v
Port 80
    |
    v
Nginx
    |
    v
Backend
    |
    v
MongoDB
```

This is a simple lab architecture rather than a production-grade cloud architecture, but it establishes the correct principle of keeping internal application services behind the public entry point.

---

## What This Volume Demonstrates

By completing Volume 5, the project demonstrates practical understanding of:

* React application structure from a DevOps perspective
* Frontend environment configuration
* React production builds
* Multi-stage Docker builds
* Nginx
* Reverse proxying
* SPA routing
* Docker service discovery
* Container-to-container networking
* Port publishing
* Internal versus public services
* Docker Compose
* Amazon ECR
* Versioned container releases
* Jenkins-based image builds
* AWS IAM roles
* EC2 deployment
* Application verification
* Database persistence
* Deployment troubleshooting

---

## Engineering Principles Reinforced

### Build Once, Deploy the Same Artifact

The image built by Jenkins is the artifact distributed through ECR and deployed to EC2.

### Verify Before Assuming

Every major layer was tested independently.

```text
Container
   ↓
Network
   ↓
Backend
   ↓
Database
   ↓
Nginx
   ↓
Browser
```

### Failure Is a Teacher

Several problems became learning opportunities:

* Incorrect EC2 SSH username
* Missing Docker Compose
* Missing MongoDB shell command
* IAM authorization failure
* Empty EC2 database
* API routing versus HTTP method behavior

### Engineering Before Tooling

The objective was not simply to run Docker, Jenkins, Nginx, or AWS commands.

The objective was to understand the role each component plays in the system.

---

## Final Architecture

The completed Volume 5 architecture can be summarized as:

```text
                         GitHub
                           |
                           v
                        Jenkins
                           |
                 Build + Test + Release
                           |
                           v
                      Amazon ECR
                    /             \
                   /               \
                  v                 v
        Backend Image       Frontend Image
                  \                 /
                   \               /
                    v             v
                     AWS EC2
                         |
                  Docker Compose
                         |
              +----------+----------+
              |                     |
              v                     v
       Frontend / Nginx          Backend
          Port 80              Port 3000
              |                     |
              +----------+----------+
                         |
                         v
                      MongoDB
                      Port 27017
```

---

## Volume Completion

**Volume 5 — Frontend & Full-Stack Application Integration**

Status: **COMPLETE ✅**

The application progressed from a locally integrated full-stack system to a versioned, containerized, registry-distributed, cloud-deployed application.

The final result is not just a working application.

It is a working application backed by an understandable deployment architecture.

> **Understand the system. Build the system. Break the system. Fix the system. Document the system.**
