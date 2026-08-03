# First Jenkins Pipeline

## Objective

Build the backend application automatically whenever the pipeline is executed.

## Pipeline Stages

1. Checkout Source
2. Install Dependencies
3. Verify Environment

## Jenkins Features Used

* Pipeline Job
* Declarative Pipeline
* NodeJS Plugin
* Jenkins Tool Management
* Git Integration

## Node.js Management

Instead of relying on a Node.js installation available on the operating system, Jenkins was configured to manage its own Node.js installation using the **NodeJS Plugin**.

This allows the pipeline to request a specific Node.js version without depending on the machine configuration.

```groovy
tools {
    nodejs 'node22'
}
```

## Lessons Learned

* Every pipeline stage should have a single responsibility.
* Pipelines automate manual processes.
* Jenkins can provision build tools automatically.
* The first execution downloads required tools, while subsequent builds reuse the cached installation, making them much faster.

## Next Steps

* Store the pipeline in a `Jenkinsfile`.
* Configure the job to use **Pipeline script from SCM**.
* Add automated testing.
* Build a Docker image as part of the pipeline.
