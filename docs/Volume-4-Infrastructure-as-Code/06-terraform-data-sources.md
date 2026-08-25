# 06 — Terraform Data Sources

## Objective

Understand how Terraform reads information about existing resources using data sources.

---

## 1. Resource vs Data Source

A resource tells Terraform:

> "I want Terraform to manage this."

A data source tells Terraform:

> "I want Terraform to read information about this."

Simple mental model:

```text
Resource
    ↓
Manage

Data Source
    ↓
Read / Look up
````

---

## 2. Creating a Data Source

We already had an existing file:

```text
hello-variable.txt
```

Instead of managing it again, we used a data source to read it:

```hcl
data "local_file" "existing_file" {
  filename = "${path.module}/hello-variable.txt"
}
```

The address of the data source is:

```text
data.local_file.existing_file
```

---

## 3. Data Sources Are Read During Plan

We ran:

```bash
terraform plan
```

Terraform showed:

```text
data.local_file.existing_file: Reading...
data.local_file.existing_file: Read complete
```

Terraform was able to read the existing file during `plan` because it needed the information to evaluate the configuration.

No infrastructure changes were required.

---

## 4. Using Data Source Values

We used the data source value in an output:

```hcl
output "existing_file_content" {
  description = "Content read from the existing file"
  value       = data.local_file.existing_file.content
}
```

The flow became:

```text
Existing file
      ↓
Data source
      ↓
Read content
      ↓
Output
      ↓
existing_file_content
```

Terraform produced:

```text
existing_file_content = "Terraform has changed this file."
```

---

## 5. Applying the Output

We ran:

```bash
terraform apply
```

Terraform reported:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The outputs were:

```text
existing_file_content = "Terraform has changed this file."
filename = "./hello-variable.txt"
```

This confirmed that the data source was used to read information without creating or changing the existing file.

---

## 6. Final Verification

We used:

```bash
terraform output
```

to retrieve the output values.

Then:

```bash
terraform plan
```

confirmed:

```text
No changes. Your infrastructure matches the configuration.
```

---

## Key Lesson

Data sources allow Terraform to read information about existing resources or objects so that the information can be used elsewhere in the configuration.

The main difference is:

```text
Resource
    ↓
Terraform manages it

Data Source
    ↓
Terraform reads it
```

---

## Useful Commands

```bash
terraform plan
terraform apply
terraform output
```

---

## Session Outcome

We used a `local_file` data source to read an existing file and exposed its content through a Terraform output.

The experiment demonstrated that Terraform can retrieve information during `plan` without creating or changing infrastructure.
