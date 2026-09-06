# Note 21 — Terraform AWS EC2 & ECR Application Deployment

## 1. Objective

Deploy the already-built Expense Tracker backend container to the AWS EC2 instance using the Docker image stored in Amazon ECR.

The objective was to demonstrate the complete path from Terraform-provisioned AWS infrastructure to a running containerized application, including its MongoDB dependency.

This note also documents the Terraform workflow used to define infrastructure and explains the process for adding a new AWS resource to the project.

---

## 2. Starting Point

At the beginning of this session:

* AWS infrastructure had already been provisioned with Terraform.
* The EC2 instance was already running.
* The EC2 instance had an IAM instance profile attached.
* The EC2 IAM role had permission to access the ECR repository.
* The backend Docker image had already been built and pushed to ECR.
* The EC2 instance had successfully authenticated to ECR.
* The backend image `1.0.0` had already been pulled onto the EC2 instance.

The application image was:

```text
expense-tracker-dev-backend:1.0.0
```

---

## 3. Terraform Project Structure

The AWS infrastructure was managed as code using Terraform.

The project was organized around reusable configuration files and modules rather than placing every resource in one large file.

A typical structure looked like this:

```text
terraform/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── providers.tf
├── versions.tf
├── backend.tf
└── modules/
    ├── networking/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ecr/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The exact module names may vary, but the principle remains the same:

* Root files compose the infrastructure.
* Modules group related resources.
* Variables make configuration reusable.
* Outputs expose values needed by other modules or operators.
* Remote state stores Terraform's state outside the local machine.

---

## 4. Responsibility of Each Terraform File

### `main.tf`

The root `main.tf` connects the modules together.

It defines which modules are used and passes values between them.

For example:

```hcl
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}
```

The root module is responsible for composition rather than containing every implementation detail.

---

### `variables.tf`

The root `variables.tf` declares the inputs accepted by the Terraform configuration.

Example:

```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
```

Variables prevent values from being hardcoded throughout the configuration.

---

### `terraform.tfvars`

The `terraform.tfvars` file provides values for declared variables.

Example:

```hcl
project_name = "expense-tracker"
environment  = "dev"
aws_region   = "us-east-1"
```

This separates configuration values from resource definitions.

Sensitive values should not be committed to source control. If a variable contains credentials or other secrets, it should be supplied through a secure mechanism such as environment variables, a secrets manager, or a protected CI/CD variable.

---

### `outputs.tf`

The root `outputs.tf` exposes useful values after Terraform applies the configuration.

Example:

```hcl
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}
```

Outputs make important infrastructure values easy to retrieve.

---

### `providers.tf`

The provider configuration defines how Terraform communicates with AWS.

Example:

```hcl
provider "aws" {
  region = var.aws_region
}
```

The provider determines which cloud platform Terraform manages and which region is used.

---

### `versions.tf`

The versions file defines Terraform and provider version constraints.

Example:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Version constraints help keep infrastructure behavior predictable across machines and environments.

---

### `backend.tf`

The backend configuration defines where Terraform state is stored.

The project used an S3 remote backend so that state was not limited to one local machine.

Example:

```hcl
terraform {
  backend "s3" {
    bucket = "expense-tracker-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Remote state provides:

* Centralized state storage
* Better collaboration
* Protection against losing local state
* A foundation for state locking when configured with a locking mechanism

Terraform state should be treated as sensitive because it can contain infrastructure details and, depending on the resource, sensitive values.

---

## 5. Terraform Modules

Modules were used to organize infrastructure by responsibility.

Typical module responsibilities included:

```text
Networking
    ├── VPC
    ├── Subnet
    ├── Route Table
    └── Internet Gateway

Security
    └── Security Group

IAM
    ├── IAM Role
    ├── IAM Policy
    └── Instance Profile

EC2
    └── EC2 Instance

ECR
    └── ECR Repository
```

A module normally contains:

```text
main.tf
variables.tf
outputs.tf
```

### Module `main.tf`

Defines the resources managed by the module.

### Module `variables.tf`

Defines the values the module requires from the root configuration.

### Module `outputs.tf`

Exposes values that other modules or the root module may need.

For example, the networking module may output a subnet ID:

```hcl
output "public_subnet_id" {
  value = aws_subnet.public.id
}
```

The EC2 module can then receive that value:

```hcl
module "ec2" {
  source = "./modules/ec2"

  subnet_id = module.networking.public_subnet_id
}
```

This creates a clear dependency between modules without tightly coupling their internal implementation.

---

## 6. Process for Adding a New Terraform Resource

When adding a new AWS resource, the process should be deliberate and consistent.

### Step 1 — Identify the Resource and Its Responsibility

First determine:

* What AWS resource is required?
* Which module owns that responsibility?
* What existing resources does it depend on?
* What values should be configurable?
* What values should be exposed as outputs?

For example, if adding an S3 bucket for application uploads, the resource may belong in a storage module.

If adding an additional security rule, it may belong in the security module.

---

### Step 2 — Decide Whether a New Module Is Needed

A new resource should be added to an existing module when it belongs to that module's responsibility.

For example:

```text
Security group rule → security module
Subnet → networking module
IAM policy → IAM module
ECR repository → ECR module
```

A new module should be created when the resource represents a separate infrastructure concern or when grouping it with an existing module would make that module unclear or difficult to maintain.

---

### Step 3 — Add Resource-Specific Variables

If the resource requires configurable values, declare them in the module's `variables.tf`.

Example:

```hcl
variable "bucket_name" {
  description = "Name of the application storage bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}
```

Avoid hardcoding values that may change between environments.

---

### Step 4 — Define the Resource in the Module

Add the resource to the module's `main.tf`.

Example:

```hcl
resource "aws_s3_bucket" "application_storage" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = "expense-tracker"
  }
}
```

The resource should follow the project's naming, tagging, and security conventions.

---

### Step 5 — Add Required Supporting Resources

Some AWS resources require additional configuration.

For example, an S3 bucket may require:

* Versioning
* Encryption
* Public access blocking
* Lifecycle rules
* Ownership controls

A resource should not be considered complete merely because its primary block exists. Its supporting security and operational configuration must also be evaluated.

---

### Step 6 — Add Module Outputs

If another module, the root module, or an operator needs a value from the new resource, expose it through `outputs.tf`.

Example:

```hcl
output "bucket_name" {
  description = "Name of the application storage bucket"
  value       = aws_s3_bucket.application_storage.bucket
}

output "bucket_arn" {
  description = "ARN of the application storage bucket"
  value       = aws_s3_bucket.application_storage.arn
}
```

Outputs should expose useful identifiers without exposing unnecessary sensitive information.

---

### Step 7 — Call the Module from the Root Configuration

If a new module was created, call it from the root `main.tf`.

Example:

```hcl
module "storage" {
  source = "./modules/storage"

  bucket_name = var.storage_bucket_name
  environment = var.environment
}
```

If the resource was added to an existing module, update that module call with any new required variables.

---

### Step 8 — Add Root Variables

If the root module needs to provide a new value, declare it in the root `variables.tf`.

Example:

```hcl
variable "storage_bucket_name" {
  description = "Name of the application storage bucket"
  type        = string
}
```

---

### Step 9 — Add Environment Values

Provide the value in the appropriate `.tfvars` file.

Example:

```hcl
storage_bucket_name = "expense-tracker-dev-storage"
```

Different environments should use different values where necessary.

For example:

```text
dev  → expense-tracker-dev-storage
prod → expense-tracker-prod-storage
```

---

### Step 10 — Format and Validate

Before planning or applying changes, format and validate the configuration:

```bash
terraform fmt -recursive
```

```bash
terraform validate
```

`terraform fmt` keeps the configuration consistently formatted.

`terraform validate` checks whether the configuration is syntactically valid and internally consistent.

---

### Step 11 — Initialize if Required

If a new provider, module, or backend dependency was introduced, initialize Terraform:

```bash
terraform init
```

If Terraform reports that module or provider initialization is required, run:

```bash
terraform init -upgrade
```

This should be done carefully because upgrading providers can change behavior.

---

### Step 12 — Review the Execution Plan

Generate a plan before applying:

```bash
terraform plan -var-file="terraform.tfvars"
```

The plan should be reviewed carefully.

Confirm:

* The expected resource will be created.
* No existing resource will be unexpectedly destroyed.
* Dependencies are correct.
* Security settings are correct.
* Names and tags are correct.
* The selected environment values are correct.

The plan is the safety checkpoint between writing configuration and changing AWS infrastructure.

---

### Step 13 — Apply the Change

After reviewing the plan, apply the configuration:

```bash
terraform apply -var-file="terraform.tfvars"
```

Terraform will create, update, or destroy resources according to the approved configuration and current state.

For controlled environments, the saved-plan workflow is safer:

```bash
terraform plan \
  -var-file="terraform.tfvars" \
  -out=tfplan
```

Then:

```bash
terraform apply tfplan
```

This applies the exact plan that was reviewed.

---

### Step 14 — Verify the Resource

After applying, verify the result through:

```bash
terraform output
```

Also verify the resource in AWS using:

* AWS Console
* AWS CLI
* Resource-specific commands
* Application integration tests

Terraform confirms that the desired infrastructure was applied, but operational verification confirms that the resource works as intended.

---

### Step 15 — Update Documentation

The final step is to document:

* Why the resource was added
* Which module owns it
* Which variables control it
* Which outputs were added
* How it connects to other resources
* Any security considerations
* Any commands used to verify it

Infrastructure changes should be understandable to someone who did not create them.

---

## 7. Example Resource Addition Flow

Suppose the application needs an additional ECR repository for a frontend image.

The process would be:

```text
Identify requirement
        │
        ▼
Decide that ECR module owns the resource
        │
        ▼
Add repository variables if required
        │
        ▼
Define repository in modules/ecr/main.tf
        │
        ▼
Add repository URL and ARN outputs
        │
        ▼
Expose outputs through root outputs.tf
        │
        ▼
Run terraform fmt
        │
        ▼
Run terraform validate
        │
        ▼
Run terraform plan
        │
        ▼
Review changes
        │
        ▼
Run terraform apply
        │
        ▼
Verify repository in AWS
```

This process keeps infrastructure changes predictable and reviewable.

---

## 8. Production Deployment Perspective

At this stage, the DevOps VM was no longer part of the deployment process.

The deployment was approached from the perspective of a production team member who had SSH access to an EC2 instance and the appropriate IAM role.

The workflow was:

```text
Developer
    │
    │ Build application image
    ▼
Docker Image
    │
    │ Push
    ▼
Amazon ECR
    │
    │ Pull
    ▼
Production EC2
    │
    ▼
Docker Container
    │
    ▼
Running Application
```

This demonstrated the separation between **building an artifact** and **running an artifact**.

---

## 9. Application Dependency Analysis

Before starting the backend container, the application's runtime dependency was identified.

The backend uses MongoDB and expects a MongoDB connection string.

The Docker environment configuration contains:

```text
PORT=3000
MONGO_URL=mongodb://mongodb:27017/expense-tracker
```

Therefore, MongoDB needed to be available to the backend container.

Instead of using a paid AWS-managed database service, MongoDB was run as a Docker container on the EC2 instance.

This kept the deployment within the project's Free Tier-conscious approach.

---

## 10. Creating the Docker Network

A dedicated Docker network was created directly on the EC2 instance:

```bash
docker network create expense-network
```

The network was verified with:

```bash
docker network ls
```

The result confirmed:

```text
expense-network   bridge   local
```

This network allows the backend container to communicate with MongoDB using the hostname:

```text
mongodb
```

---

## 11. Running MongoDB

MongoDB was started directly on the EC2 instance:

```bash
docker run -d \
  --name mongodb \
  --network expense-network \
  -v mongo-data:/data/db \
  --restart unless-stopped \
  mongo:4.4
```

The container was verified with:

```bash
docker ps
```

MongoDB was running successfully.

The MongoDB port was not published to the EC2 host. It was only available inside the Docker network.

This meant the database was not unnecessarily exposed externally.

---

## 12. Running the Backend from ECR

The backend was not rebuilt.

The already-existing ECR image was executed directly:

```bash
docker run -d \
  --name backend \
  --network expense-network \
  -p 3000:3000 \
  -e APP_ENV=docker \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  --restart unless-stopped \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.0
```

This demonstrated the production-style principle:

> Build the application artifact once and deploy the existing artifact rather than rebuilding the application on the server.

---

## 13. Verifying Running Containers

The containers were checked with:

```bash
docker ps
```

The result showed both services running:

```text
backend
mongodb
```

The backend was exposed through:

```text
0.0.0.0:3000->3000/tcp
```

MongoDB was available internally through:

```text
27017/tcp
```

Both containers were connected to:

```text
expense-network
```

---

## 14. Backend Application Logs

The backend logs were inspected with:

```bash
docker logs backend
```

The application reported:

```text
Starting application with 'local' configuration
MongoDB Connected to mongodb
Server is listening on http://localhost:3000
```

The most important confirmation was:

```text
MongoDB Connected to mongodb
```

This proved that the backend container could communicate with the MongoDB container through the Docker network.

---

## 15. APP_ENV Observation

An important configuration behavior was discovered during deployment.

The container was started with:

```bash
-e APP_ENV=docker
```

However, the application's `package.json` contains:

```json
"start": "APP_ENV=local node server.js"
```

Therefore, the `npm start` command explicitly sets:

```text
APP_ENV=local
```

which overrides the value supplied when the container was started.

This explains why the logs reported:

```text
Starting application with 'local' configuration
```

instead of:

```text
Starting application with 'docker' configuration
```

Despite this, the explicitly supplied:

```text
MONGO_URL=mongodb://mongodb:27017/expense-tracker
```

was successfully used, and MongoDB connected correctly.

This is an important configuration lesson: startup commands can explicitly override environment variables provided to a container.

---

## 16. Application Health Check

The final application test was performed directly on the EC2 instance:

```bash
curl http://localhost:3000/health
```

The application returned:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

This confirmed that the application was not merely running as a container; the backend was responding successfully.

---

## 17. Final Deployment Architecture

The final deployment looked like this:

```text
                         AWS
                          │
                    Amazon ECR
                          │
                 backend:1.0.0
                          │
                       pull
                          ▼
                    ┌───────────┐
                    │    EC2    │
                    │           │
                    │  Docker   │
                    └─────┬─────┘
                          │
                 expense-network
                    ┌─────┴─────┐
                    │           │
                    ▼           ▼
               ┌────────┐  ┌─────────┐
               │backend │  │ mongodb │
               │ :3000  │  │ :27017  │
               └────┬───┘  └─────────┘
                    │
                    ▼
               /health
                    │
                    ▼
                 status: UP
```

---

## 18. Terraform's Role vs Docker's Role

This deployment demonstrated an important separation of responsibilities.

### Terraform

Terraform was responsible for provisioning the AWS infrastructure:

```text
VPC
Subnet
Route Table
Internet Gateway
Security Group
IAM
EC2
ECR
S3 Remote State
```

### Docker / ECR

Docker and ECR were responsible for the application artifact and runtime:

```text
Docker image
      │
      ▼
ECR
      │
      ▼
EC2
      │
      ├── Backend container
      └── MongoDB container
```

Terraform does not need to build the application image.

Docker does not need to provision the AWS VPC.

Each tool has a clear responsibility.

---

## 19. Key Lessons

* Infrastructure provisioning and application deployment are separate concerns.
* Terraform configuration should be organized into root files and reusable modules.
* `main.tf` composes resources and modules.
* `variables.tf` declares configurable inputs.
* `terraform.tfvars` supplies environment-specific values.
* `outputs.tf` exposes useful resource information.
* Modules group infrastructure by responsibility.
* A new resource should be added to the module that owns its responsibility.
* Terraform changes should be formatted, validated, planned, reviewed, applied, and verified.
* Remote state allows Terraform state to be shared and managed centrally.
* A Docker image is an application artifact, not the complete runtime environment.
* Applications may require external runtime dependencies such as databases.
* Docker networks allow containers to communicate using service/container names.
* MongoDB does not need to be publicly exposed for the backend to use it.
* ECR provides a central location for storing application images.
* An EC2 IAM role allows the instance to interact with AWS services without storing static AWS credentials on the server.
* A production server should run the existing image rather than rebuild the application unnecessarily.
* `docker ps` confirms container state, but application logs and health endpoints are required to verify application health.
* Environment variables can be affected by commands defined inside the image.
* The deployment VM is not required once the application artifact has been pushed to ECR and the production infrastructure is ready.

---

## 20. Common Mistakes

### Mistake 1 — Rebuilding the application on EC2

The production server already had access to the immutable ECR artifact.

Rebuilding from source would unnecessarily mix development and production responsibilities.

### Mistake 2 — Running the backend without MongoDB

The application depends on MongoDB and would fail to establish its database connection if MongoDB were unavailable.

### Mistake 3 — Using `localhost` for MongoDB

Inside the backend container:

```text
localhost
```

refers to the backend container itself.

The correct Docker-network hostname is:

```text
mongodb
```

### Mistake 4 — Exposing MongoDB unnecessarily

MongoDB only needs to be reachable by the backend container.

Publishing port `27017` to the host would unnecessarily increase the attack surface.

### Mistake 5 — Assuming `docker ps` means the application works

A container can be running while the application inside it is failing.

Logs and an application health endpoint provide stronger verification.

### Mistake 6 — Adding resources without reviewing the Terraform plan

Running `terraform apply` without reviewing the plan can result in unexpected changes, replacements, or destruction of existing infrastructure.

### Mistake 7 — Placing every resource in the root `main.tf`

A large, unstructured Terraform file becomes difficult to understand and maintain.

Resources should be grouped into modules according to responsibility.

### Mistake 8 — Hardcoding environment-specific values

Hardcoding names, regions, IDs, and configuration values makes it difficult to reuse the same infrastructure for development, staging, and production.

Variables and `.tfvars` files should be used instead.

---

## 21. Best Practices

* Build application images in the development or CI environment.
* Store application images in a container registry such as ECR.
* Deploy the existing image to the target environment.
* Use IAM roles instead of static AWS credentials on EC2.
* Keep databases private when they do not need public access.
* Use Docker networks for container-to-container communication.
* Use persistent volumes for stateful container dependencies.
* Verify deployments through logs and health endpoints.
* Use versioned image tags such as `1.0.0` rather than relying only on `latest`.
* Keep infrastructure provisioning separate from application deployment.
* Organize Terraform resources into modules by responsibility.
* Use variables instead of hardcoded configuration values.
* Store environment-specific values in appropriate `.tfvars` files.
* Run `terraform fmt` and `terraform validate` before creating a plan.
* Review `terraform plan` before applying infrastructure changes.
* Use remote state for shared or long-lived infrastructure.
* Avoid committing secrets or sensitive state files to source control.
* Add outputs for important resource identifiers and connection values.
* Document the purpose and dependencies of new resources.

---

## 22. Beyond This Chapter

The manual deployment successfully demonstrated the complete infrastructure-to-application path.

The next improvement is to remove the manual deployment steps.

The desired future workflow is:

```text
Developer
    │
    ▼
GitHub
    │
    ▼
CI Pipeline
    │
    ├── Test
    ├── Build Docker Image
    └── Push Image to ECR
              │
              ▼
        Deployment Stage
              │
              ▼
             EC2
              │
              ▼
        New application
        container version
```

This is where Jenkins or GitHub Actions can be introduced to automate the deployment process.

The important distinction is that automation will build upon the infrastructure and artifact-management foundation already established rather than replacing it.

Terraform can also be integrated into CI/CD so that infrastructure changes follow the same controlled workflow:

```text
Pull Request
    │
    ▼
terraform fmt
    │
    ▼
terraform validate
    │
    ▼
terraform plan
    │
    ▼
Review
    │
    ▼
terraform apply
```

Application deployment and infrastructure changes should remain related but independently controlled.

---

## 23. If I Were Interviewed

**Question: How did you deploy your containerized application to AWS?**

I would explain:

> I used Terraform to provision the AWS infrastructure, including the VPC, subnet, security group, EC2 instance, IAM configuration, and ECR repository. The Terraform configuration was organized into reusable modules, with root files such as `main.tf`, `variables.tf`, `terraform.tfvars`, and `outputs.tf` composing the infrastructure. The application was built into a Docker image and pushed to ECR. The EC2 instance used an IAM instance role to authenticate to ECR and pull the image without storing AWS credentials on the server. Because the application depends on MongoDB, I ran MongoDB as a separate container on the EC2 instance and connected both containers through a private Docker network. I then ran the existing ECR image as the backend container and verified the deployment through application logs and the `/health` endpoint.

**Question: How would you add a new AWS resource to the Terraform project?**

I would explain:

> First, I would identify which module owns the resource and determine its dependencies. I would add configurable values to the appropriate `variables.tf`, define the resource in the module's `main.tf`, expose important values through `outputs.tf`, and connect the module from the root `main.tf` if necessary. I would then provide environment-specific values through `terraform.tfvars`, run `terraform fmt` and `terraform validate`, generate and review a `terraform plan`, apply the approved change, verify the resource in AWS, and document the change.

This demonstrates understanding of:

```text
Infrastructure
+
Terraform Structure
+
Modules
+
Variables
+
Remote State
+
IAM
+
Containerization
+
Artifact Management
+
Networking
+
Application Dependencies
+
Deployment Verification
```

rather than simply knowing individual commands.

---

## 24. Engineer's Takeaways

The biggest lesson from this milestone is:

> **Infrastructure is only useful when it provides a reliable environment for running workloads.**

Terraform provisioned the environment.

Terraform modules organized the infrastructure.

Variables and `.tfvars` files made the configuration reusable.

Remote state provided centralized state management.

ECR stored the application artifact.

IAM provided secure access.

Docker provided the runtime.

MongoDB provided the application dependency.

The Docker network connected the services.

The health endpoint proved that the workload was actually functioning.

The complete chain was successfully demonstrated:

```text
Terraform
   ↓
Terraform Modules
   ↓
AWS Infrastructure
   ↓
EC2 + IAM
   ↓
ECR
   ↓
Docker
   ↓
MongoDB
   ↓
Backend
   ↓
Health Check
   ↓
STATUS: UP
```

The Terraform resource lifecycle was also established:

```text
Requirement
   ↓
Module Ownership
   ↓
Variables
   ↓
Resource Definition
   ↓
Outputs
   ↓
Formatting
   ↓
Validation
   ↓
Plan
   ↓
Review
   ↓
Apply
   ↓
Verification
   ↓
Documentation
```

---

## 25. Commands Used

### Terraform formatting

```bash
terraform fmt -recursive
```

### Terraform validation

```bash
terraform validate
```

### Terraform initialization

```bash
terraform init
```

### Terraform plan

```bash
terraform plan -var-file="terraform.tfvars"
```

### Terraform apply

```bash
terraform apply -var-file="terraform.tfvars"
```

### Create a saved Terraform plan

```bash
terraform plan \
  -var-file="terraform.tfvars" \
  -out=tfplan
```

### Apply a saved Terraform plan

```bash
terraform apply tfplan
```

### View Terraform outputs

```bash
terraform output
```

### Create Docker network

```bash
docker network create expense-network
```

### List Docker networks

```bash
docker network ls
```

### Run MongoDB

```bash
docker run -d \
  --name mongodb \
  --network expense-network \
  -v mongo-data:/data/db \
  --restart unless-stopped \
  mongo:4.4
```

### Run backend from ECR

```bash
docker run -d \
  --name backend \
  --network expense-network \
  -p 3000:3000 \
  -e APP_ENV=docker \
  -e PORT=3000 \
  -e MONGO_URL=mongodb://mongodb:27017/expense-tracker \
  --restart unless-stopped \
  748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.0
```

### Check containers

```bash
docker ps
```

### Check backend logs

```bash
docker logs backend
```

### Test application health

```bash
curl http://localhost:3000/health
```

---

## 26. Session Outcome

The Expense Tracker backend was successfully deployed to the AWS EC2 instance using the Docker image already stored in Amazon ECR.

The deployment successfully demonstrated:

* ECR image retrieval from EC2
* IAM-based AWS authentication
* Docker container execution
* MongoDB container deployment
* Docker network communication
* Persistent MongoDB storage
* Backend-to-MongoDB connectivity
* Application startup
* Application health verification
* Terraform module-based infrastructure organization
* Terraform variable and environment configuration
* Terraform planning and application workflow
* A repeatable process for adding future AWS resources

Final health response:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

This completes the practical AWS deployment portion of **Volume 4 — Infrastructure as Code**.

The next stage is to explore how the manual deployment can be converted into a repeatable CI/CD deployment workflow using Jenkins or GitHub Actions.

### 🟢 Note 21 COMPLETE
