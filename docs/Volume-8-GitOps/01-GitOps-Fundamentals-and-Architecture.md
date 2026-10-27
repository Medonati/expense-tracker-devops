# Milestone 01 — GitOps Fundamentals and Architecture

## 1. Objective

Understand the GitOps operating model, the relationship between desired and actual state, the reconciliation loop, and how GitOps complements an existing CI/CD pipeline.

## 2. What Is GitOps?

GitOps is an approach to managing application deployments and infrastructure where Git stores the desired configuration and automated controllers work to reconcile the live environment with that configuration.

The core model is:

```text
Git
 ↓
Desired State
 ↓
GitOps Controller
 ↓
Infrastructure / Kubernetes
 ↓
Reconciliation and Verification
```

Git provides a version-controlled record of the intended state. The controller compares that intent with the live environment and acts according to its synchronization configuration.

## 3. Desired State and Actual State

**Desired state** describes how the application should be configured. For example, a Kubernetes Deployment manifest may declare three backend replicas using a particular container image version.

**Actual state** describes what is currently running in the Kubernetes cluster.

When the desired and actual states differ, configuration drift exists.

## 4. Reconciliation

Reconciliation is the process of comparing the desired configuration with the live state and working to bring them into alignment.

For example, if Git declares three backend replicas but the live Deployment has one, a GitOps controller can detect the difference.

Automatic correction depends on the controller's configuration and the type of change. Detecting drift does not, by itself, guarantee automatic recovery.

## 5. Introduction to Argo CD

Argo CD is a GitOps continuous delivery tool for Kubernetes.

It connects a Git repository containing Kubernetes configuration to a target cluster. It can report synchronization status and application health and, when configured, synchronize resources from Git.

Important concepts:

- **Synced:** The managed live resources match the desired configuration according to Argo CD's comparison.
- **OutOfSync:** The live resources differ from the desired configuration.
- **Healthy / Degraded:** Health assessments describe the condition of the managed application resources; they are distinct from synchronization status.
- **Automatic synchronization and self-healing:** Configuration options that influence whether and how Argo CD applies changes and corrects certain forms of drift.

Argo CD does not replace Kubernetes, build container images, or guarantee successful application startup.

## 6. CI/CD and GitOps

The planned Expense Tracker workflow separates image delivery from deployment reconciliation.

1. A developer changes application code.
2. Jenkins tests the code, builds a container image, and publishes it to Amazon ECR.
3. The deployment configuration in Git is updated to reference the intended image version.
4. Argo CD observes the configuration and reconciles Kubernetes according to its settings.
5. The resulting synchronization status and workload health are verified.

Publishing a new image to ECR does not, by itself, update the Kubernetes Deployment. An explicit configuration update or a separately configured image automation mechanism is required.

## 7. Failure Handling and Rollback

Argo CD provides synchronization and health visibility, but an unhealthy deployment is not necessarily rolled back automatically.

Recovery may require investigating the failure, correcting the configuration, or reverting the Git change to a previously known-good version.

A production workflow should also consider rollout strategies, application health checks, alerting, permissions, and incident response procedures.

## 8. Acceptance Criteria

The conceptual learning objectives for this milestone are considered satisfied when the learner can:

- Explain GitOps and the role of Git as the source of truth.
- Distinguish desired state from actual state.
- Explain reconciliation and configuration drift.
- Describe how Jenkins, ECR, Git, Argo CD, and Kubernetes fit together.
- Distinguish synchronization status from application health.
- Explain why drift detection does not always result in automatic correction.
- Explain why failed deployments may require a separate rollback or recovery process.

## 9. Learning Evidence

The learner correctly explained the following concepts during the guided discussion:

- A GitOps controller can restore the declared replica count when automatic synchronization and self-healing are appropriately configured.
- Jenkins builds and publishes images, while the deployment configuration in Git identifies the intended image version.
- OutOfSync indicates a difference between the desired and live configuration; it does not necessarily mean the application is unavailable.
- When automatic correction is not enabled, detecting drift does not necessarily change the live Deployment.

This evidence reflects conceptual learning and discussion, not a completed hands-on Argo CD implementation.

## 10. Scope and Limitations

No Argo CD installation, repository connection, synchronization test, drift-recovery test, or production deployment has been performed as part of this milestone.

Those practical exercises will be completed in later milestones using the Expense Tracker project and Minikube, subject to environment verification.

## 11. Outcome

The foundational GitOps concepts have been covered and discussed. The conceptual acceptance criteria have been met through guided explanation and learner responses.

The milestone documentation must be saved, reviewed, and committed according to the mentorship workflow. Practical GitOps implementation and verification remain outstanding and are not claimed as completed here.
