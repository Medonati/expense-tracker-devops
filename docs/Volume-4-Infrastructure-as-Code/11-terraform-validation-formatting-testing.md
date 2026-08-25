# 11 — Terraform Validation, Formatting & Testing

## Objective

Understand how Terraform formatting, validation, and native testing help ensure Terraform configurations are clean, valid, and behave as expected before deployment.

---

## 1. Terraform Formatting

We used:

```bash
terraform fmt -check
```

Initially, Terraform returned:

```text
main.tf
```

This indicated that `main.tf` was not correctly formatted.

We then ran:

```bash
terraform fmt main.tf
```

and verified again:

```bash
terraform fmt -check
```

This time, Terraform returned nothing, confirming that the configuration was properly formatted.

### Key Concept

```text
terraform fmt
        ↓
Formats Terraform files

terraform fmt -check
        ↓
Checks formatting without modifying files
```

`terraform fmt -check` is useful in CI/CD because it can detect improperly formatted Terraform code before it proceeds through the pipeline.

---

## 2. Terraform Validation

We ran:

```bash
terraform validate
```

and received:

```text
Success! The configuration is valid.
```

`terraform validate` checks whether the Terraform configuration is syntactically valid and internally consistent.

It does not apply infrastructure or modify Terraform state.

---

## 3. JSON Validation

We also used:

```bash
terraform validate -json
```

A successful validation returned:

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 0,
  "diagnostics": []
}
```

The JSON format is useful for automation because CI/CD systems can consume structured validation results.

---

## 4. Deliberate Validation Failure

We intentionally changed:

```hcl
var.filename
```

to:

```hcl
var.nonexistent
```

Terraform returned:

```text
Error: Reference to undeclared input variable
```

This demonstrated that Terraform validation can detect references to variables that have not been declared.

We restored the configuration and confirmed:

```bash
terraform fmt -check
terraform validate
```

both passed successfully.

### Key Lesson

A configuration can fail validation without Terraform making any infrastructure changes.

---

## 5. Terraform Native Testing

Terraform provides a native testing framework using `.tftest.hcl` files.

We created:

```text
modules/file/
├── file.tftest.hcl
├── main.tf
├── outputs.tf
└── variables.tf
```

Our test supplied:

```hcl
variables {
  filename = "test-hello.txt"
  content  = "Terraform testing works!"
}
```

and asserted:

```hcl
assert {
  condition     = output.filename == "${path.root}/test-hello.txt"
  error_message = "The module did not create the expected filename."
}
```

We initialized the test configuration with:

```bash
terraform init
```

and executed:

```bash
terraform test
```

The result was:

```text
Success! 1 passed, 0 failed.
```

---

## 6. Testing a Failure

We deliberately changed the expected filename to:

```text
./wrong-name.txt
```

while the module actually produced:

```text
./test-hello.txt
```

Terraform reported:

```text
Error: Test assertion failed
```

and showed the difference between the actual and expected values.

The test returned:

```text
Failure! 0 passed, 1 failed.
```

We restored the correct assertion and confirmed the test passed again.

### Key Concept

```text
terraform validate
        ↓
"Is the configuration valid?"

terraform test
        ↓
"Does the configuration behave as expected?"
```

---

## 7. Test Teardown

After running the successful test, we checked the module directory.

The temporary:

```text
test-hello.txt
```

file was not present.

Terraform had shown:

```text
file.tftest.hcl... tearing down
```

This confirmed that the test resources were cleaned up after execution.

---

## 8. Local Terraform Quality Gate

We finished the session by successfully running:

```bash
terraform fmt -check
terraform validate
terraform test
```

The workflow can be represented as:

```text
Terraform Code
      │
      ↓
terraform fmt -check
      │
      ↓
terraform validate
      │
      ↓
terraform test
      │
      ↓
Ready for Plan
```

This provides a basic quality gate before Terraform proceeds to planning and deployment.

---

## Useful Commands

### Format Terraform files

```bash
terraform fmt
```

### Check formatting

```bash
terraform fmt -check
```

### Validate configuration

```bash
terraform validate
```

### Validate with machine-readable output

```bash
terraform validate -json
```

### Run Terraform tests

```bash
terraform test
```

### Initialize test/module dependencies

```bash
terraform init
```

---

## Key Mental Model

```text
             Terraform Quality
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
       fmt       validate      test
        │           │           │
   Formatting   Validity    Behaviour
        │           │           │
        └───────────┼───────────┘
                    ↓
               terraform plan
```

The key distinction is:

> **Formatting checks how the code is written, validation checks whether the configuration is valid, and testing checks whether the configuration behaves as expected.**

---

## Session Outcome

Successfully used Terraform formatting, validation, JSON diagnostics, and native testing.

We deliberately created both a validation failure and a test assertion failure, observed Terraform's diagnostics, restored the configuration, and completed the local quality gate successfully.

**Session 11 complete.**
