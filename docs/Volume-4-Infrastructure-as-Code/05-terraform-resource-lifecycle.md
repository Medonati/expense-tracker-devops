# 05 — Terraform Resource Lifecycle

## Objective

Understand how Terraform reacts when a managed resource changes or is removed from the configuration.

---

## 1. Inspecting a Resource

We used:

```bash
terraform state list
````

to see the resources currently tracked by Terraform.

```text
local_file.experiment
```

We then used:

```bash
terraform state show local_file.experiment
```

to inspect the details Terraform had recorded for that specific resource.

This showed attributes such as:

```text
content
filename
id
content hashes
file permissions
```

---

## 2. Changing a Resource

We changed the file content from:

```text
Terraform is managing this file.
```

to:

```text
Terraform has changed this file.
```

Running:

```bash
terraform plan
```

showed:

```text
-/+ destroy and then create replacement
```

Terraform also showed:

```text
content = "Terraform is managing this file." -> "Terraform has changed this file." # forces replacement
```

The provider's resource behavior determines whether an attribute can be changed in place or requires replacement.

---

## 3. Applying the Replacement

We applied the plan:

```bash
terraform apply
```

Terraform destroyed the previous resource and created the replacement.

We then verified:

```bash
cat hello-variable.txt
```

and:

```bash
terraform state show local_file.experiment
```

Both showed the new content.

Finally:

```bash
terraform plan
```

returned:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 4. Removing a Resource from Configuration

We temporarily removed the `local_file.experiment` resource from `main.tf`.

When we first ran:

```bash
terraform plan
```

Terraform returned an error because `outputs.tf` still referenced:

```text
local_file.experiment.filename
```

After removing the output reference, Terraform generated this plan:

```text
local_file.experiment will be destroyed
(because local_file.experiment is not in configuration)
```

The plan showed:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

This demonstrated that removing a managed resource from the configuration normally causes Terraform to plan its destruction.

We did **not** apply this destructive plan.

Instead, we restored the resource and output configuration.

Terraform then returned:

```text
No changes. Your infrastructure matches the configuration.
```

---

## Key Lessons

### Configuration represents desired state

Terraform uses the configuration to determine what infrastructure should exist.

### State records Terraform's knowledge

Terraform keeps information about managed resources in its state.

### Changes can cause different actions

Depending on the resource and attribute being changed, Terraform may:

* Make no changes
* Update a resource
* Replace a resource

### Removing a resource from configuration

If a resource is still tracked in state but is removed from the configuration, Terraform normally plans to destroy it.

### Always review the plan

A plan showing:

```text
1 to destroy
```

should be reviewed carefully before applying it.

---

## Useful Commands

```bash
terraform plan
terraform apply
terraform state list
terraform state show <resource>
```

---

## Session Outcome

We demonstrated how Terraform detects resource changes, determines when replacement is required, and plans the destruction of resources that are no longer declared in the configuration.

We also verified the final state with `terraform plan` and confirmed:

```text
No changes.
```
