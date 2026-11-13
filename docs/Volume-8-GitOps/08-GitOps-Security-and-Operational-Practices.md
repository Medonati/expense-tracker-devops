# Milestone 8 — GitOps Security and Operational Practices

**Volume:** 8 — GitOps  
**Milestone:** 8 of 10  
**Project:** Expense Tracker DevOps  
**Repository:** `Medonati/expense-tracker-devops`  
**Environment:** Vagrant Ubuntu VM, Minikube and Argo CD v3.5.6  
**Status:** Practical exercises completed; documentation pending review.

---

## 1. Introduction

GitOps introduces a declarative approach to managing Kubernetes applications. However, automating deployments also introduces security and operational responsibilities.

A GitOps environment must ensure that:

- Only authorized users can access and manage applications.
- Users receive only the permissions required for their responsibilities.
- Applications deploy from trusted repositories.
- Deployment destinations are restricted.
- Sensitive information is handled appropriately.
- Automated synchronization does not introduce unnecessary operational risks.

This milestone focused on applying these principles to the existing Expense Tracker application managed by Argo CD.

The practical work was performed against the existing Minikube cluster without reinstalling Argo CD or recreating the application.

## 2. Argo CD Administrator Security

### 2.1 Initial administrator Secret

We inspected the Argo CD namespace to identify the initial administrator Secret.

```bash
kubectl get secrets -n argocd
```

The initial Secret was:

```text
argocd-initial-admin-secret
```

We inspected its metadata without exposing the password:

```bash
kubectl describe secret argocd-initial-admin-secret -n argocd
```

The original administrator password was still in use.

### 2.2 Administrator password rotation

We changed the initial administrator password through the Argo CD dashboard.

After updating the password:

1. We logged out of the dashboard.
2. We authenticated again using the new password.
3. We confirmed that the new password worked.
4. We removed the initial bootstrap Secret.

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

This removed the initial bootstrap credential after successful password rotation.

**Security lesson:** Initial administrator credentials should be replaced after installation. Bootstrap credentials should not remain unnecessarily available.

## 3. Role-Based Access Control (RBAC)

### 3.1 Understanding the access-control requirement

Not every Argo CD user should have administrator privileges.

For this exercise, we established the following requirements for a developer account:

- View the `expense-tracker` application.
- Synchronize the `expense-tracker` application.
- Cannot delete applications.
- Cannot manage other applications.
- Cannot modify project configuration.
- Cannot administer Argo CD.

The objective was to implement least-privilege access.

### 3.2 Creating a local developer account

We inspected the Argo CD configuration and confirmed that the local account was not already configured.

We created the account using:

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"accounts.developer-user":"login"}}'
```

We verified the configuration:

```bash
kubectl get configmap argocd-cm -n argocd -o jsonpath='{.data.accounts\.developer-user}{"\n"}'
```

Expected output:

```text
login
```

### 3.3 Creating the developer RBAC role

We configured a dedicated role called `developer`.

The policy grants permission to view and synchronize only the designated application.

```bash
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.csv":"p, role:developer, applications, get, default/expense-tracker, allow\np, role:developer, applications, sync, default/expense-tracker, allow\ng, developer-user, role:developer"}}'
```

The resulting policy:

```csv
p, role:developer, applications, get, default/expense-tracker, allow
p, role:developer, applications, sync, default/expense-tracker, allow
g, developer-user, role:developer
```

We also added permission to view the AppProject associated with the application:

```bash
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.csv":"p, role:developer, applications, get, default/expense-tracker, allow\np, role:developer, applications, sync, default/expense-tracker, allow\np, role:developer, projects, get, default, allow\ng, developer-user, role:developer"}}'
```

The project-view permission was necessary because Argo CD also checks access to the project when retrieving application information.

### 3.4 Setting the developer password

We installed the Argo CD CLI v3.5.6 for Linux AMD64.

The downloaded binary was verified against the official release checksum before installation.

```bash
sha256sum ~/argocd-linux-amd64
```

The verified checksum was:

```text
db9d17b70593d3f86a4dcf08d9ebbb85a42e995426ac5f928b737260656102d3
```

We installed the binary:

```bash
sudo install -m 755 ~/argocd-linux-amd64 /usr/local/bin/argocd
```

We verified the installation:

```bash
argocd version --client
```

Argo CD CLI version:

```text
v3.5.6
```

We authenticated as the administrator:

```bash
argocd login 192.168.49.2:30080 --insecure --username admin
```

Then configured the developer password:

```bash
argocd account update-password --account developer-user --prompts-enabled
```

The password was successfully updated.

We logged out of the administrator session:

```bash
argocd logout 192.168.49.2:30080
```

And authenticated as the developer:

```bash
argocd login 192.168.49.2:30080 --insecure --username developer-user
```

The developer login succeeded.

### 3.5 Verifying application access

We tested application visibility:

```bash
argocd app get expense-tracker
```

The developer successfully retrieved the application details after the required project-view permission was added.

We then tested synchronization without applying changes:

```bash
argocd app sync expense-tracker --dry-run
```

The command completed successfully, reporting that the resources were unchanged.

This demonstrated that the developer could initiate a synchronization operation without requiring administrator access.

### 3.6 RBAC permission audit

We used the Argo CD RBAC checker to verify the effective permissions.

The command format requires singular resource names such as `application` and `project`.

Example:

```bash
argocd admin settings rbac can developer-user get application default/expense-tracker --namespace argocd
```

The following checks were completed:

| Permission | Result |
|---|---|
| View `expense-tracker` | Yes |
| Sync `expense-tracker` | Yes |
| Delete `expense-tracker` | No |
| View another application | No |
| View default project | Yes |
| Modify default project | No |
| Delete default project | No |

These results confirmed that the developer role was restricted to its intended responsibilities.

**Key lesson:** RBAC should be verified rather than assumed. A user successfully logging in does not prove that the user has the correct permissions.

## 4. AppProject Security and Deployment Boundaries

### 4.1 Understanding the initial configuration

We inspected the existing AppProject:

```bash
kubectl get appproject default -n argocd -o yaml
```

The original configuration contained:

```yaml
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - namespace: '*'
    server: '*'
  sourceRepos:
  - '*'
```

This configuration was broad.

It allowed any repository, any destination cluster and namespace, and all cluster-scoped resource kinds.

### 4.2 Identifying the actual application requirements

We inspected the application source and destination:

```bash
kubectl get application expense-tracker -n argocd -o jsonpath='{.spec.destination.server}{"\n"}{.spec.destination.namespace}{"\n"}{.spec.source.repoURL}{"\n"}{.spec.source.path}{"\n"}'
```

The actual configuration was:

```text
https://kubernetes.default.svc
default
https://github.com/Medonati/expense-tracker-devops
kubernetes
```

We also inspected the resources managed by the application:

```bash
kubectl get application expense-tracker -n argocd -o jsonpath='{range .status.resources[*]}{.group}{"\t"}{.kind}{"\t"}{.namespace}{"\t"}{.name}{"\n"}{end}'
```

The application managed:

- ConfigMaps
- PersistentVolumeClaim
- Services
- Deployments
- Ingress

All ten tracked resources were namespace-scoped and deployed in the `default` namespace.

We also confirmed that `expense-tracker` was the only application using the default AppProject.

### 4.3 Restricting the AppProject

Based on the actual application requirements, we restricted the project.

```bash
kubectl patch appproject default -n argocd --type merge -p '{"spec":{"sourceRepos":["https://github.com/Medonati/expense-tracker-devops"],"destinations":[{"namespace":"default","server":"https://kubernetes.default.svc"}],"clusterResourceWhitelist":[]}}'
```

The resulting configuration was:

```yaml
spec:
  clusterResourceWhitelist: []
  destinations:
  - namespace: default
    server: https://kubernetes.default.svc
  sourceRepos:
  - https://github.com/Medonati/expense-tracker-devops
```

This established the following boundaries:

| Security boundary | Allowed configuration |
|---|---|
| Git repository | Expense Tracker repository only |
| Destination cluster | In-cluster Kubernetes API |
| Destination namespace | `default` |
| Cluster-scoped resources | None |

The empty cluster-resource whitelist means the project does not permit cluster-scoped resource kinds through that allowlist.

### 4.4 Verifying the application after restriction

We checked the Argo CD application:

```bash
kubectl get application expense-tracker -n argocd
```

Result:

```text
NAME              SYNC STATUS   HEALTH STATUS
expense-tracker   Synced        Healthy
```

We also checked the running Pods:

```bash
kubectl get pods -n default
```

All four Pods were running and ready:

- Backend
- Two frontend replicas
- MongoDB

**Key lesson:** Security boundaries should be based on actual application requirements. Restricting repositories, clusters, namespaces and resource permissions reduces unnecessary deployment privileges.

## 5. Git Repository Security

### 5.1 Repository configuration inspection

We inspected registered repositories:

```bash
argocd repo list
```

The command returned the column headings without registered repository entries.

We also inspected repository credential Secret metadata:

```bash
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
```

Result:

```text
No resources found in argocd namespace.
```

We established that the GitHub repository was public.

Repository:

```text
https://github.com/Medonati/expense-tracker-devops
```

Because the repository is public, Argo CD can access it without stored private-repository credentials.

We did not configure additional GitHub credentials because they were not required for this public repository.

**Security lesson:** Public repository access does not eliminate the need to protect sensitive application configuration. Passwords, tokens and private keys must never be committed to a public Git repository.

## 6. Kubernetes Secrets Management

### 6.1 Identifying application Secrets

We inspected the Secrets in the application namespace:

```bash
kubectl get secrets -n default
```

**Security lessons:**

- Keep sensitive values out of application manifests and public Git repositories.
- Use Kubernetes Secrets to separate sensitive configuration from ordinary ConfigMaps.
- Restrict access to Secrets through Kubernetes RBAC.
- Avoid printing Secret values during troubleshooting.
- Kubernetes Secret data is base64-encoded by default; base64 encoding is not encryption.

Production environments should additionally consider encryption at rest, tightly scoped access permissions and dedicated secret-management solutions.

## 7. Automated Synchronization and Operational Safeguards

We inspected the application's synchronization policy:

```bash
kubectl get application expense-tracker -n argocd -o jsonpath='{.spec.syncPolicy}{"\n"}'
```

The result was:

```yaml
automated:
  enabled: true
  prune: false
  selfHeal: true
```

### 7.1 Automated synchronization

Automated synchronization is enabled.

Argo CD can automatically synchronize changes committed to the configured Git repository.

### 7.2 Pruning

Pruning is disabled.

When a resource is removed from Git, Argo CD will not automatically delete that resource from the cluster through automated pruning.

This reduces the risk of unintended resource deletion.

### 7.3 Self-healing

Self-healing is enabled.

When live Kubernetes configuration drifts from the desired Git configuration, Argo CD can automatically reconcile the live state.

This helps maintain the declared desired state.

### 7.4 Current operational configuration

| Setting | Current state |
|---|---|
| Automated sync | Enabled |
| Pruning | Disabled |
| Self-healing | Enabled |

**Key lesson:** Automated deployment should be accompanied by deliberate safeguards. Synchronization, deletion and drift correction have different operational consequences and should be configured intentionally.

## 8. Practical Engineering Lessons

The milestone reinforced the following principles:

1. **Least privilege:** Users should receive only the permissions required for their responsibilities.
2. **Verify access:** Successful authentication does not automatically mean authorization is correct.
3. **Secure project boundaries:** AppProjects should restrict repositories, destinations and resource permissions.
4. **Protect credentials:** Sensitive values should not be committed to public repositories or exposed during troubleshooting.
5. **Understand automation:** Automated synchronization and self-healing improve consistency, but pruning introduces deletion risks.
6. **Verify after changes:** Security configuration changes must be followed by application health and synchronization checks.
7. **Preserve working infrastructure:** Security improvements should not unnecessarily disrupt existing deployments.

## 9. Additional Production-Hardening Considerations

The practical exercises completed in this milestone establish important security controls. However, a production environment would require further assessment.

Areas for future hardening include:

- Kubernetes API encryption at rest for Secrets.
- More granular Kubernetes RBAC permissions for application Secrets.
- External secret-management integration.
- Regular credential rotation.
- Container security contexts and non-root execution.
- Image vulnerability scanning and image provenance verification.
- Network policies and workload isolation.
- Audit logging and monitoring of privileged operations.
- Dedicated AppProjects for applications as the environment grows.

These are recommendations for further hardening, not configurations claimed to have been implemented in this milestone.

## 10. Milestone Outcome

**Milestone:** 8 — GitOps Security and Operational Practices

The practical exercises covered:

- Argo CD administrator password rotation.
- Removal of the initial administrator bootstrap Secret.
- Local developer account creation.
- RBAC role configuration.
- Least-privilege permission verification.
- AppProject repository and destination restrictions.
- Cluster-scoped resource restrictions.
- Git repository access inspection.
- Kubernetes Secret reference inspection.
- Automated synchronization and operational safeguards.

The existing Expense Tracker application remained operational after the security changes.

Final observed Argo CD state:

```text
Sync Status:   Synced
Health Status: Healthy
```

**Milestone status:** Practical work completed. Documentation and repository closure pending review and approval.

### Next Milestone

**Milestone 9 — End-to-End GitOps Workflow**

The next milestone will bring together the GitOps components established so far into a complete workflow, demonstrating how changes move from Git through Argo CD reconciliation to the running Kubernetes application.