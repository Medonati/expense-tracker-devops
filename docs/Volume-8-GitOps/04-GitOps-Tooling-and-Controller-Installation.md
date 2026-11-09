# Volume 8 — GitOps
# Milestone 4: GitOps Tooling and Controller Installation

## 1. Milestone Overview

This milestone introduced Argo CD as the GitOps continuous delivery tool for the Expense Tracker application.

The objective was to establish a connection between the GitHub repository and the existing Kubernetes cluster, allowing Argo CD to monitor the desired application configuration stored in Git and synchronize Kubernetes resources against that configuration.

We used the existing Minikube environment and installed Argo CD deployment rather than creating a new Kubernetes cluster or reinstalling Argo CD.

By the end of this milestone, the Expense Tracker application was successfully registered in Argo CD, its Kustomize configuration was recognized, and its Kubernetes resources were successfully synchronized.

### Objectives

- Understand the role of Argo CD in a GitOps workflow.
- Access and inspect the existing Argo CD installation.
- Create an Argo CD Application.
- Connect the application to the GitHub repository.
- Configure Kustomize as the manifest management tool.
- Understand the difference between application health and synchronization status.
- Investigate and resolve synchronization failures.
- Verify successful reconciliation of the application resources.

---

## 2. Environment and Architecture

| Component | Configuration |
|---|---|
| Operating environment | Vagrant Ubuntu VM |
| Kubernetes distribution | Minikube |
| Kubernetes version | v1.37.0 |
| Minikube driver | Docker |
| Argo CD version | v3.5.6 |
| Source control | GitHub |
| Configuration management | Kustomize |
| Repository | Medonati/expense-tracker-devops |
| Branch | main |
| Manifest directory | kubernetes/ |
| Destination cluster | in-cluster |
| Destination namespace | default |
| Synchronization policy | Manual |

### GitOps architecture

The workflow established in this milestone:

1. Kubernetes manifests are maintained in GitHub.
2. Argo CD connects to the repository.
3. Argo CD reads the desired configuration from the configured branch and directory.
4. Kustomize renders the Kubernetes resources.
5. Argo CD compares the desired state with the live cluster state.
6. When synchronization is initiated, Argo CD applies the required changes.
7. Argo CD reports synchronization and health status.

```text
              GitHub Repository
                     |
                     |
             Main Branch
                     |
                     v
             kubernetes/
                     |
                     v
              Kustomize
                     |
                     v
                 Argo CD
                     |
          Compare Desired State
              with Live State
                     |
                     v
             Manual Sync
                     |
                     v
             Minikube Cluster
                     |
          ---------------------
          |         |         |
       Frontend   Backend   MongoDB
```

---

## 3. Accessing the Existing Argo CD Installation

Argo CD was already installed in the Minikube cluster from earlier work.

We verified and reused the existing installation instead of reinstalling it.

The Argo CD dashboard was accessed through Kubernetes port forwarding.

### Port-forwarding command

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

**Explanation:**

- `kubectl port-forward` creates a temporary connection between the local machine and a Kubernetes service.
- `svc/argocd-server` identifies the Argo CD server service.
- `-n argocd` specifies the namespace where Argo CD is installed.
- `8081:443` maps local port 8081 to the service's HTTPS port 443.

The dashboard was accessed through:

```text
https://localhost:8081
```

The browser displayed a certificate security warning because the local Argo CD endpoint uses a certificate that is not trusted by the browser.

Port forwarding is temporary. If the terminal session is stopped, the connection is terminated. This does not uninstall Argo CD or delete its Application configuration.

---

## 4. Creating the Argo CD Application

We created a new application through the Argo CD dashboard.

The application was named:

```text
expense-tracker
```

### Application configuration

| Field | Value |
|---|---|
| Application Name | expense-tracker |
| Project | default |
| Repository URL | https://github.com/Medonati/expense-tracker-devops |
| Target Revision | HEAD |
| Path | kubernetes |
| Cluster | in-cluster |
| Namespace | default |
| Sync Policy | Manual |

The repository was configured as the source of truth.

The `kubernetes` directory was selected because it contains the application's Kubernetes deployment manifests.

### Why did we select manual synchronization?

We deliberately retained manual synchronization at this stage.

This allowed us to:

- Inspect changes before applying them.
- Understand how Argo CD identifies differences.
- Observe synchronization failures.
- Learn how reconciliation works.
- Retain control over when changes are applied.

Automated synchronization and self-healing were left for subsequent GitOps milestones.

---

## 5. Kustomize Recognition and Integration

During application creation, Argo CD automatically recognized the Kustomize configuration in the selected repository directory.

This happened because the directory contains:

```text
kubernetes/
├── kustomization.yaml
├── README.md
├── backend/
├── frontend/
└── mongodb/
```

The `kustomization.yaml` file defines the Kubernetes resources that should be rendered and managed together.

It also defines the container image versions used by the application.

### Why did we use Kustomize?

Kustomize allows us to customize and organize Kubernetes manifests without duplicating entire YAML files.

Instead of independently managing every resource, we can define a collection of resources through a single Kustomize configuration.

This also gives Argo CD a clear entry point for rendering the application's desired Kubernetes configuration.

### Kustomize validation

We previously validated the configuration locally using:

```bash
kubectl kustomize kubernetes/
```

This command renders the Kubernetes manifests defined by the Kustomize configuration.

A successful result confirms that Kubernetes can process the Kustomize directory and produce the combined manifests.

We also used the following command to validate an individual manifest against the Kubernetes API server without applying it:

```bash
kubectl apply --dry-run=server -f kubernetes/frontend/ingress.yaml
```

Observed result:

```text
ingress.networking.k8s.io/frontend-ingress unchanged (server dry run)
```

This confirmed that the Ingress manifest passed server-side validation at that time without changing the live resource.

---

## 6. Initial Synchronization and OutOfSync Status

After creating the application, Argo CD displayed the application as:

- Application Health: Healthy
- Synchronization Status: OutOfSync

This was an important distinction.

**Healthy does not necessarily mean Synced.**

Health describes the operational condition of the Kubernetes resources.

Synchronization status describes whether the live Kubernetes configuration matches the desired configuration stored in Git.

Therefore, an application can be Healthy while still being OutOfSync.

### Investigating the differences

We used the Argo CD resource tree and Diff view to inspect the differences.

The Diff view compared the desired manifests from Git with the live Kubernetes resources.

We observed differences involving:

- Argo CD tracking annotations.
- Kubernetes metadata.
- The PersistentVolumeClaim pruning protection annotation.
- Deployment replica configurations during the resource optimization work.

For example, Argo CD added tracking metadata to resources so that it could associate them with the `expense-tracker` Application.

The PersistentVolumeClaim also had the following annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
```

This annotation prevents Argo CD from automatically pruning that PVC when it is removed from the desired configuration.

It is particularly important because the MongoDB PVC stores persistent application data.

This protection is not a substitute for backups.

### Refresh versus synchronization

We also explored the difference between the Refresh and Sync operations.

**Refresh**

Refresh makes Argo CD re-evaluate the application and its resources.

It updates Argo CD's understanding of the live state and the desired state.

Refresh does not apply changes to the cluster.

**Sync**

Sync applies the desired configuration from Git to the Kubernetes cluster.

Refreshing the application alone did not resolve the OutOfSync status because actual reconciliation was still required.

---

## 7. Resource Optimization and Git State Alignment

During the milestone, we also addressed the resource constraints of our local Minikube environment.

The existing application had:

- Backend: 3 replicas.
- Frontend: 2 replicas.
- MongoDB: 1 replica.

To reduce resource consumption, we decided to reduce the backend and frontend replicas to one each.

### Backend Deployment

Original configuration:

```yaml
spec:
  replicas: 3
```

Updated configuration:

```yaml
spec:
  replicas: 1
```

File:

```text
kubernetes/backend/deployment.yaml
```

### Frontend Deployment

Original configuration:

```yaml
spec:
  replicas: 2
```

Updated configuration:

```yaml
spec:
  replicas: 1
```

File:

```text
kubernetes/frontend/deployment.yaml
```

MongoDB remained at one replica.

### Why did we update Git after scaling?

A direct Kubernetes scaling operation changes the live cluster, but it does not automatically update the manifests stored in Git.

If we had only scaled the deployments using `kubectl scale`, Git would still describe the previous replica counts.

Argo CD would therefore identify a difference between the desired and live states.

We updated the deployment manifests in Git to ensure that the desired state reflected our resource optimization.

### Verifying the replica configuration

We used:

```bash
grep -n -A4 "replicas:" kubernetes/backend/deployment.yaml kubernetes/frontend/deployment.yaml
```

The updated result confirmed:

```text
kubernetes/backend/deployment.yaml:9:  replicas: 1
kubernetes/frontend/deployment.yaml:9:  replicas: 1
```

### Reviewing the changes

Before committing, we inspected the changes:

```bash
git diff -- kubernetes/backend/deployment.yaml kubernetes/frontend/deployment.yaml
```

The diff confirmed that only the intended replica values changed.

The files were then staged and committed using the established repository workflow.

The changes were pushed to GitHub.

The repository was subsequently confirmed to be up to date with `origin/main`, with a clean working tree.

This ensured that the resource optimization was recorded in Git rather than existing only as a live cluster modification.

---

## 8. Synchronization Troubleshooting

The first synchronization attempt did not complete successfully.

The failure was associated with the Ingress resource.

### 8.1 Initial synchronization error

Argo CD reported:

```text
one or more synchronization tasks completed unsuccessfully

error when patching "/dev/shm/3960003488":

Internal error occurred: failed calling webhook
"validate.nginx.ingress.kubernetes.io":

failed to call webhook:

Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=9s":

context deadline exceeded
```

### Understanding the error

The Kubernetes API server attempted to validate the Ingress resource through the NGINX Ingress Controller admission webhook.

The webhook is responsible for validating Ingress configuration before the API server accepts it.

The request timed out, preventing the Ingress resource from being successfully synchronized.

This was not evidence that the GitHub repository or Kustomize configuration was incorrect.

It indicated a problem communicating with the admission webhook.

### 8.2 Inspecting the ingress-nginx components

We inspected the ingress-nginx resources using:

```bash
kubectl get pods,svc,endpoints -n ingress-nginx
```

The output showed:

```text
NAME                                           READY   STATUS
ingress-nginx-admission-create-7pcgx           0/1     Completed
ingress-nginx-admission-patch-t79cd            0/1     Completed
ingress-nginx-controller-d7cd8c989-bqqxx       1/1     Running
```

The controller service was available as a NodePort service.

```text
service/ingress-nginx-controller
TYPE: NodePort
PORTS: 80:32136/TCP,443:31787/TCP
```

The admission service was also present:

```text
service/ingress-nginx-controller-admission
TYPE: ClusterIP
PORTS: 443/TCP
```

The endpoints output confirmed that the controller and admission services had registered endpoints.

This showed that the controller pod and its services existed, but did not by itself prove that the admission webhook was functioning correctly.

### 8.3 Inspecting ingress-nginx controller logs

We examined the controller logs to understand the underlying problem.

The logs contained the following error:

```text
Unexpected failure reloading the backend:

exit status 1

[error] invalid PID number "" in "/tmp/nginx/nginx.pid"

nginx: [error] invalid PID number "" in "/tmp/nginx/nginx.pid"
```

The controller also reported:

```text
Dynamic reconfiguration failed:

dial tcp 127.0.0.1:10246: connect: connection refused
```

There were additional errors involving Kubernetes API communication:

```text
etcdserver: request timed out
```

and:

```text
context deadline exceeded
```

The controller subsequently logged:

```text
Backend successfully reloaded
```

It also reported:

```text
Successfully acquired lease
```

These messages indicated that the controller had experienced reload and API communication problems but later recovered some of its operations.

### 8.4 Understanding the resource and webhook relationship

The investigation showed that the Ingress synchronization failure was associated with the admission webhook's inability to respond within the expected timeout.

The controller logs also showed intermittent Kubernetes API communication problems.

We therefore avoided immediately deleting or reinstalling the ingress-nginx controller.

Instead, we inspected its resources and logs, then validated the Ingress manifest.

### 8.5 Validating the Ingress manifest

We executed:

```bash
kubectl apply --dry-run=server -f kubernetes/frontend/ingress.yaml
```

The result was:

```text
ingress.networking.k8s.io/frontend-ingress unchanged (server dry run)
```

This confirmed that the Kubernetes API server accepted the manifest during the server-side dry run.

It did not change the live Ingress resource.

### 8.6 Retrying synchronization

After the investigation and validation, we initiated synchronization again through the Argo CD dashboard.

The subsequent synchronization completed successfully.

Observed result:

```text
OPERATION
Sync

PHASE
Succeeded

MESSAGE
successfully synced (all tasks run)

```

The synchronization operation succeeded, and all synchronization tasks completed.

**Important:** The successful retry confirms that the application was synchronized. It does not establish that the underlying ingress-nginx reload and admission webhook issues have been permanently resolved. Those should remain separate troubleshooting considerations if the problem reappears.

---

## 9. Final Application Verification

After synchronization, we returned to the Argo CD application dashboard.

The final status showed:

```text
APP HEALTH
Healthy

SYNC STATUS
Synced

LAST SYNC
Sync OK
```

The dashboard also showed:

```text
Synced: 9
OutOfSync: 0
```

This confirmed that all nine desired application resources were synchronized.

### Verifying through kubectl

The final configuration can also be inspected from the terminal.

We used the following command to verify the Argo CD Application's synchronization policy and status:

```bash
kubectl get application expense-tracker -n argocd \
  -o jsonpath='{.spec.syncPolicy.automated}{"\n"}{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'
```

Expected result:

```text
Synced
Healthy
```

The first line is empty because automated synchronization is not configured.

This confirms that manual synchronization remains in place.

---

## 10. Important Commands Reference

The following commands were used during the milestone or represent the final verification commands documented above.

| Command | Purpose |
|---|---|
| `kubectl port-forward svc/argocd-server -n argocd 8081:443` | Access Argo CD dashboard |
| `kubectl kustomize kubernetes/` | Render Kustomize resources |
| `kubectl apply --dry-run=server -f kubernetes/frontend/ingress.yaml` | Validate Ingress against the API server without applying it |
| `kubectl get pods,svc,endpoints -n ingress-nginx` | Inspect ingress-nginx components |
| `grep -n -A4 "replicas:" kubernetes/backend/deployment.yaml kubernetes/frontend/deployment.yaml` | Verify replica configuration |
| `git diff -- kubernetes/backend/deployment.yaml kubernetes/frontend/deployment.yaml` | Inspect manifest changes |
| `kubectl get application expense-tracker -n argocd -o jsonpath=...` | Verify Argo CD Application status and sync policy |

The following dashboard actions were also performed:

- Create the `expense-tracker` Application.
- Configure the GitHub repository and target revision.
- Select the `kubernetes` directory.
- Confirm Kustomize recognition.
- Inspect application resources and Diff.
- Refresh application state.
- Initiate manual synchronization.
- Inspect synchronization results and application health.

---

## 11. Key Lessons Learned

### 1. Git is the source of truth

Changes made directly to Kubernetes do not automatically update the repository.

The desired configuration must be maintained in Git to avoid persistent differences between Git and the cluster.

### 2. Healthy and Synced are different

An application can be healthy but OutOfSync.

Health describes operational readiness, while synchronization describes configuration alignment.

### 3. Refresh is not Sync

Refreshing updates Argo CD's view of the application. Synchronization applies the desired configuration to the cluster.

### 4. Admission webhooks are part of Kubernetes resource validation

A manifest can be correctly structured but still fail to apply if a required admission webhook is unavailable or times out.

### 5. Logs are essential for troubleshooting

The Argo CD error identified the failing operation, while the ingress-nginx logs provided additional information about controller reload and API communication issues.

### 6. Persistent storage requires protection

The MongoDB PersistentVolumeClaim was configured with `Prune=false` to reduce the risk of accidental removal through GitOps pruning.

This does not replace a proper backup and recovery strategy.

### 7. Manual synchronization provides operational control

Manual sync allowed us to inspect changes and decide when to apply them. Automated sync and self-healing are reserved for later milestones.

---

## 12. Current State and Scope Boundaries

At the end of this milestone:

| Item | Status |
|---|---|
| Argo CD installation | Existing installation reused |
| Argo CD dashboard | Accessible |
| GitHub repository connection | Configured |
| Application resource | Created |
| Kustomize recognition | Successful |
| Initial reconciliation | Successful |
| Final application health | Healthy |
| Final synchronization status | Synced |
| Automated sync | Not enabled |
| Self-healing | Not configured |
| Drift detection and recovery testing | Deferred |
| Jenkins-to-Git integration | Deferred |
| Helm deployment | Not implemented |

The application is currently managed through Argo CD with manual synchronization.

The next milestones will build on this foundation by connecting Git changes to Kubernetes reconciliation and exploring drift detection, recovery and GitOps operational practices.

---

## 13. Milestone Completion

Milestone 4 established Argo CD as the GitOps management tool for the Expense Tracker application.

The repository was connected, Kustomize was recognized, the initial synchronization failure was investigated, and the application was successfully reconciled.

Final verification confirmed:

- 9 resources synchronized.
- 0 resources OutOfSync.
- Application health: Healthy.
- Synchronization status: Synced.
- Automated synchronization: Disabled.

**Milestone 4 — GitOps Tooling and Controller Installation: COMPLETED.**