# Troubleshooting

This document records issues encountered while building the Jenkins pipeline and how they were resolved.

---

## Issue 1 – Repository Branch Not Found

### Error

```text
Couldn't find any revision to build.
Verify the repository and branch configuration.
````

### Cause

Jenkins attempted to build the default `master` branch, while the repository uses `main`.

### Resolution

Specify the branch explicitly in the pipeline.

```groovy
git branch: 'main',
    url: 'https://github.com/Medonati/expense-tracker-devops.git'
```

---

## Issue 2 – Node.js Not Found

### Error

```text
node: command not found
npm: command not found
```

### Cause

Node.js was installed using **NVM** for the `vagrant` user. Jenkins runs as the `jenkins` user, so it could not access the developer's Node.js installation.

### Investigation

Verified the environments using:

```bash
sudo -u jenkins which node
sudo -u jenkins which npm
sudo -u jenkins env | grep PATH
```

The Jenkins user did not have access to the NVM installation.

### Resolution

Installed and configured the **NodeJS Plugin**, then created a managed Node.js installation (`node22`) using Jenkins Tool Management.

The pipeline now requests the managed tool instead of relying on the operating system.

---

## Issue 3 – Jenkins Git Checkout / Workspace Failure

### Error

Jenkins encountered a Git checkout failure and eventually reported:

```text
Maximum checkout retry attempts reached, aborting
```

### Cause

The affected Jenkins workspace was in an incomplete or unhealthy Git state.

Rather than immediately changing the Jenkinsfile or repository configuration, the Jenkins workspace was investigated directly.

### Investigation

First, the Jenkins workspace directory was inspected:

```bash
sudo ls -la /var/lib/jenkins/workspace/
```

Git repositories inside the Jenkins workspace were then located:

```bash
sudo find /var/lib/jenkins/workspace/ \
  -maxdepth 3 \
  -type d \
  -name ".git" \
  -print
```

After identifying the affected workspace, its Git state was checked as the `jenkins` user:

```bash
sudo -u jenkins git \
  -C /var/lib/jenkins/workspace/tracker-backend-multibranch_main \
  status
```

The repository history was also inspected:

```bash
sudo -u jenkins git \
  -C /var/lib/jenkins/workspace/tracker-backend-multibranch_main \
  log
```

Because Jenkins performs Git operations as the `jenkins` user, GitHub access was also tested using that same user.

```bash
sudo -u jenkins git fetch --no-tags --force --progress \
  https://github.com/Medonati/expense-tracker-devops.git \
  +refs/heads/main:refs/remotes/origin/main
```

The fetch completed successfully.

### Resolution

The affected Jenkins workspace was removed so Jenkins could recreate it cleanly and perform a fresh checkout.

### Key Lesson

When Jenkins reports a Git checkout failure, inspect the actual Jenkins workspace before assuming that the Jenkinsfile or GitHub repository is the problem.

The investigation process was:

```text
Jenkins Checkout Failure
        ↓
Inspect Workspace
        ↓
Find .git Directory
        ↓
Check Git Status
        ↓
Check Git History
        ↓
Test Git Fetch as jenkins User
        ↓
Identify Workspace Problem
        ↓
Recreate Workspace
        ↓
Retry Jenkins Build
```

Jenkins does not perform Git operations as the normal developer user. It operates through the `jenkins` user and its own workspace.

---

## Issue 4 – Docker Image Push Failed Because of Repository Name

### Error

The Docker image was initially built as:

```text
expense-tracker-backend:1.0.0
```

When Jenkins attempted to push the image, Docker interpreted the destination as:

```text
docker.io/library/expense-tracker-backend:1.0.0
```

The push failed because the repository was not under the correct Docker Hub namespace.

### Cause

The Docker Hub username was missing from the image name.

### Resolution

The image was changed to:

```text
medonati/expense-tracker-backend:1.0.0
```

Docker could then resolve the destination as:

```text
docker.io/medonati/expense-tracker-backend:1.0.0
```

The push subsequently succeeded.

### Key Lesson

The image name determines the destination repository.

```text
expense-tracker-backend:1.0.0
```

and:

```text
medonati/expense-tracker-backend:1.0.0
```

are not the same repository reference.

---

## Issue 5 – ngrok / Webhook TLS Error

### Error

The first webhook test from PowerShell returned:

```text
curl: (35) schannel: failed to receive handshake,
SSL/TLS connection failed
```

### Investigation

The request was repeated with verbose output:

```powershell
curl.exe -v -X POST "https://<ngrok-domain>/multibranch-webhook-trigger/invoke?token=<trigger-token>"
```

The verbose output showed that the connection was successfully established.

Jenkins returned:

```text
HTTP/1.1 200 OK
```

The response also indicated that the Multibranch project had been triggered.

### Resolution

The webhook endpoint itself was confirmed to be functioning.

### Key Lesson

A client-side TLS error does not automatically mean that the webhook server or ngrok tunnel is unavailable.

Verbose network output provides more useful information when diagnosing connectivity problems.

---

## Issue 6 – Webhook Appeared Not to Trigger Jenkins

### Symptom

The webhook returned a successful response, but it initially appeared as though nothing was happening in Jenkins.

### Investigation

The existing repository scan was cancelled.

The webhook request was then sent while Jenkins was idle.

The Scan Repository Log subsequently showed:

```text
Started
[Wed Aug 12 11:38:18 UTC 2026] Starting branch indexing...
```

The timestamp matched the webhook request.

### Resolution

The webhook was confirmed to be working.

### Key Lesson

Do not rely only on the HTTP response from the webhook.

Confirm that Jenkins actually reacts to the event by checking the Multibranch Scan Repository Log.

---

## Issue 7 – GitHub API Rate Limiting

### Symptom

Jenkins repository indexing became very slow.

The log initially showed:

```text
Connecting to https://api.github.com with no credentials, anonymous access
```

Jenkins eventually reported:

```text
Jenkins-Imposed API Limiter
```

and entered a waiting period before continuing its GitHub API requests.

### Cause

Jenkins was communicating with the GitHub API anonymously.

Multibranch indexing can require multiple GitHub API requests, which can cause anonymous API access to become rate-limited.

### Resolution

A GitHub Personal Access Token was configured in Jenkins Credentials.

The GitHub Branch Source configuration was updated to use the credential.

The Jenkins log then showed:

```text
Connecting to https://api.github.com using Medonati/*****
(GitHub API credentials for Jenkins Multibranch)
```

Repository indexing subsequently completed much faster.

For example:

```text
Finished branch indexing. Indexing took 11 sec
Finished: SUCCESS
```

### Key Lesson

Webhook delivery and GitHub API communication are separate parts of the workflow.

The webhook can work correctly while Jenkins is still experiencing GitHub API rate limiting.

Authenticated API access is important for Multibranch Jenkins projects.

---

## Issue 8 – GitHub Commit Status Returned 403

### Error

The Jenkins pipeline completed successfully, but Jenkins could not update the GitHub commit status.

```text
Could not update commit status.

Message:
Resource not accessible by personal access token

status: 403
```

### Cause

The GitHub credential was valid and could authenticate with GitHub, but it did not have the required permission to update commit statuses.

### Resolution

The GitHub credential was updated with the appropriate repository permission.

After the change, Jenkins reported:

```text
GitHub has been notified of this commit’s build result

Finished: SUCCESS
```

### Key Lesson

Authentication and authorization are different.

A credential can successfully authenticate with GitHub while still being denied permission for a particular API operation.

---

## Issue 9 – Git Tag Discovered but No Build Started

### Symptom

Jenkins successfully discovered a Git tag:

```text
Checking tag v1.0.1
  ‘Jenkinsfile’ found
Met criteria
```

However, the scan reported:

```text
No automatic build triggered for v1.0.1
```

### Cause

Jenkins was configured to discover tags, but no tag build strategy had been configured.

### Resolution

The **Basic Branch Build Strategies** plugin was installed.

A tag build strategy was then added under:

```text
Build strategies
    ↓
Tags
```

After saving the configuration, Jenkins automatically scheduled the discovered tags.

No manual **Build Now** action was required.

### Key Lesson

Tag discovery and tag building are separate concepts.

Jenkins can discover a tag without automatically executing the pipeline for that tag.

The build strategy determines what Jenkins does after discovering the tag.

---

## Issue 10 – Multiple Tag Builds Waiting in the Queue

### Symptom

After enabling the tag build strategy, Jenkins automatically scheduled multiple existing tags:

```text
v0.3-ci-artifacts
v0.4-docker-registry
v1.0.0
v1.0.1
```

Two builds were running while two additional builds were waiting in the queue.

### Cause

The Jenkins installation had two executors.

More builds were scheduled than could run simultaneously.

### Resolution

No corrective action was required.

The queued builds were waiting for an available executor.

### Key Lesson

Build queue activity is not necessarily an error.

Jenkins uses executors to control how many builds can run simultaneously.

```text
2 Executors
    ↓
2 Builds Running
    ↓
Additional Builds Queued
```

This also demonstrated that automatically building historical tags can create a large amount of work when a tag strategy is first enabled.

---

## Issue 11 – Docker Legacy Builder Deprecation Warning

### Warning

During the `v1.0.1` release, Docker displayed:

```text
DEPRECATED: The legacy builder is deprecated and will be removed
in a future release.

Install the buildx component to build images with BuildKit.
```

### Cause

The Jenkins environment is currently using Docker's legacy image builder.

### Resolution

No immediate corrective action was required because the Docker build completed successfully:

```text
Successfully built 03875437d96d
Successfully tagged medonati/expense-tracker-backend:1.0.1
```

The warning was recorded as a future improvement rather than treated as a pipeline failure.

### Next Step

Investigate Docker BuildKit and `buildx` and migrate the Jenkins Docker build process to the modern builder.

---

## Useful Diagnostic Commands

### Check Jenkins GitHub API Authentication

Inspect the Multibranch Scan Repository Log for:

```text
Connecting to https://api.github.com using ...
```

rather than:

```text
Connecting to https://api.github.com with no credentials, anonymous access
```

---

### Test the Jenkins Webhook

```powershell
curl.exe -v -X POST "https://<ngrok-domain>/multibranch-webhook-trigger/invoke?token=<trigger-token>"
```

---

### Inspect Jenkins Workspaces

```bash
sudo ls -la /var/lib/jenkins/workspace/
```

---

### Find Git Repositories Inside Jenkins Workspaces

```bash
sudo find /var/lib/jenkins/workspace/ \
  -maxdepth 3 \
  -type d \
  -name ".git" \
  -print
```

---

### Check a Jenkins Workspace Git Status

```bash
sudo -u jenkins git \
  -C /var/lib/jenkins/workspace/<workspace-name> \
  status
```

---

### Inspect Jenkins Workspace Git History

```bash
sudo -u jenkins git \
  -C /var/lib/jenkins/workspace/<workspace-name> \
  log
```

---

### Test GitHub Fetch as the Jenkins User

```bash
sudo -u jenkins git fetch --no-tags --force --progress \
  https://github.com/Medonati/expense-tracker-devops.git \
  +refs/heads/main:refs/remotes/origin/main
```

---

### Check Repository State

```bash
git status
```

---

### Inspect Recent Commits

```bash
git log --oneline --decorate -5
```

---

### List Git Tags

```bash
git tag
```

---

### Inspect a Release Tag

```bash
git show v1.0.1
```

---

### Confirm the Exact Git Tag on the Current Commit

```bash
git describe --tags --exact-match
```

---

### Push a Release Tag

```bash
git push origin v1.0.1
```

---

## Troubleshooting Approach

The main lesson from this phase was to troubleshoot the pipeline layer by layer.

```text
GitHub
   ↓
Webhook
   ↓
ngrok
   ↓
Jenkins
   ↓
GitHub API
   ↓
Multibranch Discovery
   ↓
Build Strategy
   ↓
Pipeline
   ↓
Docker
   ↓
Docker Hub
```

When something fails, identify which layer actually failed before changing the configuration.

For example:

```text
Webhook works
      ↓
Jenkins receives event
      ↓
GitHub API is slow
      ↓
Problem = API authentication/rate limiting
```

Or:

```text
Tag discovered
      ↓
No build triggered
      ↓
Problem = Build Strategy
```

Or:

```text
Pipeline succeeds
      ↓
GitHub status returns 403
      ↓
Problem = Credential authorization
```

Or:

```text
Jenkins checkout fails
      ↓
Inspect workspace
      ↓
Test Git as jenkins user
      ↓
Workspace problem identified
```

This approach prevents changing components that are already working and makes Jenkins troubleshooting more systematic.

---

## Key Lessons

* Read the console output carefully before making changes.
* Validate assumptions before applying fixes.
* Build logs provide valuable information for troubleshooting.
* Root cause analysis is more effective than trial-and-error debugging.
* Jenkins operates under its own `jenkins` user and workspace.
* Webhook delivery, GitHub API access, Multibranch discovery, build strategies, and pipeline execution are separate layers.
* Authentication does not automatically provide authorization.
* Build queue activity does not necessarily indicate a failure.
* Good CI/CD pipelines are improved incrementally through observation and testing.