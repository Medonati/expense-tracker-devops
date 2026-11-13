# Milestone 9 — End-to-End GitOps Workflow

## 1. Introduction

This milestone demonstrates the complete GitOps workflow using the Expense Tracker application, GitHub, Argo CD and Kubernetes.

The objective was to demonstrate how a change to the desired application state in Git is detected by Argo CD, synchronized with the Kubernetes cluster, and verified in the running application infrastructure.

Unlike previous milestones that focused on individual GitOps concepts and configurations, this exercise brought the components together into one practical workflow.

## 2. Lab Environment

| Component | Configuration |
|---|---|
| Application | Expense Tracker |
| Source Control | GitHub |
| Repository | `https://github.com/Medonati/expense-tracker-devops` |
| Kubernetes Manifest Path | `kubernetes` |
| Specific Manifest | `kubernetes/frontend/deployment.yaml` |
| GitOps Controller | Argo CD v3.5.6 |
| Kubernetes Environment | Minikube |
| Argo CD Application | `expense-tracker` |
| Application Namespace | `default` |
| Argo CD Namespace | `argocd` |

The Argo CD Application was configured to monitor the GitHub repository and deploy the manifests from the `kubernetes` directory to the local Kubernetes cluster.

## 3. Implementation: Controlled Git Change

To demonstrate the complete workflow without changing application functionality or introducing unnecessary infrastructure changes, a controlled modification was made to the frontend Deployment manifest.

**File:** `kubernetes/frontend/deployment.yaml`

The original pod-template label was:

```yaml
labels:
  app: frontend
  rollout-experiment: "m08"
```

It was changed to:

```yaml
labels:
  app: frontend
  rollout-experiment: "m09"
```

No other Deployment configuration was changed.

The following settings remained unchanged:

- Two frontend replicas.
- Existing frontend container image: `1.0.4`.
- Rolling update strategy.
- CPU and memory requests and limits.
- ECR image pull Secret.

### Why this change?

Kubernetes Deployment pod-template metadata is part of the desired state. Changing a pod-template label changes the Deployment's pod template and triggers a new ReplicaSet and rolling update.

This provided a visible and traceable way to demonstrate the movement of a configuration change from Git into the live Kubernetes environment.

## 4. Git Workflow

After updating the manifest, the change was reviewed using:

```bash
git diff --check

git diff -- kubernetes/frontend/deployment.yaml
```

The review confirmed that the intended label modification was the only change.

The file was then committed:

```bash
git add kubernetes/frontend/deployment.yaml

git commit -m "feat(gitops): update frontend rollout experiment label"
```

The commit was pushed to the remote GitHub repository.

The working tree was subsequently confirmed clean.

This established Git as the source of truth for the updated frontend Deployment configuration.

## 5. Argo CD Detection and Reconciliation

After the change was pushed, the Argo CD Application was inspected:

```bash
argocd app get expense-tracker
```

The relevant output was:

```text
Name:               argocd/expense-tracker
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default

Source:
- Repo:             https://github.com/Medonati/expense-tracker-devops
  Target:           HEAD
  Path:             kubernetes

Sync Policy:        Automated
Sync Status:        Synced to HEAD (7ea33b9)
Health Status:      Healthy
```

The frontend Deployment showed:

```text
apps  Deployment  default  frontend  Synced  Healthy
      deployment.apps/frontend configured
```

The other application resources were reported as unchanged.

### Observations

The output demonstrated that:

1. Argo CD was monitoring the expected GitHub repository.
2. The application was configured to track the latest repository revision (`HEAD`).
3. The application synchronized to revision `7ea33b9`.
4. The frontend Deployment was configured with the updated desired state.
5. The application remained healthy after reconciliation.

The `configured` status indicated that the frontend Deployment had been updated, while `unchanged` indicated that the other resources already matched their desired state.

## 6. Kubernetes Verification

Argo CD reporting a successful synchronization was not treated as the only proof of success. The live Kubernetes resources were inspected independently.

### 6.1 Verify the Deployment label

Command:

```bash
kubectl get deployment frontend -n default -o jsonpath='{.spec.template.metadata.labels}{"\n"}'
```

Actual output:

```json
{"app":"frontend","rollout-experiment":"m09"}
```

This confirmed that Kubernetes had received the updated pod-template label from the GitOps reconciliation process.

### 6.2 Verify the rolling update

Command:

```bash
kubectl rollout status deployment/frontend -n default
```

Actual output:

```text
deployment "frontend" successfully rolled out
```

This confirmed that Kubernetes successfully completed the frontend Deployment rolling update.

### 6.3 Verify frontend pods

Command:

```bash
kubectl get pods -n default -l app=frontend --show-labels
```

Actual output:

```text
NAME                       READY   STATUS    RESTARTS   AGE     LABELS
frontend-7cc57f6c4-9nphd   1/1     Running   0          5m43s   app=frontend,pod-template-hash=7cc57f6c4,rollout-experiment=m09
frontend-7cc57f6c4-wtlzn   1/1     Running   0          6m41s   app=frontend,pod-template-hash=7cc57f6c4,rollout-experiment=m09
```

### Observations

Both frontend pods:

- Were `1/1 Ready`.
- Had a `Running` status.
- Had zero restarts at the time of inspection.
- Carried the updated `rollout-experiment=m09` label.
- Shared the new ReplicaSet hash `7cc57f6c4`.

This provided direct evidence that the new ReplicaSet had been created and its two frontend replicas were running successfully.

## 7. End-to-End Workflow Summary

The following sequence was successfully demonstrated:

```text
Developer updates Kubernetes manifest
                 |
                 v
       Change committed locally
                 |
                 v
       Change pushed to GitHub
                 |
                 v
       Argo CD detects Git change
                 |
                 v
       Argo CD reconciles cluster
                 |
                 v
       Kubernetes Deployment updated
                 |
                 v
       New ReplicaSet created
                 |
                 v
       Rolling update completed
                 |
                 v
       Two frontend pods running
```

### Verification Results

| Verification | Result |
|---|---|
| Git manifest updated | Successful |
| Change committed and pushed | Successful |
| Git working tree clean | Confirmed |
| Argo CD synchronization | Synced |
| Argo CD application health | Healthy |
| Live Deployment label | `m09` confirmed |
| Kubernetes rollout | Successful |
| Frontend replicas | 2/2 running and ready |
| Frontend pod restarts | 0 at verification |

## 8. Engineering Lessons

### Git is the source of truth

The desired configuration was changed in Git rather than by manually editing the live Kubernetes Deployment.

This ensures that the repository remains the authoritative record of the intended application state.

### Argo CD automates reconciliation

With automated synchronization enabled, Argo CD can detect changes in the tracked repository and reconcile the cluster with the desired configuration.

### A successful sync is not the end of verification

Argo CD reporting `Synced` and `Healthy` is important, but Kubernetes resources must also be checked.

In this exercise, the live Deployment, rollout status and frontend pods were independently inspected.

### Kubernetes rolling updates

A change to the Deployment pod template created a new ReplicaSet. Kubernetes then completed the rolling update while maintaining the desired two frontend replicas.

### Traceability across the deployment lifecycle

The same change could be followed from the Git manifest to the Argo CD synchronization revision and finally to the live Kubernetes pods.

This provides a clear audit trail for application configuration changes.

## 9. Milestone Outcome

**Milestone 9 — End-to-End GitOps Workflow: Completed.**

The complete GitOps workflow was successfully demonstrated using the existing Expense Tracker application.

A controlled change was made to the frontend Deployment manifest, committed and pushed to GitHub. Argo CD detected and synchronized the change, and Kubernetes successfully applied the updated configuration.

The live Deployment contained the expected `m09` label, the rolling update completed successfully, and both frontend replicas were verified as Ready and Running.

The exercise demonstrated how Git, Argo CD and Kubernetes work together to maintain the desired application state through a declarative GitOps workflow.

**Next:** Milestone 10 — Documentation, Evidence and Volume Closure.