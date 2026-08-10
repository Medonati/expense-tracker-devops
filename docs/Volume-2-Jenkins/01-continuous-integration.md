# Chapter 01 – Continuous Integration

## Overview

Continuous Integration (CI) is a software development practice where code changes are frequently integrated into a shared repository and automatically validated through a build pipeline. The objective is to identify integration issues early, improve software quality, and provide rapid feedback to developers.

This chapter documents the implementation of my first Jenkins Continuous Integration pipeline within the Expense Tracker DevOps project. Rather than focusing only on configuration, it explains the engineering decisions that shaped the pipeline and the lessons learned throughout the implementation.

---

# Objectives

The objectives of this milestone were to:

* Install and configure Jenkins.
* Understand Jenkins architecture and core components.
* Connect Jenkins to the GitHub repository.
* Create a Pipeline as Code using a Jenkinsfile.
* Execute the first successful Continuous Integration pipeline.

---

# Jenkins Architecture

The Jenkins server was deployed inside the DevOps lab environment running on Vagrant.

The pipeline retrieves application source code from GitHub and executes each stage defined in the Jenkinsfile.

```text
Developer
      │
      ▼
GitHub Repository
      │
      ▼
Jenkins Pipeline
      │
      ├── Install Dependencies
      ├── Verify Environment
      └── Successful Build
```

---

# Pipeline as Code

Instead of configuring jobs manually through the Jenkins interface, the pipeline was defined inside a **Jenkinsfile** stored alongside the application source code.

This approach provides several advantages:

* Version control
* Reproducibility
* Easier collaboration
* Infrastructure as Code principles

Every pipeline modification becomes part of the project's Git history.

---

# Initial Pipeline Stages

The first pipeline focused on validating that the application could build successfully.

The implemented stages were:

* Install Dependencies
* Verify Environment

At this stage, the pipeline confirmed that the application could install required packages and that the build environment contained the required Node.js and npm versions.

---

# Challenges Encountered

Several configuration issues were encountered while connecting Jenkins to the project.

These included:

* Jenkins tool configuration
* Node.js installation through Jenkins
* Repository checkout configuration
* Pipeline syntax validation

Each issue was investigated individually before expanding the pipeline further.

---

# Results

At the end of this milestone, Jenkins successfully:

* Retrieved the latest application source code.
* Installed project dependencies.
* Verified the build environment.
* Completed the pipeline successfully.

This established the foundation for future CI improvements.

---

# Lessons Learned

* Continuous Integration begins with automation of repeatable tasks.
* Pipelines should be built incrementally.
* Jenkinsfiles provide a maintainable and version-controlled pipeline definition.
* Early automation reduces manual verification and improves consistency.

---

# Conclusion

The first successful Jenkins pipeline demonstrated how Continuous Integration can automate the software build process. Although simple, it provided the foundation upon which validation, testing, artifact creation, and future deployment stages would later be built.
