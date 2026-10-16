# M09 — Resource Requests, Limits, and Scheduling

## 1. Objective

The objective of this session was to understand how Kubernetes manages CPU and memory resources for containers, configure resource requests and limits for the Expense Tracker frontend, and verify that the application remained healthy after the change.

This session focused on resource configuration and validation rather than deliberately exhausting node resources.

## 2. The Engineering Problem

Kubernetes workloads share finite node resources. Without explicit resource requests and limits, the scheduler has less workload-specific information for making placement decisions, and containers do not have the resource constraints declared in their Pod specifications.

For our Expense Tracker project, we needed to establish a baseline, choose conservative resource values for the lightweight frontend, apply them through the Deployment manifest, and verify the outcome.

## 3. Core Concepts

### 3.1 Resource requests

A resource request declares the amount of CPU or memory Kubernetes should account for when scheduling a Pod.

- **CPU request:** The CPU amount used during scheduling decisions.
- **Memory request:** The memory amount used during scheduling decisions.

A request is not a hard runtime usage ceiling.

### 3.2 Resource limits

A resource limit specifies the maximum resource consumption allowed for a container.

- **CPU limit:** CPU usage can be throttled when the container attempts to exceed its configured limit.
- **Memory limit:** Exceeding the memory limit can result in the container being terminated, commonly with an `OOMKilled` status.

### 3.3 CPU and memory units

Kubernetes supports several resource units.

| Unit | Meaning |
|---|---|
| `50m` CPU | 50 millicores, or 0.05 CPU |
| `200m` CPU | 200 millicores, or 0.2 CPU |
| `64Mi` memory | 64 mebibytes |
| `128Mi` memory | 128 mebibytes |

The `m` suffix for CPU means millicores. The `Mi` suffix for memory means mebibytes.

### 3.4 Scheduling and resource allocation

Kubernetes uses requests when deciding whether a node has enough allocatable resources for a Pod. A node can have free physical memory while still lacking sufficient unallocated requested resources for a particular Pod.

Requests and limits serve different purposes and should not be treated as interchangeable.

## 4. Lab Environment

The experiment used the existing Minikube Kubernetes environment.

| Item | Value |
|---|---|
| Application | Expense Tracker frontend |
| Kubernetes resource | Deployment |
| Deployment name | `frontend` |
| Initial replicas | 2 |
| Container port | 80 |
| Container image | `expense-tracker-dev-frontend:1.0.4` |
| Image registry | Amazon ECR |
| Image pull secret | `ecr-secret` |
| Manifest | `kubernetes/frontend/deployment.yaml` |

The frontend was already deployed and accessible through the configured Nginx Ingress Controller.

## 5. Baseline Inspection

### 5.1 Inspecting existing resource settings

The initial inspection showed:

```text
Container: frontend
Requests:
Limits:
```

The frontend container had no explicitly configured CPU or memory requests or limits in its Deployment template.

### 5.2 Inspecting node capacity

The Minikube node reported:

```text
Capacity:
  cpu:                2
  memory:             2523796Ki
  pods:               110

Allocatable:
  cpu:                2
  memory:             2523796Ki
  pods:               110
```

The reported memory capacity was approximately 2.41 GiB.

Capacity and allocatable memory were identical in this output. This did not mean that all reported memory was unused or available for additional workloads.

### 5.3 Inspecting allocated resources

The node reported:

```text
Allocated resources:
  Resource           Requests     Limits
  cpu                950m (47%)   100m (5%)
  memory             310Mi (12%)  220Mi (8%)
```

These figures represented the aggregate resource requests and limits declared by workloads on the node, expressed as percentages of node capacity.

The CPU requests exceeded the aggregate CPU limits. This is possible because requests and limits are independently configured values; Kubernetes does not require aggregate requests to be lower than aggregate limits.

The figures were not measurements of actual CPU or memory consumption.

## 6. Resource Configuration Decision

We selected conservative initial values for the frontend container.

| Resource | Request | Limit |
|---|---:|---:|
| CPU | `50m` | `200m` |
| Memory | `64Mi` | `128Mi` |

These were starting values suitable for a lightweight Nginx-served frontend in our lab. They were not derived from load testing or production performance measurements.

### 6.1 Expected allocation for two replicas

With two frontend replicas, the declared totals would be:

| Resource | Combined requests | Combined limits |
|---|---:|---:|
| CPU | `100m` | `400m` |
| Memory | `128Mi` | `256Mi` |

These totals represent the resource settings for the two frontend containers, not actual consumption.

## 7. Updating the Deployment Manifest

The configuration was added to the existing container definition in:

`kubernetes/frontend/deployment.yaml`

The relevant section became:

```yaml
resources:
  requests:
    cpu: "50m"
    memory: "64Mi"
  limits:
    cpu: "200m"
    memory: "128Mi"
```

The existing Deployment configuration was preserved, including:

- Two replicas.
- The `app: frontend` selector.
- The `rollout-experiment: "m08"` Pod-template label.
- The existing ECR image reference and tag `1.0.4`.
- The `ecr-secret` image pull secret.
- The `RollingUpdate` strategy with `maxSurge: 25%` and `maxUnavailable: 25%`.

The resource configuration was added to the container specification, not to the Deployment metadata.

## 8. Validation and Application

### 8.1 Client-side dry-run validation

Before changing the live Deployment, we ran:

```bash
kubectl apply --dry-run=client \
  -f kubernetes/frontend/deployment.yaml
```

The command returned:

```text
deployment.apps/frontend configured (dry run)
```

This confirmed that the client-side dry run accepted the manifest. It did not apply the configuration to the live cluster.

### 8.2 Applying the manifest

The manifest was then applied using:

```bash
kubectl apply -f kubernetes/frontend/deployment.yaml
```

The Deployment was subsequently checked and reported:

```text
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
frontend   2/2     2            2           17d
```

The Deployment retained two ready, up-to-date, and available replicas.

## 9. Verifying the Live Resource Configuration

We queried the Deployment's live Pod template with:

```bash
kubectl get deployment frontend \
  -o jsonpath='{range .spec.template.spec.containers[*]}Container: {.name}{"\n"}Requests: {.resources.requests}{"\n"}Limits: {.resources.limits}{"\n\n"}{end}'
```

The output confirmed:

```text
Container: frontend
Requests: {"cpu":"50m","memory":"64Mi"}
Limits: {"cpu":"200m","memory":"128Mi"}
```

This established that the live Deployment template contained the intended resource configuration.

We also checked the frontend Pods and their configuration, and the user confirmed that the verification checks passed.

## 10. Application Availability Verification

After applying the configuration, we checked that the application continued to respond through the existing Ingress route.

The command used was:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  --resolve expense.example.test:32136:192.168.49.2 \
  http://expense.example.test:32136/
```

The expected and verified result was:

```text
HTTP 200
```

This confirmed that the frontend remained reachable through the established Ingress path after the resource configuration change.

The check verified HTTP availability. It did not measure performance under load or establish actual resource consumption.

## 11. What We Learned

### Lesson 1 — Requests and limits solve different problems

Requests influence scheduling decisions. Limits constrain container resource consumption at runtime.

### Lesson 2 — A resource request is not a hard usage ceiling

A container may use more CPU than its request when CPU is available, provided it stays within its configured CPU limit.

### Lesson 3 — Memory limits require care

If a container exceeds its memory limit, it may be terminated. Limits should therefore be selected with knowledge of the application's normal and peak memory requirements.

### Lesson 4 — Configuration should be validated before application

The client-side dry run provided an initial validation step before the live Deployment was changed.

### Lesson 5 — The live cluster must be inspected after changes

A manifest edit alone does not prove that the intended configuration is active. We inspected the live Deployment and confirmed its resource settings.

### Lesson 6 — Application availability and resource performance are different checks

The HTTP 200 response confirmed that the frontend remained accessible. It did not demonstrate how the application behaves under CPU pressure, memory pressure, or high traffic.

## 12. What We Did Not Test

The following experiments were not performed during this session:

- Deliberately exhausting node memory.
- Triggering an `OOMKilled` termination.
- Generating sustained CPU load to observe throttling.
- Comparing measured CPU and memory usage before and after the change.
- Testing whether a new Pod would remain pending because of insufficient requested resources.

These were excluded to avoid putting unnecessary pressure on the limited-memory lab environment.

The selected resource values remain initial lab values and should be revisited if performance measurements or workload requirements change.

## 13. Common Mistakes

### Mistake 1 — Treating requests as limits

A request informs scheduling. It does not impose the same runtime ceiling as a limit.

### Mistake 2 — Assuming a successful apply proves the application is healthy

A successful manifest application confirms that the API accepted the change; it does not alone prove that the application is functioning correctly.

### Mistake 3 — Choosing limits without considering application needs

An excessively low memory limit can cause avoidable container terminations. Resource values should reflect measured behavior and workload requirements when available.

### Mistake 4 — Confusing declared allocation with actual usage

The node's allocated resource summary reports declared requests and limits. It is not a live utilization report.

### Mistake 5 — Testing failure scenarios without protecting the lab

Resource exhaustion experiments can destabilize other workloads, especially on a small VM. Failure experiments should be isolated and controlled.

## 14. Best Practices

- Start with a baseline inspection before changing resource settings.
- Use explicit requests and limits where appropriate for the workload.
- Select conservative initial values for constrained environments.
- Keep the Kubernetes manifest as the configuration source of truth.
- Validate manifests before applying them.
- Verify the live Deployment after applying changes.
- Check both workload health and application availability.
- Use metrics and load tests to refine resource settings rather than guessing.
- Avoid resource-exhaustion experiments on a shared or memory-constrained lab without appropriate safeguards.

## 15. Commands Used

Inspect the frontend's current resource settings:

```bash
kubectl get deployment frontend \
  -o jsonpath='{range .spec.template.spec.containers[*]}Container: {.name}{"\n"}Requests: {.resources.requests}{"\n"}Limits: {.resources.limits}{"\n\n"}{end}'
```

Inspect node capacity and allocated resources:

```bash
kubectl describe node minikube
```

Validate the manifest without applying it:

```bash
kubectl apply --dry-run=client \
  -f kubernetes/frontend/deployment.yaml
```

Apply the manifest:

```bash
kubectl apply -f kubernetes/frontend/deployment.yaml
```

Inspect Deployment status:

```bash
kubectl get deployment frontend
```

Inspect frontend Pods:

```bash
kubectl get pods -l app=frontend
```

Inspect Pod configuration:

```bash
kubectl describe pods -l app=frontend
```

Check frontend availability through Ingress:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  --resolve expense.example.test:32136:192.168.49.2 \
  http://expense.example.test:32136/
```

## 16. Session Outcome

**M09 practical work is complete.**

The frontend Deployment was updated with explicit CPU and memory requests and limits. The live configuration was verified, both frontend replicas remained available, and the Ingress HTTP check succeeded.

No resource-exhaustion or load-testing experiments were performed.

The next step in the mentorship workflow is to save this document in the Volume 6 documentation directory, review it, commit and push the documentation, and then resume M10 — Probes and Application Health.

Volume 6 should not be tagged as complete until all required modules in the Volume have been completed and documented.