# 20 — Terraform ECR + EC2 Application Deployment

## Overview

This milestone continues from **`19-terraform-aws-application-deployment.md`**.

The focus is moving the Expense Tracker backend toward an AWS container deployment using Terraform, Amazon ECR, Amazon EC2, Docker, VPC networking, SSH key pairs, and IAM.

The key architectural lesson is separating the **Terraform infrastructure identity** from the **EC2 workload identity**.

---

## 1. Architecture at This Stage

```text
                         AWS
                          │
             ┌────────────┴────────────┐
             │                         │
            ECR                       VPC
             │                         │
 expense-tracker-dev-          10.0.0.0/16
 backend:1.0.0                      │
             │                  ┌─────┴─────┐
             │                  │           │
             │               Subnet     Security Group
             │             10.0.1.0/24
             │                  │
             │             Internet Gateway
             │                  │
             └──────────────► EC2
                              │
                           Docker
                              │
                       Backend container
                              │
                           Port 3000
```

Current EC2:

```text
Instance ID:   i-0618461d53034fa8a
Public IP:     54.163.32.19
Instance type: t3.micro
OS:            Amazon Linux 2023
```

ECR:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend
```

---

# 2. ECR Module

We introduced an ECR Terraform module for the backend image.

Repository:

```text
expense-tracker-dev-backend
```

Terraform configured the repository with:

- Mutable image tags
- Scan-on-push enabled

The repository URL was exposed through Terraform:

```text
ecr_repository_url = "748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend"
```

Useful commands:

```bash
cd ~/projects/expense-tracker-devops/terraform/labs/aws/environments/dev

terraform init
terraform plan
terraform apply
terraform output
terraform output -raw ecr_repository_url
```

---

# 3. New Module Lesson

When a new Terraform module or provider dependency is introduced, initialize the working directory:

```bash
terraform init
```

`terraform init` prepares Terraform and downloads/initializes dependencies. It does not itself create the infrastructure.

---

# 4. ECR IAM Permission Troubleshooting

Terraform initially failed while refreshing/managing the ECR repository because the Terraform execution role lacked:

```text
ecr:ListTagsForResource
```

We inspected the role:

```bash
aws iam list-role-policies   --role-name terraform-dev-execution-role
```

Result:

```text
"PolicyNames": []
```

We then checked attached policies:

```bash
aws iam list-attached-role-policies   --role-name terraform-dev-execution-role
```

The relevant managed policy was:

```text
terraform-dev-execution-policy
```

We inspected its version:

```bash
aws iam get-policy-version   --policy-arn arn:aws:iam::748241639517:policy/terraform-dev-execution-policy   --version-id v22
```

The ECR management statement included permissions such as:

```text
ecr:UploadLayerPart
ecr:UntagResource
ecr:TagResource
ecr:PutImage
ecr:ListTagsForResource
ecr:ListImages
ecr:InitiateLayerUpload
ecr:GetRepositoryPolicy
ecr:DescribeRepositories
ecr:DeleteRepository
ecr:CreateRepository
ecr:CompleteLayerUpload
ecr:BatchGetImage
ecr:BatchCheckLayerAvailability
```

### Lesson

Terraform is calling AWS APIs. If an AWS API operation is denied, the error usually identifies the exact missing IAM action.

---

# 5. IAM Managed Policy Version Limit

When another managed-policy version was created, AWS returned:

```text
LimitExceeded:
A managed policy can have up to 5 versions.
Before you create a new version, you must delete an existing version.
```

We checked the versions:

```bash
aws iam list-policy-versions   --policy-arn arn:aws:iam::748241639517:policy/terraform-dev-execution-policy
```

The policy had:

```text
v22  default
v21
v20
v19
v18
```

AWS permits a maximum of five versions for a customer-managed managed policy. An old non-default version therefore had to be removed before creating another.

The updated policy became:

```text
DefaultVersionId: v23
```

### Lesson

Repeated IAM policy changes can consume the five available policy-version slots. Old non-default versions need to be cleaned up.

---

# 6. Docker Image Optimization

Before pushing the backend image to ECR, we compared image sizes:

| Stage | Image Size |
|---|---:|
| Original `node:22` image | ~423 MB |
| `--omit=dev` optimization | ~407 MB |
| `node:22-slim` optimization | ~93 MB |

The biggest improvement came from changing the base image:

```text
node:22
```

to:

```text
node:22-slim
```

### Lesson

The base image can have a much greater effect on container size than removing development dependencies alone.

---

# 7. Tagging the Image for ECR

The ECR repository URL came from Terraform:

```bash
export ECR_REPO=$(terraform output -raw ecr_repository_url)
```

The local image could then be tagged:

```bash
docker tag expense-tracker-devops_backend:latest $ECR_REPO:1.0.0
```

Target:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.0
```

---

# 8. Verifying Image Identity

`docker ps` initially showed the running container using:

```text
expense-tracker-devops_backend:latest
```

while ECR used:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.0
```

We verified both tags:

```bash
docker image inspect expense-tracker-devops_backend:latest   --format '{{.Id}}'
```

and:

```bash
docker image inspect "$ECR_REPO:1.0.0"   --format '{{.Id}}'
```

Both returned:

```text
sha256:8abc73d22fe7499800716d5a96d23beae8bef2ca20e73f5b8a53c3d238ee9a39
```

Therefore both names pointed to the same underlying image.

### Lesson

Docker tags are references. Different repository/tag names can point to the same image. Checking the image ID is useful when troubleshooting whether two tags represent the same image.

---

# 9. ECR Authentication and Push

Authentication was performed with:

```bash
aws ecr get-login-password --region us-east-1   | docker login     --username AWS     --password-stdin "$ECR_REPO"
```

Result:

```text
Login Succeeded
```

The Docker client warned that credentials were stored unencrypted in:

```text
/home/vagrant/.docker/config.json
```

This is a useful security lesson: production environments should consider a Docker credential helper or another secure credential-management mechanism.

The image was then pushed:

```bash
docker push "$ECR_REPO:1.0.0"
```

The application image is now available in the private ECR repository.

---

# 10. Internet Gateway and Public Networking

We added an Internet Gateway to the VPC and a default route:

```text
0.0.0.0/0
```

The subnet was also changed so instances receive public IP addresses:

```text
map_public_ip_on_launch = true
```

The resulting path is:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Route Table
   │
   ▼
Public Subnet
10.0.1.0/24
   │
   ▼
EC2
```

### Cost lesson

An Internet Gateway itself does not have a separate hourly charge simply for existing/being attached. However, AWS networking and traffic can still generate charges, so the whole architecture must remain cost-aware.

---

# 11. EC2 Replacement

Changing the EC2 networking configuration caused Terraform to replace the instance.

The plan showed:

```text
associate_public_ip_address = false -> true
```

and:

```text
forces replacement
```

Terraform therefore destroyed the previous instance and created a new one.

Previous instance:

```text
i-018b321577f0809a3
```

Current instance:

```text
i-0618461d53034fa8a
```

Current public IP:

```text
54.163.32.19
```

### Lesson

Some EC2 attributes cannot be changed in place. Terraform identifies these with:

```text
forces replacement
```

Always inspect replacement operations carefully before applying.

---

# 12. SSH Key Pair

The existing:

```text
~/.ssh/devops
~/.ssh/devops.pub
```

key was already used for Git.

Rather than mixing the Git key with the application server, we created a dedicated EC2 key pair:

```text
expense-tracker-dev
```

The public key was imported into AWS. The private key remains on the local machine.

Conceptually:

```text
Local machine
   │
   ├── expense-tracker-dev       ← PRIVATE
   │
   └── expense-tracker-dev.pub   ← PUBLIC
                                  │
                                  ▼
                               AWS EC2
```

Example key generation command:

```bash
ssh-keygen -t ed25519   -f ~/.ssh/expense-tracker-dev   -C "expense-tracker-dev-ec2"
```

The public key can be viewed with:

```bash
cat ~/.ssh/expense-tracker-dev.pub
```

### Lesson

The private key should remain private. AWS needs the public key to configure SSH authentication.

---

# 13. EC2 Key-Pair Permission Failure

Terraform initially failed while importing the EC2 public key:

```text
not authorized to perform: ec2:ImportKeyPair
```

The Terraform execution role did not have:

```text
ec2:ImportKeyPair
```

Because the key pair was not created, the subsequent EC2 operation failed with:

```text
InvalidKeyPair.NotFound:
The key pair 'expense-tracker-dev' does not exist
```

The sequence was:

```text
Terraform
   │
   ├── Import public key
   │       │
   │       └── DENIED: ec2:ImportKeyPair
   │
   └── Create EC2
           │
           └── FAILED: key pair does not exist
```

### Lesson

The second error was a consequence of the first. When troubleshooting, start with the earliest/root failure.

---

# 14. Terraform Execution Role vs EC2 Workload Role

This became one of the most important architecture lessons in the milestone.

Terraform uses:

```text
terraform-dev-execution-role
```

Its job is infrastructure management:

```text
Terraform
   │
   └── terraform-dev-execution-role
          │
          ├── VPC management
          ├── EC2 management
          ├── ECR management
          ├── Terraform state access
          └── other infrastructure operations
```

The EC2 should have a separate role:

```text
EC2
 │
 └── application workload role
          │
          └── ECR pull permissions
```

The EC2 does **not** need:

```text
Terraform permissions
Git permissions
ECR push permissions
Terraform-state S3 permissions
VPC management permissions
```

This follows the principle of **least privilege**.

---

# 15. Production Workload Perspective

A useful way to think about this is:

> The production workload should be authorized to consume the application artifact.

For example:

```text
                    ECR
                     │
        expense-tracker-dev-backend
                     │
          ┌──────────┴──────────┐
          │                     │
   Production EC2          Production CI/CD
          │                     │
     IAM role               IAM role
          │                     │
       Pull ✅                Pull ✅
```

AWS implements this through IAM identities and permissions. A "production team" is represented through appropriate IAM users, groups, roles, or workload identities.

---

# 16. Amazon Linux 2023

After the new EC2 was created, we connected through SSH.

The instance reported:

```bash
whoami
```

as:

```text
ec2-user
```

The operating system was:

```text
Amazon Linux 2023
```

The AWS CLI was already available:

```text
aws-cli/2.33.15
```

Docker was not installed:

```bash
docker --version
```

returned:

```text
-bash: docker: command not found
```

Git was also not installed:

```bash
git --version
```

returned:

```text
-bash: git: command not found
```

This is intentional for our deployment model.

The production server does not need to clone the source repository. The deployment artifact is the Docker image stored in ECR.

---

# 17. Why Git Is Not Needed on the EC2

We are moving away from:

```text
EC2
 │
 └── git clone
      │
      ▼
 application source
      │
      ▼
 build/run
```

toward:

```text
Developer / CI
      │
      ▼
Docker image
      │
      ▼
ECR
      │
      ▼
EC2
      │
      ▼
Docker container
```

The production EC2 consumes a versioned artifact instead of building the application from source.

---

# 18. Important Commands From This Milestone

## Terraform

```bash
cd ~/projects/expense-tracker-devops/terraform/labs/aws/environments/dev

terraform init
terraform plan
terraform apply
terraform output
terraform output -raw ecr_repository_url
```

## Docker

```bash
docker images

docker image inspect expense-tracker-devops_backend:latest   --format '{{.Id}}'

docker image inspect "$ECR_REPO:1.0.0"   --format '{{.Id}}'

docker tag expense-tracker-devops_backend:latest $ECR_REPO:1.0.0
```

## ECR login and push

```bash
aws ecr get-login-password --region us-east-1   | docker login     --username AWS     --password-stdin "$ECR_REPO"

docker push "$ECR_REPO:1.0.0"
```

## IAM investigation

```bash
aws iam list-role-policies   --role-name terraform-dev-execution-role

aws iam list-attached-role-policies   --role-name terraform-dev-execution-role

aws iam get-policy-version   --policy-arn arn:aws:iam::748241639517:policy/terraform-dev-execution-policy   --version-id v22

aws iam list-policy-versions   --policy-arn arn:aws:iam::748241639517:policy/terraform-dev-execution-policy
```

Exporting a policy document:

```bash
aws iam get-policy-version   --policy-arn arn:aws:iam::748241639517:policy/terraform-dev-execution-policy   --version-id v22   --query 'PolicyVersion.Document'   --output json > /tmp/terraform-dev-execution-policy-v22.json
```

## SSH

```bash
ssh-keygen -t ed25519   -f ~/.ssh/expense-tracker-dev   -C "expense-tracker-dev-ec2"

cat ~/.ssh/expense-tracker-dev.pub
```

## EC2 verification

```bash
whoami
cat /etc/os-release
docker --version
aws --version
git --version
```

---

# 19. Key Lessons Learned

### 1. Terraform is an AWS API client

Terraform uses the permissions of its execution identity to call AWS APIs.

```text
Terraform
   │
   ▼
AWS API
   │
   ▼
IAM permission
```

---

### 2. Read authorization errors literally

For example:

```text
ec2:ImportKeyPair
```

identifies the missing EC2 permission.

Likewise:

```text
ecr:ListTagsForResource
```

identifies the missing ECR permission.

---

### 3. Root errors can produce secondary failures

The key-pair failure caused the later:

```text
InvalidKeyPair.NotFound
```

error.

Always find the first meaningful failure.

---

### 4. Docker tags are references

Different tags can point to the same underlying image.

The image ID helped prove that the local running image and ECR-tagged image were identical.

---

### 5. Base images matter

Moving from:

```text
node:22
```

to:

```text
node:22-slim
```

was the biggest image-size optimization.

---

### 6. Separate infrastructure and workload identities

Terraform should manage infrastructure.

The EC2 should have only the runtime permissions it needs.

```text
Terraform Role
      │
      └── Infrastructure management

EC2 Role
      │
      └── ECR pull
```

---

### 7. Production servers should consume artifacts

The server should pull:

```text
expense-tracker-dev-backend:1.0.0
```

from ECR rather than cloning source code and building the application itself.

---

# 20. Current Infrastructure State

```text
VPC
10.0.0.0/16
 │
 └── Subnet
     10.0.1.0/24
          │
          └── EC2
              Instance: i-0618461d53034fa8a
              Public IP: 54.163.32.19
              Type: t3.micro
              OS: Amazon Linux 2023
```

ECR:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend
```

Terraform state:

```text
s3://terraform-devops-state-medon-2026/
terraform-state-lab/dev/terraform.tfstate
```

The application image has been pushed to ECR.

---

# 21. Next Step

The next milestone is the EC2 runtime deployment.

We will:

1. Create a dedicated EC2 IAM role.
2. Give it ECR pull-only permissions.
3. Create/attach the instance profile.
4. Attach the profile to the EC2.
5. Install Docker on Amazon Linux 2023.
6. Verify the EC2 IAM identity.
7. Authenticate Docker to ECR.
8. Pull `expense-tracker-dev-backend:1.0.0`.
9. Run the backend container.
10. Test the application on port `3000`.

Target architecture:

```text
                 ECR
                  │
                  │ Pull
                  ▼
             EC2 IAM Role
                  │
                  ▼
                 EC2
                  │
                Docker
                  │
                  ▼
          Expense Tracker API
                  │
                :3000
```

This completes the transition from a local Docker deployment to:

```text
AWS ECR → EC2 → Docker → Expense Tracker Backend
```
