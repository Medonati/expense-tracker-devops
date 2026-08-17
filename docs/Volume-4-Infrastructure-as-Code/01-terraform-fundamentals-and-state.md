# 01 — Terraform Fundamentals & State

## Objective

Understand the fundamental purpose of Terraform and how it uses configuration, state, providers, planning, and application of changes to manage infrastructure.

This session focused on building the Terraform mental model before working with AWS infrastructure.

---

## 1. Infrastructure as Code

Infrastructure as Code (IaC) allows infrastructure to be defined as code rather than relying entirely on manual provisioning.

Instead of manually performing actions such as:

- Create a network
- Create a subnet
- Create a server
- Create a storage resource

we describe the desired infrastructure in configuration.

Terraform then evaluates the configuration and determines what actions are required to make the actual infrastructure match the desired configuration.

The key idea is:

> Configuration describes what we want; Terraform determines how to make reality match it.

---

## 2. Terraform's Core Components

The session established the relationship between four important components.

### Configuration

The Terraform configuration describes the desired infrastructure.

Example:

```hcl
resource "local_file" "experiment" {
  filename = "${path.module}/hello.txt"
  content  = "Terraform is managing this file."
}
````

The configuration declares that Terraform should manage a `local_file` resource named `experiment`.

---

### State

Terraform maintains a state file containing its recorded knowledge of the resources it manages.

The default local state file created during our experiment was:

```text
terraform.tfstate
```

The state records information such as:

* Terraform version
* Resource type
* Resource name
* Provider association
* Resource attributes
* Resource identity
* Resource metadata

State is not simply a copy of the real infrastructure.

Terraform can refresh its knowledge of managed resources through the provider.

---

### Provider

A provider allows Terraform to interact with a particular platform or service.

For this experiment we used:

```text
hashicorp/local
```

The provider was installed during:

```bash
terraform init
```

The provider was stored under:

```text
.terraform/providers/
```

Our installed provider was:

```text
hashicorp/local v2.9.0
linux_amd64
```

---

### Actual Infrastructure

The actual infrastructure is the resource that exists in reality.

For this experiment, the resource was:

```text
hello.txt
```

Terraform used the local provider to manage this resource.

---

## 3. Terraform Installation

Terraform was not initially installed in the DevOps VM.

The environment was verified as:

```text
Ubuntu 22.04.5 LTS
x86_64
```

Terraform was installed using the official HashiCorp APT repository.

The installation process involved:

1. Preparing the required package tools.
2. Adding the HashiCorp package signing key.
3. Inspecting the signing key fingerprint.
4. Adding the official HashiCorp APT repository.
5. Updating APT package metadata.
6. Installing Terraform.
7. Verifying the installation.

The installed version was:

```text
Terraform v1.15.8
on linux_amd64
```

The important engineering principle was:

> Know where software comes from, establish trust, install it, and verify what was installed.

This follows the same provenance-oriented thinking applied to artifacts in Volume 3.

---

## 4. Terraform Configuration

A simple local Terraform configuration was created:

```hcl
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "local" {}

resource "local_file" "experiment" {
  filename = "${path.module}/hello.txt"
  content  = "Terraform is managing this file."
}
```

The configuration defined a local file resource.

No AWS infrastructure was used for this experiment.

The purpose was to safely observe Terraform behavior before introducing cloud infrastructure.

---

## 5. `terraform init`

The first Terraform command used after creating the configuration was:

```bash
terraform init
```

Initialization:

* Read the configuration.
* Identified the required provider.
* Located `hashicorp/local`.
* Installed `hashicorp/local v2.9.0`.
* Created the `.terraform/` directory.
* Created `.terraform.lock.hcl`.

The provider was observed at:

```text
.terraform/providers/registry.terraform.io/hashicorp/local/2.9.0/linux_amd64/
```

The provider executable was:

```text
terraform-provider-local_v2.9.0_x5
```

---

## 6. Provider Lock File

Terraform created:

```text
.terraform.lock.hcl
```

The lock file records provider selections made during initialization.

Terraform explicitly recommended including this file in version control so that future `terraform init` operations can make consistent provider selections.

This demonstrates that Terraform dependencies, like application dependencies, can be controlled and reproduced.

---

## 7. `terraform validate`

The configuration was validated with:

```bash
terraform validate
```

Terraform returned:

```text
Success! The configuration is valid.
```

Validation answers the question:

> Is the Terraform configuration valid?

Validation does not create infrastructure.

After validation:

```text
hello.txt          → did not exist
terraform.tfstate  → did not exist
```

---

## 8. `terraform plan`

The configuration was evaluated with:

```bash
terraform plan
```

Terraform proposed:

```text
+ create
```

The plan showed:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

The important distinction is:

> `terraform plan` proposes changes; it does not apply them.

The plan allowed us to inspect what Terraform intended to do before making the change.

Some values were displayed as:

```text
(known after apply)
```

These were values that Terraform could only determine after the resource was actually created.

---

## 9. `terraform apply`

The proposed change was applied using:

```bash
terraform apply
```

After confirmation, Terraform created:

```text
hello.txt
```

The file contained:

```text
Terraform is managing this file.
```

Terraform also created:

```text
terraform.tfstate
```

This was the first time we could directly inspect a real Terraform state file.

---

## 10. Inspecting Terraform State

The state file was inspected with:

```bash
cat terraform.tfstate
```

The state contained information including:

```text
Terraform version
Resource type
Resource name
Provider
Resource attributes
Resource ID
Hashes
State metadata
```

For example:

```json
"type": "local_file",
"name": "experiment"
```

corresponded directly to:

```hcl
resource "local_file" "experiment"
```

The state also recorded the provider:

```text
registry.terraform.io/hashicorp/local
```

and the resource filename:

```text
./hello.txt
```

The state also contained content hashes including MD5, SHA-1, SHA-256 and SHA-512.

### Important observation

The state file did not contain a simple creation/change timestamp for the resource.

Our earlier prediction that the state would contain a time of change was therefore not supported by the experiment.

---

## 11. `terraform show`

We used:

```bash
terraform show
```

to inspect Terraform's current state representation.

It showed the managed resource:

```text
local_file.experiment
```

and its recorded attributes.

This allowed us to compare Terraform's recorded state with the actual file.

---

## 12. `terraform state list`

We used:

```bash
terraform state list
```

Terraform returned:

```text
local_file.experiment
```

This is the Terraform resource address corresponding to:

```hcl
resource "local_file" "experiment"
```

---

## 13. Controlled Drift Experiment

We deliberately changed the managed file outside Terraform.

The Terraform configuration declared:

```text
Terraform is managing this file.
```

The actual file was manually changed to:

```text
Someone changed this outside Terraform.
```

We then ran:

```bash
terraform plan
```

Terraform reported:

```text
local_file.experiment: Refreshing state...
```

and proposed:

```text
+ create
```

with:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

This demonstrated that Terraform does not simply rely on the old state file without checking the managed resource through the provider.

---

## 14. Reconciliation

We applied the proposed change:

```bash
terraform apply
```

Terraform recreated the managed file.

The file was restored to:

```text
Terraform is managing this file.
```

We then ran:

```bash
terraform plan
```

Terraform returned:

```text
No changes. Your infrastructure matches the configuration.
```

This demonstrated the reconciliation cycle:

```text
Desired configuration
        ↓
Terraform
        ↓
Inspect / refresh
        ↓
Compare
        ↓
Detect difference
        ↓
Plan change
        ↓
Apply
        ↓
Infrastructure matches configuration
```

---

## 15. Terraform Workflow Learned

The session established the following workflow:

```text
Configuration
      ↓
terraform init
      ↓
terraform validate
      ↓
terraform plan
      ↓
Review proposed changes
      ↓
terraform apply
      ↓
Infrastructure
      ↓
State updated
```

When `terraform plan` is run, Terraform can refresh its knowledge of managed resources through the provider before determining the proposed changes.

---

## Key Lessons

### 1. Terraform is declarative

We describe the desired infrastructure rather than manually specifying every action required to create it.

### 2. Configuration and state are different

Configuration describes what we want.

State records Terraform's knowledge of resources it manages.

### 3. State is not simply reality

Terraform can refresh its knowledge of infrastructure through the provider.

### 4. Providers connect Terraform to resources

The provider is responsible for enabling Terraform to interact with the target platform.

### 5. `plan` is a safety mechanism

`terraform plan` lets us inspect proposed infrastructure changes before applying them.

### 6. `apply` executes the changes

`terraform apply` makes the approved changes to the managed infrastructure.

### 7. Drift can occur

Infrastructure can change outside Terraform.

Terraform can detect differences during refresh and propose reconciliation.

### 8. Verification matters

The session deliberately used observation and controlled failure rather than assuming Terraform's behavior.

---

## Commands Practiced

```bash
terraform version
terraform init
terraform validate
terraform plan
terraform apply
terraform show
terraform state list
```

---

## Session Outcome

By the end of this session, we moved from understanding Terraform conceptually to observing Terraform manage an actual resource.

We demonstrated:

```text
Configuration
      ↓
Provider
      ↓
Resource
      ↓
State
      ↓
Plan
      ↓
Apply
      ↓
Drift detection
      ↓
Reconciliation
```

The central mental model established in this session is:

> Terraform uses configuration to define desired infrastructure, state to track managed resources, and providers to inspect and interact with real infrastructure. `terraform plan` evaluates the situation and proposes changes, while `terraform apply` executes those changes.
