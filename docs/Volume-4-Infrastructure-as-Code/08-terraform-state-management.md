# 08 — Terraform State Management

## Objective

Understand how to inspect, modify, and safely manage Terraform state.

---

## 1. Inspecting State

To see resources currently tracked by Terraform:

```bash
terraform state list
````

To inspect a specific resource:

```bash
terraform state show <resource>
```

Example:

```bash
terraform state show module.file.local_file.this
```

---

## 2. Terraform State Pull

To retrieve the current state:

```bash
terraform state pull
```

With our local backend, this showed essentially the same state information as:

```bash
head -20 terraform.tfstate
```

The difference becomes more useful when using a remote backend because the state may not exist as a local file.

---

## 3. Moving a Resource in State

When we moved our resource into a module, its address changed:

```text
local_file.experiment
```

to:

```text
module.file.local_file.this
```

Terraform initially planned to destroy and recreate the resource.

Instead, we migrated the state address:

```bash
terraform state mv local_file.experiment module.file.local_file.this
```

Terraform reported:

```text
Successfully moved 1 object(s).
```

After making sure the configuration still described the same infrastructure:

```bash
terraform plan
```

returned:

```text
No changes. Your infrastructure matches the configuration.
```

This allowed us to refactor the configuration without recreating the real file.

---

## 4. Removing a Resource from State

We used:

```bash
terraform state rm data.local_file.existing_file
```

Terraform removed the data source from state:

```text
Removed data.local_file.existing_file
Successfully removed 1 resource instance(s).
```

The real file remained unchanged.

Because the data source was still present in the configuration, the next `terraform plan` read it again:

```text
data.local_file.existing_file: Reading...
data.local_file.existing_file: Read complete
```

and returned:

```text
No changes.
```

### Important distinction

```text
terraform state rm
    ↓
Remove Terraform's state record
    ↓
Does not directly destroy the real object
```

---

## 5. State Backups

Our local Terraform directory contained:

```text
terraform.tfstate
terraform.tfstate.backup
terraform.tfstate.*.backup
```

The current state is stored in:

```text
terraform.tfstate
```

Backup files can contain previous versions of the state and may be useful during recovery.

State should be treated as important data and should not be manually edited as part of normal Terraform operations.

---

## 6. State Metadata

We inspected the state file and saw fields such as:

```json
{
  "version": 4,
  "terraform_version": "1.15.8",
  "serial": 11,
  "lineage": "..."
}
```

### Important fields

`version`

The Terraform state file format version.

`terraform_version`

The Terraform version that last wrote the state.

`serial`

A state version/change counter.

`lineage`

An identifier associated with the state lineage.

---

## 7. Important State Commands

```bash
terraform state list
terraform state show <resource>
terraform state pull
terraform state mv <old> <new>
terraform state rm <resource>
```

---

## Key Lesson

Terraform state maintains Terraform's knowledge of managed infrastructure.

State commands allow us to inspect and carefully modify that relationship.

```text
State
  ↓
Inspect
  ├── state list
  ├── state show
  └── state pull

Manage
  ├── state mv
  └── state rm
```

State should be treated as important operational data and handled carefully.

---

## Session Outcome

We inspected Terraform state, moved a resource address during a module refactor, removed a data source from state, examined state backups and metadata, and verified our configuration with `terraform plan`.

Final result:

```text
No changes. Your infrastructure matches the configuration.
```