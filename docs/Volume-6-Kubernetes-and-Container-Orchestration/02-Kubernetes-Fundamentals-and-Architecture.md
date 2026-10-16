# Kubernetes Fundamentals and Architecture

## Volume 6 — Kubernetes & Container Orchestration

### Milestone 01 — Why Kubernetes? & Orchestration Fundamentals

---

## 1. Introduction

Before introducing Kubernetes, we first examined the engineering problem that orchestration is intended to solve.

A container can package and run an application, but operating an application reliably becomes more complicated when the workload needs:

* multiple instances
* scaling
* service discovery
* failure recovery
* workload placement
* controlled application updates
* consistent desired state

The goal of this milestone was therefore not simply to learn Kubernetes commands, but to understand **why orchestration exists and how Kubernetes solves these operational problems**.

The learning progression was:

```text
Application Capacity
        ↓
Why orchestration?
        ↓
Desired State
        ↓
Reconciliation
        ↓
Self-Healing
        ↓
Scaling
        ↓
Scheduling
        ↓
Service Discovery
        ↓
Rolling Updates
        ↓
Kubernetes Architecture
```

---

# 2. Why Kubernetes?

Docker allows us to package and run applications as containers.

Docker Compose allows us to define and run multiple related containers together.

However, as application environments become larger, additional operational problems appear.

For example:

```text
Application
│
├── Backend
│   ├── Instance 1
│   ├── Instance 2
│   └── Instance 3
│
├── Database
│
├── Frontend
│
└── Networking
```

Someone or something needs to continuously manage:

* how many application instances should exist
* where workloads should run
* what happens when an instance fails
* how new versions are deployed
* how services find each other
* how workloads are distributed across available infrastructure

This is where orchestration becomes valuable.

Kubernetes provides a system for **declaring the desired state of workloads and continuously working toward that state**.

---

# 3. Containers vs Orchestration

A container runtime is concerned primarily with running containers.

Orchestration operates at a higher level.

### Container

A container answers:

> How do I package and run this application?

### Orchestration

Orchestration answers questions such as:

> How many instances should run?

> Where should they run?

> What happens if one fails?

> How should a new version be introduced?

> How can other applications reliably reach these instances?

The distinction can be summarized as:

```text
Container
    ↓
Run application

Orchestrator
    ↓
Manage application workloads
```

Kubernetes is therefore not simply a replacement for Docker. It is a system for managing containerized workloads across a cluster.

---

# 4. Why Docker Compose Has Limits

Docker Compose was sufficient for our local full-stack environment.

Our application could be represented as:

```text
Frontend
Backend
MongoDB
```

and Compose could create the required containers and networking.

However, Compose primarily manages the environment on the machine where Compose is running.

As the environment becomes larger, we need capabilities such as:

* cluster-level scheduling
* multiple worker nodes
* automated reconciliation
* self-healing
* rolling updates
* service discovery
* workload scaling

Kubernetes is designed around these orchestration problems.

The important lesson is not:

> Docker Compose is bad.

Instead:

> Docker Compose and Kubernetes solve problems at different levels of operational complexity.

---

# 5. Capacity and Performance as an Engineering Problem

Before studying orchestration, we performed a controlled application capacity experiment.

The purpose was to understand an important principle:

> **Application capacity should be measured rather than assumed.**

We tested the backend under increasing concurrency and measured:

* throughput
* mean latency
* P95 latency
* P99 latency
* maximum latency
* failures

The `/health` endpoint initially handled increasing concurrency without failures.

At 500 concurrent requests:

```text
Requests:       10,000
Concurrency:    500
Throughput:     1,573.52 req/s
Mean latency:   317.76 ms
P95:            330 ms
P99:            334 ms
Failures:       0
```

At 1,000 concurrent requests:

```text
Requests:       10,000
Concurrency:    1,000
Throughput:     1,062.70 req/s
Mean latency:   941 ms
P95:            1,771 ms
P99:            7,618 ms
Max:            8,752 ms
Failures:       0
```

The important observation was that throughput eventually decreased while latency increased dramatically.

This demonstrated that:

> **Capacity is workload-dependent and degradation can appear before requests begin failing.**

We also tested a database-backed endpoint.

At 25 concurrent requests:

```text
Throughput:     322.09 req/s
Mean latency:   77.62 ms
P95:            103 ms
Failures:       0
```

At 500 concurrent requests:

```text
Throughput:     498.34 req/s
Mean latency:   1,003.33 ms
P95:            1,253 ms
P99:            1,392 ms
Max:            1,506 ms
Failures:       0
```

This reinforced the lesson that different workloads can have very different capacity characteristics.

The experiment helped establish the engineering problem that orchestration addresses: workloads may need to scale, recover, and be managed dynamically as demand and operating conditions change.

---

# 6. Desired State

One of Kubernetes' most important ideas is **desired state**.

Instead of manually telling Kubernetes every action it should perform, we describe the state we want.

For example:

```yaml
replicas: 3
```

means:

> I want three replicas of this workload.

We don't manually create:

```text
Pod 1
Pod 2
Pod 3
```

Instead, we describe the desired state.

Kubernetes then works to make reality match that state.

Conceptually:

```text
Desired State
      │
      ▼
"3 backend Pods"
      │
      ▼
Kubernetes
      │
      ▼
Actual State
```

---

# 7. Reconciliation

**Reconciliation** is the continuous process of bringing actual state toward desired state.

For example:

```text
Desired: 3 Pods
Actual:  3 Pods
```

Everything is aligned.

If one Pod disappears:

```text
Desired: 3 Pods
Actual:  2 Pods
```

Kubernetes detects the difference and takes action.

```text
Desired: 3
Actual:  2
   ↓
Reconciliation
   ↓
Replacement Pod
   ↓
Desired: 3
Actual:  3
```

This became one of the most important mental models of the milestone.

> Kubernetes is continuously working to make actual state match desired state.

---

# 8. Self-Healing

We performed a controlled failure experiment.

The backend Deployment was configured with:

```text
replicas: 3
```

We deliberately deleted one backend Pod.

Before failure:

```text
backend Pod
backend Pod
backend Pod
```

After deleting one:

```text
backend Pod
backend Pod
```

Kubernetes immediately created a replacement Pod.

The resulting state returned to:

```text
backend Pod
backend Pod
backend Pod
```

This demonstrated Kubernetes' self-healing behavior.

The important distinction is that Kubernetes did not magically prevent the Pod from being deleted.

Instead:

> Kubernetes detected that the actual state no longer matched the desired state and reconciled the difference.

---

# 9. Scaling

We changed the backend Deployment from:

```yaml
replicas: 1
```

to:

```yaml
replicas: 3
```

Kubernetes created the additional Pods.

This demonstrated declarative scaling.

Instead of manually starting two additional containers, we changed the desired state:

```text
1 replica
    ↓
3 replicas
```

Kubernetes handled the transition.

Scaling therefore connects directly to reconciliation.

---

# 10. Scheduling

Once Kubernetes needs to run a Pod, it must determine **where that Pod should run**.

This is the responsibility of the Kubernetes Scheduler.

Conceptually:

```text
New Pod
   │
   ▼
Scheduler
   │
   ├── Node 1
   ├── Node 2
   └── Node 3
```

The Scheduler evaluates available nodes and determines which nodes are suitable according to resource requirements and scheduling constraints.

Our Minikube cluster currently contains one node:

```text
minikube
```

We verified that all our Pods were running on this node.

```text
NAME                       NODE
backend-...                minikube
backend-...                minikube
backend-...                minikube
mongodb-...                minikube
```

Because our cluster has only one node, there was no meaningful multi-node placement decision to observe.

However, the mental model is:

> **Deployment determines what workload is required; Scheduler helps determine where a Pod should run.**

### What happens if no suitable node exists?

A Pod can remain:

```text
Pending
```

because Kubernetes cannot place it on a node that does not satisfy its requirements.

This is different from an application that starts and then crashes.

---

# 11. Service Discovery

Pods are temporary.

Their IP addresses can change when Pods are recreated.

Therefore, applications should not depend on a specific Pod IP.

Our backend connects to MongoDB using:

```text
mongodb:27017
```

rather than MongoDB's Pod IP.

We created a Kubernetes Service:

```text
Service:
mongodb
```

The Service had:

```text
ClusterIP: 10.100.16.154
Port:      27017
```

The current MongoDB Pod had:

```text
10.244.0.6:27017
```

The relationship was:

```text
Backend
   │
   │ mongodb:27017
   ▼
MongoDB Service
10.100.16.154:27017
   │
   ▼
MongoDB Pod
10.244.0.6:27017
```

If the MongoDB Pod changes IP, the backend can continue using:

```text
mongodb:27017
```

The Service provides the stable access point.

Therefore:

> **Service discovery allows applications to find workloads through stable Service names rather than relying on temporary Pod IP addresses.**

---

# 12. Kubernetes DNS

We verified that Kubernetes DNS allows the backend Pod to resolve:

```text
mongodb
```

to:

```text
10.100.16.154
```

The command returned:

```text
10.100.16.154 mongodb.default.svc.cluster.local
```

This demonstrated the relationship:

```text
mongodb
   ↓
mongodb.default.svc.cluster.local
   ↓
10.100.16.154
```

The fully qualified name can be understood as:

```text
mongodb.default.svc.cluster.local
│       │       │      │
│       │       │      └── cluster domain
│       │       └───────── Service
│       └───────────────── Namespace
└───────────────────────── Service name
```

This allows workloads to communicate using Kubernetes Service names.

---

# 13. Rolling Updates

We then explored how Kubernetes replaces an old application version with a new version.

Our original backend image was:

```text
1.0.4
```

We created a new ECR tag:

```text
1.0.5
```

For this controlled Kubernetes experiment, both tags intentionally pointed to the same image digest.

The purpose was to study the Kubernetes rollout mechanism rather than application changes.

The Deployment initially represented:

```text
3 replicas
image: 1.0.4
```

We then changed the live Deployment to:

```text
image: 1.0.5
```

Kubernetes began replacing the old Pods with Pods belonging to a new ReplicaSet.

We observed:

```text
1 out of 3 new replicas have been updated...
```

This demonstrated that Kubernetes did not simply remove all existing Pods simultaneously.

Instead, it progressively moved the workload toward the new desired state.

Conceptually:

```text
Before:

1.0.4
1.0.4
1.0.4

        ↓

Rolling Update

1.0.5
1.0.4
1.0.4

        ↓

1.0.5
1.0.5
1.0.4

        ↓

1.0.5
1.0.5
1.0.5
```

---

# 14. Controlled Rolling-Update Failure

The rolling-update experiment produced a real failure.

The new Pod entered:

```text
ImagePullBackOff
```

The Deployment eventually reported:

```text
deployment "backend" exceeded its progress deadline
```

We did not immediately change configuration.

Instead, we inspected the Pod events.

The important error was:

```text
403 Forbidden

denied: Your authorization token has expired.
Reauthenticate and try again.
```

This showed that the problem was not the Deployment itself.

The new Pod had been successfully scheduled:

```text
Successfully assigned ... to minikube
```

The failure occurred when Kubernetes attempted to pull the private ECR image.

The chain was:

```text
Deployment
    ↓
New ReplicaSet
    ↓
New Pod
    ↓
Scheduler assigns Pod
    ↓
Kubelet attempts ECR image pull
    ↓
ECR authentication token expired
    ↓
403 Forbidden
    ↓
ImagePullBackOff
    ↓
Rollout cannot progress
```

---

# 15. Refreshing the ECR Kubernetes Secret

The Kubernetes cluster used an `ecr-secret` for private ECR image authentication.

The secret contained an ECR authorization credential.

ECR authorization credentials are temporary.

We refreshed the Secret using a newly generated ECR password.

After updating the Secret, we deleted the failed Pod.

Because the Deployment still desired three replicas, Kubernetes created replacement Pods.

The replacement Pods successfully started:

```text
backend-69d45c8f67-k6s2n   1/1 Running
backend-69d45c8f67-ptbqs   1/1 Running
backend-69d45c8f67-wqxp7   1/1 Running
```

This was another practical demonstration of reconciliation.

We did not manually create the three replacement Pods.

Kubernetes restored the desired state.

---

# 16. Rolling Back to 1.0.4

After completing the experiment, we restored the repository configuration to:

```text
1.0.4
```

and applied:

```text
deployment.yaml
```

Kubernetes performed another rolling transition.

The rollout completed successfully:

```text
deployment "backend" successfully rolled out
```

The live Deployment was then verified as:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4
```

This brought the live cluster back in line with the repository configuration.

---

# 17. Deployment, ReplicaSet and Pod Relationship

During the experiment, we observed several ReplicaSets:

```text
backend-5df9cb8dd8
backend-69d45c8f67
...
```

The important relationship is:

```text
Deployment
    │
    ├── ReplicaSet
    │      │
    │      └── Pods
    │
    └── Previous ReplicaSets
```

When the Deployment changed from `1.0.4` to `1.0.5`, Kubernetes created a new ReplicaSet.

When we returned to the exact `1.0.4` Pod template, Kubernetes was able to use the existing ReplicaSet associated with that template again.

This explained why the Pod names returned to:

```text
backend-5df9cb8dd8-...
```

The value:

```text
5df9cb8dd8
```

is a ReplicaSet/Pod-template hash.

It is **not the image version**.

Therefore:

```text
ReplicaSet hash     Image
5df9cb8dd8           1.0.4
69d45c8f67           1.0.5
```

The ReplicaSet object for the previous version can remain in the cluster with zero replicas, allowing Kubernetes to retain rollout history.

---

# 18. Live Cluster State vs Configuration File

An important DevOps lesson came from using:

```bash
kubectl set image
```

This changes the live Kubernetes resource.

It does **not** automatically modify:

```text
kubernetes/backend/deployment.yaml
```

This can create configuration drift:

```text
Git / YAML
    ↓
1.0.4

Cluster
    ↓
1.0.5
```

For a production-style declarative workflow, the configuration file should normally be updated and committed:

```text
deployment.yaml
    ↓
change 1.0.4 → 1.0.5
    ↓
Git commit
    ↓
CI/CD or deployment process
    ↓
Kubernetes
```

For this milestone, `kubectl set image` was intentionally used as an experiment to understand the live Kubernetes mechanism.

---

# 19. Kubernetes Architecture

The final concept in M01 was the conceptual architecture of Kubernetes.

At a high level:

```text
                         YOU
                          │
                       kubectl
                          │
                          ▼
                    ┌───────────┐
                    │ API SERVER│
                    └─────┬─────┘
                          │
                 ┌────────┼────────┐
                 │        │        │
                 ▼        ▼        ▼
               etcd   Scheduler Controllers
                 │        │        │
                 │        │        │
                 │        │        ▼
                 │        │   Reconciliation
                 │        │
                 │        ▼
                 │    Pod placement
                 │
                 ▼
            Cluster State
                          │
                          ▼
                   Worker Node
                          │
                    ┌─────┴─────┐
                    ▼           ▼
                   Pod         Pod
                    │           │
                Container   Container
```





                         YOU
                          │
                          │ kubectl
                          ▼
                   ┌─────────────┐
                   │ API SERVER  │
                   │             │
                   │ Front Door  │
                   └──────┬──────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
              ▼           ▼           ▼
            etcd      Scheduler   Controllers
              │           │           │
              │           │           │
              │           │           ▼
              │           │      Desired vs Actual
              │           │        Reconciliation
              │           │
              │           ▼
              │      Pod placement
              │
              ▼
        Cluster State
                          │
                          ▼
                  ┌───────────────┐
                  │  Worker Node  │
                  │               │
                  │   ┌───────┐   │
                  │   │  Pod  │   │
                  │   └───────┘   │
                  │               │
                  │   ┌───────┐   │
                  │   │  Pod  │   │
                  │   └───────┘   │
                  └───────────────┘
## API Server

The API Server is the central communication interface of Kubernetes.

`kubectl` communicates with the API Server rather than directly communicating with individual control-plane components.

For example:

```text
kubectl get pods
       ↓
API Server
       ↓
Kubernetes cluster state
       ↓
API Server
       ↓
kubectl
```

The API Server is therefore often described as the **front door of the Kubernetes control plane**.

---

## etcd

`etcd` is Kubernetes' key-value store for cluster state.

It stores information Kubernetes needs to manage the cluster, including desired configuration and information about Kubernetes objects.

Important distinction:

```text
etcd
→ Kubernetes cluster state

MongoDB
→ Expense Tracker application data
```

They serve completely different purposes.

---

## Scheduler

The Scheduler determines where unscheduled Pods should run.

It evaluates available nodes and determines suitable placement according to resources and scheduling constraints.

```text
Pod needs placement
       ↓
Scheduler
       ↓
Suitable Node
       ↓
Pod assigned
```

---

## Controllers

Controllers are responsible for continuously reconciling actual state toward desired state.

For example:

```text
Desired: 3 Pods
Actual:  2 Pods
     ↓
Controller
     ↓
Replacement Pod
     ↓
Desired: 3
Actual: 3
```

Controllers are therefore central to Kubernetes' reconciliation model.

---

# 20. Control Plane and Worker Nodes

A Kubernetes cluster can be understood as two broad areas:

```text
Kubernetes Cluster
│
├── Control Plane
│
└── Worker Nodes
```

### Control Plane

The control plane contains the components responsible for managing the cluster.

Major components discussed:

* API Server
* etcd
* Scheduler
* Controllers

### Worker Node

Worker nodes provide the environment where application workloads run.

Conceptually:

```text
Worker Node
│
├── Backend Pod
│
├── Backend Pod
│
└── MongoDB Pod
```

Our Minikube lab uses a compact single-node environment, so the same node performs the control-plane role while also running our application workloads.

---

# 21. M01 Engineering Mental Model

The main lesson from this milestone is that Kubernetes should not be understood as a collection of commands.

The deeper model is:

```text
                Desired State
                     │
                     ▼
                API Server
                     │
                     ▼
                    etcd
                     │
                     ▼
                Controllers
                     │
              Reconciliation
                     │
                     ▼
                Scheduler
                     │
               Pod placement
                     │
                     ▼
                Worker Node
                     │
                     ▼
                    Pods
                     │
                     ▼
              Application Workload
```

Services provide stable networking around the workloads, while Deployments and ReplicaSets manage application instances and controlled transitions.

The central principle is:

> **Describe what the system should look like, and Kubernetes continuously works to make reality match that desired state.**

---

# 22. Key Engineering Lessons

### 1. Don't confuse a Pod with a container

A Pod is the smallest unit Kubernetes manages for running application workloads.

Containers run inside Pods.

### 2. Don't confuse a Service with a Pod

A Service provides stable access to Pods.

Pods themselves are temporary.

### 3. Don't rely on Pod IPs

Pod IPs can change.

Use Kubernetes Services and DNS for stable application communication.

### 4. Running does not automatically mean healthy

A Pod can exist and be running while the application inside it still has problems.

Application health and Kubernetes state must be observed separately.

### 5. Scheduling and reconciliation solve different problems

Scheduler:

> Where should the Pod run?

Controllers/reconciliation:

> Does actual state match desired state?

### 6. Live cluster state and Git configuration can diverge

Commands such as:

```bash
kubectl set image
```

can modify live state without modifying the YAML stored in Git.

Production-style workflows should maintain a controlled source of truth.

### 7. Failure is useful

The ECR authentication failure gave us a real troubleshooting sequence:

```text
ImagePullBackOff
      ↓
Inspect Events
      ↓
403 Forbidden
      ↓
Expired ECR token
      ↓
Refresh Secret
      ↓
Recreate failed Pod
      ↓
Successful rollout
```

The failure was more educational than a perfectly clean deployment would have been.

---

# 23. M01 Completion Checklist

* [x] Containers vs orchestration
* [x] Why Docker Compose has limits
* [x] Desired state
* [x] Reconciliation
* [x] Self-healing
* [x] Scaling
* [x] Scheduling
* [x] Service discovery
* [x] Kubernetes DNS
* [x] Rolling updates
* [x] Kubernetes architecture at a conceptual level
* [x] API Server
* [x] etcd
* [x] Scheduler
* [x] Controllers
* [x] Control Plane
* [x] Worker Nodes
* [x] Deployment → ReplicaSet → Pod relationship
* [x] Controlled rolling-update failure
* [x] ECR authentication troubleshooting
* [x] Rollback to version 1.0.4

**Milestone 01 is complete.**

---

# 24. Practical Commands & Code Used

The following commands represent the important commands used during this milestone.

## Cluster and Node Inspection

```bash
kubectl get nodes
```

```bash
kubectl get pods
```

```bash
kubectl get pods -o wide
```

---

## Deployment Inspection

```bash
kubectl get deployment backend
```

```bash
kubectl get deployment backend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

---

## Scaling

```bash
kubectl scale deployment backend --replicas=3
```

---

## Pod Failure / Self-Healing

```bash
kubectl delete pod <pod-name>
```

---

## Service Discovery

```bash
kubectl get service mongodb
```

```bash
kubectl get endpoints mongodb
```

```bash
kubectl exec <backend-pod> -- getent hosts mongodb
```

Example result:

```text
10.100.16.154 mongodb.default.svc.cluster.local
```

---

## Rolling Update

Create a second tag from the existing image:

```bash
docker tag expense-tracker-dev-backend:1.0.4 \
  expense-tracker-dev-backend:1.0.5
```

Tag it for ECR:

```bash
docker tag expense-tracker-dev-backend:1.0.5 \
  ecr.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.5
```

Push to ECR:

```bash
docker push \
  ecr.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.5
```

Verify the ECR image:

```bash
aws ecr describe-images \
  --repository-name expense-tracker-dev-backend \
  --image-ids imageTag=1.0.5 \
  --region us-east-1
```

Update the live Deployment:

```bash
kubectl set image deployment/backend \
  backend=ecr.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.5
```

Observe rollout:

```bash
kubectl rollout status deployment/backend
```

---

## Inspecting Rollout Failures

```bash
kubectl describe pod <pod-name>
```

```bash
kubectl get pods
```

---

## Refreshing the ECR Secret

```bash
ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)

kubectl create secret docker-registry ecr-secret \
  --docker-server=ecr.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

After refreshing the credential, the failed Pod was deleted so that Kubernetes could create a fresh Pod using the updated Secret:

```bash
kubectl delete pod <failed-pod-name>
```

---

## Declarative Rollback

The repository `deployment.yaml` was restored to:

```yaml
image: ecr.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4
```

Then:

```bash
kubectl apply -f kubernetes/backend/deployment.yaml
```

Rollout verification:

```bash
kubectl rollout status deployment/backend
```

---

## ReplicaSet Inspection

```bash
kubectl get rs
```

This was used to observe the relationship between Deployment revisions and ReplicaSets.

---

## Final Image Verification

```bash
kubectl get deployment backend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
---

## Final State

At the end of M01:

```text
Deployment: backend
Image:      1.0.4
Replicas:   3
Ready:      3
Available:  3
```

The Kubernetes lab was returned to the `1.0.4` application state after the rolling-update experiment.