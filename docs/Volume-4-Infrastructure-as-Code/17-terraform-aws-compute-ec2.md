# 17. Terraform AWS Compute: EC2 Instance

## 17.1 Objective

The objective of this milestone was to extend our Terraform AWS infrastructure by introducing **compute resources** through an EC2 instance.

We built the EC2 configuration as a reusable Terraform module and connected it to the existing DEV environment.

By the end of this milestone, Terraform successfully managed:

* AWS VPC
* AWS Subnet
* Route Table
* Route Table Association
* S3 Storage
* EC2 Compute
* Remote Terraform State
* IAM Terraform Execution Role

---

## 17.2 Project Structure

The compute configuration was added as a reusable module:

```text
terraform/
└── labs/
    └── aws/
        ├── environments/
        │   └── dev/
        │       ├── main.tf
        │       ├── variables.tf
        │       ├── terraform.tfvars
        │       └── outputs.tf
        │
        ├── modules/
        │   ├── networking/
        │   ├── storage/
        │   └── compute/
        │       ├── main.tf
        │       ├── variables.tf
        │       └── outputs.tf
        │
        └── iam/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

This reinforces the principle of separating **environment configuration** from **reusable infrastructure modules**.

---

## 17.3 EC2 Configuration

The compute module provisions an EC2 instance using variables for:

* AMI ID
* Instance type
* Instance name
* Subnet

The DEV environment uses:

```text
AMI: ami-0db1c5c6dc64eb019
Instance type: t3.micro
Instance name: expense-tracker-dev-ec2
```

The instance was placed inside the subnet created during the networking milestone:

```text
VPC CIDR:    10.0.0.0/16
Subnet CIDR: 10.0.1.0/24
```

---

## 17.4 Free Tier Consideration

Because this project is being built using an AWS Free Tier account, compute selection was made with cost awareness.

The selected instance type was:

```text
t3.micro
```

We also verified through the AWS CLI that `t3.micro` was identified as Free Tier eligible.

The AMI selected was an Amazon Linux 2023 x86_64 AMI.

Free Tier eligibility does not mean unlimited usage. Usage must still be monitored through AWS Billing and Free Tier tracking.

---

## 17.5 Understanding `cpu_credits = "standard"`

The Terraform plan showed:

```text
credit_specification {
  cpu_credits = "standard"
}
```

This relates to the **CPU credit model used by burstable T3 instances**.

`standard` means the instance operates under the standard CPU credit model rather than Unlimited mode.

For this DEV lab, this is appropriate because we are not running a sustained high-CPU workload.

---

## 17.6 Terraform Provider Initialization

When Terraform was initially run from the compute module directory, validation produced:

```text
Error: Missing required provider

This configuration requires provider
registry.terraform.io/hashicorp/aws,
but that provider isn't available.
```

The issue was caused by running Terraform directly inside the module before the required provider had been initialized in that working configuration.

The solution was to initialize the Terraform environment:

```bash
terraform init
```

This reinforced an important Terraform concept:

> `terraform init` prepares a working directory by downloading and configuring required providers and modules.

---

## 17.7 Integrating the Compute Module

The EC2 configuration was kept separate from the networking module.

The DEV environment consumes the compute module rather than placing the EC2 resource directly inside the environment configuration.

This maintains the modular architecture:

```text
DEV Environment
       │
       ├── Storage Module
       │
       ├── Networking Module
       │
       └── Compute Module
```

The networking module remains responsible for networking resources, while the compute module is responsible for compute resources.

---

## 17.8 IAM Permissions and Terraform

One of the most important lessons from this milestone was understanding that Terraform requires permissions not only to **create** resources but also to **read and refresh** them.

The Terraform execution role initially failed with:

```text
ec2:DescribeInstanceTypes
```

Later failures included:

```text
ec2:DescribeTags
ec2:DescribeInstanceAttribute
ec2:DescribeVolumes
ec2:DescribeInstanceCreditSpecifications
```

These were not separate infrastructure failures.

They were permission failures occurring while Terraform attempted to inspect the EC2 instance.

---

## 17.9 Improving the EC2 IAM Permission Model

Instead of continually adding individual `Describe` permissions whenever Terraform encountered another API call, the EC2 compute permissions were consolidated using:

```hcl
"ec2:Describe*"
```

alongside the required lifecycle permissions:

```hcl
"ec2:RunInstances",
"ec2:StartInstances",
"ec2:StopInstances",
"ec2:TerminateInstances"
```

This was an important practical lesson:

> Terraform providers perform multiple read operations during refresh and planning. IAM policies must account for the provider's required read operations, not only the obvious create/delete actions.

---

## 17.10 Terraform State and the Tainted Instance

The first EC2 creation attempt was interrupted by an IAM permission failure.

Terraform subsequently marked the EC2 resource as:

```text
tainted
```

Terraform therefore proposed:

```text
-/+ destroy and then create replacement
```

The existing instance was intentionally allowed to be replaced because this was a DEV lab environment.

Terraform then successfully completed:

```text
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

This demonstrated how Terraform handles a resource that has been marked for replacement.

---

## 17.11 Final Infrastructure State

The final DEV environment contains:

```text
S3 Bucket
    │
    └── expense-tracker-dev-terraform-2026

VPC
    │
    └── 10.0.0.0/16
          │
          └── Subnet
                │
                └── 10.0.1.0/24
                      │
                      └── EC2 t3.micro
```

Terraform also manages the route table and route table association for the subnet.

---

## 17.12 Terraform Validation

Before deployment, the configuration was formatted and validated:

```bash
terraform fmt
terraform validate
```

Validation returned:

```text
Success! The configuration is valid.
```

---

## 17.13 Terraform Plan

Terraform successfully generated the EC2 deployment plan:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The planned instance was:

```text
AMI:           ami-0db1c5c6dc64eb019
Instance type: t3.micro
Subnet:        subnet-09486006cf28434dd
Region:        us-east-1
Name:          expense-tracker-dev-ec2
```

---

## 17.14 Final Verification

After the EC2 replacement was completed, Terraform was run again:

```bash
terraform plan
```

The final result was:

```text
No changes.
```

This is an important Terraform milestone.

It confirms that:

```text
Terraform configuration
        ↓
Terraform state
        ↓
AWS infrastructure
```

are synchronized.

Terraform does not currently need to create, modify, or destroy anything.

---

## 17.15 Key Lessons

### 1. Terraform modules improve reusability

Compute was separated into its own module rather than mixing EC2 resources with networking resources.

### 2. Terraform needs read permissions

Terraform must be able to inspect existing infrastructure during:

```text
plan
apply
refresh
```

Create permissions alone are not sufficient.

### 3. IAM errors can appear during refresh

A `403 UnauthorizedOperation` does not necessarily mean Terraform failed to create something. It may simply be unable to read an existing resource.

### 4. Tainted resources can be replaced

A tainted resource causes Terraform to propose:

```text
destroy → create
```

### 5. `terraform plan` is our safety mechanism

We don't blindly apply infrastructure changes.

The workflow remains:

```text
terraform fmt
      ↓
terraform validate
      ↓
terraform plan
      ↓
terraform apply
      ↓
terraform plan
      ↓
No changes
```

### 6. Free Tier must be monitored

Using a Free Tier eligible instance does not remove the need to monitor AWS usage.

---

## 17.16 Common Mistakes to Avoid

### Mistake 1: Putting module arguments outside the module block

Incorrect:

```hcl
module "compute" {
  source = "../../modules/compute"
}

ami_id = var.ami_id
```

The arguments must belong inside the module block.

Correct:

```hcl
module "compute" {
  source = "../../modules/compute"

  ami_id        = var.ami_id
  instance_type = var.instance_type
  instance_name = var.instance_name
}
```

### Mistake 2: Running Terraform from the wrong directory

Terraform commands should be executed from the intended environment directory when working with the environment configuration.

For DEV:

```bash
cd ~/projects/expense-tracker-devops/terraform/labs/aws/environments/dev
```

### Mistake 3: Adding IAM permissions one error at a time

Repeatedly responding to individual `Describe...` errors is inefficient.

A better approach is to understand the provider's read requirements and design the IAM policy accordingly.

---

## 17.17 Best Practice

The infrastructure now follows a clearer separation of responsibilities:

```text
IAM
 └── Terraform execution permissions

Storage Module
 └── S3

Networking Module
 ├── VPC
 ├── Subnet
 └── Route Table

Compute Module
 └── EC2

DEV Environment
 └── Composes the modules
```

This is much closer to how infrastructure is structured in real-world Terraform projects.

---

## 17.18 Beyond This Chapter

The next stages can build on this foundation by introducing additional infrastructure and eventually connecting the infrastructure to the application and deployment workflow.

The important foundation has now been established:

```text
Remote State
     ↓
IAM
     ↓
Networking
     ↓
Storage
     ↓
Compute
```

---

## 17.19 Interview Perspective

If asked:

**"What happens when you run ****`terraform plan`**** against an existing EC2 instance?"**

A strong answer would be:

> Terraform refreshes the resource state by querying AWS APIs, compares the real infrastructure against the configuration and state, and then generates a plan showing any required changes. This is why the Terraform execution role needs appropriate read permissions such as EC2 Describe actions.

If asked:

**"Why did Terraform want to replace your EC2 instance?"**

Answer:

> The resource had been marked as tainted after the initial creation process encountered an error. Terraform therefore treated the resource as unhealthy and proposed destroying and recreating it.

---

## 17.20 Engineer's Takeaways

This milestone reinforced several important infrastructure engineering principles:

* Infrastructure should be modular.
* IAM permissions should reflect actual provider requirements.
* Terraform must be able to read infrastructure it manages.
* `terraform plan` should be reviewed before applying changes.
* State consistency is critical.
* Free Tier resources still require cost awareness.
* Troubleshooting should focus on the underlying system rather than repeatedly fixing individual symptoms.

---

## 17.21 Commands Used

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

AWS CLI commands used during the milestone included:

```bash
aws ec2 describe-instance-types
aws ec2 describe-images
aws iam get-policy
aws iam get-policy-version
```

---

## 17.22 Session Outcome

The AWS DEV environment now successfully includes a Terraform-managed EC2 compute layer.

Final verification:

```text
terraform plan

No changes.
```

**Infrastructure is synchronized and the compute milestone is complete.**

### 🟢 Note 17 COMPLETE
