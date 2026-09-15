# Volume 5 — Frontend & Full-Stack Application Integration

## Milestone 05 — End-to-End Application Deployment

**Status:** ✅ Complete

---

## 1. Objective

The objective of this milestone was to deploy the Expense Tracker application to an AWS EC2 instance using the versioned container images already published to Amazon ECR.

The deployment was designed around the principle:

> **Build once, deploy the same artifact.**

Jenkins builds the application images and publishes them to ECR. EC2 pulls those exact images and runs them using Docker Compose.

The target architecture was intentionally simple and suitable for the current AWS Free Tier/lab environment.

---

## 2. Target Architecture

```text
                         INTERNET
                            │
                            │ HTTP :80
                            ▼
                  ┌────────────────────┐
                  │        EC2         │
                  │                    │
                  │  Docker Compose    │
                  │                    │
                  │  ┌──────────────┐  │
                  │  │    Nginx     │  │
                  │  │   Frontend   │  │
                  │  │     :80      │  │
                  │  └──────┬───────┘  │
                  │         │          │
                  │         │ /api/*   │
                  │         ▼          │
                  │  ┌──────────────┐  │
                  │  │   Backend    │  │
                  │  │    :3000     │  │
                  │  └──────┬───────┘  │
                  │         │          │
                  │         ▼          │
                  │  ┌──────────────┐  │
                  │  │   MongoDB    │  │
                  │  │   :27017     │  │
                  │  └──────────────┘  │
                  │                    │
                  └────────────────────┘

                  AWS ECR
                     ▲
                     │ docker pull
                     │
                  EC2

                  Jenkins
                     │
                     │ docker push
                     ▼
                  AWS ECR
```

Only the frontend/Nginx service is publicly exposed.

Backend port `3000` and MongoDB port `27017` remain internal to the Docker network.

---

## 3. AWS Infrastructure

The deployment used:

* AWS region: `us-east-1`
* EC2 instance type: `t3.micro`
* Operating system: Ubuntu 22.04.5 LTS
* Security Group: `expense-tracker-dev-sg`

The Security Group allowed:

* SSH `22` from the administrative IP
* HTTP `80` from the Internet

Ports `3000` and `27017` were not exposed publicly.

---

## 4. EC2 IAM Role

Instead of configuring static AWS credentials on the EC2 server, a dedicated IAM role was created:

`expense-tracker-ec2-ecr-pull`

The role was attached to the EC2 instance through an instance profile.

The role provides only the ECR permissions required to authenticate and pull the application images.

The relevant permissions include:

```text
ecr:GetAuthorizationToken

ecr:BatchCheckLayerAvailability
ecr:BatchGetImage
ecr:GetDownloadUrlForLayer
```

The permissions were scoped to the two application repositories:

```text
expense-tracker-dev-backend
expense-tracker-dev-frontend
```

This allowed EC2 to pull images without storing long-lived AWS access keys on the server.

---

## 5. EC2 Docker Environment

Docker was installed on the Ubuntu EC2 instance.

Docker was configured so the `ubuntu` user could execute Docker commands without `sudo`.

Docker Compose V2 was also installed.

The final environment was verified with:

```bash
docker --version
docker compose version
```

Git was already available on the instance and was used to obtain the deployment configuration from the repository.

---

## 6. Deployment Configuration

The deployment configuration was stored in:

```text
deploy/docker-compose.yml
```

The deployment Compose file uses the versioned ECR images rather than building images on EC2.

```yaml
services:
  mongodb:
    image: mongo:4.4
    container_name: mongodb
    volumes:
      - mongo-data:/data/db
    restart: unless-stopped

  backend:
    image: .dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4
    container_name: backend
    environment:
      PORT: 3000
      MONGO_URL: mongodb://mongodb:27017/expense
    expose:
      - "3000"
    depends_on:
      - mongodb
    restart: unless-stopped

  frontend:
    image: .dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
    container_name: frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  mongo-data:
    name: mongo-data
```

The configuration was committed to Git and pushed to `main`.

---

## 7. Why the Port Configuration Works

The deployment uses different networking boundaries.

### Frontend

```yaml
ports:
  - "80:80"
```

This publishes EC2 port `80` to Nginx port `80` inside the frontend container.

Therefore:

```text
Internet
   ↓
EC2 :80
   ↓
Nginx :80
```

### Backend

The backend uses:

```yaml
expose:
  - "3000"
```

This makes port `3000` available to other containers on the Docker network without publishing it to the EC2 host.

### MongoDB

MongoDB has no `ports` configuration.

Therefore its `27017` port is only reachable through the internal Docker network.

The resulting architecture is:

```text
Public
  │
  ▼
EC2 :80
  │
  ▼
Nginx
  │
  ├── frontend files
  │
  └── /api/* → backend:3000
                       │
                       ▼
                  mongodb:27017
```

This means the browser does not need direct access to ports `3000` or `27017`.

---

## 8. Nginx Configuration

The production frontend uses Nginx rather than the React development server.

The configuration is:

```nginx
server {
    listen 80;

    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://backend:3000;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Static frontend requests

Requests such as:

```text
/
```

are handled by:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

Nginx serves the React production build from:

```text
/usr/share/nginx/html
```

The `/index.html` fallback is important because React uses client-side routing.

For example:

```text
/login
/register
/setAvatar
```

are application routes rather than physical files.

---

## 9. Nginx Reverse Proxy

API requests beginning with `/api/` are handled separately:

```nginx
location /api/ {
    proxy_pass http://backend:3000;
}
```

For example:

```text
POST /api/auth/login
```

follows this path:

```text
Browser
   ↓
EC2 :80
   ↓
Nginx
   ↓
backend:3000
   ↓
Express
```

Nginx communicates with the backend using the Docker Compose service name:

```text
backend
```

Docker's internal DNS resolves the service name to the backend container.

This removes the need to hard-code the EC2 IP address inside the Nginx configuration.

---

## 10. Frontend Production API Configuration

The production frontend uses an empty:

```text
REACT_APP_API_URL
```

This causes API requests to use relative paths.

Instead of the browser attempting:

```text
http://localhost:3000/api/auth/login
```

the deployed application requests:

```text
/api/auth/login
```

The browser therefore sends the request to the same host serving the frontend:

```text
http://18.215.154.133/api/auth/login
```

Nginx then forwards the request internally to:

```text
http://backend:3000
```

This provides a single public entry point for the application.

---

## 11. ECR Authentication

The EC2 instance authenticated to Amazon ECR using the attached IAM role.

The authentication command was:

```bash
aws ecr get-login-password --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  .dkr.ecr.us-east-1.amazonaws.com
```

The result was:

```text
Login Succeeded
```

No static AWS access key or secret key was configured on the EC2 instance.

---

## 12. Image Distribution

The exact versioned artifacts produced during Milestone 04 were pulled from ECR.

Backend:

```text
.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4
```

Frontend:

```text
.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

This follows the intended release model:

```text
Git
 ↓
Jenkins
 ↓
Docker build
 ↓
ECR
 ↓
EC2
 ↓
Docker Compose
```

The EC2 server does not build the application.

It consumes the already-built release artifacts.

---

## 13. Deployment

The deployment was started with:

```bash
docker compose -f deploy/docker-compose.yml up -d
```

Docker Compose created the application network and started:

```text
mongodb
backend
frontend
```

The deployment was verified using:

```bash
docker compose -f deploy/docker-compose.yml ps
```

The final container state showed:

```text
backend     Up
frontend    Up
mongodb     Up
```

The frontend published:

```text
0.0.0.0:80->80/tcp
```

while backend and MongoDB remained internally accessible.

---

## 14. Verification

### Frontend

The following command returned the React application's HTML:

```bash
curl http://localhost
```

This confirmed that Nginx was serving the production frontend.

---

### Backend health

The backend health endpoint was tested from inside the backend container:

```bash
docker exec backend \
  node -e "fetch('http://localhost:3000/health').then(r => r.text()).then(console.log).catch(console.error)"
```

Result:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

---

### Container-to-container networking

Docker DNS was verified from the frontend container:

```bash
docker exec frontend getent hosts backend
```

The `backend` service successfully resolved to its Docker network IP.

Container-to-container HTTP communication was also verified:

```bash
docker exec frontend wget -qO- http://backend:3000/health
```

The backend returned its health response.

---

### Nginx API routing

The following request:

```text
GET /api/health
```

reached the backend but returned `404`.

This was expected because the backend exposes:

```text
/health
```

rather than:

```text
/api/health
```

The Express response confirmed that Nginx was forwarding the request to the backend.

Similarly:

```text
GET /api/auth/login
```

returned `404` because the login endpoint expects `POST`.

These tests demonstrated that routing was functioning even though the specific HTTP methods/routes were incorrect for those tests.

---

## 15. Application-Level Verification

Infrastructure verification alone was not considered sufficient.

The deployed application was tested through the browser.

### Registration

A new test account was registered through:

```text
http://18.215.154.133/register
```

The registration succeeded.

### Login

The newly created account was used to log into:

```text
http://18.215.154.133/login
```

Login succeeded.

### Transaction

A transaction was created through the deployed application.

The transaction was successfully created and persisted.

This verified the complete application flow:

```text
Browser
   ↓
Nginx
   ↓
Backend
   ↓
MongoDB
   ↓
Transaction persisted
```

---

## 16. Database Persistence Observation

The EC2 MongoDB database initially contained no users.

The local MongoDB data did not automatically appear on EC2.

This demonstrated an important Docker concept:

> **A Docker named volume is local to its Docker host.**

The local environment had its own:

```text
mongo-data
```

volume.

The EC2 environment created a different:

```text
mongo-data
```

volume.

Even though the names were identical, they were not the same storage resource.

Therefore:

```text
DevOps VM mongo-data
        ≠
EC2 mongo-data
```

Application deployment and database/data migration are separate concerns.

For this lab, data migration was intentionally not performed. A new test user was created through the application's normal registration flow.

---

## 17. Failures and Troubleshooting

### 17.1 Incorrect SSH username

The initial SSH attempt used:

```text
ec2-user
```

The EC2 instance was actually Ubuntu.

AWS connection information identified the correct username:

```text
ubuntu
```

**Lesson:** Verify the operating system and AWS-provided connection information instead of assuming the default username.

---

### 17.2 Incorrect key permissions

The private key initially had overly permissive permissions.

SSH requires a sufficiently restricted private key.

The permissions were corrected to:

```bash
chmod 400 ~/.ssh/expense-tracker-dev-key.pem
```

**Lesson:** SSH private keys are sensitive credentials and must have appropriate filesystem permissions.

---

### 17.3 AWS CLI initially had no credentials

Before the EC2 IAM role was attached:

```bash
aws sts get-caller-identity
```

returned a credentials error.

After attaching:

```text
expense-tracker-ec2-ecr-pull
```

the same command returned the assumed-role identity.

**Lesson:** IAM roles provide temporary credentials to EC2 without storing long-lived AWS credentials on the server.

---

### 17.4 ECR `DescribeImages` AccessDenied

The EC2 role did not include:

```text
ecr:DescribeImages
```

An attempt to use `aws ecr describe-images` therefore returned `AccessDenied`.

This was intentional rather than immediately expanding the policy.

Docker image pulling does not require `DescribeImages`.

**Lesson:**

> Authentication and authorization are separate concerns, and IAM permissions should be driven by actual requirements rather than simply adding permissions whenever an unrelated command fails.

---

### 17.5 Docker Compose command differences

The EC2 environment initially did not have the Compose V2 plugin available through the `docker compose` command.

The appropriate Ubuntu package:

```text
docker-compose-v2
```

was installed.

The resulting command was:

```bash
docker compose
```

rather than the older:

```bash
docker-compose
```

**Lesson:** Tool versions and package names matter. Verify the installed tooling instead of assuming a command exists.

---

### 17.6 MongoDB shell mismatch

The MongoDB image was:

```text
mongo:4.4
```

An attempt to use:

```bash
mongosh
```

failed because that executable was not present.

The older MongoDB shell:

```bash
mongo
```

was available.

**Lesson:** Container image versions influence the available tooling. Verify the image's actual environment before assuming commands from newer versions are available.

---

### 17.7 Login returned HTTP 401

The deployed login initially returned:

```text
401 Unauthorized
```

Backend logs confirmed:

```text
POST /api/auth/login 401
```

The backend was connected to MongoDB.

Investigation showed that the EC2 database contained no users because it was a new volume.

A new account was subsequently created through the application's normal registration flow, after which login worked successfully.

**Lesson:** A healthy infrastructure deployment does not imply that application data already exists.

---

## 18. Docker Compose Networking Mental Model

The final deployment helped establish the distinction between:

### Host ports

Ports published to the EC2 host:

```text
80
```

### Container ports

Ports on which applications listen inside containers:

```text
Nginx       :80
Backend     :3000
MongoDB     :27017
```

### Internal service communication

Containers communicate through Docker's internal network using service names:

```text
backend:3000
mongodb:27017
```

The final model is:

```text
Internet
   │
   │ :80
   ▼
EC2
   │
   ▼
frontend/Nginx :80
   │
   │ backend:3000
   ▼
backend
   │
   │ mongodb:27017
   ▼
mongodb
```

Only the required public entry point is exposed.

---

## 19. Important Docker Volume Lesson

The deployment Compose configuration contains:

```yaml
volumes:
  mongo-data:
    name: mongo-data
```

Running:

```bash
docker compose down
```

removes the containers and Compose network but normally preserves the named volume.

Therefore:

```text
docker compose down
```

does not intentionally delete the MongoDB data.

However:

```bash
docker compose down -v
```

also removes the volumes.

For this reason, `-v` must be used deliberately when persistent database data is involved.

---

## 20. Final Architecture

The completed lab architecture is:

```text
                         Internet
                            │
                            │ HTTP :80
                            ▼
                ┌───────────────────────┐
                │         EC2           │
                │                       │
                │   Docker Compose      │
                │                       │
                │  ┌─────────────────┐  │
                │  │ Nginx / React   │  │
                │  │      :80       │  │
                │  └────────┬────────┘  │
                │           │           │
                │           │ /api/*   │
                │           ▼           │
                │  ┌─────────────────┐  │
                │  │ Node/Express    │  │
                │  │      :3000      │  │
                │  └────────┬────────┘  │
                │           │           │
                │           ▼           │
                │  ┌─────────────────┐  │
                │  │    MongoDB      │  │
                │  │      :27017     │  │
                │  └─────────────────┘  │
                │                       │
                └───────────────────────┘
                            ▲
                            │
                       Docker pull
                            │
                     ┌─────────────┐
                     │     ECR     │
                     └──────▲──────┘
                            │
                       Docker push
                            │
                     ┌──────┴──────┐
                     │   Jenkins   │
                     └──────▲──────┘
                            │
                          GitHub
```

---

## 21. Key Engineering Lessons

### 1. Build once, deploy the same artifact

EC2 consumes the images produced by Jenkins rather than rebuilding the application.

### 2. Containers do not automatically carry application data

Container images contain application artifacts. Persistent data belongs to storage.

### 3. Named volumes are host-local

A volume named `mongo-data` on one Docker host is different from a volume with the same name on another host.

### 4. Internal ports do not have to be public

Backend `3000` and MongoDB `27017` can remain private while Nginx exposes only port `80`.

### 5. Nginx can serve and route

Nginx serves the React production build and reverse-proxies `/api/*` requests to the backend.

### 6. Docker Compose provides service discovery

Services communicate using names such as:

```text
backend
mongodb
```

rather than hard-coded container IP addresses.

### 7. Infrastructure verification and application verification are different

A container showing `Up` does not prove that the application works.

The deployment was therefore verified at multiple levels:

```text
Infrastructure
      ↓
Container
      ↓
Networking
      ↓
HTTP routing
      ↓
Application
      ↓
Database
      ↓
User workflow
```

### 8. Verify before assuming

Several issues in this milestone were resolved by inspecting the actual environment:

* Ubuntu vs `ec2-user`
* Compose V2 availability
* IAM role identity
* ECR permissions
* MongoDB shell version
* Empty production database
* Actual HTTP response codes

---

## 22. Milestone Outcome

Milestone 05 successfully deployed the Expense Tracker application from versioned ECR artifacts to AWS EC2.

The deployed system successfully supports:

* Frontend delivery through Nginx
* API reverse proxying through Nginx
* Backend execution
* Internal MongoDB connectivity
* User registration
* User authentication
* Transaction creation
* Persistent MongoDB storage

The milestone demonstrates the complete path:

```text
GitHub
   ↓
Jenkins
   ↓
ECR
   ↓
EC2
   ↓
Docker Compose
   ↓
Nginx
   ↓
React
   ↓
Backend
   ↓
MongoDB
```

**Milestone 05: COMPLETE ✅**
