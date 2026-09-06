# Note 15 — Terraform AWS Networking: VPC & Subnet

This follows naturally from:

* **Note 13** → transition from local Terraform to cloud infrastructure
* **Note 14** → secure Terraform's AWS execution with IAM
* **Note 15** → provision the first AWS networking infrastructure with Terraform

---

## 1. Objective

Move from configuring Terraform's AWS execution identity to actually provisioning AWS infrastructure.

The goal was to create a basic AWS networking foundation using Terraform:

```text
VPC
 ↓
Subnet
```

We deliberately kept the AWS architecture simple and cost-conscious because this is a Free Tier learning environment.

---

## 2. Starting Point

Terraform was already configured to use the dedicated IAM execution role:

```text
terraform-dev-execution-role
```

rather than the Administrator identity.

Before creating new infrastructure, we verified that Terraform could successfully:

```text
Authenticate
     ↓
Assume IAM role
     ↓
Read existing infrastructure
     ↓
Plan AWS changes
```

---

## 3. Creating the VPC

We created an AWS VPC using the Terraform networking module.

The VPC uses:

```text
CIDR:
10.0.0.0/16
```

Terraform planned:

```text
module.networking.aws_vpc.this
```

with:

```text
enable_dns_support   = true
enable_dns_hostnames = true
```

The VPC was successfully created.

AWS assigned:

```text
VPC ID:
vpc-00b33c390c81c1f70
```

---

## 4. VPC IAM Permission Troubleshooting

Our first VPC deployment failed because the Terraform execution role did not have:

```text
ec2:CreateVpc
```

permission.

The error demonstrated an important principle:

```text
Terraform configuration
        ↓
AWS API request
        ↓
IAM authorization
        ↓
AWS resource
```

Terraform can have perfectly valid configuration while still being unable to create the resource because its execution identity lacks the required permission.

We updated the Terraform execution policy to include the required EC2 networking permissions.

---

## 5. Resource Tagging Permission

After adding the VPC creation permission, the next attempt failed with:

```text
ec2:CreateTags
```

This happened because our VPC configuration included a tag:

```hcl
tags = {
  Name = var.vpc_name
}
```

This taught us that creating infrastructure and tagging infrastructure can require separate IAM permissions.

We added the required tagging permission rather than broadly granting:

```text
ec2:*
```

---

## 6. Successful VPC Creation

After correcting the IAM policy, Terraform successfully created the VPC:

```text
module.networking.aws_vpc.this: Creation complete
```

Final result:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

We then verified the resource directly through AWS:

```bash
aws ec2 describe-vpcs \
  --vpc-ids vpc-00b33c390c81c1f70 \
  --query 'Vpcs[0].[VpcId,CidrBlock,State]' \
  --output table
```

AWS returned:

```text
vpc-00b33c390c81c1f70
10.0.0.0/16
available
```

This confirmed that the VPC existed in AWS and was available.

---

## 7. Creating the Subnet

After successfully creating the VPC, we extended the networking module to create a subnet.

The subnet uses:

```text
CIDR:
10.0.1.0/24
```

The subnet references the VPC through:

```hcl
vpc_id = aws_vpc.this.id
```

This creates the dependency:

```text
VPC
 ↓
Subnet
```

Terraform therefore knows that the VPC must exist before creating the subnet.

---

## 8. Subnet Plan

Terraform correctly detected that the VPC already existed in state.

The plan showed:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The only resource being added was:

```text
module.networking.aws_subnet.this
```

Terraform also exposed:

```text
vpc_id      = vpc-00b33c390c81c1f70
subnet_cidr = 10.0.1.0/24
```

This demonstrated that Terraform was correctly connecting the new subnet to the existing VPC.

---

## 9. Successful Subnet Creation

We applied the configuration.

Terraform successfully created:

```text
Subnet ID:
subnet-09486006cf28434dd
```

Final result:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Terraform outputs:

```text
bucket_name = "expense-tracker-dev-terraform-2026"
subnet_cidr = "10.0.1.0/24"
subnet_id   = "subnet-09486006cf28434dd"
vpc_cidr    = "10.0.0.0/16"
vpc_id      = "vpc-00b33c390c81c1f70"
```

---

## 10. Final Networking Architecture

Our AWS networking foundation is now:

```text
AWS
 │
 └── VPC
      │
      │ 10.0.0.0/16
      │
      └── Subnet
           │
           │ 10.0.1.0/24
```

The subnet is therefore a smaller network range contained within the VPC's larger address space.

---

## 11. Terraform Dependency

One of the important Terraform concepts demonstrated in this milestone was implicit dependency.

We did not manually tell Terraform:

> Create the VPC first.

Instead, Terraform determined the dependency from:

```hcl
vpc_id = aws_vpc.this.id
```

Conceptually:

```text
aws_vpc.this.id
       ↓
aws_subnet.this
```

Terraform builds the dependency graph from these references.

---

## 12. AWS Credentials Troubleshooting

During the AWS work, Terraform also encountered:

```text
Signature expired
```

The error was caused by expired AWS session credentials.

This was different from an IAM authorization failure.

### Credential failure

```text
Signature expired
```

means the credentials/session are no longer valid.

### Authorization failure

```text
is not authorized to perform...
```

means the credentials are valid but the IAM identity does not have the required permission.

We can check the current AWS identity with:

```bash
aws sts get-caller-identity
```

Important distinction:

> `aws sts get-caller-identity` verifies the current credentials; it does not refresh expired credentials.

---

## 13. Free Tier Consideration

The purpose of this AWS phase is to gain practical cloud experience without unnecessarily consuming the AWS credit.

We therefore decided to avoid infrastructure that introduces unnecessary costs.

In particular:

```text
NAT Gateway
```

will not be used simply for the sake of making the architecture more sophisticated.

The focus remains:

```text
Understand the workflow
        ↓
Provision real AWS infrastructure
        ↓
Use Terraform
        ↓
Demonstrate cloud experience
        ↓
Avoid unnecessary costs
```

---

# Key Lessons

### Terraform can manage real cloud infrastructure

Terraform is not limited to local resources.

The same Infrastructure as Code principles apply when Terraform communicates with AWS.

### IAM is part of infrastructure automation

Terraform's ability to create infrastructure depends on the permissions of its execution identity.

### Resource creation can involve multiple API permissions

Creating a VPC required more than simply understanding the Terraform resource itself.

The execution role needed permissions for operations such as:

```text
ec2:CreateVpc
ec2:CreateTags
```

### Terraform understands dependencies

Referencing:

```hcl
aws_vpc.this.id
```

automatically establishes the relationship between the VPC and subnet.

### Verify before assuming

Terraform reported successful creation, but we still verified the VPC directly through AWS.

This follows one of our core engineering principles:

> **Don't assume. Verify.**

---

# Common Mistakes

* Assuming `terraform plan` creates infrastructure.
* Assuming a valid Terraform configuration automatically means AWS will authorize it.
* Assuming one IAM permission covers an entire resource lifecycle.
* Confusing credential expiration with IAM authorization failure.
* Adding unnecessarily broad permissions instead of understanding the required actions.
* Creating AWS resources without considering their cost implications.

---

# Best Practices

* Use a dedicated IAM execution role for Terraform.
* Keep permissions scoped to the infrastructure being managed.
* Use Terraform modules to organize infrastructure.
* Use variables for environment-specific values.
* Use outputs to expose important infrastructure information.
* Run `terraform plan` before `terraform apply`.
* Verify important resources after deployment.
* Consider cost before introducing AWS services.

---

# If I Were Interviewed

**Question:** How did you provision your AWS networking infrastructure?

**Answer:**

> I used Terraform modules to provision an AWS VPC and subnet. Terraform operates through a dedicated IAM execution role rather than Administrator access. I used `terraform plan` to review changes before applying them, and Terraform automatically handled the dependency between the VPC and subnet through resource references. After deployment, I verified the VPC directly through the AWS CLI.

---

# Engineer's Takeaways

The important workflow from this milestone is:

```text
Terraform Code
      ↓
IAM Execution Role
      ↓
AWS API
      ↓
Terraform Plan
      ↓
Review
      ↓
Terraform Apply
      ↓
AWS Infrastructure
      ↓
Verify
```

The bigger lesson is:

> **Cloud infrastructure is not just about creating resources. It is about defining infrastructure as code, controlling who can create it, understanding dependencies, reviewing changes, deploying safely, and verifying the result.**

---

# Commands Used

Format and validate:

```bash
terraform fmt
terraform validate
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

View outputs:

```bash
terraform output
```

Verify AWS identity:

```bash
aws sts get-caller-identity
```

Verify VPC:

```bash
aws ec2 describe-vpcs \
  --vpc-ids vpc-00b33c390c81c1f70 \
  --query 'Vpcs[0].[VpcId,CidrBlock,State]' \
  --output table
```

---

# Session Outcome

Successfully moved Terraform from **IAM-controlled AWS execution** into actual AWS infrastructure provisioning.

Created:

```text
VPC
└── vpc-00b33c390c81c1f70
    └── 10.0.0.0/16

Subnet
└── subnet-09486006cf28434dd
    └── 10.0.1.0/24
```

Terraform successfully manages the infrastructure through the dedicated execution role, while the AWS environment remains intentionally small and cost-conscious.

### 🟢 Note 15 COMPLETE
