# 07 — Terraform Modules and State Migration

## Objective

Understand how Terraform modules organize reusable configuration and how state can be migrated when a resource is moved into a module.

---

## 1. Why Modules?

Modules allow Terraform configuration to be packaged and reused.

Instead of copying the same configuration multiple times, we can create a reusable module.

A simple structure:

```text
Root Module
    ↓
Child Module
    ↓
Resources
````

---

## 2. Root Module and Child Module

Our root configuration contains:

```text
main.tf
variables.tf
terraform.tfvars
outputs.tf
```

We created a child module:

```text
modules/file/
├── main.tf
├── variables.tf
└── outputs.tf
```

The child module contains the resource:

```hcl
resource "local_file" "this" {
  filename = "${path.root}/${var.filename}"
  content  = var.content
}
```

---

## 3. Calling a Module

The root module calls the child module:

```hcl
module "file" {
  source = "./modules/file"

  filename = var.filename
  content  = "Terraform has changed this file."
}
```

The root module provides values to the child module.

The flow is:

```text
Root Module
    ↓
Module inputs
    ↓
Child Module
    ↓
Resource
```

---

## 4. Module Outputs

The child module exposes its resource's filename:

```hcl
output "filename" {
  value = local_file.this.filename
}
```

The root module can access the child module's output with:

```hcl
module.file.filename
```

This creates a clear boundary between the root module and the child module.

---

## 5. Resource Addresses Change

Before using the module, the resource address was:

```text
local_file.experiment
```

After moving the resource into the module, the new address became:

```text
module.file.local_file.this
```

Terraform initially planned:

```text
1 to add, 1 to destroy
```

because Terraform saw the old and new addresses as different resources.

---

## 6. Migrating the State

We did not want Terraform to destroy and recreate the existing file.

We used:

```bash
terraform state mv local_file.experiment module.file.local_file.this
```

Terraform confirmed:

```text
Successfully moved 1 object(s).
```

We then checked:

```bash
terraform state list
```

The resource was now:

```text
module.file.local_file.this
```

---

## 7. Keeping the Same Infrastructure

We also had to make sure the module configuration still described the existing resource.

We used:

```hcl
filename = "${path.root}/${var.filename}"
```

instead of:

```hcl
filename = "${path.module}/${var.filename}"
```

This kept the file at:

```text
./hello-variable.txt
```

We also kept the existing content:

```text
Terraform has changed this file.
```

After the state migration and configuration changes:

```bash
terraform plan
```

returned:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 8. Verifying the Migration

The file still existed:

```bash
cat hello-variable.txt
```

and contained:

```text
Terraform has changed this file.
```

The state now contained:

```text
data.local_file.existing_file
module.file.local_file.this
```

The old address:

```text
local_file.experiment
```

was no longer present.

---

## Key Lesson

Moving Terraform configuration can change a resource's address.

If the underlying infrastructure has not changed, we can migrate the resource's state address instead of unnecessarily destroying and recreating the resource.

```text
Old Address
    ↓
local_file.experiment
    ↓
terraform state mv
    ↓
New Address
    ↓
module.file.local_file.this
    ↓
Same Infrastructure
```

---

## Useful Commands

```bash
terraform init
terraform plan
terraform state list
terraform state show <resource>
terraform state mv <old_address> <new_address>
```

---

## Session Outcome

We created a reusable Terraform module and moved an existing resource into it without recreating the underlying file.

The experiment demonstrated how modules, resource addresses, state, and Terraform refactoring work together.
