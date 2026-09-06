# Note 16 — Terraform AWS Networking: Route Tables & Subnet Association

## 1. Objective

Continue building the AWS networking foundation by introducing a **route table** and associating it with our existing subnet.

The objective is to understand how Terraform represents the relationship between:

```text
VPC
 ↓
Subnet
 ↓
Route Table
```

We are still keeping the AWS environment intentionally simple and Free-Tier-conscious.

---

## 2. Starting Point

At the beginning of this milestone, we already had:

```text
VPC
10.0.0.0/16
```

and:

```text
Subnet
10.0.1.0/24
```

Both were already managed by Terraform.

Our next question was:

> **How does a subnet know where network traffic should go?**

This introduces the concept of a **route table**.

---

## 3. What Is a Route Table?

A route table contains rules that determine where network traffic should be directed.

Conceptually:

```text
Destination
     ↓
Route
     ↓
Target
```

For example, a VPC's local routing allows resources within the VPC to communicate with one another.

At this stage, we are **not** introducing an Internet Gateway or NAT Gateway.

Our purpose is simply to understand the routing relationship.

---

## 4. Creating the Route Table

We added the following resource to the networking module:

```hcl
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.route_table_name
  }
}
```

### Important parts

```hcl
vpc_id = aws_vpc.this.id
```

connects the route table to our existing VPC.

Terraform therefore understands:

```text
VPC
 ↓
Route Table
```

We also made the route table name configurable through a variable rather than hardcoding it.

---

## 5. Route Table Variable

We added:

```hcl
variable "route_table_name" {
  description = "Name of the route table"
  type        = string
}
```

The DEV environment supplies:

```text
expense-tracker-dev-route-table
```

This follows the same module pattern we've been using:

```text
Environment
    ↓
Variables
    ↓
Module
    ↓
AWS Resource
```

---

## 6. Route Table Association

Creating a route table does not automatically mean that our subnet uses it.

We therefore created:

```hcl
resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}
```

This creates the relationship:

```text
Route Table
     │
     │ association
     ↓
Subnet
```

The complete dependency becomes:

```text
VPC
 │
 ├── Subnet
 │
 └── Route Table
       │
       └── Association → Subnet
```

---

## 7. Terraform Validation

After updating the configuration, we ran:

```bash
terraform fmt
```

Terraform formatted:

```text
main.tf
terraform.tfvars
```

We then ran:

```bash
terraform validate
```

Terraform returned:

```text
Success! The configuration is valid.
```

This confirmed that our configuration was structurally valid before attempting to provision anything.

---

## 8. Terraform Plan

We then ran:

```bash
terraform plan
```

Terraform first refreshed the existing infrastructure:

```text
module.storage.aws_s3_bucket.this
module.networking.aws_vpc.this
module.networking.aws_subnet.this
```

It then proposed two new resources:

```text
module.networking.aws_route_table.this
module.networking.aws_route_table_association.this
```

The plan showed:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

This was important because Terraform was **not recreating or modifying our existing VPC or subnet**.

It correctly understood that they already existed.

---

## 9. Understanding the Plan

The route table would be created inside:

```text
VPC:
vpc-00
```

The association would connect the new route table to:

```text
Subnet:
subnet-094
```

Therefore:

```text
VPC
│
├── Subnet
│   └── subnet-094
│
└── Route Table
    └── rtb-0d82
             │
             └── associated with subnet
```

---

## 10. Applying the Configuration

After reviewing the plan, we ran:

```bash
terraform apply
```

Terraform successfully created the route table:

```text
rtb-0d82
```

Then it created the association:

```text
rtbassoc-05b1
```

Terraform reported:

```text
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

## 11. Terraform Dependency Graph

This milestone reinforced Terraform's dependency graph.

We didn't manually instruct Terraform:

```text
Create VPC first
Create subnet second
Create route table
Associate route table
```

Terraform determines dependencies from resource references such as:

```hcl
vpc_id = aws_vpc.this.id
```

and:

```hcl
subnet_id = aws_subnet.this.id
```

and:

```hcl
route_table_id = aws_route_table.this.id
```

Therefore Terraform can build the correct order automatically.

Conceptually:

```text
aws_vpc.this
     │
     ├──────────────┐
     ↓              ↓
aws_subnet     aws_route_table
     │              │
     └──────┬───────┘
            ↓
  aws_route_table_association
```

---

## 12. Current AWS Networking Architecture

Our networking layer now looks like:

```text
AWS
│
└── VPC
    │
    │ 10.0.0.0/16
    │
    ├── Subnet
    │   │
    │   └── 10.0.1.0/24
    │
    └── Route Table
        │
        └── Associated with Subnet
```

Resources created so far:

```text
VPC:
vpc-00

Subnet:
subnet-09486
Route Table:
rtb-0d82

Route Table Association:
rtbassoc-05b1
```

---

# Key Lessons

### 1. A route table defines routing rules

It determines how traffic should be handled within a network.

### 2. A route table and subnet are separate resources

Creating a route table doesn't automatically attach it to a subnet.

The association explicitly connects them.

### 3. Terraform understands dependencies

Resource references allow Terraform to determine the correct creation order.

### 4. `terraform plan` protects us from surprises

The plan showed:

```text
2 to add
0 to change
0 to destroy
```

before we applied anything.

### 5. Existing infrastructure remains managed

Terraform refreshed our existing S3 bucket, VPC and subnet before calculating the changes.

---

# Common Mistakes

* Assuming a route table automatically applies to every subnet.
* Creating a route table without associating it with the intended subnet.
* Adding an Internet Gateway or NAT Gateway when it isn't required for the learning objective.
* Applying changes without reviewing the Terraform plan.
* Assuming resources need to be recreated simply because new resources depend on them.

---

# Best Practices

* Keep networking resources modular.
* Use variables for environment-specific names and configuration.
* Explicitly associate route tables with the appropriate subnets.
* Review `terraform plan` before applying.
* Keep AWS infrastructure intentionally small while learning.
* Avoid unnecessary resources that may introduce AWS charges.

---

# Beyond This Chapter

We now have:

```text
VPC
 ↓
Subnet
 ↓
Route Table
```

The next networking milestone will build on this foundation.

We will continue incrementally rather than introducing unnecessary AWS components simply to make the architecture look bigger.

---

# If I Were Interviewed

**Question: What is the purpose of a route table in AWS?**

**Answer:**

> A route table contains routing rules that determine where network traffic should be directed. In our Terraform configuration, I created a route table inside the VPC and explicitly associated it with the subnet so that the subnet uses that route table for its routing decisions.

**Question: How does Terraform know the correct creation order?**

**Answer:**

> Terraform builds a dependency graph from references between resources. For example, the subnet references the VPC ID and the route table association references both the subnet and route table IDs, allowing Terraform to determine the correct order automatically.

---

# Engineer's Takeaways

The important workflow from this milestone is:

```text
Define
  ↓
Validate
  ↓
Plan
  ↓
Review
  ↓
Apply
  ↓
Verify
```

And the networking relationship we learned is:

```text
VPC
 │
 ├── Subnet
 │
 └── Route Table
       │
       └── Association
             ↓
           Subnet
```

The bigger lesson:

> **Infrastructure is built from relationships, not isolated resources. Terraform's dependency graph allows us to express those relationships as code and let Terraform determine the correct order of operations.**

---

# Commands Used

```bash
terraform fmt
```

```bash
terraform validate
```

```bash
terraform plan
```

```bash
terraform apply
```

---

## Milestone Result

Successfully created and associated an AWS route table with our existing subnet using Terraform.

```text
VPC
10.0.0.0/16
    │
    ├── Subnet
    │   10.0.1.0/24
    │
    └── Route Table
        rtb-0d82
             │
             └── Association
                 rtbassoc-05b1
```

### 🟢 Note 16 COMPLETE
