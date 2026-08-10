# Chapter 02 – Automated Testing

## Overview

After establishing the initial Continuous Integration pipeline, the next objective was to improve software quality by introducing automated validation and testing.

This chapter documents the evolution of the Jenkins pipeline from simply verifying the build environment to validating application source code and executing automated integration tests.

---

# Objectives

The objectives of this milestone were to:

* Integrate application validation into the Jenkins pipeline.
* Add automated testing using Jest.
* Ensure code quality checks execute before artifact creation.
* Prevent broken code from progressing through the pipeline.

---

# Pipeline Evolution

The pipeline expanded from basic dependency installation into a quality assurance workflow.

```text
Install Dependencies
        │
Verify Environment
        │
Validate Source
        │
Run Tests
```

Each stage introduced an additional quality gate before allowing the build to continue.

---

# Source Validation

Application validation was implemented using a dedicated npm script.

The validation stage ensures that the application structure and startup configuration are verified before running automated tests.

This stage acts as an early quality checkpoint, allowing configuration issues to be detected before additional pipeline work is performed.

---

# Automated Testing

Jest was introduced as the project's testing framework.

Integration tests were created for the application's health and readiness endpoints.

The pipeline executes:

```text
npm test
```

during every build, ensuring application functionality is verified automatically.

---

# Health and Readiness Testing

Two application endpoints were introduced:

* **Health Endpoint** – Confirms that the application process is running.
* **Readiness Endpoint** – Confirms that the application is ready to serve requests.

These endpoints provide valuable information for both automated testing and future container orchestration platforms such as Kubernetes.

---

# Challenges Encountered

Several issues were encountered while implementing automated testing.

These included:

* Invalid package.json configuration.
* Empty Jest test files.
* Test file placement.
* Application export structure.
* Environment-specific configuration.

Each issue was resolved before expanding the pipeline further.

---

# Results

At the completion of this milestone, Jenkins successfully:

* Installed project dependencies.
* Verified the build environment.
* Validated application source code.
* Executed automated integration tests.
* Reported test results as part of every pipeline execution.

This significantly improved confidence in every build produced by the pipeline.

---

# Lessons Learned

* Automated testing should become part of every Continuous Integration pipeline.
* Small, focused tests provide fast feedback during development.
* Validation should occur before packaging software into deployable artifacts.
* Health and readiness endpoints support both testing and future production deployments.

---

# Conclusion

Introducing automated testing transformed the Jenkins pipeline from a simple build process into a quality assurance workflow. Every successful build now represents software that has been validated and tested automatically, establishing a reliable foundation for Docker artifact creation and future Continuous Delivery stages.
