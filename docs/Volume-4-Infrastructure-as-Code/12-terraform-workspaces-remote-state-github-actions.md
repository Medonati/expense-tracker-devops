# 12 — Terraform Workspaces, Remote State & GitHub Actions CI

## Objective

Understand how Terraform remote state, workspaces, state isolation, state locking, and GitHub Actions CI work together to manage Terraform infrastructure safely and validate changes automatically.

---

## 1. Terraform Remote State with S3

We configured Terraform to use an S3 backend instead of storing state only on the local machine.

Our backend configuration is:

```hcl
backend "s3" {
  bucket       = "terraform-devops-state-medon-2026"
  key          = "terraform-state-lab/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
```

This means Terraform stores its state remotely in S3.

The backend provides the interface Terraform uses to:

```text
Store state
Read state
Lock state
Perform Terraform operations
```

Instead of relying only on:

```text
terraform.tfstate
```

on the local machine, our state is managed through the remote S3 backend.

---

## 2. Backend Reinitialization

When we returned to the Terraform state lab, Terraform reported:

```text
Error: Backend initialization required
```

Terraform detected that the backend configuration had changed to S3.

We initialized the backend again and Terraform detected:

```text
Previous: local
New:      s3
```

It then asked whether we wanted to copy the previous local state into the existing S3 state.

We selected:

```text
no
```

because an existing non-empty state already existed in S3.

Terraform then successfully configured the S3 backend:

```text
Successfully configured the backend "s3"!
```

### Key Lesson

Backend changes can involve state migration.

Before accepting a migration prompt, understand:

```text
Where is the old state?
Where is the new state?
Which state should remain authoritative?
```

Never blindly overwrite remote state.

---

## 3. Terraform Workspaces

We inspected the available workspaces:

```bash
terraform workspace list
```

and found:

```text
* default
  dev
```

We checked the active workspace with:

```bash
terraform workspace show
```

Initially:

```text
default
```

We then switched to:

```bash
terraform workspace select dev
```

and confirmed:

```text
dev
```

### Key Concept

A Terraform workspace provides a separate state instance while using the same Terraform configuration.

Conceptually:

```text
Same Terraform Configuration
             │
      ┌──────┴──────┐
      ↓             ↓
   default          dev
      │             │
      ↓             ↓
 Default State    Dev State
```

---

## 4. Demonstrating Workspace State Isolation

While using the `default` workspace, we ran:

```bash
terraform state list
```

and saw:

```text
module.file.local_file.this
```

We switched to `dev` and initially found that its state did not contain the managed resource.

This demonstrated that the `dev` workspace was not using the state belonging to `default`.

### Important Distinction

The configuration is shared:

```text
Same .tf files
```

but the state is separate:

```text
default → Default state

dev → Dev state
```

Therefore:

> **Workspaces isolate state, not configuration.**

---

## 5. Planning in the Dev Workspace

While in the `dev` workspace, we ran:

```bash
terraform plan
```

Terraform detected that the resource was not present in the `dev` state.

The plan showed:

```text
+ module.file.local_file.this
```

and:

```text
filename = "./dev-hello.txt"
```

Terraform reported:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

This happened because Terraform was evaluating the configuration against the **dev workspace state**, not the `default` workspace state.

---

## 6. Applying the Dev Workspace

We then applied the plan:

```bash
terraform apply
```

Terraform completed successfully:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

The output showed:

```text
filename = "./dev-hello.txt"
```

We verified the physical file:

```bash
ls -l dev-hello.txt
```

and confirmed that it had been created.

---

## 7. Comparing Workspace States

After applying in `dev`, we ran:

```bash
terraform state list
```

while still in `dev`.

The state contained:

```text
data.local_file.existing_file
module.file.local_file.this
```

We then switched back:

```bash
terraform workspace select default
```

and ran:

```bash
terraform state list
```

The `default` workspace showed:

```text
module.file.local_file.this
```

The result was:

```text
default
└── module.file.local_file.this

dev
├── data.local_file.existing_file
└── module.file.local_file.this
```

The same resource address can therefore exist in both workspaces because each workspace has a separate state.

---

## 8. Inspecting Remote State

We used:

```bash
terraform state pull
```

while in the `dev` workspace.

The returned state contained:

```text
"filename": {
  "value": "./dev-hello.txt"
}
```

The `dev` state also had its own:

```text
serial
lineage
resources
outputs
```

We then switched to `default` and ran:

```bash
terraform state pull
```

The `default` state contained:

```text
"filename": {
  "value": "./hello-variable.txt"
}
```

The state also had a different lineage and serial.

### Key Lesson

`terraform state pull` retrieves the state associated with the **currently selected workspace**.

It does not show the Terraform configuration.

It shows the state Terraform is using to track infrastructure.

---

## 9. Terraform State Locking

Our S3 backend contains:

```hcl
use_lockfile = true
```

During Terraform operations we repeatedly observed:

```text
Acquiring state lock. This may take a few moments...
```

and:

```text
Releasing state lock. This may take a few moments...
```

The basic lifecycle is:

```text
Terraform Operation
        │
        ↓
Acquire Lock 🔒
        │
        ↓
Read / Modify State
        │
        ↓
Release Lock 🔓
```

State locking helps prevent multiple Terraform operations from modifying the same state simultaneously.

### Important Distinction

Our configuration uses:

```hcl
use_lockfile = true
```

We should not automatically assume that S3 state locking means DynamoDB.

This lab uses the S3 lockfile mechanism.

---

## 10. Verifying State Locking

We ran:

```bash
terraform plan
```

and Terraform successfully completed the operation:

```text
No changes. Your infrastructure matches the configuration.
```

During the operation we observed:

```text
Acquiring state lock...
```

and:

```text
Releasing state lock...
```

This confirmed the normal lock lifecycle.

---

## 11. GitHub Actions CI

As part of this milestone, we introduced GitHub Actions into the Terraform workflow.

Our repository now contains:

```text
.github/
└── workflows/
    └── terraform.yml
```

The purpose of the workflow is to automatically validate Terraform changes before they are accepted into the project.

---

## 12. Path-Based Workflow Trigger

We configured the workflow to run when Terraform files change:

```yaml
paths:
  - "terraform/**"
```

This means changes anywhere under:

```text
terraform/
```

can trigger the workflow.

For example:

```text
terraform/environments/dev/
terraform/environments/prod/
terraform/modules/
```

can all trigger the Terraform CI pipeline.

### Key Concept

GitHub Actions can use path filters to avoid running workflows unnecessarily.

Instead of:

```text
Any repository change
        ↓
Run Terraform CI
```

we have:

```text
Terraform change
        ↓
Run Terraform CI
```

---

## 13. GitHub Actions Runner

We learned that GitHub Actions workflows execute on a **runner**.

The runner provides the operating-system environment in which the workflow commands execute.

Our workflow uses a Linux runner.

This is conceptually similar to the environments we've already worked with:

```text
Jenkins
   ↓
tools {
    nodejs 'node22'
}
```

and:

```text
Dockerfile
   ↓
FROM node:22
```

The important principle is:

> **The commands in a CI pipeline need an execution environment.**

The GitHub Actions runner provides that environment.

---

## 14. Terraform CI Quality Gate

Our workflow checks Terraform before changes proceed.

The validation flow is:

```text
Terraform Change
      │
      ↓
GitHub Actions Runner
      │
      ├── terraform fmt
      │
      ├── terraform validate
      │
      └── terraform test
             │
             ↓
        All succeed?
          /       \
        No         Yes
        ↓           ↓
      Fail        Pass
                    ↓
               Continue
```

The important principle is:

> **Terraform should only proceed when the required quality checks pass.**

---

## 15. Dev and Prod in GitHub Actions

We initially considered running Dev and Prod separately, but recognized that they perform the same Terraform operations against different directories.

We therefore used a matrix approach for the environments.

Conceptually:

```text
Terraform CI
     │
     ├── dev
     │
     └── prod
```

The workflow can execute the same validation logic against both environments without duplicating the entire workflow.

This is similar to:

```text
Same job definition
       │
       ├── dev
       └── prod
```

### Key Lesson

A matrix is useful when:

```text
Same process
+
Different input
```

is required.

---

## 16. Terraform Module Testing in CI

Our Terraform module contains:

```text
terraform/modules/file/
├── file.tftest.hcl
├── main.tf
├── outputs.tf
└── variables.tf
```

The GitHub Actions workflow also validates and tests the module.

This means our CI checks both:

```text
Environment configurations
```

and:

```text
Reusable module behaviour
```

before considering the Terraform changes successful.

---

## 17. Successful GitHub Actions Run

After committing the workflow, we pushed the changes to GitHub.

The workflow successfully completed:

```text
Terraform File Module   ✅
Terraform prod          ✅
Terraform dev           ✅
```

The GitHub Actions run reported:

```text
Status: Success
```

The complete run took approximately:

```text
14 seconds
```

This confirmed that our Terraform validation pipeline was functioning correctly.

---

## 18. Multiple GitHub Actions Workflows

We also discussed what happens when we eventually have multiple workflows.

GitHub Actions workflows live under:

```text
.github/workflows/
```

For example:

```text
.github/
└── workflows/
    ├── terraform.yml
    ├── docker.yml
    ├── application.yml
    └── deployment.yml
```

Each workflow is an independent YAML file.

This allows the repository to have different CI/CD processes for different parts of the project.

For example:

```text
Terraform change
      ↓
terraform.yml

Docker/application change
      ↓
docker.yml
```

Path filters can determine when a particular workflow should run.

---

## 19. GitHub Actions and Jenkins

Our GitHub Actions introduction builds directly on what we already learned with Jenkins.

The underlying CI/CD principle remains the same:

```text
Code Change
    ↓
CI Environment
    ↓
Tools
    ↓
Quality Checks
    ↓
Success / Failure
```

The main difference is the platform and configuration syntax.

### Jenkins

```text
Jenkins
   ↓
Jenkinsfile
   ↓
Pipeline
```

### GitHub Actions

```text
GitHub
   ↓
.github/workflows/*.yml
   ↓
Workflow
   ↓
Runner
```

The Jenkins experience therefore makes GitHub Actions easier to understand because the **CI/CD concepts are transferable**.

---

## Useful Commands

### List workspaces

```bash
terraform workspace list
```

### Show current workspace

```bash
terraform workspace show
```

### Create workspace

```bash
terraform workspace new <name>
```

### Switch workspace

```bash
terraform workspace select <name>
```

### List state resources

```bash
terraform state list
```

### Pull remote state

```bash
terraform state pull
```

### Reconfigure backend

```bash
terraform init -reconfigure
```

### Check Terraform plan

```bash
terraform plan
```

### Apply Terraform configuration

```bash
terraform apply
```

---

## Key Mental Model

```text
                  Terraform
                      │
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
 Configuration      State         CI/CD
        │             │             │
        ↓             ↓             ↓
    Modules       S3 Backend    GitHub Actions
        │             │             │
        ↓             ↓             ↓
  Dev / Prod     Workspaces       Runner
                      │             │
                      ↓             ↓
               State Isolation   Validation
                      │             │
                      └──────┬──────┘
                             ↓
                      Safer Terraform
```

The key distinction is:

> **Terraform configuration defines what should exist, state records what Terraform manages, the backend determines where that state lives, workspaces isolate state, locking protects shared state, and CI validates changes automatically.**

---

## Session Outcome

Successfully configured and worked with Terraform remote state using S3.

We:

* Reinitialized Terraform against the S3 backend.
* Understood the local-to-remote state migration prompt.
* Created and switched between `default` and `dev` workspaces.
* Demonstrated workspace state isolation.
* Planned and applied infrastructure in the `dev` workspace.
* Compared state between `dev` and `default`.
* Used `terraform state pull` to inspect remote state.
* Verified S3 state locking with `use_lockfile = true`.
* Introduced GitHub Actions CI.
* Configured path-based Terraform workflow triggering.
* Used GitHub Actions runners to execute Terraform commands.
* Validated Dev and Prod through the workflow.
* Ran Terraform module testing through CI.
* Successfully pushed and passed the GitHub Actions pipeline.

**Session 12 complete.** ✅

