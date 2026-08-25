Absolutely. This is a milestone worth documenting properly because we didn't just learn another Terraform concept — **we moved from local Terraform practice into real AWS infrastructure management while preserving the original lab.**

# 13 — AWS Git Lab — Terraform Applied to AWS

### Milestone: Local Terraform → Real AWS Infrastructure

We initially learned and practiced Terraform using the `local` provider. The purpose was to understand Terraform independently of a specific cloud platform:

```text
Terraform concepts
      ↓
Local provider
      ↓
local_file resource
      ↓
Understand IaC
```

The goal was never to remain local. The local implementation was our **learning laboratory**.

We therefore created a separate AWS implementation while preserving the original local work.

---

## 1. Final Repository Structure

Our Terraform labs are now separated by implementation target:

```text
terraform/
└── labs/
    ├── local/
    │   ├── environments/
    │   │   ├── dev/
    │   │   └── prod/
    │   └── file/
    │
    └── aws/
        ├── environments/
        │   └── dev/
        │       ├── main.tf
        │       ├── variables.tf
        │       ├── outputs.tf
        │       ├── terraform.tfvars
        │       └── .terraform.lock.hcl
        │
        └── modules/
            └── storage/
                ├── main.tf
                ├── variables.tf
                └── outputs.tf
```

### Why we structured it this way

We deliberately preserved:

```text
terraform/labs/local/
```

instead of deleting our original implementation.

The new AWS implementation lives independently under:

```text
terraform/labs/aws/
```

This gives us two reference points:

```text
LOCAL LAB
Learn Terraform concepts
        ↓
AWS LAB
Apply the same principles to real infrastructure
```

---

# 2. Recovering the Local Implementation

During the migration, we wanted to preserve the exact version of the local implementation that had already been committed.

We used:

```bash
git show 6ab4083:terraform/environments/dev/main.tf \
  > terraform/labs/local/environments/dev/main.tf
```

### What this command did

`git show` retrieved the version of `main.tf` from commit:

```text
6ab4083
```

and redirected that content into the new location:

```text
terraform/labs/local/environments/dev/main.tf
```

This allowed us to reorganize the repository without losing the previously committed local implementation.

**Important lesson:**

> Git history can be used to recover a specific committed version of a file and place it somewhere else in the repository.

Git subsequently recognized the restructuring as renames rather than unrelated deletions and additions.

---

# 3. AWS Provider

Our AWS environment now declares the AWS provider:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

This establishes Terraform's dependency on the HashiCorp AWS provider.

We initialized and Terraform selected:

```text
hashicorp/aws v6.61.0
```

The generated:

```text
.terraform.lock.hcl
```

was retained because provider selections should be tracked in version control.

---

# 4. Remote Terraform Backend

We configured Terraform state to live remotely in S3:

```hcl
backend "s3" {
  bucket       = "terraform-devops-state-medon-2026"
  key          = "terraform-state-lab/dev/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
```

This is **not** the S3 bucket being created by our module.

We now have two distinct S3 concepts:

```text
terraform-devops-state-medon-2026
        │
        └── Terraform backend
            Stores Terraform state


expense-tracker-dev-terraform-2026
        │
        └── Infrastructure
            Created and managed by Terraform
```

This distinction is extremely important.

---

# 5. AWS Provider Configuration

The provider uses a variable for the region:

```hcl
provider "aws" {
  region = var.aws_region
}
```

Instead of hardcoding the region directly into the provider configuration, the environment receives it through a variable.

Our current DEV value is:

```hcl
aws_region = "us-east-1"
```

---

# 6. Reusable AWS Module

We created:

```text
terraform/labs/aws/modules/storage/
```

with:

```hcl
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}
```

The module does **not** hardcode the bucket name.

Instead, it accepts:

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}
```

This means the module can be reused.

For example:

```text
DEV
    ↓
expense-tracker-dev-terraform-2026

PROD
    ↓
expense-tracker-prod-terraform-2026
```

Both could use the same module.

---

# 7. Environment Consumes the Module

Our DEV environment calls the module:

```hcl
module "storage" {
  source = "../../modules/storage"

  bucket_name = var.bucket_name
}
```

The flow is:

```text
terraform.tfvars
      ↓
variables.tf
      ↓
main.tf
      ↓
module "storage"
      ↓
modules/storage
      ↓
aws_s3_bucket
      ↓
AWS
```

This is the separation between:

**environment configuration**

and

**reusable infrastructure logic.**

---

# 8. Variables and `terraform.tfvars`

The environment defines:

```hcl
variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the dev environment"
  type        = string
}
```

The actual DEV values are supplied through:

```hcl
aws_region  = "us-east-1"
bucket_name = "expense-tracker-dev-terraform-2026"
```

This reinforced the principle:

> **Don't hardcode environment-specific values into reusable infrastructure logic.**

The module knows **how** to create an S3 bucket.

The environment decides **which bucket** it needs.

---

# 9. State Migration

When we transitioned the DEV environment from the local provider to AWS, Terraform's remote state still contained:

```text
module.file.local_file.this
```

However, the local file was no longer part of the AWS configuration.

We verified that:

```bash
find . -name "dev-hello.txt" -type f -print
```

returned nothing.

We therefore removed the obsolete resource from the DEV Terraform state:

```bash
terraform state rm module.file.local_file.this
```

Terraform confirmed:

```text
Removed module.file.local_file.this
Successfully removed 1 resource instance(s).
```

Then:

```bash
terraform state list
```

returned an empty state.

This was an important practical lesson:

> **Terraform configuration and Terraform state must be deliberately managed during infrastructure transitions.**

---

# 10. First Real AWS Plan

Terraform then produced:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The resource was:

```text
module.storage.aws_s3_bucket.this
```

with:

```text
bucket = "expense-tracker-dev-terraform-2026"
region = "us-east-1"
```

This was our first real AWS infrastructure plan in the capstone.

---

# 11. First Real AWS Apply

We then executed:

```bash
terraform apply
```

Terraform created:

```text
expense-tracker-dev-terraform-2026
```

and reported:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

The output was:

```text
bucket_name = "expense-tracker-dev-terraform-2026"
```

This was the point where our Terraform knowledge moved from a local exercise into **actual cloud infrastructure management**.

---

# 12. Infrastructure Verification

We verified the bucket directly through AWS CLI:

```bash
aws s3api head-bucket \
  --bucket expense-tracker-dev-terraform-2026
```

No error was returned.

We then checked Terraform state:

```bash
terraform state list
```

which returned:

```text
module.storage.aws_s3_bucket.this
```

Finally:

```bash
terraform plan
```

returned:

```text
No changes. Your infrastructure matches the configuration.
```

This demonstrated:

```text
Terraform Configuration
        =
Terraform State
        =
Real AWS Infrastructure
```

with no detected drift.

---

# 13. Testing Remote State Portability

We deliberately deleted the local Terraform working directory:

```text
.terraform/
```

The important point was that this did **not** destroy our infrastructure.

We then moved the AWS implementation into:

```text
terraform/labs/aws/
```

and ran:

```bash
terraform init
```

Terraform successfully reported:

```text
Successfully configured the backend "s3"!
```

It reconnected to the existing remote state.

We then ran:

```bash
terraform plan
```

and again received:

```text
No changes. Your infrastructure matches the configuration.
```

### Lesson

This demonstrated the distinction between:

```text
.terraform/
```

and:

```text
Remote Terraform State
```

`.terraform/` is local working data and can be recreated.

Our remote state in S3 persists independently.

---

# 14. Git Integration

We staged the repository restructuring:

```bash
git add -A
```

Git correctly recognized the preserved local files as renames:

```text
terraform/environments/dev/
        ↓
terraform/labs/local/environments/dev/
```

and:

```text
terraform/modules/file/
        ↓
terraform/labs/local/file/
```

The new AWS implementation was added under:

```text
terraform/labs/aws/
```

We also confirmed that `.terraform/` and local Terraform state were excluded through:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
```

The provider lock file was retained:

```text
.terraform.lock.hcl
```

---

# 15. Git Commit

The AWS Git Lab was committed with:

```text
feat(terraform): add AWS infrastructure lab
```

and pushed to GitHub.

The repository now preserves both our **local Terraform learning history** and our **real AWS implementation**.

---

# 🎯 Milestone Outcome

We can now say:

> **Terraform has been learned independently of the infrastructure platform and successfully applied to AWS.**

The progression is:

```text
Terraform Fundamentals
        ↓
Local Provider
        ↓
local_file
        ↓
Variables
        ↓
Outputs
        ↓
Providers
        ↓
Lifecycle
        ↓
Data Sources
        ↓
Modules
        ↓
State
        ↓
Remote State
        ↓
AWS Provider
        ↓
Reusable AWS Module
        ↓
AWS S3
        ↓
Real Infrastructure
        ↓
Git + GitHub
```

This is the **AWS Git Lab milestone of Volume 4**.

### Current status

| Component             | Status      |
| --------------------- | ----------- |
| Local Terraform Lab   | ✅ Preserved |
| AWS Provider          | ✅           |
| S3 Remote Backend     | ✅           |
| Remote State          | ✅           |
| State Locking         | ✅           |
| AWS Storage Module    | ✅           |
| DEV Environment       | ✅           |
| S3 Bucket             | ✅ Deployed  |
| AWS CLI Verification  | ✅           |
| Terraform Drift Check | ✅           |
| Git Integration       | ✅           |
| GitHub Push           | ✅           |

---
