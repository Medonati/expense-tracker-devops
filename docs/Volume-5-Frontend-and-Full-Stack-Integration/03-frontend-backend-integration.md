# Milestone 03 — Frontend + Backend Container Integration

**Volume:** 5 — Frontend & Full-Stack Application Integration
**Status:** ✅ Complete

---

## 1. Objective

The objective of this milestone was to integrate the React frontend with the existing Node.js backend and MongoDB containers using Docker networking and Nginx.

The goal was to move from a manually working frontend/backend setup to a containerized architecture where:

* React is built as a production application.
* Nginx serves the React production build.
* Nginx acts as a reverse proxy for API requests.
* The browser communicates with a single application entry point.
* Docker's internal DNS allows containers to communicate using service names.
* Docker Compose manages the complete application stack.

---

# 2. Final Architecture

```text
                         Browser
                            │
                            │ localhost:3001
                            ▼
                   ┌─────────────────┐
                   │      Nginx      │
                   │  Frontend :80   │
                   └────────┬────────┘
                            │
                     /api/* │
                            ▼
                   ┌─────────────────┐
                   │     Backend     │
                   │    Node :3000   │
                   └────────┬────────┘
                            │
                            │ mongodb:27017
                            ▼
                   ┌─────────────────┐
                   │     MongoDB     │
                   │     :27017      │
                   └─────────────────┘
```

### Host-to-container port mapping

| Component       | Host Port | Container Port | Purpose             |
| --------------- | --------: | -------------: | ------------------- |
| Frontend/Nginx  |      3001 |             80 | Browser entry point |
| Backend/Node.js |      3000 |           3000 | API server          |
| MongoDB         |     27017 |          27017 | Database            |

The browser uses the published host port.

Containers communicate with each other using Docker's internal network and service/container names.

---

# 3. Frontend Containerization

The frontend uses a multi-stage Docker build.

## Dockerfile

Location:

```text
docker/frontend/Dockerfile
```

```dockerfile
FROM node:22-slim AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


FROM nginx:alpine

COPY --from=builder /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf
```

## Why multi-stage builds?

The first stage contains Node.js and the dependencies required to build the React application.

The second stage contains only Nginx and the compiled production files.

```text
Node.js builder
      │
      │ npm run build
      ▼
React build/
      │
      ▼
Nginx production image
```

This avoids using the Node.js development environment as the runtime for the frontend.

---

# 4. Frontend Docker Build Context

The frontend image is built using:

```bash
docker build \
  -t expense-tracker-frontend:test \
  -f ../../docker/frontend/Dockerfile \
  .
```

The build context is:

```text
app/frontend
```

This is important because Docker can only access files inside the build context.

Therefore:

```text
app/frontend/nginx.conf
```

was used rather than placing the Nginx configuration outside the build context.

---

# 5. .dockerignore

Location:

```text
app/frontend/.dockerignore
```

Important exclusions:

```text
node_modules/
build/
.git/
coverage/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.DS_Store
```

### Important troubleshooting lesson

Initially, the file contained:

```text
.env
.env.*
```

This prevented:

```text
.env.production
```

from entering the Docker build context.

As a result, React could not access:

```text
REACT_APP_API_URL
```

during:

```bash
npm run build
```

The browser consequently generated:

```text
/undefined/api/auth/login
```

### Fix

The `.env` exclusion rules were removed from the frontend `.dockerignore`.

This allowed `.env.production` to be available during the React build.

---

# 6. React Production Environment Configuration

The frontend uses:

```text
app/frontend/.env.production
```

Final configuration:

```text
REACT_APP_API_URL=
```

This was intentional.

The application already constructs API endpoints like:

```javascript
const host = process.env.REACT_APP_API_URL;

export const loginAPI = `${host}/api/auth/login`;
export const getTransactions = `${host}/api/v1/getTransaction`;
```

With an empty production host, the browser generates relative API paths:

```text
/api/auth/login
/api/v1/getTransaction
```

The browser therefore sends the requests to the same host serving the frontend.

---

# 7. Important React Environment Variable Lesson

Create React App environment variables are embedded into the application during the build.

They are not dynamically read by Nginx after the React application has been built.

Therefore:

```text
.env.production
      │
      ▼
npm run build
      │
      ▼
React JavaScript bundle
      │
      ▼
Nginx
      │
      ▼
Browser
```

Changing `.env.production` requires rebuilding the frontend image.

For example:

```bash
docker build \
  -t expense-tracker-frontend:test \
  -f ../../docker/frontend/Dockerfile \
  .
```

Simply changing the environment file after the image has already been built will not change the compiled React application.

---

# 8. Nginx Configuration

Location:

```text
app/frontend/nginx.conf
```

Current configuration:

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

## What the configuration does

### Serve the React application

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

This allows Nginx to serve the React production files and supports client-side routes such as:

```text
/login
/register
/setAvatar
```

### Reverse proxy API requests

```nginx
location /api/ {
    proxy_pass http://backend:3000;
}
```

Requests beginning with:

```text
/api/
```

are forwarded to the backend container.

---

# 9. Browser API Routing

### Before Nginx reverse proxy integration

The production environment contained:

```text
REACT_APP_API_URL=http://localhost:3000
```

Therefore the browser requested:

```text
http://localhost:3000/api/auth/login
```

Architecture:

```text
Browser
   │
   ├── localhost:3001 → Nginx → Frontend
   │
   └── localhost:3000 → Backend
```

The browser was communicating directly with the backend.

---

## After reverse proxy integration

The production configuration became:

```text
REACT_APP_API_URL=
```

The browser now requests:

```text
http://localhost:3001/api/auth/login
```

Nginx receives the request and forwards it internally:

```text
Browser
   │
   │ localhost:3001/api/auth/login
   ▼
Nginx
   │
   │ backend:3000
   ▼
Backend
```

This makes port `3001` the application's browser-facing entry point.

---

# 10. Docker Internal DNS

Docker provides internal DNS resolution between containers on the same network.

The frontend container was tested with:

```bash
docker exec frontend getent hosts backend
```

Result:

```text
172.19.0.3    backend    backend
```

This proved that the frontend container could resolve:

```text
backend
```

to the backend container's internal IP.

### Important principle

Do not configure Nginx using a container IP such as:

```text
172.19.0.3
```

Instead use:

```text
backend:3000
```

Container IP addresses can change when containers are recreated.

Docker's service/container name provides a stable logical destination.

---

# 11. Docker-to-Docker HTTP Connectivity Test

DNS resolution was followed by an actual HTTP connectivity test.

Command:

```bash
docker exec frontend wget -qO- http://backend:3000/health
```

Response:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

This proved two separate things:

1. Docker DNS can resolve `backend`.
2. The frontend container can communicate with the backend over HTTP.

---

# 12. Backend Healthcheck

The backend uses Node.js for its Docker healthcheck:

```yaml
healthcheck:
  test:
    [
      "CMD",
      "node",
      "-e",
      "fetch('http://localhost:3000/health').then(r => { if (!r.ok) process.exit(1) }).catch(() => process.exit(1))"
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 20s
```

This was chosen because the backend image does not contain `curl`.

An earlier healthcheck attempted to use `curl`, resulting in:

```text
exec: "curl": executable file not found in $PATH
```

The healthcheck was changed to use Node's built-in `fetch()`.

---

# 13. Docker Compose

The complete application is now managed by:

```text
docker-compose.yml
```

Current configuration:

```yaml
services:
  mongodb:
    image: mongo:4.4
    container_name: mongodb
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
    restart: unless-stopped

  backend:
    build:
      context: ./app/backend
      dockerfile: ../../docker/backend/Dockerfile
    container_name: backend
    ports:
      - "3000:3000"
    environment:
      PORT: 3000
      MONGO_URL: mongodb://mongodb:27017/expense
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "fetch('http://localhost:3000/health').then(r => { if (!r.ok) process.exit(1) }).catch(() => process.exit(1))"
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    depends_on:
      - mongodb
    restart: unless-stopped

  frontend:
    build:
      context: ./app/frontend
      dockerfile: ../../docker/frontend/Dockerfile
    container_name: frontend
    ports:
      - "3001:80"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  mongo-data:
    name: mongo-data
```

---

# 14. Compose Configuration Validation

Before starting the complete stack, configuration was validated with:

```bash
docker compose config
```

This confirms that Docker Compose can parse and resolve the configuration without starting or stopping containers.

---

# 15. Start the Complete Application

The entire stack can now be started with:

```bash
docker compose up -d
```

Check the services with:

```bash
docker compose ps
```

Expected structure:

```text
NAME       SERVICE    STATUS
backend    backend    Up (healthy)
frontend   frontend   Up
mongodb    mongodb    Up
```

---

# 16. Useful Docker Commands

## View running containers

```bash
docker ps
```

## View Compose services

```bash
docker compose ps
```

## Start the application

```bash
docker compose up -d
```

## View logs

```bash
docker compose logs
```

Backend logs:

```bash
docker compose logs backend
```

Frontend/Nginx logs:

```bash
docker compose logs frontend
```

Follow logs:

```bash
docker compose logs -f backend
```

## Stop the application

```bash
docker compose stop
```

## Restart services

```bash
docker compose restart
```

## Rebuild images

```bash
docker compose build
```

## Rebuild and start

```bash
docker compose up -d --build
```

### Important

Avoid:

```bash
docker compose down -v
```

when MongoDB data needs to be preserved.

The `-v` option can remove named volumes.

---

# 17. Useful Container Inspection Commands

Check frontend container:

```bash
docker exec frontend nginx -t
```

Check Docker DNS:

```bash
docker exec frontend getent hosts backend
```

Test backend connectivity:

```bash
docker exec frontend wget -qO- http://backend:3000/health
```

Test backend directly from the host:

```bash
curl http://localhost:3000/health
```

Inspect container health:

```bash
docker inspect --format='{{json .State.Health}}' backend
```

---

# 18. Validation Performed

The following tests were successfully completed.

### Frontend

```text
http://localhost:3001
```

Result:

```text
✅ React application loads through Nginx
```

### Login

```text
POST /api/auth/login
```

Result:

```text
✅ Login successful
```

### Transaction retrieval

```text
POST /api/v1/getTransaction
```

Result:

```text
200 OK
```

The application returned:

```text
success: true
transactions: Array(2)
```

### Browser routing

The browser request was observed as:

```text
http://localhost:3001/api/v1/getTransaction
```

with:

```text
Remote Address: 127.0.0.1:3001
```

This confirms that the browser is communicating with the Nginx entry point.

### Docker DNS

```text
frontend → backend
```

resolved successfully.

### Docker HTTP connectivity

```text
frontend → http://backend:3000/health
```

returned the backend health response successfully.

---

# 19. Troubleshooting Lessons

## Problem 1 — Frontend API URL was undefined

Browser request:

```text
http://localhost:3001/undefined/api/auth/login
```

Root cause:

```text
.env.production
```

was excluded by:

```text
.env
.env.*
```

in `.dockerignore`.

### Lesson

Docker build context matters.

A file existing on the host does not mean Docker can see it.

---

## Problem 2 — Backend healthcheck was unhealthy

Error:

```text
exec: "curl": executable file not found in $PATH
```

Root cause:

The backend image did not contain `curl`.

### Fix

Use Node.js:

```bash
node -e "fetch('http://localhost:3000/health').then(r => { if (!r.ok) process.exit(1) }).catch(() => process.exit(1))"
```

### Lesson

Healthchecks should use tools actually available inside the image.

---

## Problem 3 — Browser continued using old API URL

After rebuilding, the browser initially continued requesting:

```text
http://localhost:3000/api/auth/login
```

A hard refresh was performed:

```text
Ctrl + Shift + R
```

The browser then requested:

```text
http://localhost:3001/api/auth/login
```

### Lesson

Browser caching can make a newly deployed frontend appear unchanged.

---

# 20. Key DevOps Mental Models

### Host port vs container port

```text
localhost:3001
```

means the browser is connecting to the host.

Docker maps:

```text
3001 → 80
```

so the request reaches Nginx on port 80 inside the container.

---

### localhost vs Docker service name

From the browser:

```text
localhost:3001
```

From Nginx:

```text
backend:3000
```

From the backend:

```text
mongodb:27017
```

`localhost` inside a container refers to that container itself.

It does not mean another container.

---

### Browser-facing vs internal networking

The browser should use:

```text
localhost:3001
```

The Nginx container uses:

```text
backend:3000
```

The backend uses:

```text
mongodb:27017
```

Each layer communicates using the address appropriate to its networking environment.

---

# 21. Engineering Principle

This milestone reinforced the project's core workflow:

```text
Engineering Problem
        ↓
Theory
        ↓
Architecture
        ↓
Implementation
        ↓
Experiment
        ↓
Failure
        ↓
Troubleshooting
        ↓
Observation
        ↓
Verification
        ↓
Documentation
```

The goal was not simply to make the application work.

The goal was to understand **why it works** and be able to diagnose it when it doesn't.

---

# 22. Milestone 03 Completion

**Status: ✅ COMPLETE**

The Expense Tracker application is now running as a reproducible three-container stack:

```text
Docker Compose
│
├── Frontend
│   └── Nginx
│
├── Backend
│   └── Node.js / Express
│
└── MongoDB
```

The browser communicates with Nginx as the single frontend/API entry point, while Docker's internal network handles communication between Nginx, the backend, and MongoDB.

---

## Quick Reference

### Start everything

```bash
docker compose up -d
```

### Check everything

```bash
docker compose ps
```

### Rebuild

```bash
docker compose up -d --build
```

### Frontend

```text
http://localhost:3001
```

### Backend health

```text
http://localhost:3000/health
```

### Docker DNS test

```bash
docker exec frontend getent hosts backend
```

### Container-to-container health test

```bash
docker exec frontend wget -qO- http://backend:3000/health
```

### Validate Compose

```bash
docker compose config
```

### View logs

```bash
docker compose logs -f
```

---

## Milestone Principle

> **Make it work locally → Test → Break → Fix → Understand the failure → Move toward production → Automate**
