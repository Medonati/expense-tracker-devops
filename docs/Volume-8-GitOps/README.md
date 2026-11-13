# Volume 8 — GitOps

## 1. Introduction

This volume introduces GitOps as an operational approach for managing Kubernetes application deployments through declarative configuration stored in Git.

Using the Expense Tracker application, this volume demonstrates how GitHub, Argo CD and Kubernetes work together to maintain the desired application state.

The focus was not simply on installing Argo CD. The practical work explored the principles behind GitOps, repository readiness, declarative Kubernetes configuration, automated synchronization, reconciliation, drift detection, security and the complete deployment workflow.

By the end of this volume, the Expense Tracker application was managed through an Argo CD Application connected to the GitHub repository.

## 2. Learning Objectives

The objectives of this volume were to:

- Understand GitOps principles and architecture.
- Understand Git as the source of truth for declarative infrastructure and application configuration.
- Prepare Kubernetes manifests for GitOps management.
- Install and configure Argo CD.
- Connect a Git repository to a Kubernetes cluster.
- Understand automated synchronization and reconciliation.
- Explore drift detection and recovery.
- Apply security and operational practices to a GitOps environment.
- Demonstrate an end-to-end GitOps deployment workflow.
- Document and preserve the implementation and engineering lessons.

## 3. Lab Architecture

The practical implementation used the following components:

| Component | Purpose |
|---|---|
| GitHub | Source control and desired-state repository |
| Argo CD | GitOps continuous delivery controller |
| Kubernetes | Container orchestration platform |
| Minikube | Local Kubernetes cluster |
| Expense Tracker | Application managed through GitOps |
| kubectl | Kubernetes inspection and management |
| Argo CD CLI | Argo CD application and operational management |

### GitOps Architecture

```text
        Developer
            |
            | Updates Kubernetes manifests
            v
       GitHub Repository
            |
            | Monitors repository
            v
          Argo CD
            |
            | Reconciliation
            v
      Kubernetes Cluster
            |
            v
      Expense Tracker
       /     |      \
   Frontend Backend MongoDB
```

### Application Configuration

The Argo CD Application was configured with:

```text
Application: expense-tracker

Repository:
https://github.com/Medonati/expense-tracker-devops

Target Revision:
HEAD

Manifest Path:
kubernetes

Destination:
https://kubernetes.default.svc

Namespace:
default

Sync Policy:
Automated
```

## 4. Volume 8 Milestones

This volume was completed across ten milestones.

| Milestone | Description | Status |
|---|---|---|
| 01 | GitOps Fundamentals and Architecture | Completed |
| 02 | Repository and Configuration Readiness | Completed |
| 03 | Declarative Kubernetes State | Completed |
| 04 | GitOps Tooling and Controller Installation | Completed |
| 05 | Connect Git to Kubernetes | Completed |
| 06 | Automated Synchronization and Reconciliation | Completed |
| 07 | Drift Detection and Recovery | Completed |
| 08 | GitOps Security and Operational Practices | Completed |
| 09 | End-to-End GitOps Workflow | Completed |
| 10 | Documentation, Evidence and Volume Closure | Completed |

## 5. Key Implementation and Practical Outcomes

### 5.1 Argo CD Installation and Configuration

Argo CD was installed in the Minikube environment and its dashboard was made accessible through the lab's networking configuration.

The Argo CD CLI was also installed and verified.

### 5.2 Git Repository Integration

The Expense Tracker GitHub repository was connected to Argo CD.

Argo CD was configured to monitor the `kubernetes` directory and deploy its manifests to the local Kubernetes cluster.

The repository is public, so the lab did not require repository authentication credentials.

### 5.3 Automated Synchronization

Automated synchronization was configured for the Expense Tracker application.

The observed synchronization policy was:

```json
{
  "automated": {
    "enabled": true,
    "prune": false,
    "selfHeal": true
  }
}
```

This configuration enabled automated synchronization and self-healing while leaving automated pruning disabled.

### 5.4 Drift Detection and Recovery

The drift detection exercises explored the difference between the desired state stored in Git and the live state of Kubernetes resources.

The practical work demonstrated how Argo CD identifies differences and how reconciliation restores the desired configuration.

### 5.5 Security and Operational Practices

Security exercises included:

- Changing the initial Argo CD administrator password.
- Removing the bootstrap administrator Secret after password rotation.
- Creating a local developer account.
- Configuring application-level RBAC permissions.
- Testing permitted and denied developer actions.
- Restricting the default AppProject to the required repository and destination.
- Inspecting Kubernetes Secret references without exposing their values.
- Reviewing automated synchronization, pruning and self-healing settings.

The AppProject and RBAC restrictions were applied and verified in the live lab. They should not be interpreted as Git-managed configuration unless their manifests are subsequently added to the repository.

### 5.6 End-to-End GitOps Workflow

A controlled change was made to:

`kubernetes/frontend/deployment.yaml`

The frontend pod-template label was changed from:

```yaml
rollout-experiment: "m08"
```

to:

```yaml
rollout-experiment: "m09"
```

The change was committed and pushed to GitHub.

Argo CD detected and synchronized the updated configuration.

The observed Argo CD status was:

```text
Sync Status:    Synced to HEAD (7ea33b9)
Health Status:  Healthy
```

The live Kubernetes Deployment was inspected and returned:

```json
{
  "app": "frontend",
  "rollout-experiment": "m09"
}
```

The rollout completed successfully:

```text
deployment "frontend" successfully rolled out
```

Both frontend replicas were subsequently verified as Ready and Running, with the new `m09` label.

This completed the practical demonstration of the GitOps lifecycle from Git to Kubernetes.

## 6. Important Engineering Lessons

### Git is the source of truth

Desired application configuration should be maintained in version control rather than relying on undocumented manual changes to live resources.

### Declarative configuration enables reconciliation

GitOps controllers continuously compare the desired state with the live environment and work to reconcile differences.

### Synchronization and health are different

A successful synchronization does not automatically guarantee application health. Deployment status, pod readiness and application behaviour must also be verified.

### Security must be applied at multiple levels

GitOps security involves more than protecting repository access. It also includes administrator security, RBAC, AppProject restrictions, Kubernetes Secrets and operational controls.

### Evidence matters

A successful command is not sufficient by itself. The implementation should be verified using actual resource states, controller status and deployment outcomes.

### Production practices require additional consideration

The local Minikube environment demonstrates GitOps principles and operational practices. It does not, by itself, establish production readiness.

Production deployments require additional consideration of availability, secret management, access control, monitoring, disaster recovery and operational resilience.

## 7. Documentation Index

The detailed milestone documentation is maintained in this directory:

```text
Volume-8-GitOps/
│
├── 01-GitOps-Fundamentals-and-Architecture.md
├── 02-Repository-and-Configuration-Readiness.md
├── 03-Declarative-Kubernetes-State.md
├── 04-GitOps-Tooling-and-Controller-Installation.md
├── 05-Connect-Git-to-Kubernetes.md
├── 06-Automated-Synchronization-and-Reconciliation.md
├── 07-GitOps-Drift-Detection-and-Recovery.md
├── 08-GitOps-Security-and-Operational-Practices.md
├── 09-End-to-End-GitOps-Workflow.md
└── README.md
```

The README provides the overall volume summary, while the individual milestone documents preserve the detailed implementation, commands, observations and engineering lessons.

## 8. Volume Outcome

**Volume 8 — GitOps: Completed.**

The Expense Tracker application was successfully integrated with Argo CD and managed through a declarative GitOps workflow.

The practical exercises established an understanding of GitOps architecture, automated synchronization, reconciliation, drift detection, access control and end-to-end deployment verification.

Most importantly, the volume demonstrated how a change made in Git can be detected by Argo CD, applied to Kubernetes and independently verified in the running application environment.

The completed work provides the foundation for progressing from GitOps fundamentals toward a more integrated and production-like DevOps delivery pipeline.

---

**Next Stage:** Volume 9 — Production-Like DevOps Pipeline.