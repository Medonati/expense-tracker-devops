# 02 — Terraform Variables & Variable Values

## Objective

Understand why Terraform variables are useful, how variables separate infrastructure definitions from values, and how Terraform can receive variable values through a `terraform.tfvars` file.

---

## 1. The Problem with Hardcoded Values

Our Session 1 configuration contained a hardcoded filename:

```hcl
resource "local_file" "experiment" {
  filename = "${path.module}/hello.txt"
  content  = "Terraform is managing this file."
}
````

If the filename needed to change, we would have to modify the resource definition itself.

This becomes less flexible and increases the risk of errors when values need to change repeatedly.

The problem we wanted to solve was:

> How can a value change without rewriting the resource definition?

---

## 2. Terraform Variables

We introduced a variable to separate the value from the resource definition.

A variable was declared in `variables.tf`:

```hcl
variable "filename" {
  description = "Name of the file Terraform should manage"
  type        = string
}
```

The resource was then changed to use the variable:

```hcl
resource "local_file" "experiment" {
  filename = "${path.module}/${var.filename}"
  content  = "Terraform is managing this file."
}
```

The relationship became:

```text
variable declaration
        ↓
     var.filename
        ↓
resource uses the variable
```

---

## 3. Variable Declaration vs Variable Value

An important distinction was established:

### Variable declaration

```hcl
variable "filename" {
  type = string
}
```

This tells Terraform:

> A variable named `filename` exists and expects a string.

It does not provide the value.

### Variable value

A value such as:

```text
hello-variable.txt
```

provides the actual value Terraform should use.

Therefore:

> Declaring a variable and providing a value are two separate things.

---

## 4. What Happens When a Required Variable Has No Value?

After declaring the variable and connecting it to the resource, we ran:

```bash
terraform plan
```

without providing a value.

Terraform prompted:

```text
var.filename
  Name of the file Terraform should manage

  Enter a value:
```

This demonstrated that Terraform requires a value for the variable when no value has been supplied.

We then supplied:

```text
hello-variable.txt
```

Terraform used that value when generating the plan.

---

## 5. `.tf` Files in the Same Directory

During the experiment, we initially assumed that Terraform might ask which `.tf` file should be planned because the directory contained both:

```text
main.tf
variables.tf
```

We verified that this is not how Terraform works.

Terraform treats `.tf` files in the same working directory as part of the same configuration.

Conceptually:

```text
terraform-state-lab/
├── main.tf
└── variables.tf
        ↓
One Terraform configuration
```

The filenames allow us to organize the configuration, but Terraform evaluates the configuration in the working directory rather than treating each `.tf` file as a separate Terraform program.

---

## 6. Supplying Variable Values with `terraform.tfvars`

Typing the variable value interactively is not convenient, especially for automation.

We created:

```text
terraform.tfvars
```

with:

```hcl
filename = "hello-variable.txt"
```

Terraform automatically recognized the conventional filename when we ran:

```bash
terraform plan
```

This time Terraform did not prompt for the value.

The relationship became:

```text
variables.tf
      ↓
declares var.filename
      ↑
      │ value
      │
terraform.tfvars
      ↓
filename = "hello-variable.txt"
```

This demonstrated that:

> `variables.tf` declares the variable, while `terraform.tfvars` provides its value.

---

## 7. Variable-Driven Infrastructure Change

Before using the variable, the managed resource was:

```text
./hello.txt
```

After supplying:

```text
filename = "hello-variable.txt"
```

Terraform generated a plan showing:

```text
filename = "./hello.txt" -> "./hello-variable.txt"
```

Terraform indicated:

```text
-/+ destroy and then create replacement
```

and:

```text
Plan: 1 to add, 0 to change, 1 to destroy.
```

The `local_file` resource therefore had to be replaced because changing its filename forces replacement.

---

## 8. Applying the Variable Change

We reviewed the plan and ran:

```bash
terraform apply
```

Terraform performed:

```text
Destroy old resource
        ↓
Create replacement
```

The result was:

```text
hello-variable.txt
```

with the expected content:

```text
Terraform is managing this file.
```

Terraform continued to manage:

```text
local_file.experiment
```

---

## 9. Final Verification

We verified the resource with:

```bash
terraform state list
```

which returned:

```text
local_file.experiment
```

We then ran:

```bash
terraform plan
```

Terraform returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that the variable-driven configuration and the actual resource were aligned.

---

## 10. Why Variables Are Useful

The key lesson from the experiment was that variables separate the infrastructure definition from values that may change.

Without a variable:

```hcl
filename = "${path.module}/hello.txt"
```

Changing the filename requires modifying the resource definition.

With a variable:

```hcl
filename = "${path.module}/${var.filename}"
```

the resource definition can remain unchanged while the value can be changed separately.

For example:

```text
Development
    ↓
hello-dev.txt

Staging
    ↓
hello-staging.txt

Production
    ↓
hello-prod.txt
```

This makes the configuration more flexible and reduces the risk of errors from repeatedly editing infrastructure definitions.

---

## Key Lessons

### 1. Variables separate definitions from values

The resource can define how infrastructure is structured while variable values can be supplied separately.

### 2. A variable declaration does not provide a value

`variables.tf` defines the expected input, but a value must still be supplied.

### 3. Terraform can prompt for missing variable values

If a required variable has no value, Terraform can request it interactively.

### 4. `terraform.tfvars` can provide variable values

Terraform automatically recognizes the conventional `terraform.tfvars` filename.

### 5. `.tf` files in one directory form one configuration

Terraform evaluates the configuration in the working directory rather than planning individual `.tf` files independently.

### 6. Variable changes can change infrastructure

Changing the variable value changed the desired filename and caused Terraform to replace the `local_file` resource.

---

## Commands Practiced

```bash
terraform plan
terraform apply
terraform state list
```

---

## Session Outcome

We moved from hardcoded configuration values to configurable values using Terraform variables.

The final relationship was:

```text
variables.tf
      ↓
Variable declaration
      ↓
terraform.tfvars
      ↓
Variable value
      ↓
main.tf
      ↓
Resource
      ↓
Terraform plan
      ↓
Apply
      ↓
Infrastructure
```

The central mental model established in this session is:

> Terraform variables allow infrastructure definitions to remain reusable while values can be supplied separately and changed without repeatedly modifying the resource definition.