# 03 — Container Image Security & Vulnerability Scanning

## Objective

Learn how to scan Docker artifacts for known vulnerabilities, interpret findings, and perform a controlled dependency remediation.

* Basic image scan
* Vulnerability-only scan with timeout
* Saving scan output
* Checking the summary
* Filtering important findings

## Vulnerability Scanning

Docker Scout was unavailable in the lab, so Trivy was installed and used to scan Docker images.

The initial vulnerability scan was performed with:

```bash
trivy image medonati/expense-tracker-backend:1.0.3
````

The first scan timed out during analysis. We then limited the scanner to vulnerabilities and increased the timeout:

```bash
trivy image --scanners vuln --timeout 10m \
  medonati/expense-tracker-backend:1.0.3
```

Scan output was saved for easier analysis:

```bash
trivy image --scanners vuln --timeout 10m \
  medonati/expense-tracker-backend:1.0.3 \
  | tee trivy-scan.txt
```

The same approach was used to scan the optimized and remediated images.

The optimized image used:

```text
node:22-slim
npm install --omit=dev
```

and was reduced from approximately:

```text
423MB → 93MB
```

The OS vulnerability findings also dropped significantly:

```text
3,767 → 169
```

However, the optimized image still contained vulnerable Node.js dependencies.

**Smaller does not automatically mean secure.**


## Verifying Remediation

After upgrading Mongoose, the rebuilt image was rescanned:

```bash
trivy image --scanners vuln --timeout 10m \
  expense-tracker-backend:security-remediated \
  | tee trivy-remediated.txt
````

The results changed from:

```text
102 total
45 HIGH
5 CRITICAL
```

to:

```text
94 total
42 HIGH
3 CRITICAL
```

## Dependency Investigation

Trivy identified vulnerabilities in application dependencies.

`npm ls` was used to determine whether affected packages were direct or transitive dependencies.

Example:

```text
backend
└── mongoose@7.0.3
```

Mongoose was a direct dependency.

Whereas:

```text
backend
└── jsonwebtoken@9.0.0
    └── jws@3.2.2
```

showed that JWS was a transitive dependency.

`npm outdated` was then used to evaluate available upgrade paths before making changes.

## Controlled Remediation

A CRITICAL vulnerability was identified in:

```text
mongoose@7.0.3
```

Rather than immediately moving to a newer major version, the dependency was upgraded within the existing major version:

```text
mongoose 7.0.3 → 7.8.12
```

The application tests passed:

```text
2 test suites passed
2 tests passed
```

The Docker image was rebuilt and scanned again.

The Node dependency findings changed from:

```text
102 total
45 HIGH
5 CRITICAL
```

to:

```text
94 total
42 HIGH
3 CRITICAL
```

The Mongoose vulnerability was no longer reported.

The OS findings remained unchanged because the base image was not changed during this remediation.

## Security Workflow

```text
Scan
  ↓
Understand findings
  ↓
Identify dependency
  ↓
Determine direct/transitive relationship
  ↓
Evaluate available fixes
  ↓
Upgrade deliberately
  ↓
Test application
  ↓
Rebuild image
  ↓
Rescan
```

## Key Lessons

* Vulnerability counts must be interpreted rather than blindly fixed.
* Base images contribute to the security surface of a container.
* Direct and transitive dependencies require different remediation strategies.
* `npm outdated` helps distinguish compatible updates from major-version changes.
* Security remediation should be followed by application testing and image rescanning.
* A vulnerability scan is part of an ongoing artifact lifecycle, not a one-time check.