# Note 14 — Terraform IAM & Least-Privilege AWS Execution

This follows naturally from the expanded capstone:

* **Note 13** → transition from local Terraform to cloud infrastructure
* **Note 14** → secure Terraform's AWS execution with IAM
* Next → continue building the AWS side of the capstone

## What the note should capture

### 1. Objective

> Move Terraform from using an administrative AWS identity toward a dedicated IAM execution role with controlled permissions.

### 2. Starting point

Initially, Terraform was being executed using an IAM user with `AdministratorAccess`.

That was useful for getting the infrastructure working, but it was **not an appropriate long-term execution model**.

The goal was therefore:

```text
AdministratorAccess
        ↓
Dedicated Terraform IAM Role
        ↓
Least-privilege policy
        ↓
Terraform AWS operations
```

### 3. Resources created

We created:

```text
terraform-dev-execution-role
```

and:

```text
terraform-dev-execution-policy
```

The policy was attached to the role.

We verified this with:

```bash
aws iam list-attached-role-policies \
  --role-name terraform-dev-execution-role
```

which confirmed:

```text
terraform-dev-execution-policy
```

was attached.

### 4. Trust relationship

The role trusts our current Terraform IAM user so that the user can assume the role.

We tested this directly:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::748241639517:role/terraform-dev-execution-role \
  --role-session-name terraform-test
```

The successful `AssumedRoleUser` response proved the trust relationship worked.

### 5. Terraform provider

The AWS provider was changed from simply:

```hcl
provider "aws" {
  region = var.aws_region
}
```

to using:

```hcl
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::748241639517:role/terraform-dev-execution-role"
  }
}
```

This means Terraform uses the dedicated execution role when interacting with AWS.

### 6. The IAM troubleshooting lesson

This was probably the most valuable part of the exercise.

When we first ran:

```bash
terraform plan
```

Terraform received `AccessDenied` errors such as:

```text
s3:GetBucketPolicy
s3:GetBucketAcl
s3:GetBucketCORS
s3:GetBucketWebsite
s3:GetAccelerateConfiguration
s3:GetLifecycleConfiguration
s3:GetBucketEncryption
```

This demonstrated that **Terraform's AWS provider performs numerous read operations when refreshing an `aws_s3_bucket` resource**.

We initially tried adding individual permissions one at a time.

That became inefficient.

We then learned an important distinction:

```text
AWS API operation
        ≠
IAM action name
```

For example:

```text
GetBucketLifecycleConfiguration
        ↓
s3:GetLifecycleConfiguration
```

and:

```text
GetBucketAccelerateConfiguration
        ↓
s3:GetAccelerateConfiguration
```

This explained why a wildcard such as:

```hcl
"s3:GetBucket*"
```

didn't cover every bucket-related read.

For this learning stage, we ultimately used the broader but still scoped:

```hcl
"s3:Get*"
```

rather than:

```hcl
"s3:*"
```

The important distinction is that our permissions remain scoped to the specific infrastructure resource rather than granting unrestricted S3 access.

### 7. Final verification

The most important test was:

```bash
terraform plan
```

and the final result:

```text
module.storage.aws_s3_bucket.this: Refreshing state...

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and
found no differences, so no changes are needed.
```

That confirms the execution role can successfully perform the Terraform operations required by our current DEV infrastructure.

---

# Key Lessons

### Terraform doesn't need AdministratorAccess

Terraform only needs the permissions required to perform its infrastructure operations.

### `plan` is more than a preview

We saw that `terraform plan` also refreshes the existing infrastructure and therefore exercises the permissions Terraform needs to **read** the infrastructure.

### IAM errors can be useful

An `AccessDenied` isn't necessarily a failure of the architecture.

It can tell us:

> Terraform attempted an operation that the current execution identity isn't authorized to perform.

That gives us evidence for refining the policy.

### Least privilege is a process

We don't necessarily know every permission on day one.

We can:

```text
Start restrictive
      ↓
Test
      ↓
Observe
      ↓
Understand
      ↓
Refine
      ↓
Retest
```

That's exactly what we did here.

---

## Milestone status

```text
AWS DEV infrastructure          ✅
S3 Terraform backend            ✅
S3 DEV bucket                   ✅
Dedicated IAM role              ✅
Dedicated IAM policy            ✅
Role assumption                 ✅
Terraform using assumed role    ✅
Least-privilege testing         ✅
Terraform plan                  ✅
No changes                      ✅
```

### 🟢 Note 14 COMPLETE