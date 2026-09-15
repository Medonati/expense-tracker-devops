# Milestone 04 — Container Registry & Release Distribution

**Volume:** 5 — Frontend & Full-Stack Application Integration
**Status:** In Progress
**Current Phase:** Build & Artifact Distribution Complete
**Next Phase:** EC2 Deployment

---

## 1. Milestone Objective

The objective of this milestone is to move the Expense Tracker application from a locally integrated Docker environment toward an AWS deployment.

The target lab architecture is a single EC2 instance running the application through Docker Compose.

The deployment will use Amazon ECR as the container image registry and Jenkins as the CI/release automation layer.

The intended deployment flow is:

```text
GitHub
   │
   ▼
Jenkins
   │
   ├── Test
   ├── Build Backend
   ├── Build Frontend
   ├── Tag Images
   └── Push Images
          │
          ▼
        ECR
          │
          ▼
        EC2
          │
          ▼
       Docker Compose
```

This milestone intentionally uses a single EC2 instance as a learning/lab architecture. It is not intended to represent the final production architecture.

---

# 2. Target AWS Architecture

The planned AWS deployment architecture is:

```text
                         Internet
                            │
                       :80 / :443
                            │
                            ▼
                    ┌──────────────┐
                    │     EC2      │
                    │              │
                    │   Docker     │
                    │   Compose    │
                    └──────┬───────┘
                           │
                           ▼
                       ┌───────┐
                       │ Nginx │
                       └───┬───┘
                           │
                  ┌────────┴────────┐
                  │                 │
                  ▼                 ▼
             React Frontend      /api
                                    │
                                    ▼
                                Backend
                                :3000
                                    │
                                    ▼
                                MongoDB
                                :27017
```

Nginx will be the public entry point.

The backend and MongoDB will remain internal to the EC2/Docker environment.

---

# 3. Network Exposure Model

The application follows the principle of exposing only the required public entry point.

Expected AWS Security Group rules:

| Port  | Purpose            | Exposure                       |
| ----- | ------------------ | ------------------------------ |
| 22    | SSH administration | Administration IP only         |
| 80    | HTTP               | Public                         |
| 443   | HTTPS              | Public, when TLS is configured |
| 3000  | Backend API        | Not public                     |
| 27017 | MongoDB            | Not public                     |

Docker port publishing and AWS Security Group rules are separate security layers.

For example, publishing:

```text
3000:3000
```

in Docker does not automatically mean that the application should be exposed to the Internet. AWS Security Group rules determine whether external traffic can reach the EC2 instance on that port.

The deployment architecture therefore keeps the backend and database inaccessible directly from the Internet.

---

# 4. Container Image Distribution Strategy

For this milestone, the selected image distribution strategy is:

```text
GitHub → Jenkins → ECR → EC2
```

The application images are built by Jenkins rather than being built directly on the EC2 deployment server.

This follows the principle:

> Build once, deploy the same artifact.

The deployment server should consume the image produced by the CI/release process rather than independently rebuilding application source code.

---

# 5. Amazon ECR Repositories

Two ECR repositories are used.

### Backend

```text
Repository:
expense-tracker-dev-backend
```

ECR registry:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com
```

Full repository:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend
```

### Frontend

```text
Repository:
expense-tracker-dev-frontend
```

Full repository:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend
```

Both repositories are located in:

```text
us-east-1
```

The repositories currently use mutable tags and AES256 encryption.

Image scanning on push is currently disabled for this lab configuration and can be revisited later as the project moves toward a more production-like setup.

---

# 6. ECR IAM Design

Jenkins uses a dedicated AWS IAM identity:

```text
jenkins-ecr-user
```

The user belongs to the IAM group:

```text
jenkins-ecr-push
```

The group contains the ECR push policy.

The Jenkins identity was intentionally kept separate from the broader Terraform execution permissions.

The existing Terraform execution policy contains much broader infrastructure permissions, but it was **not attached to Jenkins**.

This follows the principle of:

> Least privilege.

Jenkins only receives the permissions required for its ECR publishing responsibilities.

---

# 7. Jenkins ECR Permissions

The ECR policy allows authentication and image push operations.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRLogin",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPushToExpenseTracker",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:748241639517:repository/expense-tracker-dev-backend",
        "arn:aws:ecr:us-east-1:748241639517:repository/expense-tracker-dev-frontend"
      ]
    }
  ]
}
```

An important distinction discovered during troubleshooting was:

```text
Authentication ≠ Authorization
```

Being able to authenticate to AWS does not automatically mean the IAM identity has permission to perform every ECR operation.

---

# 8. Jenkins Credential Management

The AWS credentials are stored in Jenkins under:

```text
jenkins-ecr-aws
```

The credentials are injected only when required:

```groovy
withCredentials([
    [$class: 'AmazonWebServicesCredentialsBinding',
     credentialsId: 'jenkins-ecr-aws']
]) {
    // AWS commands
}
```

This means AWS credentials are not configured globally for the Linux `jenkins` user.

Therefore, running this directly from the VM:

```bash
sudo -u jenkins aws sts get-caller-identity
```

returns:

```text
Unable to locate credentials.
```

This is expected.

Inside the Jenkins pipeline, however:

```bash
aws sts get-caller-identity
```

successfully returned:

```text
arn:aws:iam::748241639517:user/jenkins-ecr-user
```

This confirms that Jenkins is correctly injecting the AWS credentials.

---

# 9. Jenkins Release Pipeline

A separate Jenkins pipeline was created for the ECR release process.

Pipeline:

```text
expense-tracker-ecr-release
```

It uses:

```text
Jenkinsfile.ecr
```

The existing repository `Jenkinsfile` was left unchanged.

This keeps the existing CI pipeline separate from the AWS ECR release pipeline.

---

# 10. Release Versioning Strategy

The release was created using the Git tag:

```text
v1.0.4
```

The tag points to commit:

```text
a432179
```

The Jenkins pipeline removes the `v` prefix when creating the Docker release tag:

```text
Git tag:
v1.0.4

Docker release tag:
1.0.4
```

Jenkins also extracts the short Git commit SHA:

```text
a432179
```

The result is two useful Docker tags:

```text
1.0.4
a432179
```

The release version communicates the application release.

The commit SHA provides traceability back to the exact Git revision.

---

# 11. Backend Image Build

The backend image is built using:

```bash
docker build \
  --build-arg VERSION="$IMAGE_TAG" \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  -t "$BACKEND_REPOSITORY:$IMAGE_TAG" \
  -t "$BACKEND_REPOSITORY:$GIT_SHA" \
  -f docker/backend/Dockerfile \
  app/backend
```

The backend Dockerfile supports OCI image metadata through build arguments:

```dockerfile
ARG VERSION
ARG GIT_COMMIT
ARG BUILD_DATE

LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"
```

For release `v1.0.4`, the backend image was built with:

```text
Version:
1.0.4

Git commit:
a43217973cc6f14115f1e6a3b71967595d2694de
```

---

# 12. Frontend Image Build

The frontend image is built independently:

```bash
docker build \
  -t "$FRONTEND_REPOSITORY:$IMAGE_TAG" \
  -t "$FRONTEND_REPOSITORY:$GIT_SHA" \
  -f docker/frontend/Dockerfile \
  app/frontend
```

The frontend Dockerfile uses a multi-stage build:

```text
Node.js build stage
        │
        ▼
npm ci
        │
        ▼
npm run build
        │
        ▼
Nginx runtime image
        │
        ▼
React production files
```

Unlike the backend image, the current frontend Dockerfile does not define the same OCI metadata build arguments, so the ECR release pipeline does not pass those arguments to the frontend build.

---

# 13. Docker Image Tagging Model

For release `v1.0.4`, Jenkins created:

```text
Backend:
expense-tracker-dev-backend:1.0.4
expense-tracker-dev-backend:a432179

Frontend:
expense-tracker-dev-frontend:1.0.4
expense-tracker-dev-frontend:a432179
```

These are two tags pointing to the same image in each repository.

The tags are then converted into ECR-qualified names:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4

748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:a432179
```

and:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4

748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:a432179
```

---

# 14. Image Digests

Docker/ECR also assigns an immutable content digest to an image.

For the backend release:

```text
sha256:7de93559d5fa242557159d1bbc15bc1c5fbaabf4133a86587f4fdcbd424a2bfe
```

Both:

```text
backend:1.0.4
backend:a432179
```

point to this digest.

For the frontend release:

```text
sha256:ccb9beff2d39128f695ae12c6db5a109e21124b11df73af1192cea0766c8811d
```

Both:

```text
frontend:1.0.4
frontend:a432179
```

point to this digest.

Therefore:

```text
Backend

1.0.4 ───────┐
             ├──> sha256:7de93559...
a432179 ─────┘
```

and:

```text
Frontend

1.0.4 ───────┐
             ├──> sha256:ccb9beff...
a432179 ─────┘
```

The Git SHA and image digest are different identifiers.

```text
a432179
```

identifies the Git commit.

```text
sha256:7de93559...
```

identifies the backend image content.

```text
sha256:ccb9beff...
```

identifies the frontend image content.

The relationship exists because Jenkins built the images from the Git commit represented by `a432179`.

---

# 15. Why We Use Both Release and Commit Tags

The release tag:

```text
1.0.4
```

answers:

> Which application release is this?

The commit tag:

```text
a432179
```

answers:

> Which Git revision produced this image?

The digest answers:

> What exact image content is this?

Together they provide a useful traceability chain:

```text
v1.0.4
   │
   ▼
a432179
   │
   ▼
Docker Image
   │
   ▼
ECR
   │
   ▼
Immutable Digest
```

This will become particularly important when deploying the image to EC2.

---

# 16. ECR Authentication Test

Before the final release succeeded, ECR authentication was tested independently from the release pipeline.

The following command was used inside a Jenkins credential context:

```bash
aws sts get-caller-identity
```

It returned:

```text
arn:aws:iam::748241639517:user/jenkins-ecr-user
```

The ECR login command was then tested:

```bash
aws ecr get-login-password \
  --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  748241639517.dkr.ecr.us-east-1.amazonaws.com
```

The result was:

```text
Login Succeeded
```

This confirmed that Jenkins could successfully authenticate Docker to ECR.

---

# 17. Troubleshooting the Initial Release Failure

The first `v1.0.4` release attempt encountered multiple failures.

## Docker Build Failure

The backend build initially failed with:

```text
failed to commit snapshot
snapshot ... does not exist: not found
```

The Docker environment was investigated.

The environment included:

```text
Docker: 29.1.3
Buildx: 0.30.1
Storage Driver: overlayfs
Docker Root Dir: /var/lib/docker
Ubuntu: 22.04.5 LTS
CPU: 2
Memory: approximately 1.9 GiB
```

Disk space was also checked:

```text
39G total
21G used
18G available
```

Docker storage usage was inspected using:

```bash
docker system df
```

A manual build of the same backend image outside Jenkins subsequently succeeded.

The pipeline was then rerun and the backend build succeeded.

The failure was therefore treated as a transient Docker/build environment issue rather than a confirmed Dockerfile defect.

---

# 18. ECR Login Failure

After the Docker builds succeeded, the pipeline initially failed during:

```bash
aws ecr get-login-password --region us-east-1
```

The error was:

```text
Could not connect to the endpoint URL:
"https://api.ecr.us-east-1.amazonaws.com/"
```

At this point, no pipeline or IAM change was immediately made.

The failure was isolated through controlled testing.

First, the AWS identity was tested inside Jenkins.

It succeeded:

```text
arn:aws:iam::748241639517:user/jenkins-ecr-user
```

A separate test of:

```bash
aws ecr describe-repositories
```

returned an `AccessDeniedException` because the Jenkins IAM policy does not include:

```text
ecr:DescribeRepositories
```

This was not considered a problem because the release pipeline does not require that permission.

The exact ECR authentication operation was then tested:

```bash
aws ecr get-login-password \
  --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  748241639517.dkr.ecr.us-east-1.amazonaws.com
```

The command succeeded:

```text
Login Succeeded
```

The release pipeline was rerun without modifying the pipeline or IAM configuration.

The subsequent release succeeded.

This demonstrated the importance of testing the exact failing operation rather than changing configuration based on assumptions.

---

# 19. Successful ECR Release

The final `v1.0.4` pipeline completed successfully.

The pipeline performed:

```text
Checkout                    ✓
Install Dependencies        ✓
Verify Environment          ✓
Validate Source             ✓
Run Tests                   ✓
Determine Release Version    ✓
Build Backend Image         ✓
Build Frontend Image        ✓
Verify Docker Artifacts     ✓
Login to ECR                 ✓
Tag Images for ECR           ✓
Push Backend to ECR          ✓
Push Frontend to ECR         ✓
```

Jenkins reported:

```text
Finished: SUCCESS
```

GitHub was also notified of the build result.

---

# 20. ECR Artifact Verification

After the Jenkins release succeeded, the images were independently verified using AWS CLI.

Backend:

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-backend \
  --region us-east-1 \
  --query 'imageDetails[].{Tags:imageTags,Digest:imageDigest}' \
  --output table
```

The release image was confirmed as:

```text
Tags:
1.0.4
a432179

Digest:
sha256:7de93559d5fa242557159d1bbc15bc1c5fbaabf4133a86587f4fdcbd424a2bfe
```

Frontend:

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-frontend \
  --region us-east-1 \
  --query 'imageDetails[].{Tags:imageTags,Digest:imageDigest}' \
  --output table
```

The release image was confirmed as:

```text
Tags:
1.0.4
a432179

Digest:
sha256:ccb9beff2d39128f695ae12c6db5a109e21124b11df73af1192cea0766c8811d
```

This independently verified that both release artifacts exist in ECR.

---

# 21. Lessons Learned

### 21.1 Authentication and authorization are different

Successfully authenticating to AWS does not grant permission to perform every AWS operation.

The Jenkins identity could authenticate successfully while lacking:

```text
ecr:DescribeRepositories
```

---

### 21.2 Don't change configuration before identifying the failure

The first ECR failure did not automatically justify changing IAM permissions.

The exact command was tested separately before modifying anything.

---

### 21.3 Retry can be valid for transient failures

The pipeline eventually succeeded without changing its configuration.

However, a successful retry does not prove the exact root cause of a transient failure.

The correct conclusion is that the failure was not reproducible on the subsequent attempt.

---

### 21.4 Build once, deploy the same artifact

Jenkins builds the container images.

ECR stores those artifacts.

EC2 will later pull those same artifacts.

The deployment server should not rebuild the application.

---

### 21.5 Tags provide human-readable identity

```text
1.0.4
a432179
```

make images easy to identify.

---

### 21.6 Digests provide immutable artifact identity

A digest identifies the image content independently of its tag.

This allows us to verify that a deployed container corresponds to the expected artifact.

---

### 21.7 Least privilege matters

The Jenkins IAM identity was given ECR permissions rather than the much broader Terraform execution policy.

This keeps CI/CD permissions separated from infrastructure-management permissions.

---

# 22. Current Status

### Completed

```text
✓ Local full-stack application
✓ Frontend Docker container
✓ Backend Docker container
✓ MongoDB container
✓ Nginx integration
✓ Docker Compose integration
✓ ECR backend repository
✓ ECR frontend repository
✓ Jenkins ECR credentials
✓ Jenkins ECR permissions
✓ Release tagging
✓ Backend image build
✓ Frontend image build
✓ ECR authentication
✓ Backend ECR push
✓ Frontend ECR push
✓ ECR artifact verification
```

### Not Yet Completed

```text
□ Prepare EC2 deployment environment
□ Configure EC2 Docker Compose deployment
□ Pull release images from ECR
□ Deploy Nginx
□ Configure AWS Security Group
□ Run application on EC2
□ Validate frontend
□ Validate backend through Nginx
□ Validate database connectivity
□ Perform end-to-end AWS testing
□ Document final deployment
```

---

# 23. Next Step

The next engineering problem is:

> How do we take the exact images stored in ECR and run them on the EC2 deployment server?

The next phase will therefore inspect the existing EC2 environment before making changes.

No EC2 deployment has been performed yet.
