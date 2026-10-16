# M07 — Kubernetes Ingress and External Access

## 1. Overview

This milestone introduced Kubernetes Ingress and demonstrated how HTTP traffic can be routed to an application Service using hostname-based routing.

The practical work used the Expense Tracker application running on Minikube. The Nginx Ingress Controller was enabled, an Ingress resource was created, and HTTP requests were tested against the existing frontend Service.

The milestone focused on understanding the difference between an Ingress resource, an Ingress Controller, and a Kubernetes Service.

## 2. Learning Objectives

By completing this milestone, I demonstrated how to:

- Explain the role of Kubernetes Ingress.
- Distinguish an Ingress resource from an Ingress Controller.
- Configure the Nginx Ingress Controller in Minikube.
- Route HTTP traffic to an existing Kubernetes Service.
- Configure hostname-based routing.
- Test matching and non-matching hostnames.
- Trace traffic from the Ingress Controller to the frontend application.
- Troubleshoot controller startup and application routing issues.

## 3. Lab Environment

| Component | Observed configuration |
|---|---|
| Kubernetes environment | Minikube |
| Ingress Controller | Nginx Ingress Controller |
| Ingress class | `nginx` |
| Minikube node IP | `192.168.49.2` |
| Ingress HTTP NodePort | `32136` |
| Ingress HTTPS NodePort | `31787` |
| Ingress resource | `frontend-ingress` |
| Frontend Service | `frontend` |
| Frontend Service type | `ClusterIP` |
| Frontend Service port | `80` |
| Application | Expense Tracker React frontend |

The NodePort values and node IP above reflect the observed lab environment. They are not universal Kubernetes defaults.

## 4. Ingress Fundamentals

### 4.1 Ingress Resource

An Ingress is a Kubernetes API resource that defines rules for routing HTTP and HTTPS requests to Services.

Rules can use request hostnames and URL paths to determine the destination Service.

### 4.2 Ingress Controller

An Ingress Controller implements the routing rules defined by Ingress resources.

In this lab, the Nginx Ingress Controller receives HTTP traffic, evaluates the configured rules, and forwards matching requests to the appropriate Kubernetes Service.

Creating an Ingress resource alone does not implement traffic routing; a compatible controller must process it.

### 4.3 Kubernetes Service

The frontend Service provides a stable internal endpoint for the frontend Pods.

The Service remained `ClusterIP` throughout this milestone. The Ingress Controller provided the HTTP entry point without requiring the frontend Service itself to be changed to NodePort.

## 5. Enabling the Nginx Ingress Controller

The initial command was:

```bash
minikube addons enable ingress
```

Minikube downloaded or prepared the required Ingress images but reported a timeout while waiting for the Ingress Pods.

The initial error was:

```text
waiting for app.kubernetes.io/name=ingress-nginx pods:
context deadline exceeded
```

A subsequent status check reported:

```text
host: Running
kubelet: Running
apiserver: Stopped
kubeconfig: Configured
```

The Kubernetes API server later recovered and reported `Running`.

Inspection of the Ingress namespace showed:

- The admission-create Job had completed.
- The admission-patch Job had completed.
- The Nginx Ingress Controller Pod was `1/1 Running`.

The controller had accumulated restarts, but it was running when inspected.

The controller Service was:

```text
NAME                                 TYPE       PORT(S)
ingress-nginx-controller             NodePort   80:32136/TCP,443:31787/TCP
ingress-nginx-controller-admission   ClusterIP  443/TCP
```

This established the HTTP NodePort used for subsequent experiments.

**Troubleshooting lesson:** an addon command timing out does not necessarily mean that all its resources failed to start. Inspect the actual Kubernetes resources and control-plane status before reinstalling or restarting components.

## 6. Initial Ingress Configuration

The first Ingress configuration did not specify a hostname:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

The resource was applied using:

```bash
kubectl apply -f kubernetes/frontend/ingress.yaml
```

The controller processed the resource, and the Ingress address was reported as `192.168.49.2`.

The rule directed requests matching `/` to the `frontend` Service on port `80`.

### 6.1 Initial HTTP Verification

The following command was used:

```bash
curl -I http://192.168.49.2:32136/
```

Observed result:

```text
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1092
```

The frontend HTML contained:

```html
<title>Expense Management System</title>
```

This confirmed that the response contained the expected Expense Tracker frontend content.

## 7. Hostname-Based Routing

The initial configuration had no `host` field. Requests using different hostnames both returned HTTP 200.

The baseline tests were:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "Host: expense.example.test" \
  http://192.168.49.2:32136/
```

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "Host: another.example.test" \
  http://192.168.49.2:32136/
```

Both requests returned:

```text
HTTP 200
```

This demonstrated that the original rule did not restrict requests to a particular hostname.

### 7.1 Updated Ingress Configuration

The Ingress manifest was then updated to specify a hostname:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: expense.example.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

The updated configuration was applied using:

```bash
kubectl apply -f kubernetes/frontend/ingress.yaml
```

The live Ingress resource confirmed the following rule:

```text
Host:     expense.example.test
Path:     /
Backend:  frontend:80
Address:  192.168.49.2
```

### 7.2 Matching Hostname Test

Command:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "Host: expense.example.test" \
  http://192.168.49.2:32136/
```

Observed result:

```text
HTTP 200
```

The matching hostname was routed to the frontend.

### 7.3 Non-Matching Hostname Test

Command:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "Host: another.example.test" \
  http://192.168.49.2:32136/
```

Observed result:

```text
HTTP 404
```

The non-matching hostname did not match the configured Ingress rule, and the controller returned its default 404 response.

These two tests demonstrated the effect of introducing a hostname condition.

## 8. Hostname Resolution Simulation

The hostname was tested without changing DNS or the VM's hosts file.

Command:

```bash
curl -i --resolve expense.example.test:32136:192.168.49.2 \
  http://expense.example.test:32136/
```

Observed result:

```text
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 1092
```

The response contained the Expense Tracker frontend HTML.

The `--resolve` option made curl connect to the specified IP for the hostname and port. The HTTP request still used `expense.example.test` as its hostname.

This demonstrated hostname-based routing without requiring a publicly registered domain.

**Scope limitation:** these tests were executed from inside the DevOps VM. They verified access through Minikube's NodePort but did not establish public Internet access or direct browser access from the host laptop.

## 9. Understanding the Application's Routing Layers

The lab also examined the relationship between Ingress, frontend Nginx, and the Node.js backend.

### 9.1 Kubernetes Ingress

The configured rule routed:

```text
/ → frontend:80
```

### 9.2 Frontend Nginx

The existing Nginx configuration contained:

```nginx
location /api/ {
    proxy_pass http://backend:3000;
}

location / {
    try_files $uri $uri/ /index.html;
}
```

Because the `proxy_pass` URL does not include a trailing slash after the upstream port, the original request URI is preserved when forwarded.

For example:

```text
/api/health
    ↓
backend:3000/api/health
```

### 9.3 Backend Route Verification

The request through the frontend proxy returned:

```text
Cannot GET /api/health
```

This was an application-level 404, not an Ingress routing failure.

A direct request to the backend's actual `/health` endpoint was tested using Node.js because `curl` was not installed in the backend container.

The observed result was:

```text
STATUS: 200
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This confirmed that the backend health endpoint was healthy.

The experiment demonstrated that a request can successfully pass through network routing layers and still return an application-level 404 when the requested route is not defined.

No application routing changes were made as part of this experiment.

## 10. Final Traffic Flow

The verified frontend access path was:

```text
HTTP Client
    |
    v
Minikube Node
192.168.49.2:32136
    |
    v
Nginx Ingress Controller
    |
    v
Ingress Rule
Host: expense.example.test
Path: /
    |
    v
frontend Service
ClusterIP:80
    |
    v
Frontend Pods
Nginx:80
    |
    v
Expense Tracker React Application
```

When a request matches the hostname and path, the Ingress Controller routes it to the configured Service. The Service then forwards traffic to its available frontend Pods.

## 11. Key Lessons

1. An Ingress resource defines routing rules; the Ingress Controller implements them.
2. A hostname-free rule can accept matching paths regardless of the request hostname.
3. A hostname-specific rule restricts matching to the configured host.
4. The frontend Service can remain `ClusterIP` while the Ingress Controller provides an HTTP entry point.
5. A successful HTTP response from the frontend proves the tested request reached the application.
6. A 404 can originate from the Ingress Controller or from the application. The response and request path must be examined before diagnosing the failure.
7. A Minikube NodePort test from inside the VM is not proof of public Internet exposure.
8. Troubleshooting should begin with observed resource status and logs rather than immediate reinstallation.

## 12. Completion Criteria

- Nginx Ingress Controller running.
- Ingress class `nginx` registered.
- Ingress resource created and synchronized.
- HTTP request routed to the frontend.
- Hostname-free routing baseline tested.
- Hostname-specific routing configured.
- Matching hostname returned HTTP 200.
- Non-matching hostname returned HTTP 404.
- Hostname access tested using curl `--resolve`.
- Existing frontend-to-backend proxy behavior investigated.
- Troubleshooting observations documented.

## 13. Milestone Status

**M07 — Ingress & External Access: Practical experiments complete.**

The lab demonstrated Ingress controller operation, HTTP routing to the frontend Service, hostname-based routing, and the distinction between infrastructure-level routing and application-level routes.

Documentation and repository housekeeping must be committed and pushed as part of the established Volume 6 workflow before proceeding to M08 — Scaling, Updates & Failure Experiments.
