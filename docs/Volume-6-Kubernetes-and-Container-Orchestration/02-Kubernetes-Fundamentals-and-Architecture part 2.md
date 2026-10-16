# Kubernetes Fundamentals and Architecture

## Volume 6 — Kubernetes & Container Orchestration

### Milestone 02 — Kubernetes Cluster & Core Concepts

---

## 1. Milestone Objective

The objective of this milestone was to build a foundational understanding of Kubernetes architecture before introducing more advanced Kubernetes resources.

The focus was on understanding:

* Kubernetes clusters
* Control planes
* Worker nodes
* Pods
* Containers
* `kubectl`
* Kubernetes API Server
* Namespaces
* The relationship between these components

The goal was not to memorize Kubernetes commands, but to build a mental model of how the components fit together.

---

# 2. Kubernetes Cluster

A **Kubernetes cluster** is the overall environment used to manage and run containerized workloads.

A cluster contains one or more nodes.

Conceptually:

```text
Kubernetes Cluster
        │
        ├── Control Plane
        │
        └── Worker Nodes
              │
              └── Pods
                    │
                    └── Containers
```

A production Kubernetes environment can contain multiple worker nodes, allowing workloads to be distributed across machines.

For this lab, however, Minikube provides a single-node Kubernetes cluster.

---

# 3. Control Plane

The **control plane** is responsible for managing the Kubernetes cluster.

It is the management and decision-making side of Kubernetes.

The control plane is responsible for tasks such as:

* managing the cluster
* maintaining the desired state
* responding to changes in the cluster
* coordinating workloads

The simplified mental model used during this milestone was:

```text
Control Plane
      │
      └── Manages the cluster
```

The control plane should be distinguished from the machines that primarily provide the environment where application workloads run.

---

# 4. Worker Nodes

A **node** provides the environment and resources where Kubernetes workloads can run.

A worker node can run Pods containing application containers.

Conceptually:

```text
Worker Node
    │
    ├── Pod
    │    └── Container
    │
    ├── Pod
    │    └── Container
    │
    └── Pod
         └── Container
```

In larger Kubernetes environments, control-plane and worker responsibilities are commonly separated across nodes.

Our Minikube environment is intentionally simpler.

---

# 5. The Minikube Cluster

The lab uses Minikube to provide a local Kubernetes environment.

The cluster was verified with:

```bash
kubectl get nodes
```

The result was:

```text
NAME       STATUS   ROLES           AGE    VERSION
minikube   Ready    control-plane   7d1h   v1.37.0
```

This showed that the cluster currently consists of one node:

```text
minikube
```

The node was:

```text
STATUS: Ready
ROLES: control-plane
VERSION: v1.37.0
```

Because this is a single-node Minikube cluster, the same node can provide the control-plane role while also providing the environment where workloads run.

The simplified architecture is therefore:

```text
Minikube Cluster
       │
       └── Minikube Node
             │
             ├── Control Plane responsibilities
             │
             └── Application workloads
```

This is a development-oriented architecture and should not be confused with a typical production cluster containing dedicated control-plane and worker nodes.

---

# 6. Pods

A **Pod is the smallest deployable unit in Kubernetes.**

Kubernetes does not use the individual container as its primary deployment abstraction.

Instead:

```text
Kubernetes
     │
     ▼
   Pod
     │
     ▼
 Container
```

A Pod can contain one or more containers.

For most of our application workloads, we are using one container per Pod:

```text
Backend Pod
    │
    └── Backend container
```

However, Kubernetes allows multiple closely associated containers to exist within the same Pod.

For example:

```text
Pod
├── Application container
└── Supporting container
```

Containers within the same Pod share the Pod's networking environment and can share configured storage.

The important distinction is:

> A Pod is not a container. A Pod is the Kubernetes unit that runs one or more closely related containers.

---

# 7. Pod Lifecycle and Temporary IP Addresses

Pods should be treated as **temporary workloads**.

A Pod can be terminated, recreated, rescheduled, or replaced.

Because Pods are temporary, their IP addresses should also be considered temporary.

For example:

```text
Pod A
IP: 10.244.x.x
```

If Pod A is replaced:

```text
Pod A
   ↓
terminated

Pod B
IP: 10.244.y.y
```

The replacement Pod does not have to receive the same IP address.

This is one of the reasons Kubernetes networking requires a stable abstraction such as a **Service**, which will be explored in a later milestone.

The mental model established was:

```text
Pod
  ↓
Temporary workload
  ↓
Temporary IP
```

while:

```text
Service
  ↓
Stable access to Pods
```

Service networking is intentionally deferred to **Milestone 04 — Kubernetes Services & Networking**.

---

# 8. Why Kubernetes Manages Pods Instead of Containers Directly

A key question in this milestone was:

> Why doesn't Kubernetes simply manage containers directly?

The answer developed during the session was that Kubernetes needs a higher-level unit for managing workloads.

A Pod provides a management boundary around one or more containers and provides the environment in which those containers operate.

This allows Kubernetes to manage concepts such as:

* workload lifecycle
* networking
* storage
* grouping of closely related containers

Therefore:

```text
Container
```

is the runtime unit, while:

```text
Pod
```

is the Kubernetes deployment and management unit.

A Pod may contain one container or multiple closely associated containers.

---

# 9. kubectl

`kubectl` is the command-line client used to communicate with Kubernetes.

The simplified communication model is:

```text
User
  │
  │ kubectl command
  ▼
Kubernetes API Server
  │
  ▼
Kubernetes Cluster
```

For example:

```bash
kubectl get nodes
```

does not directly communicate with a worker node.

Instead, `kubectl` sends the request to the **Kubernetes API Server**.

The API Server is the main interface through which Kubernetes resources and cluster operations are accessed.

Therefore:

> `kubectl` is the client; the Kubernetes API Server is the interface through which the client communicates with the cluster.

---

# 10. Namespaces

A **Namespace** is a logical boundary used to organize and separate Kubernetes resources within the same cluster.

Namespaces allow multiple workloads, teams, or environments to be logically separated without requiring separate Kubernetes clusters.

For example:

```text
Cluster
│
├── development
│     ├── backend
│     └── frontend
│
├── staging
│     ├── backend
│     └── frontend
│
└── production
      ├── backend
      └── frontend
```

Namespaces are therefore more than naming.

They can be used for:

* organizing resources
* separating environments or teams
* applying access controls and policies
* managing resource quotas

A Namespace is **not a machine**.

Multiple namespaces can exist within the same Kubernetes cluster.

---

# 11. Kubernetes Default Namespaces

The existing cluster was inspected with:

```bash
kubectl get namespaces
```

The result was:

```text
NAME              STATUS   AGE
default           Active   7d1h
kube-node-lease   Active   7d1h
kube-public       Active   7d1h
kube-system       Active   7d1h
```

### `default`

The `default` namespace is used when no namespace is explicitly specified.

For example:

```bash
kubectl get pods
```

queries the Pods in the `default` namespace unless another namespace is specified.

Our application workloads currently reside in this namespace.

### `kube-system`

This namespace contains Kubernetes system components and cluster infrastructure.

Application workloads should generally not be placed here.

### `kube-public`

This namespace is intended for resources that are publicly readable within the cluster.

It is not being used for our application workloads.

### `kube-node-lease`

This namespace contains node lease information used by Kubernetes as part of node health and availability tracking.

The application does not deploy its workloads into this namespace.

---

# 12. Our Current Kubernetes Workloads

The current cluster was inspected with:

```bash
kubectl get pods
```

The result was:

```text
NAME                       READY   STATUS    RESTARTS      AGE
backend-5df9cb8dd8-fsbsm   1/1     Running   1 (21m ago)   3d21h
backend-5df9cb8dd8-hllfs   1/1     Running   1 (21m ago)   3d21h
backend-5df9cb8dd8-kcwc7   1/1     Running   1 (21m ago)   3d21h
mongodb-57994ccb8d-8dmg2   1/1     Running   1 (21m ago)   6d23h
```

This demonstrates the architecture we have been learning.

The backend Deployment is configured with three replicas, resulting in three backend Pods:

```text
Backend
├── Pod 1
│    └── Backend container
│
├── Pod 2
│    └── Backend container
│
└── Pod 3
     └── Backend container
```

MongoDB currently has one Pod:

```text
MongoDB
└── MongoDB container
```

Each of these Pods currently contains one container.

The `1/1` value in the `READY` column indicates that one expected container in each Pod is ready.

---

# 13. Container Restart vs Pod Replacement

An important observation from the current cluster was the `RESTARTS` column:

```text
RESTARTS
1 (21m ago)
```

A container can restart while the Pod itself remains in existence.

Therefore:

> A container restart does not necessarily mean that Kubernetes created a new Pod.

This distinction is important.

A simplified example:

```text
Existing Pod
    │
    └── Container crashes
            │
            ▼
       Container restarts
            │
            ▼
       Same Pod remains
```

This is different from a Pod being removed and Kubernetes creating a replacement Pod.

The latter behavior is tied to Kubernetes' reconciliation and self-healing mechanisms, which will be explored further in later milestones.

---

# 14. Troubleshooting During M02

During the milestone, the existing Minikube cluster became unavailable.

The first symptom appeared when running:

```bash
kubectl get nodes
```

which returned:

```text
The connection to the server 192.168.49.2:8443 was refused
```

Instead of immediately recreating the cluster, the failure was investigated systematically.

### Step 1 — Check Minikube

```bash
minikube status
```

Initially, Minikube could not inspect its Docker container and eventually reported a timeout.

### Step 2 — Check Docker

```bash
docker info
```

Docker itself responded normally.

The VM had:

```text
CPUs: 2
Total Memory: 2.899GiB
```

### Step 3 — Inspect containers

```bash
docker ps
docker ps -a
```

The Minikube container was found stopped:

```text
minikube
Exited (255)
```

### Step 4 — Inspect container state

```bash
docker inspect minikube \
  --format='{{.State.ExitCode}} | {{.State.Error}} | {{.State.FinishedAt}}'
```

Result:

```text
255 |  | 2026-09-25T11:15:17.847111171Z
```

Docker did not report a container-level error.

### Step 5 — Inspect Minikube logs

```bash
docker logs --tail 100 minikube
```

The logs showed repeated failures involving:

```text
systemd-journald.service
```

including:

```text
Main process exited, code=dumped, status=6/ABRT
Failed with result 'watchdog'
```

and repeated restart attempts.

The logs eventually showed watchdog timeouts and process termination.

### Step 6 — Check memory

```bash
free -h
```

The VM currently showed:

```text
Total:       2.9Gi
Used:        768Mi
Free:        183Mi
Available:   2.0Gi
Swap:        0B
```

This did not establish that the VM was currently experiencing memory exhaustion.

### Step 7 — Check for Docker OOM termination

```bash
docker inspect minikube \
  --format='OOMKilled={{.State.OOMKilled}} | Error={{.State.Error}} | ExitCode={{.State.ExitCode}}'
```

Result:

```text
OOMKilled=false | Error= | ExitCode=255
```

Therefore, there was no evidence that Docker killed the Minikube container because of an out-of-memory event.

### Step 8 — Restart the existing Minikube cluster

The existing cluster was restarted with:

```bash
minikube start --driver=docker --memory=2048
```

Minikube reported some startup warnings involving the storage addons and control-plane communication.

However, the final status check showed:

```text
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

The cluster was therefore operational again.

---

# 15. Engineering Lesson from the Failure

The troubleshooting process reinforced the project's:

> **Verify Before Assuming**

principle.

The initial Kubernetes error did not immediately tell us the root cause.

Instead, we moved through the system layer by layer:

```text
kubectl
   ↓
Kubernetes API Server
   ↓
Minikube
   ↓
Docker container
   ↓
Minikube internal processes
```

We did not conclude that memory was the cause simply because Minikube produced a memory warning.

The evidence showed:

```text
Minikube container stopped
        ↓
Exit code 255
        ↓
Repeated journald watchdog failures
        ↓
OOMKilled=false
```

The exact underlying cause of the journald failure was not established, so it was not recorded as a confirmed root cause.

This is an important engineering distinction:

> **Observed evidence should be separated from hypotheses that have not been proven.**

---

# 16. Final Architecture Mental Model

The complete mental model developed during M02 is:

```text
                    Kubernetes Cluster
                           │
             ┌─────────────┴─────────────┐
             │                           │
        Control Plane                  Node
        (management)              (runs workloads)
                                         │
                              ┌──────────┼──────────┐
                              │          │          │
                           Backend    Backend    Backend
                            Pod        Pod        Pod
                              │          │          │
                           Container  Container  Container
                                         
                                         │
                                      MongoDB
                                        Pod
                                         │
                                      Container
```

Alongside this architecture:

```text
User
 │
 │ kubectl
 ▼
Kubernetes API Server
 │
 ▼
Cluster
```

And:

```text
Namespace
    ↓
Logical organization/separation
    ↓
Resources
    ↓
Pods / Services / Deployments / etc.
```

---

# 17. Key Takeaways

By the end of M02, the following concepts were established:

1. A **Kubernetes cluster** is the overall environment for managing containerized workloads.
2. A **control plane** manages and makes decisions for the cluster.
3. A **node** provides the environment where Pods can run.
4. A **Pod** is the smallest deployable Kubernetes unit.
5. A Pod can contain one or more closely associated containers.
6. A Pod is not the same thing as a container.
7. Pods are temporary, so their IP addresses should also be treated as temporary.
8. `kubectl` is a client used to communicate with the Kubernetes API Server.
9. A **Namespace** provides logical organization and separation of Kubernetes resources.
10. Multiple namespaces can exist inside the same cluster.
11. A container can restart without the Pod necessarily being replaced.
12. Our Minikube environment currently consists of one node performing both control-plane and workload responsibilities.
13. The current application has three backend Pods and one MongoDB Pod.
14. Troubleshooting should proceed from evidence rather than assumptions.

---

# 18. M02 Completion

**Milestone:** M02 — Kubernetes Cluster & Core Concepts

**Status:** Complete ✅

The foundational Kubernetes architecture is now understood and verified against the actual Minikube environment.

### Next milestone

**M03 — Deploying the Backend**

Topics:

* Deployments
* ReplicaSets
* Pods
* Container images
* Environment configuration
* Health probes

The next milestone will move from understanding Kubernetes architecture to understanding **how Kubernetes manages application workloads through Deployments and ReplicaSets**.
