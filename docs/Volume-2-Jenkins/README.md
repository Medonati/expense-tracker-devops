# Volume 2 – Jenkins CI

## Overview

This volume documents my journey of learning Jenkins as a Continuous Integration (CI) platform. The focus is on understanding how Jenkins automates software builds, how pipelines are designed, and how to troubleshoot common CI issues.

Unlike traditional tutorials, this documentation captures both the implementation and the engineering decisions made throughout the learning process.

---

## What I Learned

* Jenkins architecture and core components
* Continuous Integration (CI) fundamentals
* Pipeline Jobs vs Freestyle Jobs
* Jenkins Tool Management
* Pipeline as Code concepts
* Building my first CI pipeline
* Reading and troubleshooting pipeline logs

---

## Pipeline Overview

```text
Developer Push
      │
      ▼
GitHub Repository
      │
      ▼
Jenkins Pipeline
      │
      ├── Checkout Source
      ├── Install Dependencies
      └── Verify Environment
              │
              ▼
        Successful Build
```

---

## Repository Structure

```text
Volume-2-Jenkins/
├── README.md
├── first-pipeline.md
├── troubleshooting.md
└── images/
```

---

## Progress

* ✅ Jenkins Installation
* ✅ Jenkins Administration
* ✅ Jenkins Tool Management
* ✅ First Pipeline
* ✅ First Successful Build
* ⏳ Jenkinsfile (Pipeline from SCM)
* ⏳ Automated Testing
* ⏳ Docker Build Stage

---

## Key Takeaways

* CI is about validating code automatically before integration.
* Automation should be based on a process that is already understood manually.
* Jenkins plugins extend Jenkins capabilities.
* Build failures are opportunities to improve the pipeline.
* Pipeline configuration should eventually be stored alongside the application code.
