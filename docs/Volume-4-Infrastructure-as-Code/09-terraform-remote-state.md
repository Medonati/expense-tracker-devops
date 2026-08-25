# 09 — Terraform Remote State

## Objective

Understand why Terraform uses remote state and how to migrate local state to an AWS S3 backend.

---

## 1. Why Remote State?

Local state works well for a personal lab:

```text
Terraform
    ↓
terraform.tfstate
    ↓
One machine
````

But when multiple engineers work on the same infrastructure, separate local state files can become inconsistent.

Remote state provides a shared location for Terraform state.

```text
             Remote State
                  │
        ┌─────────┼─────────┐
        ↓         ↓         ↓
   Engineer A Engineer B  CI/CD
```

---

## 2. Provider vs Backend

### Provider

A provider enables Terraform to communicate with and manage resources on a specific platform or service.

Example:

```text
hashicorp/local
    ↓
local_file
```

### Backend

A backend determines where Terraform stores and manages its state.

```text
Backend
   ↓
Terraform state
```

The key distinction:

```text
Provider → How Terraform interacts with infrastructure

Backend  → Where/how Terraform manages state
```

---

## 3. Local Backend

Terraform uses the local backend by default when no backend is explicitly configured.

We tested an explicit local backend:

```hcl
backend "local" {
  path = "terraform.tfstate"
}
```

After changing backend configuration, we ran:

```bash
terraform init
```

Terraform successfully configured the local backend and:

```bash
terraform plan
```

returned:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 4. AWS S3 Remote Backend

We created an S3 bucket for Terraform state:

```text
terraform-devops-state-medon-2026
```

The state object uses the key:

```text
terraform-state-lab/terraform.tfstate
```

Our backend configuration:

```hcl
backend "s3" {
  bucket       = "terraform-devops-state-medon-2026"
  key          = "terraform-state-lab/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
```

---

## 5. S3 Encryption

We verified that the bucket uses server-side encryption:

```text
SSEAlgorithm: AES256
```

This provides encryption at rest for objects stored in the bucket.

---

## 6. S3 Versioning

We enabled S3 versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket terraform-devops-state-medon-2026 \
  --versioning-configuration Status=Enabled
```

We verified it with:

```bash
aws s3api get-bucket-versioning \
  --bucket terraform-devops-state-medon-2026
```

Result:

```json
{
    "Status": "Enabled"
}
```

Versioning allows previous versions of the Terraform state object to be retained.

---

## 7. S3 Native State Locking

Our Terraform version supports native S3 state locking.

We configured:

```hcl
use_lockfile = true
```

During:

```bash
terraform plan
```

Terraform displayed:

```text
Releasing state lock. This may take a few moments...
```

This confirmed that Terraform was using the state locking mechanism.

---

## 8. Migrating Local State to S3

Our state originally existed locally:

```text
terraform.tfstate
```

We changed the backend from:

```text
local
```

to:

```text
s3
```

Terraform detected the backend change.

We then used:

```bash
terraform init -migrate-state
```

Terraform successfully initialized the S3 backend and migrated the existing state.

---

## 9. Verifying Remote State

We verified that Terraform still matched the infrastructure:

```bash
terraform plan
```

Result:

```text
No changes. Your infrastructure matches the configuration.
```

We verified the state object in S3:

```bash
aws s3 ls \
  s3://terraform-devops-state-medon-2026/terraform-state-lab/
```

The result showed:

```text
terraform.tfstate
```

We also verified that Terraform could retrieve the remote state:

```bash
terraform state pull
```

The returned state contained the expected resources and outputs.

---

## 10. Verifying State Versioning

We checked the versions of the remote state object:

```bash
aws s3api list-object-versions \
  --bucket terraform-devops-state-medon-2026 \
  --prefix terraform-state-lab/terraform.tfstate
```

This confirmed that S3 versioning was active for the Terraform state object.

The state was also verified through the AWS Console.

---

## 11. Important Concept

Git and Terraform state serve different purposes.

```text
Git
 ↓
Stores Terraform configuration
 ↓
What Terraform SHOULD build
```

Remote state:

```text
S3
 ↓
Stores Terraform state
 ↓
What Terraform KNOWS it manages
```

---

## 12. Useful Commands

### Check AWS identity

```bash
aws sts get-caller-identity
```

### Check AWS region

```bash
aws configure get region
```

### List S3 buckets

```bash
aws s3 ls
```

### Check bucket versioning

```bash
aws s3api get-bucket-versioning \
  --bucket <bucket-name>
```

### Check bucket encryption

```bash
aws s3api get-bucket-encryption \
  --bucket <bucket-name>
```

### List objects in the backend

```bash
aws s3 ls \
  s3://<bucket-name>/<key-path>/
```

### Migrate existing state

```bash
terraform init -migrate-state
```

### Verify infrastructure

```bash
terraform plan
```

### Retrieve current state

```bash
terraform state pull
```

### List object versions

```bash
aws s3api list-object-versions \
  --bucket <bucket-name> \
  --prefix <state-key>
```

---

## Key Lesson

Remote state provides a centralized location for Terraform state.

For our AWS lab:

```text
Terraform
    │
    ├── Provider
    │      ↓
    │   Infrastructure
    │
    └── S3 Backend
           │
           ├── State storage
           ├── Encryption
           ├── Versioning
           └── Native locking
```

We migrated the existing local state to S3 without changing the infrastructure.

```text
Local State
    ↓
terraform init -migrate-state
    ↓
Remote S3 State
    ↓
terraform plan
    ↓
No changes
```

---

## Session Outcome

Successfully configured and verified an AWS S3 remote Terraform backend with encryption, versioning, and native state locking.

Existing local Terraform state was migrated to S3 without recreating the managed infrastructure.
