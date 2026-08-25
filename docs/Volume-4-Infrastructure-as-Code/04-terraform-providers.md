# 04 — Terraform Providers

## Objective

Understand what Terraform providers are, why Terraform needs them, and how providers relate to resources.

---

## 1. What Is a Provider?

Terraform is the engine that determines what infrastructure should look like.

A provider gives Terraform the ability to communicate with a specific platform or service and manage its resources.

A simple mental model:

```text
Terraform
    ↓
Provider
    ↓
Platform / Service
````

Without providers, Terraform does not have the capability to communicate with platforms such as AWS or manage their resources.

---

## 2. Required Providers

Our configuration contains:

```hcl
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}
```

This tells Terraform that the configuration requires the `hashicorp/local` provider.

The provider source identifies where the provider comes from.

---

## 3. Provider Configuration

We also have:

```hcl
provider "local" {}
```

This is the provider configuration.

The `local` provider does not require additional settings for our experiment, so the block is empty.

Provider configuration can be different depending on the platform being managed.

For example, cloud providers may require settings such as a region or authentication configuration.

---

## 4. `terraform init`

When we ran:

```bash
terraform init
```

Terraform identified the required provider and installed it:

```text
Finding latest version of hashicorp/local...
Installing hashicorp/local v2.9.0...
Installed hashicorp/local v2.9.0
```

Terraform also created:

```text
.terraform/
.terraform.lock.hcl
```

The provider plugin was stored under:

```text
.terraform/providers/
```

`terraform init` prepares the working directory and installs the provider dependencies required by the configuration.

---

## 5. Provider vs Resource

Our resource is:

```hcl
resource "local_file" "experiment" {
  filename = "${path.module}/${var.filename}"
  content  = "Terraform is managing this file."
}
```

The declaration contains:

```text
local_file
    ↓
Resource type

experiment
    ↓
Resource name
```

So:

```text
local_file.experiment
```

is the Terraform address of this resource.

The provider and resource have different roles:

```text
local
  ↓
Provider
  ↓
Provides the capability to work with local resources

local_file
  ↓
Resource type
  ↓
Defines the specific type of resource being managed
```

---

## 6. Provider Schema

We used:

```bash
terraform providers schema -json > provider-schema.json
```

This allowed us to inspect the provider's machine-readable schema.

The schema showed that `local_file` has attributes such as:

```text
content
filename
content_sha256
content_md5
...
```

It also showed that some attributes are provided as inputs while others are computed by the provider.

For example:

```text
content
    ↓
Provided to the resource

content_sha256
    ↓
Computed by the provider
```

This explains attributes we previously saw in `terraform plan` as:

```text
(known after apply)
```

---

## 7. Provider Documentation

We established that we should not guess resource syntax.

When we need to use a resource, we should check the provider documentation to understand:

* Available resource types
* Supported arguments
* Resource attributes
* Provider configuration
* Resource behavior

The provider schema is the machine-readable representation of what the provider exposes, while the documentation is the primary resource we use as humans.

---

## Useful Commands

```bash
terraform init
terraform providers
terraform providers schema -json > provider-schema.json
```

---

## Key Mental Model

```text
Terraform
    ↓
Provider
    ↓
Resource Type
    ↓
Resource Schema
    ↓
Resource Attributes
```

And:

```text
required_providers
    ↓
Which provider is required?

provider "local"
    ↓
How is the provider configured?

resource "local_file" "experiment"
    ↓
What resource should Terraform manage?
```

## Session Outcome

We learned that providers give Terraform the capability to communicate with external platforms and manage their resources.

We also learned how providers, resource types, resource names, and provider schemas fit together.

Most importantly:

> When working with Terraform, don't guess what a provider supports. Check its documentation and schema.
