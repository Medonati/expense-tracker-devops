# Docker Build Optimization

## Overview

As part of improving the CI/CD pipeline for the Expense Tracker DevOps project, we investigated unusually slow Docker build times and optimized the Docker build process.

Rather than immediately changing the Dockerfile, we first established a performance baseline, investigated the root cause, implemented a targeted fix, and measured the improvement.

---

## Problem Statement

Building the backend Docker image was taking an unusually long time.

During the build, Docker reported:

```text
Sending build context to Docker daemon 89.7MB
```

The build spent an excessive amount of time during the following instruction:

```dockerfile
COPY . .
```

This indicated that Docker was copying a much larger build context than expected.

---

## Investigation

The backend directory size was inspected.

```bash
du -sh app/backend
```

Result:

```text
138M app/backend
```

The `node_modules` directory was then inspected.

```bash
du -sh app/backend/node_modules
```

Result:

```text
138M app/backend/node_modules
```

This confirmed that almost the entire backend directory consisted of dependencies that should never be sent as part of the Docker build context.

A search for the `.dockerignore` file was then performed.

```bash
find . -name ".dockerignore"
```

Result:

```text
./docker/backend/.dockerignore
```

The Docker build command was using the following build context:

```bash
docker build \
  -t expense-tracker-backend:1.0.0 \
  -f docker/backend/Dockerfile \
  app/backend
```

This revealed the root cause.

Docker only looks for a `.dockerignore` file in the **root of the build context** (`app/backend`), not beside the Dockerfile.

Because the `.dockerignore` file was stored in `docker/backend`, Docker ignored it entirely.

As a result, the entire `node_modules` directory was being transferred to the Docker daemon during every build.

---

## Solution

The `.dockerignore` file was moved into the build context:

```text
app/backend/.dockerignore
```

The file was updated to exclude unnecessary files from the build context.

```text
node_modules
.git
.gitignore
tests
coverage
*.log
npm-debug.log*
.DS_Store
Thumbs.db
.vscode
.idea
.env
.env.*
```

This ensured that only the files required for building the application were sent to Docker.

---

## Results

### Before

| Metric        |                                     Value |
| ------------- | ----------------------------------------: |
| Build Context |                                   ~138 MB |
| Docker Build  |                            Extremely slow |

### After

Docker reported:

```text
Sending build context to Docker daemon 280.2kB
```

The build completed successfully.

The resulting Docker image size was:

```text
443 MB
```

This image size became the baseline for future optimization using multi-stage builds.

---

## Image Analysis

The image history showed that the largest application layer was produced by dependency installation.

```text
RUN npm install    181 MB
```

The application source code itself occupied only a few hundred kilobytes.

This demonstrated that:

* the application code is relatively small;
* most of the image size comes from the base image and installed dependencies;
* future optimizations should focus on dependency management and production-only runtime images.

---

## Lessons Learned

This investigation reinforced several important DevOps principles.

* Always establish a baseline before optimizing.
* Measure first, then improve.
* Docker reads `.dockerignore` from the build context, not from the Dockerfile location.
* A small build context significantly improves Docker build performance.
* Build artifacts should contain only what is required for packaging the application.
* Root Cause Analysis (RCA) is more valuable than immediately applying a perceived fix.

---

## Next Steps

The next phase of the project will focus on producing a production-ready Docker artifact by:

* refactoring application startup to be environment-driven;
* implementing a multi-stage Docker build;
* installing production dependencies only;
* comparing the new image against the current baseline;
* integrating the optimized image build into the Jenkins CI pipeline.

---

## Key Takeaway

The most impactful optimization during this phase was **not** changing the Dockerfile itself.

It was correctly configuring the Docker build context.

By identifying the true root cause and validating the improvement with measurable results, the build process became significantly more efficient while establishing a solid foundation for future Docker and CI/CD optimizations.

