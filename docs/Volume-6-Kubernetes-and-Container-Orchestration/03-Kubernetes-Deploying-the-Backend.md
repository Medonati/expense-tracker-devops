# M03 — Deploying the Backend

## 1. Objective

The objective of this milestone was to deploy and manage the Expense Tracker backend using Kubernetes and understand how Kubernetes maintains the desired state of an application.

The milestone focused on:

* Deployments
* ReplicaSets
* Pods
* Pod templates
* Container images
* Environment configuration
* Rolling updates
* Liveness probes
* Readiness probes
* Container self-healing

The goal was not simply to deploy the backend, but to understand the relationship between these Kubernetes resources and observe their behaviour through controlled changes and failure.

---

## 2. Deployment Architecture

The backend follows this Kubernetes relationship:

```text
Deployment
    │
    ▼
ReplicaSet
    │
    ▼
Pods
    │
    ▼
Container
```

The Deployment defines the desired application state.

The ReplicaSet ensures that the desired number of Pods exists.

The Pods provide the execution environment for the backend container.

The container runs the backend application from the specified container image.

For the backend workload, the desired replica count was:

```text
3 replicas
```

---

## 3. Backend Deployment

The backend Deployment was already present in:

```text
kubernetes/backend/deployment.yaml
```

The Deployment uses:

```yaml
replicas: 3
```

and selects Pods using:

```yaml
selector:
  matchLabels:
    app: backend
```

The Pod template uses the matching label:

```yaml
labels:
  app: backend
```

This creates the relationship between the Deployment and the Pods it manages.

### Backend image

The backend runs from the ECR image:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4
```

The Deployment also uses the ECR image pull secret:

```yaml
imagePullSecrets:
- name: ecr-secret
```

---

## 4. Environment Configuration

The backend container receives its runtime configuration through environment variables:

```yaml
env:
- name: PORT
  value: "3000"
- name: MONGO_URL
  value: mongodb://mongodb:27017/expense
```

This demonstrates an important Kubernetes concept:

> Container images contain the application, while environment variables can provide runtime configuration.

Changing an environment variable changes the Pod template even when the container image itself remains unchanged.

Kubernetes therefore treats such a change as a new desired Pod configuration and performs a rollout.

---

## 5. Understanding the Pod Template

The Pod template is the blueprint Kubernetes uses when creating Pods.

For the backend, it contains information such as:

* Pod labels
* Container name
* Container image
* Environment variables
* Health probes
* Image pull configuration

The Deployment does not directly create individual Pods itself.

Instead:

```text
Deployment
    ↓
creates/manages ReplicaSet
    ↓
ReplicaSet creates/manages Pods
```

If the Pod template changes, Kubernetes creates a new ReplicaSet representing the new version of the template.

---

## 6. Rolling Updates

The backend Deployment uses the:

```text
RollingUpdate
```

strategy.

The configured strategy was:

```yaml
rollingUpdate:
  maxSurge: 25%
  maxUnavailable: 25%
```

During the milestone, changes to the Pod template caused Kubernetes to create new ReplicaSets and gradually replace Pods belonging to the previous ReplicaSet.

This was observed through rollout output such as:

```text
2 out of 3 new replicas have been updated
```

followed by:

```text
1 old replicas are pending termination
```

and finally:

```text
deployment "backend" successfully rolled out
```

The important lesson is that Kubernetes does not simply destroy all existing Pods and create all new Pods simultaneously.

The Deployment controller manages the transition between the old and new desired states.

---

## 7. ReplicaSet Observation

Before the final configuration, several historical ReplicaSets existed.

The final state showed:

```text
backend-77f54f76c7   3   3   3
```

while the previous backend ReplicaSets had:

```text
0   0   0
```

The active ReplicaSet therefore became:

```text
backend-77f54f76c7
```

with:

```text
DESIRED: 3
CURRENT: 3
READY: 3
```

The older ReplicaSets remained as historical revisions but were no longer running Pods.

This demonstrates that ReplicaSets also provide the mechanism through which Deployment revisions are represented.

---

## 8. Health Checks

A major part of this milestone was understanding that:

> A running container does not automatically mean the application is healthy or ready to receive traffic.

The backend exposes two relevant endpoints:

```text
/health
/ready
```

The distinction is:

```text
/health → Is the application alive?
/ready  → Is the application ready to receive traffic?
```

---

## 9. Liveness Probe

The liveness probe was configured as:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
```

The probe checks the backend every 10 seconds using the default configuration observed in the Deployment:

```text
delay=0s
timeout=1s
period=10s
success=1
failure=3
```

The purpose of the liveness probe is to determine whether Kubernetes should restart the container.

Conceptually:

```text
/health
   ↓
Application alive?
   ↓
No
   ↓
Liveness failure
   ↓
Container restarted
```

---

## 10. Readiness Probe

The readiness probe was initially configured to use `/health`.

It was later changed to the application's dedicated readiness endpoint:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 3000
```

The final configuration therefore became:

```text
Liveness  → /health
Readiness → /ready
```

This is a clearer separation of responsibilities.

The readiness probe answers:

> Is this application currently ready to receive traffic?

A readiness failure does not mean Kubernetes should restart the container.

Instead, the Pod can remain running while Kubernetes considers it unavailable for traffic.

---

## 11. Controlled Failure Observation

The liveness behaviour was observed through the actual Kubernetes events of a backend Pod.

The Pod reported:

```text
Restart Count: 4
```

and its previous container state showed:

```text
Last State:
  Terminated
  Reason: Error
  Exit Code: 1
```

More importantly, Kubernetes recorded:

```text
Liveness probe failed:
connect: connection refused
```

followed by:

```text
Container backend failed liveness probe, will be restarted
```

Kubernetes then recorded the container being:

```text
Created
Started
```

This demonstrated the difference between a container restart and Pod replacement.

---

## 12. Container Restart vs Pod Replacement

One of the most important lessons from this milestone was:

```text
Container failure
        ↓
Kubelet restarts container
        ↓
Same Pod remains
```

This is different from:

```text
Pod disappears/deleted
        ↓
ReplicaSet detects fewer Pods than desired
        ↓
Replacement Pod created
```

Therefore:

> A container restart does not necessarily mean that Kubernetes created a new Pod.

This distinction is fundamental to understanding Kubernetes self-healing.

---

## 13. Final Backend State

The final Deployment verification showed:

```text
NAME      READY   UP-TO-DATE   AVAILABLE
backend   3/3     3            3
```

The backend Pods were:

```text
backend-77f54f76c7-6c8w5   1/1   Running
backend-77f54f76c7-hbgvg   1/1   Running
backend-77f54f76c7-k6ph7   1/1   Running
```

The active ReplicaSet was:

```text
backend-77f54f76c7   3   3   3
```

The final health configuration was:

```text
Liveness  → /health
Readiness → /ready
```

---

## 14. Key Mental Model

The complete backend workload can now be represented as:

```text
Deployment
│
│ Desired state:
│ 3 replicas
│
▼
ReplicaSet
│
│ Maintains:
│ 3 Pods
│
├── Pod
│    └── Backend container
│         ├── Image
│         ├── Environment
│         ├── Liveness → /health
│         └── Readiness → /ready
│
├── Pod
│    └── Backend container
│
└── Pod
     └── Backend container
```

---

## 15. What I Learned

### Deployment

A Deployment defines the desired state and manages the lifecycle of the application workload.

### ReplicaSet

A ReplicaSet ensures that the desired number of Pods exists.

### Pod Template

The Pod template is the blueprint used to create Pods.

Changes to the template can create a new ReplicaSet and trigger a rollout.

### Rolling Update

A Deployment can gradually transition from an old Pod template to a new one without replacing all Pods simultaneously.

### Liveness

Liveness determines whether Kubernetes should restart a container.

```text
/health → Is it alive?
```

### Readiness

Readiness determines whether the application is ready to receive traffic.

```text
/ready → Is it ready?
```

### Self-Healing

Kubernetes can restart failed containers and ReplicaSets can recreate missing Pods to maintain the desired state.

---

## 16. Engineering Lesson

The most important lesson from this milestone was:

> **Kubernetes does not simply run containers. It continuously works to maintain the desired state defined by the workload configuration.**

The behaviour observed during this milestone demonstrated that Kubernetes can:

* Maintain three backend replicas
* Create new ReplicaSets when the Pod template changes
* Perform rolling updates
* Monitor application health
* Restart unhealthy containers
* Distinguish application liveness from readiness

The experiments provided evidence for these behaviours rather than relying only on theoretical explanations.

---

## 17. Verification

Final verification commands used:

```bash
kubectl get deployment backend
```

```bash
kubectl get pods -l app=backend
```

```bash
kubectl get replicasets
```

```bash
kubectl describe deployment backend
```

```bash
kubectl describe pod <backend-pod>
```

```bash
kubectl rollout status deployment/backend
```

Final state:

```text
Deployment: 3/3 available
Pods:       3/3 Running
ReplicaSet: 3/3 Ready
Liveness:   /health
Readiness:  /ready
```

---

## 18. Milestone Status

**Milestone 03 — Deploying the Backend: COMPLETE ✅**

The backend is now managed by a Kubernetes Deployment with three replicas, rolling updates, liveness checking, and readiness checking.

The next milestone is **M04 — Kubernetes Services & Networking**, where we will learn how applications communicate with Pods through stable Kubernetes networking rather than relying on temporary Pod identities.
