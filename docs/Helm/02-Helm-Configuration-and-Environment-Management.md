# Helm Configuration and Release Management

**Document:** 02  
**Module:** Supplemental Helm Learning  
**Repository:** `expense-tracker-devops`  
**Chart:** `helm/expense-tracker`  
**Previous document:** `01-Helm-Chart-Creation-and-Rendering.md`

---

## 1. Introduction

Following the completion of Helm chart creation and rendering, this milestone focused on using Helm to manage application configuration, install releases, perform upgrades, inspect release history, and recover from changes through rollback.

The practical exercises used the existing Expense Tracker Helm chart. We also examined how Helm compares with Kustomize and how Helm integrates with Argo CD for GitOps-based deployment.

The purpose was to understand Helm beyond chart creation: how it manages the lifecycle of Kubernetes applications.

## 2. Environment-Specific Configuration

### 2.1 The problem

Applications often require different configurations depending on the environment in which they run.

For example:

- Development environments may require fewer replicas and smaller resource allocations.
- Production environments may require additional replicas, higher availability, and larger storage allocations.

Maintaining separate copies of Kubernetes manifests for every environment can introduce duplication and configuration inconsistencies.

Helm addresses this through values files.

### 2.2 Understanding Helm values files

The chart uses:

- `values.yaml` — default configuration.
- `values-dev.yaml` — development-specific configuration.
- `values-production.yaml` — production-specific configuration.

The templates reference values rather than hardcoding every configuration directly.

For example:

```yaml
replicaCount: 1
```

A deployment template can consume this value:

```yaml
spec:
  replicas: {{ .Values.backend.replicaCount }}
```

This allows the same chart to produce different Kubernetes configurations depending on the values supplied.

### 2.3 Environment-specific configuration

The development and production values files define different application configurations.

The settings covered included:

| Component | Development | Production |
|---|---:|---:|
| Frontend replicas | 1 | 3 |
| Backend replicas | 1 | 2 |
| MongoDB PVC | 1Gi | 5Gi |

These values illustrate how one chart can support multiple environments without duplicating its templates.

### 2.4 Values precedence

Helm allows users to override default chart values.

The general precedence, from lower to higher priority, is:

1. Chart defaults in `values.yaml`.
2. Values supplied through a values file using `-f`.
3. Values supplied through `--set`.

When multiple values files are supplied, later files override earlier files for matching keys.

Example:

```bash
helm template expense-tracker-dev helm/expense-tracker \
  -f helm/expense-tracker/values-dev.yaml
```

Production rendering:

```bash
helm template expense-tracker-production helm/expense-tracker \
  -f helm/expense-tracker/values-production.yaml
```

These commands render the Kubernetes manifests using the selected environment configuration without installing the application.

### 2.5 Important lesson

A Helm chart separates application structure from environment-specific configuration.

This makes the chart reusable while allowing each environment to have its own settings.

---

## 3. Helm Installation and Release Management

### 3.1 Understanding a Helm release

A chart is the package containing the application templates and default configuration.

A release is an installed instance of that chart.

This distinction is important because the same chart can be installed multiple times, potentially with different release names, namespaces, or values.

For the practical exercise, we used an isolated Helm release:

- **Release:** `expense-tracker-lab`
- **Namespace:** `helm-practice`
- **Chart:** `helm/expense-tracker`

This kept the Helm CLI exercise separate from the Argo CD-managed deployment.

### 3.2 Installing the chart

The installation command:

```bash
helm install expense-tracker-lab helm/expense-tracker \
  --namespace helm-practice \
  -f helm/expense-tracker/values-dev.yaml
```

The command:

- `helm install` creates a new release.
- `expense-tracker-lab` identifies the release.
- `helm/expense-tracker` specifies the chart path.
- `--namespace helm-practice` selects the Kubernetes namespace.
- `-f` supplies the development configuration.

### 3.3 Inspecting releases

List releases in a namespace:

```bash
helm list -n helm-practice
```

Inspect a particular release:

```bash
helm status expense-tracker-lab -n helm-practice
```

Retrieve the values applied to a release:

```bash
helm get values expense-tracker-lab -n helm-practice
```

Retrieve the generated Kubernetes manifests:

```bash
helm get manifest expense-tracker-lab -n helm-practice
```

These commands help administrators understand what Helm has installed and how the release is configured.

---

## 4. Helm Upgrades

### 4.1 Why upgrades are necessary

Applications change over time.

A deployment may require:

- Additional replicas.
- Updated container images.
- New environment variables.
- Changed resource allocations.
- Updated application configuration.

Helm provides the `upgrade` command to apply chart or configuration changes to an existing release.

An upgrade modifies the existing release rather than creating an entirely new release name.

### 4.2 Practical upgrade exercise

During the practical exercise, we performed two upgrades.

| Revision | Change |
|---|---|
| Revision 1 | Initial installation |
| Revision 2 | Backend replicas increased to 2 |
| Revision 3 | Backend replicas returned to 1 and frontend replicas increased to 2 |

The changes demonstrated how Helm records successive release revisions.

### 4.3 Upgrade command patterns

Increase backend replicas:

```bash
helm upgrade expense-tracker-lab helm/expense-tracker \
  --namespace helm-practice \
  -f helm/expense-tracker/values-dev.yaml \
  --set backend.replicaCount=2
```

Set backend replicas to 1 and frontend replicas to 2:

```bash
helm upgrade expense-tracker-lab helm/expense-tracker \
  --namespace helm-practice \
  -f helm/expense-tracker/values-dev.yaml \
  --set backend.replicaCount=1 \
  --set frontend.replicaCount=2
```

### 4.4 Important lesson

Helm upgrades provide a controlled way to change an application's Kubernetes configuration while maintaining the release's revision history.

---

## 5. Release History

### 5.1 Why release history matters

Every successful Helm upgrade creates a new release revision.

Keeping this history is important because it allows administrators to:

- Identify previous configurations.
- Track changes made to an application.
- Investigate unexpected deployment behaviour.
- Return to a previously working revision.

### 5.2 Inspecting release history

Command:

```bash
helm history expense-tracker-lab -n helm-practice
```

The practical exercise produced the following release progression:

| Revision | Operation | Result |
|---|---|---|
| 1 | Install | Initial release |
| 2 | Upgrade | Backend replicas set to 2 |
| 3 | Upgrade | Backend replicas set to 1; frontend replicas set to 2 |
| 4 | Rollback | Returned to revision 1 configuration |

This demonstrated that Helm maintains a record of release revisions and their operations.

### 5.3 Important lesson

Release history provides visibility into the lifecycle of an application and supports recovery when a change does not produce the expected result.

---

## 6. Helm Rollback

### 6.1 Understanding rollback

An upgrade can introduce an unwanted configuration change or cause an application to behave unexpectedly.

Helm rollback allows an administrator to return a release to a previous revision.

Rather than manually reconstructing the previous configuration, Helm uses its recorded release history.

### 6.2 Practical rollback exercise

The release had reached revision 3 after two upgrades.

We then rolled it back to revision 1.

Command:

```bash
helm rollback expense-tracker-lab 1 -n helm-practice
```

This restored the release to the configuration represented by revision 1.

The rollback itself created revision 4 in the release history.

### 6.3 Verifying rollback

Inspect release history:

```bash
helm history expense-tracker-lab -n helm-practice
```

Inspect the release:

```bash
helm status expense-tracker-lab -n helm-practice
```

Verify Kubernetes deployments:

```bash
kubectl get deployments -n helm-practice
```

Verify pods:

```bash
kubectl get pods -n helm-practice
```

### 6.4 Practical outcome

After the rollback, the workloads were verified as ready:

| Component | Ready |
|---|---:|
| Backend | 1/1 |
| Frontend | 1/1 |
| MongoDB | 1/1 |

The rollback exercise demonstrated how Helm can restore a previous release configuration and how Kubernetes resources can be checked afterwards.

### 6.5 Important lesson

Rollback is a valuable recovery mechanism, but it should not replace proper testing, monitoring, backups, or database migration planning.

Rolling back Kubernetes manifests does not automatically reverse changes made to persistent application data.

---

## 7. Helm versus Kustomize

Both Helm and Kustomize help manage Kubernetes application configurations, but they approach the problem differently.

### 7.1 Helm

Helm uses charts, templates, and values files.

It is particularly useful when:

- Applications need reusable and configurable deployment packages.
- Different environments require different configuration values.
- Releases need to be installed, upgraded, inspected, and rolled back.
- Applications need to be distributed as versioned charts.

### 7.2 Kustomize

Kustomize manages Kubernetes manifests through a base-and-overlay approach.

It is useful when:

- Existing Kubernetes YAML manifests need environment-specific modifications.
- Teams want to avoid template engines.
- Development, staging, and production environments share a common base.
- Configuration differences can be expressed through patches and overlays.

### 7.3 Comparison

| Area | Helm | Kustomize |
|---|---|---|
| Main approach | Templates and values | Bases and overlays |
| Configuration | Values files | Patches and overlays |
| Packaging | Charts | Manifest directories |
| Release management | Built-in release lifecycle | No equivalent Helm release lifecycle |
| Upgrades | `helm upgrade` | Apply updated manifests |
| Rollback | Helm release history | Usually managed through Git or deployment tooling |
| Common use | Reusable application packaging | Customizing Kubernetes manifests |

### 7.4 Key takeaway

Helm and Kustomize solve related but different configuration problems.

Helm provides a chart and release-management model, while Kustomize provides a way to customize Kubernetes manifests.

The appropriate choice depends on the application's deployment requirements and the team's workflow.

---

## 8. Helm Integration with Argo CD

### 8.1 Why integrate Helm with Argo CD?

Helm can manage releases directly through the Helm CLI.

However, in a GitOps workflow, Argo CD can use a Helm chart stored in a Git repository as the source for deploying an application.

This allows the deployment configuration to be managed through Git.

Argo CD monitors the repository and reconciles the Kubernetes cluster with the desired configuration.

### 8.2 Existing Expense Tracker deployment

We used the existing Helm chart:

```text
helm/expense-tracker/
```

The Argo CD Application was:

```text
expense-tracker-helm
```

The deployment namespace was:

```text
helm-argocd-practice
```

This was kept separate from the standalone Helm CLI practice release.

**Important ownership distinction:**

- `expense-tracker-lab` in `helm-practice` was used for direct Helm CLI release-management exercises.
- `expense-tracker-helm` in `helm-argocd-practice` was managed by Argo CD.

We deliberately avoided installing a standalone Helm release over the Argo CD-managed application. This prevents two deployment controllers from competing to manage the same resources.

### 8.3 Verifying the Argo CD application

The application was inspected and verified using:

```bash
kubectl get applications -n argocd
```

The application status was:

```text
NAME                   SYNC STATUS   HEALTH STATUS
expense-tracker-helm   Synced        Healthy
```

### 8.4 Verifying Kubernetes workloads

The workloads were checked with:

```bash
kubectl get pods -n helm-argocd-practice
```

```bash
kubectl get deployments -n helm-argocd-practice
```

```bash
kubectl get services -n helm-argocd-practice
```

The verified deployment state was:

| Component | Ready |
|---|---:|
| Backend | 1/1 |
| Frontend | 2/2 |
| MongoDB | 1/1 |

The Argo CD Application was also confirmed as `Synced` and `Healthy`.

### 8.5 Important lesson

Helm and Argo CD can work together without requiring the Helm CLI to manage the application lifecycle directly.

In this arrangement:

- Helm provides the chart and templates.
- Git stores the desired deployment configuration.
- Argo CD monitors Git and reconciles the cluster.
- Kubernetes runs the resulting workloads.

This combines Helm's application packaging capabilities with Argo CD's GitOps reconciliation model.

---

## 9. Important Helm Commands Reference

The following commands summarize the main operations covered in this milestone.

| Purpose | Command |
|---|---|
| Lint a chart | `helm lint helm/expense-tracker` |
| Render development values | `helm template expense-tracker-dev helm/expense-tracker -f helm/expense-tracker/values-dev.yaml` |
| Render production values | `helm template expense-tracker-production helm/expense-tracker -f helm/expense-tracker/values-production.yaml` |
| List releases | `helm list -n helm-practice` |
| Install a release | `helm install expense-tracker-lab helm/expense-tracker -n helm-practice -f helm/expense-tracker/values-dev.yaml` |
| Inspect release | `helm status expense-tracker-lab -n helm-practice` |
| Inspect release values | `helm get values expense-tracker-lab -n helm-practice` |
| Inspect release manifests | `helm get manifest expense-tracker-lab -n helm-practice` |
| Upgrade a release | `helm upgrade expense-tracker-lab helm/expense-tracker -n helm-practice -f helm/expense-tracker/values-dev.yaml` |
| View release history | `helm history expense-tracker-lab -n helm-practice` |
| Roll back a release | `helm rollback expense-tracker-lab 1 -n helm-practice` |
| Verify pods | `kubectl get pods -n helm-practice` |
| Verify deployments | `kubectl get deployments -n helm-practice` |
| Inspect Argo CD applications | `kubectl get applications -n argocd` |

---

## 10. Lessons Learned

The practical work established the following:

1. A single Helm chart can support multiple environments through separate values files.
2. Helm releases represent installed instances of charts.
3. Helm upgrades create new release revisions.
4. Release history provides visibility into previous deployments.
5. Rollback allows a release to return to an earlier revision.
6. Helm and Kustomize provide different approaches to Kubernetes configuration management.
7. Argo CD can deploy Helm charts as part of a GitOps workflow.
8. Separate deployment ownership is important when combining direct Helm CLI operations with Argo CD.

## 11. Milestone Completion Summary

The following objectives were covered:

- [x] Environment-specific values and configuration.
- [x] Helm chart installation.
- [x] Helm release management.
- [x] Helm upgrades.
- [x] Release history and revisions.
- [x] Helm rollback.
- [x] Helm versus Kustomize.
- [x] Helm integration with Argo CD.
- [x] Verification of the Argo CD-managed Expense Tracker deployment.

The standalone Helm release lifecycle was exercised using `expense-tracker-lab` in `helm-practice`, while the Argo CD-managed application remained separate in `helm-argocd-practice`.

## 12. Conclusion

This milestone moved beyond creating and rendering Helm charts to managing the lifecycle of Kubernetes applications.

Through environment-specific configuration, installation, upgrades, release history, and rollback, we explored how Helm supports repeatable application management.

We also examined how Helm differs from Kustomize and how Argo CD can use Helm charts within a GitOps workflow.

With these topics covered, the supplemental Helm learning module can proceed to final documentation review, repository updates, and release tagging before continuing to Volume 9 of the DevOps mentorship roadmap.