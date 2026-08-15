# Chapter 02 – Docker Image Optimization

## Overview

After establishing Docker artifact traceability, the next step was to examine the efficiency of the Docker artifact itself.

A Docker image should not only work; it should also contain only what is reasonably required for its intended purpose.

The objective of this milestone was to investigate the size of the Expense Tracker backend image, identify where the size was coming from, optimize the image, and verify that the application continued to work after the changes.

The optimization process was performed incrementally so that each change could be measured and tested.

---

# Objectives

The objectives of this milestone were to:

* Establish a baseline for the existing Docker image.
* Understand Docker image layers.
* Identify large application layers.
* Understand the difference between `dependencies` and `devDependencies`.
* Remove unnecessary development dependencies from the runtime image.
* Separate development and production runtime commands.
* Investigate different Node.js base images.
* Compare `node:22` with `node:22-slim`.
* Build and test an optimized Docker image.
* Measure the improvement achieved.
* Understand how to select an appropriate base image in real-world environments.

---

# Establishing the Baseline

The original Docker image was:

```text
medonati/expense-tracker-backend:1.0.3
```

Docker reported:

```text
DISK USAGE:   1.84GB
CONTENT SIZE: 443MB
```

Using `docker inspect` to determine the image size gave:

```bash
docker inspect medonati/expense-tracker-backend:1.0.3 \
  --format '{{.Size}}' | numfmt --to=iec
```

The result was:

```text
423M
```

This provided our practical baseline for the optimization exercise.

---

# Examining Docker Image Layers

We used:

```bash
docker history medonati/expense-tracker-backend:1.0.3
```

to understand where the image size was coming from.

One of the largest application-specific layers was:

```text
RUN npm install
181MB
```

The application source itself was comparatively small:

```text
COPY . .
332kB
```

This showed that the application source code was not the primary contributor to the image size.

The base `node:22` image also contained several large layers.

This led to two potential areas for optimization:

1. The dependencies installed into the application image.
2. The Node.js base image used by the Dockerfile.

---

# Understanding Dependencies

The application's `package.json` separates packages into:

```json
"dependencies": {}
```

and:

```json
"devDependencies": {}
```

The development dependencies included:

```text
jest
nodemon
supertest
```

These packages are useful during development and testing but are not required for the normal application runtime.

We confirmed the difference using:

```bash
npm ls --omit=dev
```

and:

```bash
npm ls --depth=0
```

The `--omit=dev` command showed only the runtime dependencies, while the complete dependency list also included Jest, Nodemon, and Supertest.

---

# Separating Development and Runtime Dependencies

The original Dockerfile contained:

```dockerfile
RUN npm install
```

This installs both production dependencies and development dependencies.

The container also used:

```dockerfile
CMD ["npm", "run", "dev"]
```

The `dev` script was:

```json
"dev": "APP_ENV=local nodemon server.js"
```

This meant the Docker image was using the development tool `nodemon` as part of its runtime.

For a production-oriented artifact, this was unnecessary.

The Dockerfile was therefore changed to:

```dockerfile
RUN npm install --omit=dev
```

and:

```dockerfile
CMD ["npm", "start"]
```

The `start` script uses:

```json
"start": "APP_ENV=local node server.js"
```

This created a clearer separation:

```text
Development
    ↓
Jest
Nodemon
Supertest

Runtime artifact
    ↓
Application dependencies
    ↓
Node.js
    ↓
server.js
```

---

# First Optimization Result

The optimized image was built as:

```text
expense-tracker-backend:optimization-test
```

Its size was:

```text
407M
```

The dependency installation layer also decreased significantly:

```text
Original:
npm install → 181MB

Optimized:
npm install --omit=dev → 111MB
```

The first optimization therefore reduced the application dependency layer by approximately **70 MB** and reduced the overall image from approximately:

```text
423M → 407M
```

The optimized image was then run as a container.

The logs showed:

```text
> backend@1.0.0 start
> APP_ENV=local node server.js

Starting application with 'local' configuration
```

This confirmed that the application could start successfully without the development dependencies.

---

# Investigating the Base Image

The next question was whether the base image itself could be reduced.

The original Dockerfile used:

```dockerfile
FROM node:22
```

We compared the base image sizes.

The full Node image was approximately:

```text
node:22
390M
```

The slim variant was approximately:

```text
node:22-slim
77M
```

This showed that the base image itself represented a significant optimization opportunity.

However, a smaller image is not automatically a better image.

The new base image had to be tested against the application.

---

# Switching to `node:22-slim`

The Dockerfile was changed from:

```dockerfile
FROM node:22
```

to:

```dockerfile
FROM node:22-slim
```

The other optimization remained in place:

```dockerfile
RUN npm install --omit=dev
```

and:

```dockerfile
CMD ["npm", "start"]
```

The resulting test image was:

```text
expense-tracker-backend:slim-test
```

Its measured size was:

```text
93M
```

This produced a substantial reduction:

```text
Original image:
423M

After removing devDependencies:
407M

After using node:22-slim:
93M
```

The overall reduction from the original baseline was approximately **330 MB**, representing roughly a **78% reduction**.

---

# Testing the Slim Image

The optimized image was started using:

```bash
docker run -d \
  --name expense-tracker-slim-test \
  expense-tracker-backend:slim-test
```

The container remained running:

```text
STATUS
Up
```

The application logs showed:

```text
> backend@1.0.0 start
> APP_ENV=local node server.js

Starting application with 'local' configuration
```

The important result was that:

* The container started.
* Node.js started.
* The application started.
* The application reached its database connection attempt.

Therefore, the switch to `node:22-slim` did not introduce an application startup problem.

---

# Before and After

The optimization process can be summarized as:

```text
                         IMAGE SIZE

Original
node:22 + npm install
        │
        ▼
      423M
        │
        │ Remove development dependencies
        ▼
node:22 + npm install --omit=dev
        │
        ▼
      407M
        │
        │ Change base image
        ▼
node:22-slim + npm install --omit=dev
        │
        ▼
       93M
```

| Stage                       | Image Size |
| --------------------------- | ---------: |
| Original `node:22` image    |       423M |
| `--omit=dev` optimization   |       407M |
| `node:22-slim` optimization |        93M |

The biggest improvement came from changing the base image.

---

# Choosing Between Docker Base Images

One of the most important lessons from this milestone was that base-image selection should not be based solely on size.

Node.js provides different image variants, such as:

```text
node:22
node:22-slim
node:22-alpine
```

These variants have different characteristics and trade-offs.

A good engineering decision considers:

* Application requirements.
* Required operating-system packages.
* Native dependencies.
* Runtime compatibility.
* Development versus production requirements.
* Security considerations.
* Image size.
* Operational requirements.
* Whether the image can actually be tested successfully.

The decision-making process should therefore be:

```text
Application requirements
        ↓
Candidate base image
        ↓
Build
        ↓
Test
        ↓
Measure
        ↓
Compare
        ↓
Choose
```

The smallest image is not automatically the best image.

For example, an application containing native modules or requiring specific operating-system libraries may need a particular base image even if another image is smaller.

---

# Engineering Lesson

The important lesson was not simply:

> `node:22-slim` is smaller than `node:22`.

The deeper lesson was:

> **Base-image selection is an engineering decision based on application requirements, compatibility, security, operational needs, and measurable results.**

Instead of assuming that a particular image is better, we tested alternatives against the actual application.

For the Expense Tracker backend, the evidence showed that:

```text
node:22
    ↓
423M

node:22-slim
    ↓
93M
```

while the application continued to start successfully.

Therefore, `node:22-slim` is currently the better base-image choice for this project.

---

# Challenges Encountered

During this milestone, we encountered and investigated several issues:

* Understanding the difference between Docker's disk usage and image content size.
* Identifying large Docker layers.
* Understanding why `npm install` created a large dependency layer.
* Recognizing that development dependencies were being included in the runtime image.
* Understanding why `nodemon` could not simply be removed without changing the runtime command.
* Comparing full and slim Node.js images.
* Verifying that the slim image could run the application.
* Distinguishing an application dependency failure from a Docker image failure.

---

# Results

At the end of this milestone:

* Development dependencies were removed from the runtime artifact.
* The runtime command was changed from `npm run dev` to `npm start`.
* The Node.js base image was changed from `node:22` to `node:22-slim`.
* The image size was reduced from approximately **423 MB to 93 MB**.
* The optimized container successfully started the Node.js application.
* The MongoDB connection issue was identified as an external dependency issue rather than an image problem.
* Temporary test images were removed after the experiments.

---

# Lessons Learned

* Docker image optimization should be measured rather than assumed.
* `docker history` is useful for identifying large image layers.
* Development dependencies do not necessarily belong in a production runtime image.
* `npm install --omit=dev` can reduce unnecessary dependencies in a runtime image.
* Development and production container commands may need to be different.
* Base-image selection can have a major effect on final artifact size.
* A smaller base image should always be tested against the application.
* The smallest available image is not automatically the best choice.
* Temporary test artifacts should be cleaned up after experiments.
* Optimization should preserve application functionality.

---

# Conclusion

This milestone demonstrated that artifact management is not only about storing and versioning Docker images. It also involves producing artifacts that are efficient and appropriate for their intended environment.

Through measurement and controlled experimentation, the Expense Tracker backend image was reduced from approximately:

```text
423M → 93M
```

while maintaining successful application startup.

The final optimization demonstrated an important DevOps principle:

> **Build smaller artifacts where appropriate, but always balance size against compatibility, functionality, security, and operational requirements.**

This provides a stronger foundation for the next stages of artifact management and deployment.
