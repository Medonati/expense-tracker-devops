# Volume 8 — Milestone 7: Drift Detection and Recovery

## 1. Overview

**Milestone:** 07 — Drift Detection and Recovery  
**Volume:** 8 — GitOps  
**Project:** Expense Tracker DevOps  
**Platform:** Kubernetes (Minikube)  
**GitOps Controller:** Argo CD  
**Application:** `expense-tracker`  
**Status:** Practical implementation completed; documentation prepared for review.

## 2. Objective

The objective of this milestone was to understand how configuration drift occurs in Kubernetes, how Argo CD detects differences between the desired state stored in Git and the live cluster state, and how GitOps reconciliation restores consistency.

The practical work focused on:

- Understanding configuration drift.
- Detecting differences between Git and live Kubernetes resources.
- Observing Argo CD self-healing.
- Understanding how intentional Git changes are synchronized.
- Investigating reconciliation and repository connectivity problems.
- Verifying recovery and consistency.

All exercises used the existing Expense Tracker application and its Argo CD configuration.

## 3. Initial Environment and Application Configuration

The existing Argo CD Application was:

- Application name: `expense-tracker`
- Namespace: `argocd`
- Repository: `https://github.com/Medonati/expense-tracker-devops`
- Target revision: `HEAD`
- Repository path: `kubernetes`
- Destination server: `https://kubernetes.default.svc`
- Destination namespace: `default`

The synchronization policy was:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: false
    selfHeal: true
```

This configuration means:

- Automated synchronization is enabled.
- Automatic pruning is disabled.
- Self-healing is enabled.

The application was initially verified as:

```text
NAME              SYNC STATUS   HEALTH STATUS
expense-tracker   Synced        Healthy
```

## 4. Understanding Configuration Drift

Configuration drift occurs when the actual configuration of a resource in Kubernetes differs from the desired configuration declared in Git.

In a GitOps environment:

- Git represents the desired state.
- Kubernetes represents the live state.
- Argo CD continuously compares both states.
- Reconciliation attempts to bring the live state back in line with the desired state.

Drift can happen when someone modifies a resource directly using `kubectl`, when an external process changes a resource, or when the desired configuration changes in Git.

We used the frontend Deployment to demonstrate this behaviour.

## 5. Practical Exercise 1 — Detecting and Correcting Replica Drift

### 5.1 Inspecting the frontend Deployment

We inspected the frontend Deployment:

```bash
kubectl get deployment frontend -n default -o yaml
```

The desired replica count in Git was initially one replica.

### 5.2 Introducing manual drift

We deliberately changed the live Deployment through Kubernetes:

```bash
kubectl scale deployment frontend -n default --replicas=2
```

This introduced a difference between the Git configuration and the live Kubernetes state.

### 5.3 Observing self-healing

Because Argo CD had automated synchronization and self-healing enabled, it detected the difference and restored the live Deployment to the desired replica count declared in Git.

The important observation was that a direct Kubernetes modification did not permanently override the Git-defined configuration.

**Outcome:** Replica drift and automatic self-healing were successfully demonstrated.

## 6. Practical Exercise 2 — Intentional Changes Through Git

Not every difference between Git and Kubernetes is unwanted drift. Sometimes the desired configuration is intentionally changed.

This exercise demonstrated the correct GitOps workflow.

### 6.1 Updating the desired replica count

We deliberately changed the frontend Deployment manifest:

`kubernetes/frontend/deployment.yaml`

The replica count was changed from one to two:

```yaml
spec:
  replicas: 2
```

### 6.2 Committing and pushing the change

The updated manifest was committed and pushed to GitHub.

Argo CD detected the new repository revision and automatically synchronized the application.

No manual `kubectl apply` or manual Argo CD Sync operation was required.

### 6.3 Observing the result

The frontend Deployment eventually reflected the new desired state.

This demonstrated an important GitOps principle:

**Changes should be made in Git, and Argo CD should reconcile those changes into Kubernetes.**

We also observed that synchronization may take some time because Argo CD must detect the new revision, compare the desired state with the live state, and perform synchronization.

**Outcome:** Intentional Git-driven configuration changes were successfully demonstrated.

## 7. Practical Exercise 3 — Container Image Drift

We used the frontend container image to demonstrate another form of configuration drift.

### 7.1 Verifying the expected image

The live frontend image was initially verified as:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

This matched the intended image version.

### 7.2 Introducing image drift

We manually changed the live Deployment to use image version `1.0.3`:

```bash
kubectl set image deployment/frontend \
  frontend=748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.3 \
  -n default
```

This changed the live Kubernetes configuration without changing the Git manifest.

### 7.3 Observing automatic recovery

Argo CD detected the difference and restored the image declared in Git:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

The application returned to:

```text
SYNC STATUS: Synced
HEALTH STATUS: Healthy
```

**Outcome:** Image configuration drift and automatic recovery were successfully demonstrated.

## 8. Understanding Deployment Rollouts During Drift Recovery

During the exercises, we also reviewed Kubernetes rollout commands.

### 8.1 Checking rollout status

```bash
kubectl rollout status deployment/frontend
```

This command checks whether the Deployment rollout has completed successfully.

### 8.2 Inspecting rollout history

```bash
kubectl rollout history deployment/frontend
```

This displays the rollout revisions recorded for the Deployment.

### 8.3 Reverting a rollout

We reviewed:

```bash
kubectl rollout undo deployment/frontend
```

We also discussed reverting to a specific revision:

```bash
kubectl rollout undo deployment/frontend --to-revision=<revision>
```

An important distinction was established:

**Changing the replica count does not necessarily create a new Deployment rollout revision.**

Scaling changes the number of desired Pods, while a rollout revision is associated with changes to the Deployment's Pod template.

For a replica-count change, the appropriate command to change the scale directly is:

```bash
kubectl scale deployment frontend -n default --replicas=<count>
```

However, in this GitOps-managed application, Argo CD may subsequently reconcile the live replica count to match Git.

We returned the focus of the exercise to Argo CD drift detection and reconciliation.

## 9. Troubleshooting Argo CD Repository Connectivity

During the drift-recovery exercise, we investigated intermittent repository connectivity errors.

Although the application was ultimately synchronized and healthy, the Argo CD controller and repository server logs showed temporary errors retrieving repository information from GitHub.

### 9.1 Inspecting the Argo CD Application

We inspected the Application:

```bash
kubectl describe application expense-tracker -n argocd
```

The output showed:

- Sync status: Synced
- Health status: Healthy
- Successful synchronization history.
- Previous transitions between `OutOfSync` and `Synced`.
- Previous transitions between `Progressing` and `Healthy`.

We also inspected Application conditions. No current conditions were returned by the conditions query.

### 9.2 Inspecting the Application Controller

We identified the controller Pod:

```text
argocd-application-controller-0
```

We inspected its recent logs:

```bash
kubectl logs argocd-application-controller-0 -n argocd --since=15m
```

The logs included normal reconciliation activity and messages such as:

```text
Skipping auto-sync: application status is Synced
```

They also contained temporary warnings about failures retrieving repository objects and comparing application state against the repository.

### 9.3 Inspecting the Repository Server

We identified the repository server Pod:

```text
argocd-repo-server-7f4759f94-wdm2c
```

We filtered its recent logs:

```bash
kubectl logs argocd-repo-server-7f4759f94-wdm2c \
  -n argocd --since=20m | grep -iE 'error|failed|warning'
```

The logs showed errors similar to:

```text
failed to list refs:
Get "https://github.com/Medonati/expense-tracker-devops/info/refs?service=git-upload-pack":
dial tcp: lookup github.com on 10.96.0.10:53:
read udp ... ->10.96.0.10:53: i/o timeout
```

Another error reported a context deadline exceeded while awaiting response headers.

These messages indicated that the repository server was experiencing problems resolving or reaching GitHub.

### 9.4 Inspecting CoreDNS

We checked the Kubernetes system Pods:

```bash
kubectl get pods -n kube-system
```

The CoreDNS Pod was running:

```text
coredns-559f6c778d-shszj
```

However, it had a restart count of 51.

We then inspected recent CoreDNS logs:

```bash
kubectl logs -n kube-system deployment/coredns --since=30m \
  | grep -iE 'error|timeout|fail|github'
```

The logs showed successful internal service DNS queries and successful external queries for `github.com`.

However, some requests timed out while CoreDNS attempted to reach its upstream DNS server:

```text
192.168.49.1:53
```

The errors included:

```text
read udp ... ->192.168.49.1:53: i/o timeout
```

Some requests consequently returned `SERVFAIL`, while later requests successfully resolved `github.com`.

### 9.5 Understanding the DNS resolution path

The investigation established the following DNS path:

1. The Argo CD repository server attempted to resolve `github.com`.
2. The request went to the cluster DNS service at `10.96.0.10:53`.
3. CoreDNS forwarded external DNS requests to its configured upstream server at `192.168.49.1:53`.
4. Some upstream requests timed out.
5. This intermittently affected the repository server's ability to resolve and reach GitHub.

The evidence pointed to intermittent upstream DNS connectivity rather than a permanently unavailable CoreDNS Pod.

The deeper cause of the upstream timeouts was not established during this exercise.

## 10. Verifying DNS Recovery

To verify current DNS resolution from inside the Kubernetes cluster, we created a temporary BusyBox Pod:

```bash
kubectl run dns-test \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -it \
  -- nslookup github.com
```

The command displayed an attachment warning and fell back to streaming logs. This was not a DNS resolution failure.

The DNS lookup succeeded:

```text
Server:         10.96.0.10
Address:        10.96.0.10:53

Name:   github.com
Address: 140.82.121.4
```

The temporary Pod was subsequently deleted:

```text
pod "dns-test" deleted from default namespace
```

This confirmed that DNS resolution from inside the cluster was working at the time of the test.

We then inspected the repository server logs again:

```bash
kubectl logs argocd-repo-server-7f4759f94-wdm2c \
  -n argocd --since=10m | grep -iE 'error|failed|timeout'
```

The output contained only the informational default-container message and no matching error, failure, or timeout entries.

**Observation:** The repository server was no longer reporting the earlier matching errors in the inspected time window.

## 11. Final Verification of Desired and Live State

After the troubleshooting exercise, we verified the Argo CD Application:

```bash
kubectl get application expense-tracker -n argocd
```

Observed result:

```text
NAME              SYNC STATUS   HEALTH STATUS
expense-tracker   Synced        Healthy
```

We then inspected the live frontend Deployment:

```bash
kubectl get deployment frontend -n default \
  -o jsonpath='{.spec.replicas}{" replicas | "}{.spec.template.spec.containers[0].image}{"\n"}'
```

Observed result:

```text
2 replicas | 748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

Finally, we inspected the Git manifest:

```bash
grep -nE 'replicas:|image:' kubernetes/frontend/deployment.yaml
```

Observed result:

```text
9:  replicas: 2
30:          image: 748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

The desired and live configurations matched.

| Configuration | Git desired state | Kubernetes live state |
|---|---|---|
| Frontend replicas | 2 | 2 |
| Frontend image | 1.0.4 | 1.0.4 |

Final Argo CD status:

```text
expense-tracker   Synced   Healthy
```

**Outcome:** The application was confirmed synchronized and healthy, with the frontend Deployment matching the Git-defined configuration.

## 12. Important Engineering Lessons

### 12.1 Git is the source of truth

In a GitOps workflow, Git contains the intended configuration. Direct changes to Kubernetes should not become the normal method of managing application configuration.

### 12.2 Drift can occur even when automation is enabled

People and external processes can still modify Kubernetes resources. Automated reconciliation and self-healing help restore the desired configuration.

### 12.3 Intentional changes should be made through Git

A deliberate configuration change should be committed and pushed to Git. Argo CD can then detect and apply it automatically.

### 12.4 Self-healing and automated synchronization work together

Automated synchronization allows Argo CD to apply desired changes from Git. Self-healing allows it to correct live changes that conflict with Git.

### 12.5 A healthy application does not mean every infrastructure component has been error-free

The application can recover from temporary connectivity problems. Logs remain important because they help explain what happened even when the current application status is healthy.

### 12.6 DNS is an important dependency for GitOps controllers

Argo CD needs repository connectivity to retrieve and compare Git configuration. DNS failures can therefore interrupt repository access and reconciliation.

### 12.7 Troubleshooting should follow evidence

We inspected the Application, controller logs, repository server logs, CoreDNS logs, and performed a DNS lookup from inside the cluster.

This allowed us to identify the intermittent DNS timeout path without making unnecessary changes to the cluster.

## 13. Practical Commands Reference

| Purpose | Command |
|---|---|
| Inspect Argo CD Application | `kubectl get application expense-tracker -n argocd` |
| Describe Application | `kubectl describe application expense-tracker -n argocd` |
| Inspect Application YAML | `kubectl get application expense-tracker -n argocd -o yaml` |
| Inspect frontend Deployment | `kubectl get deployment frontend -n default -o yaml` |
| Scale Deployment | `kubectl scale deployment frontend -n default --replicas=2` |
| Change live container image | `kubectl set image deployment/frontend frontend=<image> -n default` |
| Check rollout status | `kubectl rollout status deployment/frontend` |
| Inspect rollout history | `kubectl rollout history deployment/frontend` |
| Undo a rollout | `kubectl rollout undo deployment/frontend` |
| Inspect controller logs | `kubectl logs argocd-application-controller-0 -n argocd --since=15m` |
| Inspect repository server logs | `kubectl logs argocd-repo-server-7f4759f94-wdm2c -n argocd --since=20m` |
| Inspect CoreDNS Pods | `kubectl get pods -n kube-system` |
| Inspect CoreDNS logs | `kubectl logs -n kube-system deployment/coredns --since=30m` |
| Test DNS from a temporary Pod | `kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- nslookup github.com` |
| Inspect Git manifest | `grep -nE 'replicas:|image:' kubernetes/frontend/deployment.yaml` |

## 14. Milestone Outcome

Milestone 7 successfully demonstrated how configuration drift can occur in Kubernetes and how Argo CD detects and corrects differences between the desired state in Git and the live cluster state.

The practical implementation established that:

- Manual changes to Kubernetes resources can introduce configuration drift.
- Argo CD self-healing can restore the Git-defined replica count and container image.
- Intentional changes committed and pushed to Git are automatically synchronized.
- Kubernetes rollout history and rollback commands have distinct purposes from GitOps reconciliation.
- Argo CD repository connectivity depends on working DNS resolution.
- Intermittent upstream DNS timeouts can affect repository access and reconciliation.
- Troubleshooting should use evidence from the controller, repository server, DNS service, and live application state.
- The final frontend configuration matched the Git manifest.

The final synchronization policy remained:

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

Final frontend configuration:

```text
2 replicas | expense-tracker-dev-frontend:1.0.4
```

**Volume 8 — Milestone 7: Drift Detection and Recovery: Practical implementation completed.**

**Next milestone:** Milestone 8 — GitOps Security and Operational Practices.