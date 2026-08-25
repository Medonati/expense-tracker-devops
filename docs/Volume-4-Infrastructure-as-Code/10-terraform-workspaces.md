# 10 — Terraform Workspaces & Environments

## Objective

Understand how Terraform workspaces provide separate state instances while using the same Terraform configuration, and how separate environment directories can provide stronger configuration and state isolation.

---

## 1. What Is a Terraform Workspace?

A Terraform workspace allows the same Terraform configuration to use a separate state.

Conceptually:

```text
Same configuration
       │
       ├── default → State A
       │
       ├── dev     → State B
       │
       └── prod    → State C
```

The configuration is shared, while the state is isolated between workspaces.

---

## 2. Viewing and Creating Workspaces

We used:

```bash
terraform workspace show
terraform workspace list
terraform workspace new dev
terraform workspace select default
```

We created a `dev` workspace and verified that it initially had an empty state while the `default` workspace retained its existing state.

---

## 3. Shared Configuration

Workspaces do not create separate copies of the Terraform configuration.

Both workspaces use the same:

```text
main.tf
variables.tf
outputs.tf
modules/
```

The difference is the state being used.

```text
              Same Configuration
                     │
          ┌──────────┴──────────┐
          ↓                     ↓
       default                 dev
          │                     │
          ↓                     ↓
     Default State           Dev State
```

Therefore:

> Configuration is shared, while state is isolated.

---

## 4. Workspace State with S3

Our S3 backend uses:

```hcl
backend "s3" {
  bucket       = "terraform-devops-state-medon-2026"
  key          = "terraform-state-lab/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
```

The default workspace state exists at:

```text
terraform-state-lab/terraform.tfstate
```

The `dev` workspace state appeared at:

```text
env:/dev/terraform-state-lab/terraform.tfstate
```

We verified this using:

```bash
aws s3 ls s3://terraform-devops-state-medon-2026/ --recursive
```

---

## 5. Environment Directories

We then moved from the workspace experiment to a separate environment structure:

```text
terraform-state-lab/
├── environments/
│   ├── dev/
│   └── prod/
│
└── modules/
    └── file/
```

Each environment is a separate Terraform root configuration.

Both environments reuse the same module:

```text
modules/file/
```

but maintain their own configuration and state.

---

## 6. DEV Environment

The DEV environment contains:

```text
environments/dev/
├── main.tf
├── variables.tf
├── terraform.tfvars
└── outputs.tf
```

Its backend uses:

```hcl
key = "terraform-state-lab/dev/terraform.tfstate"
```

DEV manages:

```text
dev-hello.txt
```

We ran:

```bash
terraform init
terraform plan
terraform apply
```

and verified its state in S3:

```bash
aws s3 ls \
  s3://terraform-devops-state-medon-2026/terraform-state-lab/dev/
```

---

## 7. PROD Environment

The PROD environment contains:

```text
environments/prod/
├── main.tf
├── variables.tf
├── terraform.tfvars
└── outputs.tf
```

Its backend uses:

```hcl
key = "terraform-state-lab/prod/terraform.tfstate"
```

PROD manages:

```text
prod-hello.txt
```

We applied the configuration and verified its independent state in S3:

```bash
aws s3 ls \
  s3://terraform-devops-state-medon-2026/terraform-state-lab/prod/
```

---

## 8. Environment State Isolation

The resulting S3 structure is:

```text
terraform-devops-state-medon-2026/
└── terraform-state-lab/
    ├── terraform.tfstate
    ├── dev/
    │   └── terraform.tfstate
    └── prod/
        └── terraform.tfstate
```

DEV and PROD therefore have independent state.

```text
DEV
Configuration
     ↓
DEV State
     ↓
dev-hello.txt
```

```text
PROD
Configuration
     ↓
PROD State
     ↓
prod-hello.txt
```

---

## 9. Verifying Environment Isolation

We changed only the DEV configuration:

```hcl
content = "Terraform DEV configuration has been updated."
```

Terraform detected the change and proposed:

```text
-/+ destroy and then create replacement
```

We then ran `terraform plan` from PROD.

The result was:

```text
No changes.
```

This demonstrated that the DEV configuration and state do not affect the PROD environment.

We restored the DEV configuration and verified:

```text
No changes.
```

---

## 10. Workspaces vs Environment Directories

### Workspaces

```text
Same configuration
       +
Different state
```

### Environment directories

```text
Separate configuration
       +
Separate state
       +
Shared reusable modules
```

Workspaces are useful when the same configuration is intentionally reused across different state instances.

Separate environment directories provide stronger configuration-level separation between environments.

---

## Key Mental Model

```text
                 Shared Module
                modules/file/
                     │
             ┌───────┴───────┐
             ↓               ↓
            DEV             PROD
             │               │
        DEV config       PROD config
             │               │
        DEV state        PROD state
             │               │
      dev-hello.txt   prod-hello.txt
```

The key distinction is:

> A workspace separates state while reusing the same configuration. An environment directory separates configuration and state while allowing reusable modules to be shared.

---

## Useful Commands

### Show current workspace

```bash
terraform workspace show
```

### List workspaces

```bash
terraform workspace list
```

### Create a workspace

```bash
terraform workspace new <name>
```

### Switch workspace

```bash
terraform workspace select <name>
```

### List resources in the current state

```bash
terraform state list
```

### Retrieve current state

```bash
terraform state pull
```

### Verify configuration

```bash
terraform plan
```

### Verify environment state in S3

```bash
aws s3 ls \
  s3://<bucket-name>/<environment-path>/
```

---

## Session Outcome

Successfully demonstrated Terraform workspace state isolation and implemented separate DEV and PROD environment configurations using a shared reusable module and independent S3 state.

Verified that DEV and PROD maintain separate configuration, resources, and state, and that a configuration change in DEV does not affect PROD.

**Session 10 complete.**