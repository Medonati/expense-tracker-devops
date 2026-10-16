# M04 — Kubernetes Services & Networking

## 1. Objective

The objective of this milestone was to understand how Kubernetes provides stable network access to Pods whose individual identities and IP addresses can change.

The milestone focused on:

* ClusterIP
* Service discovery
* Service ports
* Frontend → backend communication
* Kubernetes DNS

The goal was to understand why applications should communicate through a Kubernetes Service rather than directly through temporary Pod IP addresses.

---

## 2. The Networking Problem

Pods are temporary Kubernetes resources.

A backend Pod may have an IP address such as:

```text
10.244.0.13
```

If that Pod is deleted and Kubernetes creates a replacement, the replacement can receive a different IP address.

For example:

```text
Original Pod
10.244.0.13
      ↓
Pod deleted
      ↓
Replacement Pod
10.244.0.16
```

An application that directly depended on `10.244.0.13` would therefore become unreliable.

The engineering problem is:

> How can another application reliably communicate with a group of Pods whose individual IP addresses can change?

Kubernetes solves this problem with a **Service**.

---

## 3. Service Mental Model

The relationship is:

```text
Service
   │
   ├── Pod
   ├── Pod
   └── Pod
```

The Service provides a stable network identity while Kubernetes maintains the set of backend Pods behind it.

This creates a separation between:

```text
Application identity
        ↓
Service

Workload instances
        ↓
Pods
```

The application communicates with the Service rather than individual Pod IP addresses.

---

## 4. Backend Service

The existing backend Service is defined in:

```text
kubernetes/backend/service.yaml
```

The configuration is:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: backend

spec:
  selector:
    app: backend

  ports:
    - port: 3000
      targetPort: 3000
```

The Service is therefore named:

```text
backend
```

and selects Pods with:

```text
app=backend
```

---

## 5. Service Selectors

The backend Deployment creates Pods with:

```yaml
labels:
  app: backend
```

The Service uses:

```yaml
selector:
  app: backend
```

This establishes the relationship:

```text
Service
   │
   │ selector: app=backend
   │
   ▼
Pods with app=backend
```

The Service does not need to know the individual Pod names.

If a Pod is removed and a replacement Pod receives the same `app=backend` label, Kubernetes can include the replacement in the Service's current endpoints.

---

## 6. ClusterIP

The backend Service was verified with:

```bash
kubectl get service backend
```

The observed configuration included:

```text
NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
backend   ClusterIP   10.104.64.114   <none>        3000/TCP
```

The Service type is:

```text
ClusterIP
```

This provides a stable virtual IP for communication **inside the Kubernetes cluster**.

The observed ClusterIP was:

```text
10.104.64.114
```

This is different from the individual Pod IPs.

Conceptually:

```text
Pod IP
10.244.x.x
    ↓
Identifies an individual Pod

ClusterIP
10.104.64.114
    ↓
Identifies the Service
```

---

## 7. Service Ports

The backend Service contains:

```yaml
ports:
  - port: 3000
    targetPort: 3000
```

These two values have different responsibilities.

### `port`

```yaml
port: 3000
```

This is the port exposed by the Service.

A client inside the cluster can therefore use:

```text
backend:3000
```

### `targetPort`

```yaml
targetPort: 3000
```

This is the port on the selected backend Pods where the Service forwards traffic.

The relationship is:

```text
Client
   │
   │ backend:3000
   ▼
Service
   │
   │ port: 3000
   ▼
targetPort: 3000
   │
   ▼
Backend container
```

In this application both values happen to be `3000`, but they represent different concepts.

---

## 8. Service Endpoints

The backend Service was inspected using:

```bash
kubectl get endpoints backend
```

At one point, the Service endpoints included:

```text
10.244.0.13:3000
10.244.0.14:3000
10.244.0.15:3000
```

After a backend Pod was deleted and replaced, the endpoint set changed to reflect the new Pod.

The modern EndpointSlice mechanism was also inspected:

```bash
kubectl get endpointslice -l kubernetes.io/service-name=backend
```

The EndpointSlice ultimately showed:

```text
10.244.0.3:3000
10.244.0.2:3000
10.244.0.7:3000
```

These corresponded to the current backend Pods:

```text
backend-77f54f76c7-hbgvg → 10.244.0.3
backend-77f54f76c7-tx7fz  → 10.244.0.2
backend-77f54f76c7-x7hw5  → 10.244.0.7
```

This demonstrated that the Service's endpoint set follows the current backend workload rather than being permanently tied to specific Pod identities.

---

## 9. Controlled Pod Replacement Experiment

A backend Pod was deliberately deleted:

```text
backend-77f54f76c7-k6ph7
```

Kubernetes then created a replacement:

```text
backend-77f54f76c7-x7hw5
```

The replacement eventually became:

```text
1/1 Running
```

The experiment demonstrated:

```text
Backend Pod deleted
        ↓
ReplicaSet detects fewer than 3 Pods
        ↓
Replacement Pod created
        ↓
Replacement becomes Ready
        ↓
Service endpoint set updated
```

The important distinction is:

> The Deployment/ReplicaSet maintains the Pods, while the Service provides stable access to the current Pods.

---

## 10. Kubernetes DNS

Kubernetes provides DNS-based discovery for Services.

The backend Service has the fully qualified DNS name:

```text
backend.default.svc.cluster.local
```

From a backend Pod, DNS resolution was tested with:

```bash
kubectl exec -it backend-77f54f76c7-6c8w5 -- getent hosts backend
```

The result was:

```text
10.104.64.114   backend.default.svc.cluster.local
```

This verified that:

```text
backend
    ↓
backend.default.svc.cluster.local
    ↓
10.104.64.114
```

Therefore, applications inside the same namespace can use the shorter Service name:

```text
backend
```

instead of hard-coding the ClusterIP.

---

## 11. Backend Communication Through the Service

The Service was tested directly from a backend Pod.

The request was:

```text
http://backend:3000/health
```

The result was:

```text
STATUS: 200
BODY: {"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This demonstrated that traffic could travel through the Service using its DNS name.

The complete path was:

```text
Backend Pod
    │
    │ http://backend:3000/health
    ▼
Kubernetes DNS
    │
    ▼
Backend Service
    │
    ▼
Backend endpoint
    │
    ▼
/health
    │
    ▼
HTTP 200
```

Repeated requests were also sent through:

```text
backend:3000
```

Twenty requests were successfully completed:

```text
20 requests
20 successful
0 errors
```

The test demonstrated successful repeated routing through the Service.

However, because the `/health` response does not identify which backend Pod handled each request, the experiment did **not** establish an exact per-Pod traffic distribution pattern.

This distinction is important:

> Successful Service routing was observed; even distribution across individual Pods was not directly measured.

---

## 12. Service Configuration Verification

The final Service configuration was inspected using:

```bash
kubectl describe service backend
```

The observed configuration included:

```text
Selector:                app=backend
Type:                    ClusterIP
IP:                      10.104.64.114
Port:                    3000/TCP
TargetPort:              3000/TCP
Endpoints:               10.244.0.3:3000,
                         10.244.0.2:3000,
                         10.244.0.7:3000
Session Affinity:        None
Internal Traffic Policy: Cluster
```

This confirmed the complete Service configuration.

---

## 13. Frontend → Backend Communication

The frontend source code was inspected to determine how it obtains the backend address.

The relevant file is:

```text
app/frontend/src/utils/ApiRequest.js
```

The frontend uses:

```javascript
const host = process.env.REACT_APP_API_URL;
```

The previous local-development configuration was present as a commented example:

```javascript
// const host = "http://localhost:5000";
```

This means the frontend is designed to receive its backend address through the `REACT_APP_API_URL` configuration rather than permanently depending on a Pod IP.

For Kubernetes internal communication, the backend Service provides the logical destination:

```text
http://backend:3000
```

Conceptually:

```text
Frontend
    │
    │ http://backend:3000
    ▼
Backend Service
    │
    ├── Backend Pod
    ├── Backend Pod
    └── Backend Pod
```

The frontend therefore does not need to know the individual backend Pod IP addresses.

---

## 14. Important Boundary

The Service name:

```text
backend:3000
```

is intended for communication **inside the Kubernetes cluster**.

A browser running outside the cluster cannot automatically resolve the Kubernetes Service name `backend`.

External application access is a separate concern and will be addressed later through:

**M07 — Ingress & External Access**

M04 therefore focuses on internal Kubernetes networking.

---

## 15. What I Learned

### Service

A Service provides stable network access to a group of Pods.

### ClusterIP

ClusterIP provides a stable virtual IP for internal cluster communication.

### Selector

A Service uses a selector to identify the Pods that belong behind it.

```text
selector:
  app: backend
```

### Endpoint

Endpoints represent the current backend destinations associated with the Service.

### EndpointSlice

EndpointSlices provide Kubernetes' modern mechanism for representing Service endpoints.

### `port`

The Service port is where the Service accepts traffic.

### `targetPort`

The target port is where traffic is forwarded on the selected backend Pods.

### Kubernetes DNS

Services can be reached using DNS names instead of hard-coded IP addresses.

For the backend:

```text
backend
```

resolves within the namespace to:

```text
backend.default.svc.cluster.local
```

### Stable Application Identity

Applications should communicate with the logical Service identity rather than individual temporary Pod IPs.

---

## 16. Engineering Mental Model

The complete M04 networking model is:

```text
                         Kubernetes Cluster
┌────────────────────────────────────────────────────┐
│                                                    │
│  Frontend workload                                 │
│        │                                           │
│        │ http://backend:3000                       │
│        ▼                                           │
│  Kubernetes DNS                                    │
│        │                                           │
│        ▼                                           │
│  Backend Service                                   │
│  Type: ClusterIP                                   │
│  ClusterIP: 10.104.64.114                          │
│        │                                           │
│        │ selector: app=backend                     │
│        ▼                                           │
│  EndpointSlice                                     │
│        │                                           │
│        ├── 10.244.0.3:3000                         │
│        ├── 10.244.0.2:3000                         │
│        └── 10.244.0.7:3000                         │
│                                                    │
└────────────────────────────────────────────────────┘
```

The core abstraction is:

```text
Application
     ↓
Service name
     ↓
Service
     ↓
Current backend endpoints
     ↓
Pods
```

---

## 17. Engineering Lesson

The central lesson of M04 is:

> **Pods are temporary; Services provide stable access to workloads.**

The backend Pod IPs can change without requiring the frontend to change its configuration.

The frontend can use:

```text
backend:3000
```

while Kubernetes manages:

* Pod replacement
* Endpoint changes
* Service identity
* DNS resolution
* Internal traffic routing

This allows application communication to depend on a stable logical service rather than temporary infrastructure details.

---

## 18. Verification Commands

The following commands were used during the milestone:

```bash
kubectl get service backend
```

```bash
kubectl describe service backend
```

```bash
kubectl get endpoints backend
```

```bash
kubectl get endpointslice -l kubernetes.io/service-name=backend
```

```bash
kubectl get pods -l app=backend -o wide
```

```bash
kubectl exec -it <backend-pod> -- getent hosts backend
```

```bash
kubectl exec -it <backend-pod> -- node -e "fetch('http://backend:3000/health').then(async r => console.log('STATUS:', r.status, '\nBODY:', await r.text())).catch(console.error)"
```

---

## 19. Milestone Status

**Milestone 04 — Kubernetes Services & Networking: COMPLETE ✅**

The backend now has a stable internal Kubernetes Service with:

```text
Service name:       backend
Service type:       ClusterIP
ClusterIP:          10.104.64.114
Service port:       3000
Target port:        3000
Selector:           app=backend
DNS:                backend.default.svc.cluster.local
Internal address:   http://backend:3000
```

The Service, DNS resolution, endpoint management, Pod replacement, and internal backend communication were verified through practical experiments.

The next milestone is:

**M05 — Frontend & Nginx on Kubernetes**

Topics:

* Frontend Deployment
* Frontend Service
* Nginx reverse proxy
* SPA routing
* Internal API communication
