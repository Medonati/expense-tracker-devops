# 03 — Terraform Outputs

## Objective

Understand how Terraform outputs expose useful information from managed resources.

---

## 1. Why Outputs?

Terraform manages infrastructure and often knows useful values about the resources it creates.

Instead of manually inspecting the infrastructure to find a value, we can define an output to expose it.

For example:

```text
Terraform
   ↓
AWS EC2
   ↓
Public IP
   ↓
Terraform Output
````

Outputs become especially useful when working with cloud infrastructure.

---

## 2. Creating an Output

Our `local_file` resource already has a filename:

```hcl
resource "local_file" "experiment" {
  filename = "${path.module}/${var.filename}"
  content  = "Terraform is managing this file."
}
```

We created `outputs.tf`:

```hcl
output "filename" {
  description = "The name of the file managed by Terraform"
  value       = local_file.experiment.filename
}
```

This tells Terraform to expose the filename as an output.

---

## 3. Plan and Apply

Running:

```bash
terraform plan
```

showed:

```text
Changes to Outputs:
  + filename = "./hello-variable.txt"
```

Terraform also explained that saving the output would not change the real infrastructure.

We then ran:

```bash
terraform apply
```

The result was:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

filename = "./hello-variable.txt"
```

This demonstrated that adding an output does not necessarily modify the infrastructure.

---

## 4. Retrieving Outputs

We can retrieve all outputs with:

```bash
terraform output
```

We can retrieve a specific output with:

```bash
terraform output filename
```

Our output was:

```text
./hello-variable.txt
```

---

## Key Lesson

Outputs provide a deliberate way to expose useful values from Terraform-managed resources.

A simple mental model:

```text
Variables → information going into Terraform

Outputs → useful information coming out of Terraform
```

Outputs become much more useful with cloud resources.

For example:

```text
EC2
 ↓
Public IP
 ↓
Terraform Output
 ↓
terraform output
```

This allows us to retrieve important infrastructure values without manually searching through the cloud console.

---

## Useful Commands

```bash
terraform plan
terraform apply
terraform output
terraform output <output_name>
```

---

## Session Outcome

We created and used a Terraform output to expose the filename of our managed resource.

The experiment confirmed that outputs can be added and saved to Terraform state without changing the underlying infrastructure.