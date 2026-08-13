# 04 — GitHub Webhooks & Tag-Based Releases

## Overview

This document captures the transition from a Jenkins pipeline that required manual interaction to an event-driven CI/CD workflow.

Up to this point, Jenkins was able to validate the application, run automated tests, build a Docker image, verify the artifact, and push the image to Docker Hub.

The next objective was to remove the remaining manual steps.

The goal was to allow GitHub to automatically notify Jenkins when changes occur and use Git tags to identify Docker releases.

The target workflow became:

```text
GitHub
   ↓
Webhook
   ↓
Jenkins
   ↓
Git Tag
   ↓
Docker Build
   ↓
Docker Hub
```

The Expense Tracker backend continues to be the primary workload used throughout this phase of the DevOps project.

---

## From Manual Execution to Event-Driven CI/CD

The pipeline previously depended on Jenkins being manually interacted with when changes needed to be processed.

The next evolution was:

```text
Developer
    ↓
git push
    ↓
GitHub
    ↓
Webhook
    ↓
Jenkins
    ↓
CI Pipeline
```

For a release, the workflow becomes:

```text
Developer
    ↓
git tag
    ↓
git push
    ↓
GitHub
    ↓
Webhook
    ↓
Jenkins
    ↓
Docker Build
    ↓
Docker Hub
```

This changes Jenkins from a system that we manually tell to build into a system that reacts to repository events.

---

## Making Local Jenkins Reachable

Jenkins is running inside the local Vagrant DevOps lab.

The Jenkins server is therefore accessible locally through:

```text
http://localhost:8080
```

GitHub cannot directly send a webhook to a local `localhost` address.

To solve this, ngrok was introduced as a temporary public HTTPS tunnel.

The architecture became:

```text
GitHub
   │
   ▼
ngrok
   │
   ▼
localhost:8080
   │
   ▼
Jenkins
```

ngrok provided a public HTTPS address that forwarded requests to the Jenkins server running in the local lab.

---

## Testing the Webhook

Before configuring GitHub itself, the Jenkins webhook endpoint was tested manually.

The Multibranch Scan Webhook Trigger plugin provided the endpoint:

```text
/multibranch-webhook-trigger/invoke
```

The endpoint was tested using:

```powershell
curl.exe -v -X POST "https://<ngrok-domain>/multibranch-webhook-trigger/invoke?token=<trigger-token>"
```

The first request produced a Windows Schannel TLS error.

A verbose request was then used to inspect the connection.

The request successfully reached Jenkins and returned:

```text
HTTP/1.1 200 OK
```

The response indicated that the Multibranch project had been triggered.

However, the HTTP response alone was not treated as sufficient evidence.

The existing repository scan was cancelled and the webhook was tested again while Jenkins was idle.

The Scan Repository Log then showed:

```text
Started
[Wed Aug 12 11:38:18 UTC 2026] Starting branch indexing...
```

The timestamp matched the webhook request.

This confirmed that the webhook was actually triggering the Multibranch scan.

---

## GitHub API Authentication

The webhook was working, but repository indexing initially became slow.

Jenkins was connecting to GitHub using anonymous API access:

```text
Connecting to https://api.github.com with no credentials, anonymous access
```

The repository scan eventually reached the Jenkins-imposed API limiter and Jenkins had to pause before continuing.

This demonstrated an important distinction:

```text
Webhook
   ↓
Jenkins
   ↓
GitHub API
```

The webhook can successfully reach Jenkins while Jenkins can still experience problems communicating with the GitHub API.

---

## Configuring GitHub Credentials

A GitHub Personal Access Token was configured in Jenkins Credentials.

The GitHub Branch Source configuration was updated to use the credential.

The Jenkins log then showed:

```text
Connecting to https://api.github.com using Medonati/*****
(GitHub API credentials for Jenkins Multibranch)
```

After authentication was configured, repository indexing completed much faster.

One of the successful scans completed in approximately 11 seconds.

The result was:

```text
Finished branch indexing. Indexing took 11 sec
Finished: SUCCESS
```

This established authenticated communication between Jenkins and the GitHub API.

---

## GitHub Commit Status

The first successful automated build exposed another issue.

The Jenkins pipeline itself completed successfully, but Jenkins could not update the GitHub commit status.

The error was:

```text
Could not update commit status.

Resource not accessible by personal access token

403
```

The GitHub credential was updated with the required permission to write commit statuses.

After the permission was corrected, Jenkins reported:

```text
GitHub has been notified of this commit’s build result

Finished: SUCCESS
```

This demonstrated the difference between authentication and authorization.

The credential could authenticate with GitHub, but it also needed the appropriate permission for the specific operation Jenkins was trying to perform.

---

## Normal Commits vs Release Tags

The pipeline now has two different behaviors.

A normal commit to `main` continues to run the CI stages:

```text
Install Dependencies
        ↓
Verify Environment
        ↓
Validate Source
        ↓
Run Tests
```

The Docker release stages are skipped:

```text
Determine Release Version
        ↓
SKIPPED

Build Docker Image
        ↓
SKIPPED

Verify Docker Artifact
        ↓
SKIPPED

Push Docker Image
        ↓
SKIPPED
```

This prevents every normal commit from publishing a Docker image.

A Git tag represents a release and therefore activates the Docker release stages.

---

## Tag Discovery

The Jenkins Multibranch Pipeline was already capable of discovering Git tags.

When a tag was pushed, Jenkins reported:

```text
Checking tag v1.0.1
  ‘Jenkinsfile’ found
Met criteria
```

However, Jenkins then reported:

```text
No automatic build triggered for v1.0.1
```

This revealed an important concept:

> Discovering a tag and automatically building a tag are two separate operations.

Jenkins knew that the tag existed, but there was no configured build strategy telling Jenkins to automatically execute the tag pipeline.

---

## Tag Build Strategy

The Basic Branch Build Strategies plugin was installed to provide the required tag build strategy.

The Multibranch configuration now contains:

```text
Build strategies
    ↓
Tags
```

After saving the configuration, Jenkins automatically scheduled discovered tags without requiring the **Build Now** action.

This changed the workflow from:

```text
Tag discovered
      ↓
Manual build
```

to:

```text
Tag discovered
      ↓
Automatic build
```

---

## Jenkins Executors and Build Queue

When the tag build strategy was first enabled, Jenkins discovered multiple existing tags and automatically scheduled them.

The repository contained tags such as:

```text
v0.3-ci-artifacts
v0.4-docker-registry
v1.0.0
v1.0.1
```

The Jenkins installation had two executors.

Therefore, two builds could run at the same time while the remaining builds waited in the queue.

The build queue demonstrated that:

```text
2 Executors
    ↓
2 Builds Running
    ↓
Additional Builds Queued
```

This was not a pipeline failure.

It was Jenkins applying its executor limit.

---

## Git Tag-Based Docker Versioning

The next improvement was to make the Git release tag the source of truth for the Docker image version.

The pipeline runs:

```bash
git describe --tags --exact-match
```

For the release:

```text
v1.0.1
```

Jenkins reported:

```text
🏷️ Git release tag: v1.0.1
📦 Docker image tag: 1.0.1
```

The leading `v` is removed when generating the Docker image tag.

Therefore:

```text
Git Tag       Docker Tag

v1.0.0   →    1.0.0
v1.0.1   →    1.0.1
v1.0.2   →    1.0.2
```

The Git release tag now determines the Docker release version.

---

## Creating the Release

The repository was first verified:

```bash
git status
```

The working tree was clean and up to date.

The release tag was created:

```bash
git tag -a v1.0.1 -m "Release v1.0.1"
```

The tag was inspected:

```bash
git show v1.0.1
```

The tag pointed to the latest commit:

```text
4b5fa06384b401f754db9d12d705df9fe0966196
```

The release was then pushed:

```bash
git push origin v1.0.1
```

No Jenkins build was manually started.

GitHub triggered the webhook and Jenkins automatically processed the release tag.

---

## Docker Release

Jenkins identified the release:

```text
Git release tag: v1.0.1
Docker image tag: 1.0.1
```

The Docker image was built using:

```text
medonati/expense-tracker-backend:1.0.1
```

The pipeline then verified the image before publishing it.

The Docker image list contained:

```text
medonati/expense-tracker-backend:1.0.0
medonati/expense-tracker-backend:1.0.1
```

This confirmed that the new release artifact had been created locally.

---

## Publishing the Release

The pipeline authenticated with Docker Hub using the credentials already configured in the Jenkins Credentials Store.

Docker authentication succeeded:

```text
Login Succeeded
```

The image was then pushed:

```bash
docker push medonati/expense-tracker-backend:1.0.1
```

Docker Hub accepted the image and returned a digest:

```text
1.0.1: digest:
sha256:03875437d96db1d1f0e7b455735014b35dd96f5c7108fb6dbfc2e74a26843da5
```

Jenkins completed successfully:

```text
✅ Docker image pushed successfully.
🎉 Jenkins pipeline completed successfully.

GitHub has been notified of this commit’s build result

Finished: SUCCESS
```

---

## The Complete Release Flow

```text
git tag -a v1.0.1 -m "Release v1.0.1"
                ↓
        git push origin v1.0.1
                ↓
             GitHub
                ↓
            Webhook
                ↓
             ngrok
                ↓
             Jenkins
                ↓
       Multibranch Indexing
                ↓
          Tag Discovered
                ↓
        Tag Build Strategy
                ↓
          Jenkins Build
                ↓
       Determine Version
                ↓
              1.0.1
                ↓
          Docker Build
                ↓
       Verify Docker Image
                ↓
        Docker Hub Login
                ↓
          Docker Push
                ↓
medonati/expense-tracker-backend:1.0.1
```

---

## Key Lessons

### 1. Local infrastructure can still participate in event-driven CI/CD

Even though Jenkins is running locally inside a Vagrant lab, ngrok allows external services such as GitHub to communicate with it.

### 2. A webhook is not the same as a build

The webhook triggers Jenkins to perform Multibranch processing.

Jenkins still has to inspect the repository and determine what should be built.

### 3. Tag discovery and tag building are different

Jenkins can discover a tag without automatically building it.

The build strategy determines whether the discovered tag should actually trigger a build.

### 4. Git tags can drive releases

A Git tag can be used as the release signal for the Docker pipeline.

### 5. Git can provide the Docker version

The Docker image version no longer needs to be manually entered for each release.

The Git tag provides the version:

```text
v1.0.1 → 1.0.1
```

### 6. Authentication and authorization are different

A credential can successfully authenticate with GitHub but still lack permission for a particular API operation.

### 7. Jenkins executors determine concurrency

When more builds are scheduled than available executors, additional builds wait in the queue.

---

## Current Architecture

```text
                     GitHub
                        │
                        │ Webhook
                        ▼
                      ngrok
                        │
                        ▼
                     Jenkins
                        │
                 Multibranch Pipeline
                        │
              ┌─────────┴─────────┐
              │                   │
           main                 Git Tag
              │                   │
              ▼                   ▼
          CI Pipeline       Release Pipeline
              │                   │
              ▼                   ▼
            Tests          Determine Version
                                  │
                                  ▼
                            Docker Build
                                  │
                                  ▼
                           Docker Artifact
                                  │
                                  ▼
                             Docker Hub
```

---

## What's Next?

The CI/CD pipeline can now automatically move a Git release tag all the way to a versioned Docker image in Docker Hub.

During the `v1.0.1` release, Docker displayed a warning that the legacy builder is deprecated and recommended BuildKit/buildx.

The next milestone will investigate:

**Docker BuildKit & buildx**

The goal will be to understand why Docker is moving away from the legacy builder and how modern Docker image builds can be integrated into Jenkins.
