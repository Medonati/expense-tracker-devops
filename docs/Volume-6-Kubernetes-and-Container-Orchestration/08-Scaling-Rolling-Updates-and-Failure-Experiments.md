# M08 — Scaling, Rolling Updates, Rollbacks, and Failure Experiments

## 1. Objective

Understand how Kubernetes maintains a desired replica count, replaces Pods during updates, restores earlier Deployment revisions, and behaves when a replacement image cannot be pulled.

This milestone uses the Expense Tracker frontend in the Minikube lab.

**Known-good frontend image:**

`748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4`

## 2. The Engineering Problem

Applications need to scale when demand changes. They also need updates that minimize downtime and recovery mechanisms when a deployment fails or a Pod disappears unexpectedly.

Kubernetes addresses these challenges through controllers that continuously reconcile actual state with desired state.

A Deployment manages ReplicaSets, which maintain the requested number of Pods. Deployment revisions allow engineers to restore a previous Pod template when a rollout needs to be reversed.

## 3. Core Concepts

- **Desired state:** The replica count and Pod template declared in the Deployment.
- **Reconciliation:** Controllers compare actual state with desired state and act to reduce the difference.
- **ReplicaSet:** Maintains the requested number of matching Pods.
- **Rolling update:** Gradually replaces Pods after a Pod-template change.
- **Revision:** A recorded version of the Deployment's Pod template.
- **Rollback:** Restores an earlier Deployment revision.
- **Self-healing:** Controllers replace missing Pods to restore the desired replica count.
- **ImagePullBackOff:** Kubernetes is backing off repeated attempts to pull an image that cannot be retrieved.

## 4. Lab Architecture

```text
Client
  |
  v
Minikube node :32136
  |
  v
NGINX Ingress Controller
  |
  v
Ingress rule: expense.example.test /
  |
  v
frontend Service :80
  |
  v
Deployment frontend (2 replicas)
  |
  v
ReplicaSet
  |
  +---- Frontend Pod
  |
  +---- Frontend Pod
```

The frontend Service remained `ClusterIP`. External access was provided through the Ingress controller's NodePort.

## 5. Baseline Verification

Before the experiments, the frontend Deployment reported:

```text
NAME       READY   UP-TO-DATE   AVAILABLE
frontend   2/2     2            2
```

Both frontend Pods were `1/1 Running`, with zero restarts. The active image was `1.0.4`, and the Ingress endpoint returned HTTP 200.

The Deployment used the `RollingUpdate` strategy:

```yaml
rollingUpdate:
  maxSurge: 25%
  maxUnavailable: 25%
```

With two desired replicas:

- `maxSurge: 25%` rounds up to one additional Pod.
- `maxUnavailable: 25%` rounds down to zero unavailable Pods.

This configuration helped preserve availability during the tested rollout.

## 6. Experiment 1 — Scaling Up and Down

### Scale from two replicas to three

```bash
kubectl scale deployment frontend --replicas=3
kubectl get deployment frontend
kubectl get pods -l app=frontend -o wide
kubectl get endpoints frontend
```

### Observation

The Deployment reached `3/3`. Kubernetes created a third frontend Pod, which became ready. The Service endpoints included all three frontend Pod IPs.

### Scale back to two replicas

```bash
kubectl scale deployment frontend --replicas=2
kubectl get deployment frontend
kubectl get pods -l app=frontend
kubectl get endpoints frontend
```

### Observation

The Deployment returned to `2/2`. The Service endpoints returned to the two remaining Pods.

### Lesson learned

Scaling changes the desired replica count. Kubernetes controllers create or remove Pods to converge on that count.

We do not normally scale a Deployment by manually creating individual Pods.

## 7. Experiment 2 — Triggering a New Revision

The initial frontend image was `1.0.4`. To observe how Kubernetes creates Deployment revisions, we changed the Pod-template metadata without changing the application image.

The original labels were:

```yaml
template:
  metadata:
    labels:
      app: frontend
```

We added an experimental label:

```yaml
template:
  metadata:
    labels:
      app: frontend
      rollout-experiment: "m08"
```

The additional label was added under `spec.template.metadata.labels`, not to the Deployment's selector. The selector continued matching `app: frontend`.

After applying the change, we inspected the rollout:

```bash
kubectl rollout status deployment/frontend
kubectl rollout history deployment/frontend
kubectl get rs
kubectl get pods -l app=frontend
```

### Observations

- The rollout completed successfully.
- Deployment history showed revisions 1 and 2.
- The old frontend ReplicaSet `frontend-84849f767b` scaled to zero.
- The new ReplicaSet `frontend-86bdc79c78` reached two ready replicas.
- Both new frontend Pods were `1/1 Running`, with zero restarts.
- The container image remained `1.0.4`.

### Lesson learned

A Pod-template change creates a new Deployment revision even when the application image does not change.

Therefore, a new revision does not necessarily represent a new application release.

## 8. Experiment 3 — Rolling Back the Metadata Change

We restored the previous Deployment revision:

```bash
kubectl rollout undo deployment/frontend
kubectl rollout status deployment/frontend
kubectl get deployment frontend -o yaml
kubectl get rs
kubectl get pods -l app=frontend
kubectl rollout history deployment/frontend
```

### Observations

- The rollback completed.
- The Deployment revision advanced to revision 3.
- The current Pod template no longer contained `rollout-experiment: "m08"`.
- Two frontend replicas remained available.
- The active image remained `1.0.4`.
- An Ingress request returned HTTP 200 and the expected Expense Management System page.

The `kubectl.kubernetes.io/last-applied-configuration` annotation may still contain the experimental label. This annotation records configuration previously applied with `kubectl apply`; it is not the authoritative current Pod template. The current template is under `spec.template`.

### Lesson learned

`kubectl rollout undo` restores a previous Deployment revision. After a rollback, we must verify the current Pod template, workload health, and application access rather than relying only on the command's success message.

## 9. Experiment 4 — Testing Self-Healing

Before deletion, the frontend had two healthy Pods:

```text
frontend-84849f767b-6tcgq
frontend-84849f767b-bnrsw
```

We deliberately deleted one Pod:

```bash
kubectl delete pod frontend-84849f767b-6tcgq
kubectl get pods -l app=frontend -o wide
```

### Observations

Kubernetes created a replacement Pod:

```text
frontend-84849f767b-6p4x9   1/1 Running   0   9s   10.244.0.15
frontend-84849f767b-bnrsw   1/1 Running   0   95s  10.244.0.13
```

The replacement had a new Pod name and IP address. The other original Pod continued running. An Ingress request returned HTTP 200 after replacement.

### Lesson learned

The ReplicaSet controller restored the desired count of two Pods. It created a replacement rather than recovering the deleted Pod object.

Pod names and IP addresses should not be treated as durable identities.

## 10. Experiment 5 — Simulating a Failed Image Rollout

### Step 1: Record the known-good image

```bash
kubectl get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The output identified the known-good `1.0.4` image.

### Step 2: Apply a deliberately invalid image tag

For this controlled lab experiment, we changed the frontend image to a tag that was not expected to exist:

```bash
kubectl set image deployment/frontend \
  frontend=748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:invalid-m08
```

We then inspected the Pods and rollout:

```bash
kubectl get pods -l app=frontend
kubectl get deployment frontend
kubectl rollout status deployment/frontend --timeout=20s
```

### Observations

The replacement Pod entered `ImagePullBackOff`:

```text
frontend-799c8464b-8b256   0/1 ImagePullBackOff
frontend-84849f767b-6p4x9  1/1 Running
frontend-84849f767b-bnrsw 1/1 Running
```

The Deployment reported:

```text
NAME       READY   UP-TO-DATE   AVAILABLE
frontend   2/2     1            2
```

The rollout did not complete, but both existing replicas remained available.

This was consistent with the rolling-update configuration: the replacement Pod could not become ready, while the existing replicas continued serving traffic.

### Step 3: Recover using a manual rollback

```bash
kubectl rollout undo deployment/frontend
kubectl rollout status deployment/frontend
kubectl get deployment frontend
kubectl get pods -l app=frontend
kubectl get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

### Observations after recovery

- The rollback completed successfully.
- The Deployment returned to `2/2` ready, two up-to-date, and two available replicas.
- Both frontend Pods were `1/1 Running`, with zero restarts.
- The active image was restored to `748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4`.
- The final Ingress request returned HTTP 200.

### Lesson learned

A failed rollout did not automatically trigger a rollback. We explicitly ran `kubectl rollout undo deployment/frontend`.

Kubernetes kept the old replicas available while the replacement image failed to pull. This behaviour depends on the Deployment strategy, capacity, and readiness of existing replicas.

## 11. Final Verification

We used the following commands to verify the final state:

```bash
kubectl get deployment frontend
kubectl get pods -l app=frontend
kubectl get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

curl -s -o /dev/null -w "HTTP status: %{http_code}\n" \
  --resolve expense.example.test:32136:192.168.49.2 \
  http://expense.example.test:32136/
```

### Final verified state

- **Frontend Deployment:** `2/2` ready and available.
- **Frontend Pods:** Two `1/1 Running`, zero restarts.
- **Active image:** `1.0.4`.
- **Ingress response:** HTTP 200.

Some malformed curl attempts returned HTTP status `000` because shell commands were accidentally concatenated into the URL. The final correctly formed request returned HTTP 200 and is the result used for final verification.

## 12. Questions We Asked

- What does a Deployment do when the desired replica count changes?
- Does a new Deployment revision always mean a new application version?
- What does `kubectl rollout undo` restore?
- What happens when a managed Pod is deleted?
- What happens when a replacement image cannot be pulled?
- Does Kubernetes automatically roll back every failed rollout?

## 13. Lessons Learned

1. Deployments declare desired state; controllers reconcile actual state toward it.
2. Scaling changes the desired number of replicas.
3. Any Pod-template change can create a new ReplicaSet and revision.
4. A ReplicaSet replaces missing Pods to maintain its replica count.
5. A failed image pull can block a rollout while existing replicas remain available.
6. Rollback was an explicit recovery action in this experiment; it was not automatic.
7. Verify Deployment status, Pods, image, and real application access after each operation.
8. A successful command is not proof that the application is healthy.

## 14. Common Mistakes

- Changing the Deployment selector while experimenting with Pod labels.
- Assuming a new revision necessarily means a new image version.
- Assuming Kubernetes restores the exact same Pod after deletion.
- Treating `ImagePullBackOff` as an application-code error without checking the image name, tag, registry access, and pull credentials.
- Assuming every failed rollout automatically rolls back.
- Declaring recovery based only on the rollback command output.
- Confusing the last-applied configuration annotation with the current Pod template.

## 15. Best Practices

- Keep a known-good image version and record it before an update.
- Use controlled, reversible failure experiments in a lab.
- Observe rollout status, ReplicaSets, Pods, and application traffic together.
- Understand rollout strategy settings and percentage rounding for small replica counts.
- Use meaningful image tags and immutable digests in production workflows.
- Configure appropriate resource requests, limits, and health probes.
- Use explicit rollback procedures and verify the recovered version.
- Avoid leaving intentionally broken configurations in the cluster.

## 16. If I Were Interviewed

**How does Kubernetes self-heal a Deployment?**

A Deployment manages a ReplicaSet, which compares the desired replica count with the actual number of matching Pods. If a Pod is deleted, the ReplicaSet creates a replacement until the desired count is restored.

**What happens during a rolling update?**

A change to the Pod template creates a new ReplicaSet. Kubernetes gradually scales the new ReplicaSet up and the old ReplicaSet down according to the rollout strategy and readiness of the new Pods.

**What does `ImagePullBackOff` mean?**

Kubernetes cannot pull the requested image and is backing off between retries. The rollout may remain incomplete while old replicas continue serving traffic.

**Does Kubernetes automatically roll back a failed Deployment?**

Not by default simply because a rollout fails. In this experiment, the engineer initiated `kubectl rollout undo deployment/frontend` and verified the recovery.

**Why did changing a label create a revision?**

The label was part of `spec.template`, so the Pod template changed. Deployment revisions track Pod-template changes, not only container image changes.

## 17. Engineer's Takeaways

The goal of this milestone was not simply to run scaling and rollout commands. It was to observe controller behaviour and connect each result to desired state, reconciliation, availability, and recovery.

**Learn → Predict → Experiment → Observe → Recover → Verify → Document.**

## 18. Commands Used

### Scaling

```bash
kubectl scale deployment frontend --replicas=3
kubectl scale deployment frontend --replicas=2
kubectl get deployment frontend
kubectl get endpoints frontend
```

### Inspecting the Deployment and its history

```bash
kubectl get deployment frontend -o yaml
kubectl rollout history deployment/frontend
kubectl rollout history deployment/frontend --revision=1
```

### Observing rollouts and ReplicaSets

```bash
kubectl rollout status deployment/frontend
kubectl get rs
kubectl get pods -l app=frontend -o wide
```

### Rolling back

```bash
kubectl rollout undo deployment/frontend
```

### Testing self-healing

```bash
kubectl delete pod frontend-84849f767b-6tcgq
```

### Introducing and inspecting a controlled image-pull failure

```bash
kubectl set image deployment/frontend \
  frontend=748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:invalid-m08

kubectl rollout status deployment/frontend --timeout=20s
```

### Verifying the active image and application access

```bash
kubectl get deployment frontend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

curl -s -o /dev/null -w "HTTP status: %{http_code}\n" \
  --resolve expense.example.test:32136:192.168.49.2 \
  http://expense.example.test:32136/
```
