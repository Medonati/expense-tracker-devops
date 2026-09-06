# 18 — Terraform AWS Security Groups

## Objective

Create and manage an AWS Security Group with Terraform, then attach it to the existing EC2 instance.

The Security Group provides the network-level access control for the EC2 instance.

---

## 1. Security Group Module

We created a dedicated module:

```text
terraform/
└── labs/
    └── aws/
        └── modules/
            └── security/
                ├── main.tf
                ├── variables.tf
                └── outputs.tf
```

This keeps security configuration separate from the networking and compute modules.

---

## 2. Security Group Configuration

The Security Group is associated with the existing VPC.

The module receives the VPC ID from the networking module:

```hcl
module "security" {
  source = "../../modules/security"

  vpc_id              = module.networking.vpc_id
  security_group_name = "expense-tracker-dev-sg"
}
```

The dependency flow is:

```text
Networking Module
       │
       │ vpc_id
       ▼
Security Module
       │
       │ security_group_id
       ▼
Compute Module
```

---

## 3. Security Rules

The Security Group currently allows:

### Inbound

SSH traffic:

```text
Protocol: TCP
Port: 22
Source: 0.0.0.0/0
```

This allows SSH connections to the EC2 instance.

### Outbound

All outbound traffic:

```text
Protocol: All
Port: All
Destination: 0.0.0.0/0
```

---

## 4. Connecting Security Group to EC2

The compute module accepts Security Group IDs:

```hcl
security_group_ids = [module.security.security_group_id]
```

The EC2 instance therefore receives the Security Group created by Terraform.

This is preferable to manually creating and attaching the Security Group through the AWS Console because the relationship is now represented as infrastructure as code.

---

## 5. IAM Permissions

During deployment, Terraform encountered several `UnauthorizedOperation` errors.

The execution role initially lacked some EC2 permissions required by the AWS provider.

The EC2 permissions were expanded to include the required read and management operations.

The important lesson was that Terraform does not only require permissions to **create** resources.

It also needs permissions to **read and inspect existing resources during refresh and planning**.

Examples encountered included:

```text
ec2:DescribeInstanceTypes
ec2:DescribeTags
ec2:DescribeVolumes
ec2:DescribeInstanceCreditSpecifications
ec2:DescribeInstanceAttribute
ec2:ModifyNetworkInterfaceAttribute
ec2:CreateSecurityGroup
```

A broader EC2 read permission was subsequently used:

```hcl
actions = [
  "ec2:Describe*"
]
```

This reduced the repeated cycle of discovering individual missing `Describe` permissions.

---

## 6. Applying IAM Changes

An important Terraform workflow lesson was identified.

When the IAM configuration is changed, the IAM configuration must be applied before expecting the execution role to have the new permissions.

The workflow is:

```bash
cd ~/projects/expense-tracker-devops/terraform/labs/aws/iam

terraform fmt
terraform validate
terraform plan
terraform apply
```

Then return to the environment:

```bash
cd ~/projects/expense-tracker-devops/terraform/labs/aws/environments/dev
```

And verify:

```bash
terraform plan
```

---

## 7. Final Verification

The final Terraform plan returned:

```text
No changes.
```

This confirms that:

* Terraform state matches AWS.
* The EC2 instance exists.
* The Security Group exists.
* The Security Group is attached to the EC2 instance.
* Terraform has the permissions required to manage the current infrastructure.
* No unexpected infrastructure changes are pending.

---

## 8. Current AWS Architecture

At this stage, the DEV environment contains:

```text
                    AWS
                     │
                     ▼
              ┌─────────────┐
              │     VPC     │
              │ 10.0.0.0/16│
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │   Subnet    │
              │ 10.0.1.0/24│
              └──────┬──────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
 ┌────────────────┐    ┌─────────────────┐
 │ Security Group │───▶│   EC2 Instance  │
 │ SSH :22        │    │    t3.micro     │
 └────────────────┘    └─────────────────┘

              ┌─────────────────┐
              │   S3 Bucket     │
              │ Terraform/Dev   │
              └─────────────────┘
```

---

## Key Lessons

### 1. Terraform permissions are broader than creation permissions

Terraform must frequently read existing infrastructure during:

```text
terraform plan
terraform apply
terraform refresh
```

Therefore, missing `Describe*` permissions can prevent Terraform from even generating a plan.

### 2. IAM changes must be applied

Changing an IAM policy file does not immediately change the AWS IAM policy.

Terraform must apply the IAM configuration before the new permissions become available.

### 3. Modules should have clear responsibilities

The infrastructure is now separated into:

```text
storage/
networking/
security/
compute/
```

Each module manages a specific area of infrastructure.

### 4. Outputs connect modules together

For example:

```hcl
module.networking.vpc_id
```

is passed into the security module, while:

```hcl
module.security.security_group_id
```

is passed into the compute module.

This creates explicit dependencies between infrastructure components.

---

## Milestone Status

```text
S3                    ✅
VPC                   ✅
Subnet                ✅
Route Table           ✅
EC2                   ✅
Security Group        ✅
Security Group → EC2  ✅
IAM Execution Role    ✅
Remote State          ✅
State Locking         ✅
Terraform Plan        ✅ No changes
```

The AWS Terraform infrastructure foundation is now complete.

The next phase is to use this infrastructure for **application deployment**, rather than continuing to expand the infrastructure unnecessarily.
