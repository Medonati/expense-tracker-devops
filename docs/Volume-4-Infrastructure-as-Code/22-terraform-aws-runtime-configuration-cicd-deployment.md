# Note 22 — Terraform AWS Runtime Configuration & CI/CD Deployment

## Objective

Complete the AWS deployment path by connecting the infrastructure provisioned with Terraform to the existing Docker/Jenkins workflow.

The goal was to deploy the Expense Tracker backend to AWS using:

```text
GitHub
   ↓
Jenkins
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
EC2
   ↓
Health Check
```

We also needed to solve a real deployment failure caused by application configuration being handled incorrectly inside the Docker image.

---

## 1. The Deployment Problem

The first Jenkins deployment reached EC2 successfully, pulled the Docker image, and started the container.

However, the application repeatedly restarted.

The health check failed with:

```text
curl: (7) Failed to connect to localhost port 3000
```

We inspected the container logs:

```bash
docker logs backend
```

The important error was:

```text
Configuration file not found: ./config/config.docker.env
```

The application was trying to load an environment-specific configuration file from inside the container.

---

## 2. Why the Configuration File Was Missing

The application contained environment files such as:

```text
config.local.env
config.docker.env
config.test.env
config.env
config.env.example
```

The real configuration files were intentionally excluded from Git using:

```gitignore
**/config*.env
```

We verified this with:

```bash
git check-ignore -v app/backend/config/config.docker.env
```

which confirmed that the file was ignored.

The Docker image also did not contain the real configuration file.

We verified the image with:

```bash
docker run --rm --entrypoint ls \
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.0 \
-la /app/config
```

The image contained only:

```text
config.env.example
```

This was expected because sensitive environment-specific configuration should not be committed to Git or baked into an immutable application image.

---

## 3. Configuration Refactor

Instead of making the Docker image depend on environment-specific files, we changed the application to consume configuration from runtime environment variables.

### Previous approach

The application used:

```text
APP_ENV
   ↓
config.${APP_ENV}.env
   ↓
dotenv
   ↓
Application configuration
```

This created a dependency between the Docker image and configuration files.

### New approach

The application now uses:

```text
Runtime Environment
       ↓
process.env
       ↓
Application
```

The new `server.js` became:

```js
import app from "./app.js";
import { connectDB } from "./DB/Database.js";

const port = process.env.PORT;

const startServer = async () => {
  try {
    await connectDB();

    app.listen(port, () => {
      console.log(`Server is listening on http://localhost:${port}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
};

startServer();
```

The database connection uses:

```js
import mongoose from "mongoose";

export const connectDB = async () => {
  try {
    const db = process.env.MONGO_URL;

    const { connection } = await mongoose.connect(db);

    console.log(`MongoDB Connected to ${connection.host}`);
  } catch (error) {
    console.error("MongoDB connection failed:", error.message);

    process.exit(1);
  }
}
```

The application is therefore independent of a specific environment configuration file.

---

## 4. Runtime Configuration

The container now receives its configuration when it starts.

Example:

```bash
docker run -d \
  --name backend \
  --network expense-network \
  -p 3000:3000 \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  --restart unless-stopped \
  "$IMAGE"
```

The important distinction is:

```text
Docker Image
    ↓
Application code

Container Runtime
    ↓
Environment-specific configuration
```

This allows the same image to be used in different environments without rebuilding it for every environment.

---

## 5. Local Docker Validation

Before rebuilding and deploying the new image, we tested the refactored application locally.

We built a temporary image using the same Dockerfile:

```bash
docker build \
  -t expense-tracker-config-test \
  -f docker/backend/Dockerfile \
  app/backend
```

We initially started the temporary container on the wrong network.

The container reported:

```text
MongoDB connection failed: getaddrinfo EAI_AGAIN mongodb
```

We investigated the Docker networks.

MongoDB was running on:

```text
expense-tracker-devops_default
```

while the temporary backend was initially connected to:

```text
expense-network
```

We verified the network configuration using:

```bash
docker inspect mongodb --format '{{json .NetworkSettings.Networks}}'
```

and:

```bash
docker inspect config-test-backend \
  --format '{{json .NetworkSettings.Networks}}'
```

We then removed the temporary container and recreated it directly on the correct Compose network:

```bash
docker rm -f config-test-backend
```

```bash
docker run -d \
  --name config-test-backend \
  --network expense-tracker-devops_default \
  -p 3001:3000 \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  expense-tracker-config-test
```

The application then started successfully.

Logs showed:

```text
MongoDB Connected to mongodb
Server is listening on http://localhost:3000
```

The final health check returned:

```json
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This proved that the configuration refactor worked inside Docker before we changed the AWS deployment.

---

## 6. Deployment Script Update

Because `APP_ENV` was no longer used by the application, we removed it from `deploy.sh`.

The deployment command became:

```bash
docker run -d \
  --name backend \
  --network expense-network \
  -p 3000:3000 \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  --restart unless-stopped \
  "$IMAGE"
```

The deployment script still performs:

```text
Pull image
   ↓
Stop old container
   ↓
Remove old container
   ↓
Start new container
   ↓
Wait
   ↓
Health check
```

The health check is:

```bash
curl --fail http://localhost:3000/health
```

A failed health check causes the script to fail because the script uses:

```bash
set -e
```

---

## 7. Versioning the New Artifact

The previous artifact was:

```text
expense-tracker-dev-backend:1.0.0
```

After changing the application configuration behavior, we created a new artifact:

```text
expense-tracker-dev-backend:1.0.1
```

The image was built with:

```bash
docker build \
  -t expense-tracker-dev-backend:1.0.1 \
  -f docker/backend/Dockerfile \
  app/backend
```

We verified it with:

```bash
docker images expense-tracker-dev-backend:1.0.1
```

Image ID:

```text
9990a9f582fe
```

---

## 8. Publishing to Amazon ECR

The image was tagged for ECR:

```bash
docker tag \
  expense-tracker-dev-backend:1.0.1 \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.1
```

Docker was authenticated using:

```bash
aws ecr get-login-password --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  748241639517.dkr.ecr.us-east-1.amazonaws.com
```

Result:

```text
Login Succeeded
```

The image was pushed:

```bash
docker push \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.1
```

We then verified the image in ECR:

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-backend \
  --image-ids imageTag=1.0.1 \
  --region us-east-1 \
  --query 'imageDetails[0].[imageTags[0],imageDigest,imageSizeInBytes]' \
  --output table
```

The resulting digest was:

```text
sha256:9990a9f582fe8cc7ed4966f87f21e074fb487b94cf84bd67231bd480514b1dda
```

This confirmed that the new artifact was present in ECR.

---

## 9. Jenkins Deployment

The existing repository `Jenkinsfile` was not modified.

The deployment pipeline was configured separately in:

```text
EC2-SSH-Test
```

The pipeline performs:

```text
Checkout
   ↓
Test
   ↓
Build Docker Image
   ↓
Push to ECR
   ↓
Deploy to EC2
```

The pipeline was updated to use:

```text
1.0.1
```

instead of:

```text
1.0.0
```

The EC2 public IP was also updated after the instance was restarted.

We first verified SSH connectivity from the DevOps VM:

```bash
ssh -o StrictHostKeyChecking=no \
  -i ~/.ssh/expense-tracker-dev \
  ec2-user@18.208.171.82 \
  "hostname && docker --version"
```

Docker was available on the EC2 instance.

The Jenkins pipeline was then executed.

---

## 10. Final Deployment Result

The deployment successfully reached EC2.

The deployment script pulled the new image, replaced the previous backend container, started the new application, and executed the health check.

The final result was:

```text
{"status":"UP","message":"Expense Tracker Backend is healthy"}

Deployment successful.
```

Jenkins finished with:

```text
Finished: SUCCESS
```

Therefore the complete deployment path was successfully demonstrated.

---

## 11. Final Architecture

```text
                         GitHub
                            │
                            ▼
                         Jenkins
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
           Testing                    Docker Build
                                          │
                                          ▼
                                         ECR
                                          │
                                          │ 1.0.1
                                          ▼
                                         EC2
                                          │
                                  ┌───────┴───────┐
                                  ▼               ▼
                               Backend         MongoDB
                                  │
                                  ▼
                              /health
                                  │
                                  ▼
                                UP ✅
```

Terraform provides and manages the AWS infrastructure:

```text
Terraform
   │
   ├── VPC
   ├── Subnet
   ├── Route Table
   ├── Internet Gateway
   ├── Security Group
   ├── IAM
   ├── EC2
   ├── ECR
   └── S3
```

Jenkins handles application delivery:

```text
GitHub
   ↓
Test
   ↓
Build
   ↓
Push
   ↓
Deploy
```

This establishes a clear separation:

> **Terraform manages infrastructure; Jenkins manages application delivery.**

---

## 12. Questions We Asked

### Why shouldn't configuration files containing environment-specific values be baked into the Docker image?

Because the image should remain an immutable application artifact.

Environment-specific configuration should be supplied at runtime.

---

### What does the Docker image contain?

The application and its dependencies.

It does not need to contain environment-specific runtime configuration.

---

### Why did the first Docker test fail with `EAI_AGAIN mongodb`?

Because the temporary backend container was not connected to the same Docker network as the MongoDB container.

Docker DNS resolution depends on the containers sharing a suitable network.

---

### Why did we test locally before pushing the new image to ECR?

To isolate the application change from the AWS deployment layer.

We wanted to prove:

```text
Application change works
        ↓
Docker works
        ↓
Then deploy to AWS
```

rather than debugging application and infrastructure problems simultaneously.

---

## 13. Experiments We Performed

We deliberately investigated the original deployment failure.

### Experiment 1 — Inspect the image

Verified that the expected configuration file was not inside the image.

### Experiment 2 — Refactor runtime configuration

Changed the application from environment-file selection to `process.env`.

### Experiment 3 — Run the new image locally

Injected:

```text
PORT
MONGO_URL
```

at container runtime.

### Experiment 4 — Investigate Docker networking

Compared the networks used by:

```text
MongoDB
Backend
```

and corrected the test container's network.

### Experiment 5 — Validate application health

Confirmed:

```text
MongoDB Connected
Server listening
/health → UP
```

### Experiment 6 — Deploy through Jenkins

Published `1.0.1` to ECR and deployed it to EC2.

---

## 14. Observations

Several important observations came from this exercise.

### Running is not the same as ready

The Docker container could exist while the application was restarting.

The health endpoint provided stronger evidence of operational readiness.

### Successful `docker push` is not deployment

The image being present in ECR does not mean the application is running on EC2.

The deployment still requires:

```text
Pull
   ↓
Replace container
   ↓
Start application
   ↓
Health check
```

### Network problems can appear as application problems

The `EAI_AGAIN mongodb` error initially appeared to be a MongoDB/application issue.

Network inspection showed that the actual problem was Docker network connectivity.

---

## 15. Troubleshooting Commands

### Inspect container logs

```bash
docker logs <container>
```

### Inspect Docker networks

```bash
docker network inspect <network>
```

### Inspect container network membership

```bash
docker inspect <container> \
  --format '{{json .NetworkSettings.Networks}}'
```

### Inspect MongoDB networking

```bash
docker inspect mongodb \
  --format '{{json .NetworkSettings.Networks}}'
```

### Remove a temporary test container

```bash
docker rm -f config-test-backend
```

### Test an application endpoint

```bash
curl http://localhost:3001/health
```

### Verify an ECR image

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-backend \
  --image-ids imageTag=1.0.1 \
  --region us-east-1
```

### Test SSH connectivity

```bash
ssh -o StrictHostKeyChecking=no \
  -i ~/.ssh/expense-tracker-dev \
  ec2-user@<EC2-IP> \
  "hostname && docker --version"
```

---

## 16. Common Mistakes

### Putting secrets or environment-specific configuration into the image

Avoid baking runtime configuration into an immutable application image.

### Assuming a running container is healthy

Always verify the application itself.

### Debugging without checking the network

When one container cannot resolve another container:

```text
Check Docker network membership
        ↓
Check DNS/container names
        ↓
Then investigate the application
```

### Reusing an old image tag after changing application behavior

A new application behavior should produce a new versioned artifact.

We therefore moved from:

```text
1.0.0
```

to:

```text
1.0.1
```

### Modifying unrelated CI/CD configuration

The existing repository `Jenkinsfile` belonged to previous Jenkins work and was intentionally left unchanged.

The AWS deployment pipeline was maintained separately in:

```text
EC2-SSH-Test
```

---

## 17. Best Practices

* Keep application images environment-agnostic.
* Inject runtime configuration through the deployment environment.
* Do not commit sensitive environment files.
* Use immutable/versioned image tags.
* Verify images in the registry before deployment.
* Test application behavior before cloud deployment.
* Use health checks to verify operational state.
* Separate infrastructure provisioning from application delivery.
* Investigate the actual system state instead of assuming the cause.
* Keep temporary experiments isolated from existing containers.
* Preserve persistent database volumes when replacing application containers.

---

## 18. Beyond This Session

The current architecture is intentionally simple:

```text
Jenkins
   ↓
ECR
   ↓
Single EC2
   ↓
Docker
```

Later stages of the roadmap can improve this architecture with additional deployment and operational capabilities.

The current objective, however, was to establish the fundamental relationship between:

```text
Infrastructure
+
Application Artifact
+
Deployment Automation
```

That foundation is now working.

---

## 19. If I Were Interviewed

### "How did you troubleshoot a failed Docker deployment?"

I first checked the container state and logs instead of assuming the health check itself was the problem.

The logs showed that the application was looking for `config.docker.env`, which wasn't included in the image because environment-specific configuration files were intentionally excluded from Git.

Rather than baking the file into the image, I refactored the application to consume runtime environment variables.

I then built a temporary image and tested it locally. That test exposed a separate Docker networking issue because the backend and MongoDB containers were on different networks.

After correcting the test network, the application connected to MongoDB and passed its health check.

I then built a new `1.0.1` image, pushed it to ECR, and deployed it through Jenkins to EC2.

The final `/health` check returned `UP`.

---

### "Why separate Terraform and Jenkins?"

Terraform manages infrastructure:

```text
VPC
EC2
IAM
ECR
S3
Networking
```

Jenkins manages application delivery:

```text
Test
→ Build
→ Push
→ Deploy
→ Health Check
```

Separating those responsibilities makes the system easier to reason about and maintain.

---

## 20. Engineer's Takeaways

The most important lessons from this milestone are:

> **An immutable artifact should not depend on environment-specific files being baked into the image.**

> **Runtime configuration belongs at deployment time.**

> **A container being running does not prove that the application is healthy.**

> **When troubleshooting distributed components, verify networking before assuming an application failure.**

> **Terraform and Jenkins solve different problems: Terraform manages infrastructure; Jenkins delivers application changes.**

> **Successful deployment is not proven until the application itself reports healthy.**

The final engineering workflow is:

```text
Code
 ↓
Test
 ↓
Build
 ↓
Version
 ↓
Publish
 ↓
Deploy
 ↓
Health Check
 ↓
Confidence
```

---

## Commands Used

### Docker

```bash
docker build \
  -t expense-tracker-dev-backend:1.0.1 \
  -f docker/backend/Dockerfile \
  app/backend
```

```bash
docker images expense-tracker-dev-backend:1.0.1
```

```bash
docker logs <container>
```

```bash
docker network inspect <network>
```

```bash
docker inspect <container> \
  --format '{{json .NetworkSettings.Networks}}'
```

### ECR

```bash
aws ecr get-login-password --region us-east-1 | \
docker login \
  --username AWS \
  --password-stdin \
  748241639517.dkr.ecr.us-east-1.amazonaws.com
```

```bash
docker tag \
  expense-tracker-dev-backend:1.0.1 \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.1
```

```bash
docker push \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.1
```

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-backend \
  --image-ids imageTag=1.0.1 \
  --region us-east-1
```

### SSH

```bash
ssh -o StrictHostKeyChecking=no \
  -i ~/.ssh/expense-tracker-dev \
  ec2-user@<EC2-IP> \
  "hostname && docker --version"
```

### Health Check

```bash
curl http://localhost:3000/health
```

---

## Session Outcome

We successfully completed the AWS application deployment path.

The final system demonstrated:

```text
GitHub
   ↓
Jenkins
   ↓
Automated Tests
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
EC2
   ↓
Docker Container
   ↓
MongoDB
   ↓
Health Check
   ↓
SUCCESS
```

The application was successfully deployed using image:

```text
expense-tracker-dev-backend:1.0.1
```

with ECR digest:

```text
sha256:9990a9f582fe8cc7ed4966f87f21e074fb487b94cf84bd67231bd480514b1dda
```

**Volume 4 — Infrastructure as Code is complete.**
