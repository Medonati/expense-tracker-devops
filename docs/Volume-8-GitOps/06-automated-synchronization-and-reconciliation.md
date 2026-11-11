# Volume 8 — Milestone 6: Automated Synchronization and Reconciliation

## 1. Overview

**Milestone:** 06 — Automated Synchronization and Reconciliation  
**Volume:** 8 — GitOps  
**Project:** Expense Tracker DevOps  
**Platform:** Kubernetes (Minikube)  
**GitOps Controller:** Argo CD  
**Status:** Practical implementation completed; documentation prepared for review.

## 2. Objective

The objective of this milestone was to understand and implement automated synchronization and reconciliation using Argo CD.

The work focused on understanding how Argo CD continuously compares the desired state declared in Git with the actual state of Kubernetes resources.

We explored three important capabilities:

- Automated synchronization.
- Resource pruning.
- Self-healing.

The exercises used the existing Expense Tracker Kubernetes application and a dedicated ConfigMap created specifically for controlled GitOps experiments.

## 3. Initial Application Configuration

The existing Argo CD Application was:

- Application name: `expense-tracker`
- Namespace: `argocd`
- Repository: `https://github.com/Medonati/expense-tracker-devops`
- Target revision: `HEAD`
- Repository path: `kubernetes`
- Destination: `https://kubernetes.default.svc`
- Destination namespace: `default`

Initially, the Application did not have an automated synchronization policy configured.

## 4. Enabling Automated Synchronization

### 4.1 Understanding automated synchronization

Traditionally, when a developer pushes a change to Git, an administrator may need to manually initiate synchronization through the Argo CD dashboard or CLI.

Automated synchronization removes this manual step.

Argo CD monitors the configured Git repository and automatically attempts to synchronize changes when the desired state differs from the live Kubernetes state.

### 4.2 Implementation

We enabled automated synchronization using:

```bash
kubectl patch application expense-tracker \
  -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}'
```

The configuration was verified:

```yaml
syncPolicy:
  automated:
    enabled: true
```

At this stage, neither pruning nor self-healing was enabled.

### 4.3 Practical automatic synchronization experiment

We used the existing frontend Service manifest:

`kubernetes/frontend/service.yaml`

The following annotation was already present:

```yaml
gitops-demo: "milestone-5-change-detection"
```

We introduced an additional annotation:

```yaml
gitops-demo-auto-sync: "milestone-6-automatic-reconciliation"
```

The change was committed and pushed to GitHub.

Argo CD detected the new Git revision and automatically synchronized the application without requiring a manual Sync operation.

The dashboard subsequently displayed:

- Sync Status: Synced
- Health Status: Healthy
- Auto Sync: Enabled
- OutOfSync resources: 0

The live Service was inspected to confirm that the new annotation had been applied.

**Outcome:** Automated synchronization was successfully demonstrated.

## 5. Understanding Resource Pruning

### 5.1 What is pruning?

Pruning is the process of deleting Kubernetes resources that were previously managed by Argo CD but are no longer included in the desired state generated from Git.

For example, if a ConfigMap is removed from the Kustomize resource list, Argo CD can identify that the resource is no longer desired.

However, automated synchronization alone does not automatically authorize deletion of resources removed from Git.

The `prune` option controls this behaviour.

### 5.2 Creating a dedicated pruning demonstration resource

We created:

`kubernetes/gitops-pruning-demo.yaml`

Manifest:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitops-pruning-demo
  namespace: default
data:
  purpose: "Argo CD pruning demonstration"
  milestone: "Volume 8 Milestone 6"
```

We added the manifest to:

`kubernetes/kustomization.yaml`

```yaml
resources:
  - backend/configmap.yaml
  - backend/deployment.yaml
  - backend/service.yaml
  - frontend/deployment.yaml
  - frontend/service.yaml
  - frontend/ingress.yaml
  - mongodb/deployment.yaml
  - mongodb/service.yaml
  - mongodb/pvc.yaml
  - gitops-pruning-demo.yaml
```

We validated the Kustomize output:

```bash
kubectl kustomize kubernetes/
```

The changes were committed and pushed.

After synchronization, we confirmed that the ConfigMap existed:

```bash
kubectl get configmap gitops-pruning-demo -n default
```

The resource was successfully created.

### 5.3 Testing removal without pruning

We removed only the following entry from `kubernetes/kustomization.yaml`:

```yaml
- gitops-pruning-demo.yaml
```

The ConfigMap manifest itself was deliberately retained.

After committing and pushing the change, Argo CD detected that the desired state had changed.

The dashboard showed:

- Sync Status: OutOfSync
- Health Status: Healthy
- Auto Sync: Enabled
- Target revision: `4b8c2de`
- Last successful sync revision: `8b97f29`

The ConfigMap still existed in Kubernetes.

Verification:

```bash
kubectl get configmap gitops-pruning-demo -n default
```

The resource was returned successfully.

**Observation:** Automated synchronization was enabled, but pruning was disabled. Therefore, Argo CD detected the removed resource but did not delete it.

### 5.4 Enabling pruning

We enabled pruning while retaining automated synchronization:

```bash
kubectl patch application expense-tracker \
  -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":true}}}}'
```

Argo CD automatically deleted the demonstration ConfigMap.

Verification:

```bash
kubectl get configmap gitops-pruning-demo -n default
```

Result:

```text
Error from server (NotFound): configmaps "gitops-pruning-demo" not found
```

The dashboard subsequently showed:

- Sync Status: Synced
- Health Status: Healthy
- Target revision: `4b8c2de`
- Last successful sync revision: `4b8c2de`
- OutOfSync resources: 0

**Outcome:** Automated pruning was successfully demonstrated.

## 6. Understanding Resource Restoration

After demonstrating pruning, we restored the ConfigMap to the desired state.

We re-added:

```yaml
- gitops-pruning-demo.yaml
```

to the resources list in `kubernetes/kustomization.yaml`.

The change was committed and pushed:

```bash
git add kubernetes/kustomization.yaml
git commit -m "gitops: restore pruning demo configmap"
git push
```

Argo CD detected the change and automatically recreated the ConfigMap.

Verification:

```bash
kubectl get configmap gitops-pruning-demo -n default
```

Observed result:

```text
NAME                  DATA   AGE
gitops-pruning-demo   2      58s
```

This demonstrated that restoring a resource declaration in Git allows Argo CD to recreate the resource.

**Important lesson:** Git stores the desired configuration, not a backup of a resource's previous runtime state or data. Recreating a deleted resource does not necessarily restore its former runtime data.

## 7. Understanding Self-Healing

### 7.1 What is self-healing?

Self-healing is an Argo CD capability that allows the controller to correct live Kubernetes configuration changes that conflict with the desired state stored in Git.

This is particularly important because administrators can still modify Kubernetes resources directly using `kubectl`.

Such modifications can introduce configuration drift.

When self-healing is enabled, Argo CD can automatically restore the Git-defined configuration.

### 7.2 Restoring a safe configuration before testing

After the pruning experiment, we disabled pruning:

```bash
kubectl patch application expense-tracker \
  -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false}}}}'
```

We verified:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: false
```

This ensured that pruning was disabled before proceeding.

### 7.3 Inspecting the demonstration ConfigMap

We inspected the live resource:

```bash
kubectl get configmap gitops-pruning-demo -n default -o yaml
```

The original data was:

```yaml
data:
  milestone: Volume 8 Milestone 6
  purpose: Argo CD pruning demonstration
```

### 7.4 Introducing configuration drift

We manually modified the live ConfigMap using:

```bash
kubectl patch configmap gitops-pruning-demo \
  -n default \
  --type merge \
  -p '{"data":{"purpose":"Manually modified outside Git"}}'
```

We verified that Kubernetes accepted the change.

The live value became:

```yaml
data:
  milestone: Volume 8 Milestone 6
  purpose: Manually modified outside Git
```

However, Git still contained:

```yaml
purpose: Argo CD pruning demonstration
```

This created configuration drift between Git and the live Kubernetes environment.

### 7.5 Enabling self-healing

We enabled self-healing:

```bash
kubectl patch application expense-tracker \
  -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false,"selfHeal":true}}}}'
```

Argo CD detected the drift and automatically restored the original value.

Verification:

```bash
kubectl get configmap gitops-pruning-demo -n default -o yaml
```

The value returned to:

```yaml
data:
  milestone: Volume 8 Milestone 6
  purpose: Argo CD pruning demonstration
```

The resource version also changed from `83241` to `83343`, confirming that Kubernetes recorded another update.

**Outcome:** Argo CD self-healing was successfully demonstrated without manually restoring the ConfigMap.

## 8. Final Application Configuration

The final synchronization policy was verified:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: false
    selfHeal: true
```

The final application status was:

```text
NAME              SYNC STATUS   HEALTH STATUS
expense-tracker   Synced        Healthy
```

This confirms that the application was synchronized and healthy at the end of the experiment.

### Why pruning was left disabled

Although pruning was demonstrated successfully, we disabled it again after the experiment.

This was intentional.

The final lab configuration retains automated synchronization and self-healing without allowing automatic deletion of resources removed from Git.

## 9. Additional Concepts Covered

### 9.1 Synchronization failures

Automated synchronization does not guarantee that every deployment will succeed.

Synchronization can fail because of:

- Invalid Kubernetes manifests.
- Unavailable container images.
- Missing dependencies.
- Kubernetes API validation errors.
- Resource constraints or other deployment problems.

Argo CD reports synchronization failures through the Application's status and operation information.

### 9.2 Retry policies

Argo CD supports configurable synchronization retry behaviour.

A retry policy can define:

- `limit`: Maximum number of retry attempts.
- `duration`: Initial delay between attempts.
- `factor`: Multiplier for exponential backoff.
- `maxDuration`: Maximum backoff delay.

Example configuration studied:

```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

This was a learning example only. We did not apply a custom retry policy to the Expense Tracker Application.

### 9.3 Synchronization options

We also examined synchronization options that customize how Argo CD applies Kubernetes resources.

Examples studied include:

| Option | Purpose |
|---|---|
| `CreateNamespace=true` | Creates the destination namespace if it does not exist. |
| `ServerSideApply=true` | Uses Kubernetes server-side apply. |
| `PruneLast=true` | Prunes resources as a final synchronization step. |
| `Replace=true` | Uses replace/create operations instead of apply. |

We inspected the Application configuration and found no explicitly configured `syncOptions`.

No synchronization options were added during this milestone.

## 10. Important Engineering Lessons

### 10.1 Automated synchronization is not the same as pruning

Automated synchronization applies changes to the desired state.

Pruning controls whether resources removed from the desired state are deleted.

These are separate behaviours.

### 10.2 Configuration drift can happen outside Git

A Kubernetes administrator can modify resources directly.

Without self-healing, such modifications can remain in the cluster even when they conflict with Git.

### 10.3 Self-healing reinforces Git as the source of truth

When self-healing is enabled, Argo CD automatically corrects live changes that conflict with the desired configuration.

This reinforces the GitOps practice of making configuration changes through Git.

### 10.4 GitOps automation does not eliminate deployment failures

Argo CD automates reconciliation, but Kubernetes can still reject invalid configurations or fail to run workloads.

Automation must be accompanied by monitoring, health verification and troubleshooting.

### 10.5 Resource deletion requires caution

Pruning can be powerful, but it can also delete resources that are no longer declared in Git.

For production environments, teams should carefully consider pruning policies, resource ownership, persistence and recovery procedures.

## 11. Practical Commands Reference

| Purpose | Command |
|---|---|
| Inspect Application | `kubectl get application expense-tracker -n argocd -o yaml` |
| Check Application health | `kubectl get application expense-tracker -n argocd` |
| Enable automated sync | `kubectl patch application expense-tracker -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}'` |
| Enable pruning | `kubectl patch application expense-tracker -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":true}}}}'` |
| Disable pruning | `kubectl patch application expense-tracker -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false}}}}'` |
| Enable self-healing | `kubectl patch application expense-tracker -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":false,"selfHeal":true}}}}'` |
| Inspect ConfigMap | `kubectl get configmap gitops-pruning-demo -n default -o yaml` |
| Patch ConfigMap | `kubectl patch configmap gitops-pruning-demo -n default --type merge -p '{"data":{"purpose":"Manually modified outside Git"}}'` |
| Validate Kustomize | `kubectl kustomize kubernetes/` |
| Inspect sync options | `kubectl get application expense-tracker -n argocd -o yaml \| grep -A 10 "syncOptions"` |

## 12. Milestone Outcome

Milestone 6 successfully demonstrated the core automated synchronization and reconciliation capabilities of Argo CD.

The practical implementation established that:

- Git changes can automatically trigger Kubernetes synchronization.
- Pruning can automatically delete resources removed from the desired state.
- Resources can be recreated when their declarations are restored in Git.
- Self-healing can automatically correct configuration drift introduced through direct Kubernetes modifications.
- Argo CD reports synchronization and health status independently.

The final application configuration was verified as:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: false
    selfHeal: true
```

Final application status:

```text
expense-tracker   Synced   Healthy
```

**Milestone 6 — Automated Synchronization and Reconciliation: Practical implementation completed.**

**Next milestone:** Milestone 7 — Drift Detection and Recovery.