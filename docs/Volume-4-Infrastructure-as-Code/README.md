# Volume 4 — Infrastructure as Code with Terraform

**Status:** ✅ COMPLETED

Volume 4 focused on learning Infrastructure as Code (IaC) with Terraform and applying it to provision and manage AWS infrastructure for the Expense Tracker application.

The goal was not only to learn Terraform syntax, but to understand how infrastructure can be defined, provisioned, managed, and connected to an application deployment workflow.

---

## What I Learned

Throughout this volume, I learned how to:

* Understand Infrastructure as Code and Terraform
* Configure the AWS Terraform provider
* Organize Terraform using modules
* Separate environments from reusable infrastructure modules
* Provision AWS networking resources
* Provision and manage EC2 infrastructure
* Create and manage Amazon ECR repositories
* Create IAM roles, policies, and instance profiles
* Configure Terraform remote state using Amazon S3
* Enable Terraform state locking using the S3 lock file
* Understand Terraform state and why it must not be manually edited
* Use Terraform `plan`, `apply`, and `destroy`
* Troubleshoot AWS IAM permission and Terraform provider refresh errors
* Understand how Terraform interacts with AWS APIs
* Connect infrastructure provisioning with application deployment
* Use immutable Docker images with runtime environment variables
* Deploy a new Docker image from ECR to an EC2 instance through Jenkins

---

## Infrastructure Built

Terraform was used to manage the AWS infrastructure required for the DEV environment.

### AWS Resources

The environment includes:

* Amazon VPC
* Public subnet
* Internet Gateway
* Route table
* Internet route
* Route table association
* Security group
* EC2 instance
* IAM role
* IAM instance profile
* IAM policies
* Amazon S3 application bucket
* Amazon ECR repository

The infrastructure was organized into reusable Terraform modules.

---

## Terraform Structure

The AWS Terraform configuration follows an environment/module structure:

```text
terraform/
└── labs/
    └── aws/
        ├── environments/
        │   └── dev/
        │       ├── main.tf
        │       ├── variables.tf
        │       ├── outputs.tf
        │       ├── iam.tf
        │       └── ...
        │
        └── modules/
            ├── storage/
            ├── networking/
            ├── security/
            ├── compute/
            └── ecr/
```

This separation allows the infrastructure modules to be reused while environment-specific configuration remains inside the environment directory.

---

## Remote Terraform State

Terraform state was moved from local storage to Amazon S3.

The DEV state uses:

```text
S3 Bucket:
terraform-devops-state-medon-2026

Key:
terraform-state-lab/dev/terraform.tfstate
```

State locking was enabled using Terraform's S3 lock file:

```hcl
backend "s3" {
  bucket       = "terraform-devops-state-medon-2026"
  key          = "terraform-state-lab/dev/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
```

This provided practical experience with remote state management and state locking.

A key lesson from this work was that Terraform state should be treated carefully because it can contain sensitive infrastructure information.

---

## AWS IAM

Terraform was configured to assume a dedicated execution role:

```text
terraform-dev-execution-role
```

The process helped demonstrate an important principle:

> Terraform needs sufficient AWS permissions to manage the resources it declares.

During the build, several Terraform provider refresh operations failed because the execution role did not initially have all the required read permissions.

Examples included permissions for:

* S3 bucket configuration
* IAM roles
* IAM policies
* EC2 instance profiles

Instead of treating the error as a Terraform problem, the issue was traced to the AWS API permissions required by the provider.

This became an important troubleshooting lesson from the volume.

---

## EC2 Infrastructure

The Expense Tracker backend was deployed to an AWS EC2 instance.

The EC2 instance was configured with:

* `t3.micro`
* Amazon Linux
* 8 GB gp3 root volume
* Public IP
* VPC subnet
* Security group
* IAM instance profile

The instance was used as the application runtime environment.

The infrastructure was managed through Terraform while the application deployment itself was handled through the CI/CD workflow.

---

## Amazon ECR

An Amazon ECR repository was created for the backend application:

```text
expense-tracker-dev-backend
```

The repository stores the Docker images used by the EC2 deployment.

The application image was versioned using Docker tags:

```text
1.0.0
1.0.1
```

The `1.0.1` image was successfully pushed to ECR and subsequently deployed to EC2.

This demonstrated the separation between:

```text
Source Code → Docker Image → ECR → Runtime
```

---

## Immutable Application Configuration

During the volume, the backend application was changed from selecting environment-specific configuration files inside the application to receiving configuration at runtime.

The application now reads environment variables such as:

```text
PORT
MONGO_URL
```

The Docker image therefore does not need to contain environment-specific configuration.

This established an important deployment principle:

> Build the application artifact once and provide environment-specific configuration at runtime.

---

## EC2 Deployment

The EC2 instance runs the backend and MongoDB containers on the Docker network:

```text
expense-network
```

The backend receives its MongoDB connection through the runtime environment:

```text
MONGO_URL=mongodb://mongodb:27017/expense-tracker
```

A deployment script was created to standardize the deployment process:

```text
scripts/deploy.sh
```

The script:

1. Pulls the specified image from ECR
2. Stops the existing backend container
3. Removes the old container
4. Starts the new container
5. Waits for the application to start
6. Performs a health check
7. Reports deployment success or failure

---

## CI/CD Integration

The final deployment flow connected the infrastructure and application delivery process:

```text
GitHub
   ↓
Jenkins
   ↓
Test
   ↓
Build Docker Image
   ↓
Push to Amazon ECR
   ↓
Deploy to EC2
   ↓
Pull New Image
   ↓
Start Application
   ↓
Health Check
```

Jenkins securely connects to EC2 using SSH credentials.

The deployment was successfully executed through Jenkins using the `1.0.1` Docker image.

The final health check returned:

```text
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

Jenkins completed with:

```text
Finished: SUCCESS
```

This provided an end-to-end demonstration of infrastructure provisioning combined with application deployment.

---

## Troubleshooting Lessons

Volume 4 involved several real AWS and Terraform issues.

### 1. Terraform provider refresh failures

Terraform initially failed because the AWS execution role did not have all the permissions required to read existing resources.

The solution was to investigate the specific AWS API operations being denied and update the IAM policy accordingly.

**Lesson:**

> Terraform errors must be investigated at the AWS API/IAM level, not only at the Terraform configuration level.

---

### 2. IAM role and policy management

Managing IAM resources with Terraform required additional permissions such as:

```text
iam:GetRole
iam:GetPolicy
iam:GetPolicyVersion
iam:ListPolicyVersions
iam:CreatePolicyVersion
iam:SetDefaultPolicyVersion
iam:DeletePolicyVersion
```

**Lesson:**

Terraform requires both create/update permissions and read permissions for provider refresh and state reconciliation.

---

### 3. Expired AWS credentials

An expired AWS session resulted in:

```text
SignatureDoesNotMatch
```

The issue was resolved by refreshing the assumed-role credentials.

**Lesson:**

Temporary AWS credentials have a lifetime. When using assumed roles, authentication problems can appear as API/signature failures.

---

### 4. EC2 public IP change

After the EC2 instance was stopped and restarted, its public IP changed.

This affected the deployment configuration because Jenkins connects to EC2 through SSH.

**Lesson:**

A manually assigned public IP is not a stable deployment endpoint. Production architectures should use a more stable addressing strategy.

---

### 5. Docker image and runtime configuration

The application originally depended on environment-selection logic inside the container.

The application was refactored so that the same Docker image can be deployed to different environments while configuration is supplied at runtime.

**Lesson:**

Immutable application artifacts and runtime configuration make deployments more predictable and portable.

---

## Cost Awareness

The AWS infrastructure was intentionally designed with the AWS Free Tier/new-account credit constraints in mind.

The project avoided unnecessary paid infrastructure such as a NAT Gateway.

Resources were kept intentionally small where possible, including the use of:

```text
t3.micro
```

Cost awareness became part of the infrastructure design process rather than something considered after deployment.

---

## Key DevOps Lessons

The most important lesson from Volume 4 was that Infrastructure as Code is more than writing `.tf` files.

The complete process involves:

```text
Define
  ↓
Plan
  ↓
Provision
  ↓
Verify
  ↓
Troubleshoot
  ↓
Manage State
  ↓
Deploy
  ↓
Document
```

I also learned that Terraform, AWS IAM, Docker, ECR, EC2, and Jenkins are not isolated technologies. They can form a complete delivery system when their responsibilities are clearly separated.

---

## Volume 4 Portfolio Outcome

By the end of this volume, I had built and managed a real AWS-based DEV environment for the Expense Tracker application.

The project demonstrates experience with:

* Terraform
* AWS
* VPC networking
* EC2
* IAM
* S3
* ECR
* Docker
* Jenkins
* SSH-based deployment
* Remote Terraform state
* Infrastructure troubleshooting
* Runtime application configuration
* CI/CD deployment

The final implementation successfully connected infrastructure management with application delivery.

---

## Documentation

Detailed implementation notes from this volume are stored in the project's documentation directory.

Key documentation includes:

* Terraform fundamentals and workflow
* AWS infrastructure provisioning
* Terraform modules
* Remote state and locking
* IAM troubleshooting
* EC2 infrastructure
* ECR integration
* Application deployment
* Jenkins deployment
* Troubleshooting and lessons learned

---

# Volume Status

**Volume 4 — Infrastructure as Code with Terraform**

**Status: ✅ COMPLETED**

Technical implementation completed.
Documentation completed.
Final CI/CD deployment verified successfully.

**Next:** Volume 5
