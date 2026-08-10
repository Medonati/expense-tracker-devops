# Pipeline Evolution

This document records the major milestones in the evolution of the Jenkins CI pipeline.

The goal is to document **what changed**, **why it changed**, and **what was learned**. It complements the `Jenkinsfile`, which always represents the latest working version of the pipeline.

---

# Version 1 – First Pipeline

## Change

Created the first Declarative Jenkins Pipeline using a pipeline script stored in the Jenkins UI.

### Pipeline Stages

* Checkout Source
* Install Dependencies
* Verify Environment

### Learning

* Introduction to Declarative Pipelines.
* Understanding stages and steps.
* Running `npm install` from Jenkins.
* Verifying the Node.js environment.

### Outcome

Successfully executed the first CI pipeline.

---

# Version 2 – Pipeline as Code

## Change

Moved the pipeline from the Jenkins UI into a `Jenkinsfile` stored in the project repository.

### Why

* Version control the pipeline.
* Keep CI configuration together with application code.
* Make the pipeline portable across Jenkins servers.
* Follow modern CI/CD best practices.

### Outcome

The repository became the single source of truth for the pipeline.

---

# Version 3 – Pipeline from SCM

## Change

Changed the Jenkins job from **Pipeline Script** to **Pipeline Script from SCM**.

### Why

Allow Jenkins to automatically retrieve the pipeline definition from GitHub.

### Outcome

The pipeline is now executed directly from the repository instead of being maintained in the Jenkins UI.

---

# Version 4 – Use `checkout scm`

## Change

Replaced the hardcoded Git checkout with Jenkins SCM.

```diff
-stage('Checkout Source') {
-    steps {
-        git branch: 'main',
-            url: 'https://github.com/Medonati/expense-tracker-devops.git'
-    }
-}
+stage('Checkout Source') {
+    steps {
+        checkout scm
+    }
+}
```

### Why

Avoid hardcoding the repository URL and branch inside the pipeline.

Allow Jenkins to reuse the SCM configuration already defined in the job.

### Learning

Learned how Jenkins exposes the `scm` object when using **Pipeline Script from SCM**.

### Outcome

Pipeline executed successfully using Jenkins SCM.

---

# Version 5 – Remove Redundant Checkout *(Next Update)*

> This section will be completed after the next refactor.

## Planned Change

Remove the explicit checkout stage.

```diff
-stage('Checkout Source') {
-    steps {
-        checkout scm
-    }
-}
```

### Reason

During testing, it was observed that Jenkins already performs a repository checkout before executing the `Jenkinsfile` when using **Pipeline Script from SCM**.

Keeping an additional checkout stage results in the repository being checked out twice.

### Expected Outcome

* Cleaner pipeline.
* Eliminate redundant repository checkout.
* Improve pipeline readability.
* Rely on Jenkins' default Declarative Pipeline behavior.


## Version 6 – Application Validation

### Change

Added an Application Validation stage and stage-level post actions.

```diff
+stage('Application Validation') {
+    steps {
+        dir('app/backend') {
+            sh 'npm run validate'
+        }
+    }
+
+    post {
+        success {
+            echo '✅ Application validation passed.'
+        }
+
+        failure {
+            echo '❌ Application validation failed.'
+        }
+    }
+}
```

### Why

Introduce the first CI quality gate and provide clear feedback in the Jenkins console output.

### Outcome

The pipeline now validates the application syntax and clearly reports whether validation succeeded or failed.

---

# Lessons Learned

* Store pipelines as code instead of maintaining them in the Jenkins UI.
* Use SCM integration to keep pipeline configuration with the project.
* Prefer understanding **why** a change is made rather than simply applying it.
* Remove unnecessary steps once their purpose has been understood.
* Continuously refactor pipelines to improve clarity and maintainability.

---

# Documentation Rule

Only record milestones that introduce a new concept, architectural decision, or significant improvement.

Avoid documenting minor edits or cosmetic changes.
