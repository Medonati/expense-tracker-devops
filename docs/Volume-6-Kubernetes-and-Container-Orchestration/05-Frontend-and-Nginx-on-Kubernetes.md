# M05 — Frontend & Nginx on Kubernetes

## Objective

Deploy the React frontend to Kubernetes, expose it through a Kubernetes Service, use Nginx to serve the React application, and configure Nginx to reverse-proxy API requests to the internal backend Service.

This milestone covers:

* Frontend Deployment
* Frontend Service
* Nginx reverse proxy
* SPA routing
* Internal API communication

External access through Ingress is intentionally deferred to M07.

---

## 1. Frontend Deployment

The frontend was deployed using the existing ECR image:

```text
748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4
```

The Deployment was configured with:

* 2 frontend replicas
* container port 80
* `app=frontend` Pod label
* existing `ecr-secret` image pull secret

The frontend Pods reached `Running` and `Ready` state.

An initial image-pull failure occurred because the ECR authentication token stored in `ecr-secret` had expired. The secret was refreshed and the affected Pods were deleted so the Deployment could recreate them using the refreshed credentials.

---

## 2. Nginx Serving the React Application

The frontend image uses Nginx as its runtime web server.

The configuration was verified inside the running frontend Pod.

```nginx
server {
    listen 80;

    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://backend:3000;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The React application was successfully retrieved through Nginx using:

```bash
wget -qO- http://127.0.0.1
```

The returned HTML included:

```text
<title>Expense Management System</title>
```

This confirmed that Nginx was serving the production React build.

---

## 3. SPA Routing

The frontend uses React client-side routing.

Nginx provides the required fallback:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

If a requested path is not an actual file or directory, Nginx returns `index.html`, allowing React to handle the route.

---

## 4. Frontend Service

The Frontend Service was created as a `ClusterIP`:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: frontend

spec:
  selector:
    app: frontend

  ports:
    - port: 80
      targetPort: 80
```

The resulting Service was:

```text
Name:        frontend
Type:        ClusterIP
Cluster IP:  10.109.23.174
Port:        80/TCP
```

The Service endpoints were:

```text
10.244.0.10:80
10.244.0.11:80
```

This confirmed that the Service successfully selected both frontend Pods.

A request through:

```bash
kubectl exec -it <frontend-pod-name> -- \
  wget -qO- http://frontend
```

returned the React HTML.

---

## 5. Nginx Reverse Proxy

The frontend defines:

```javascript
const host = process.env.REACT_APP_API_URL;
```

and constructs API paths such as:

```text
/api/auth/login
/api/auth/register
/api/v1/addTransaction
/api/v1/getTransaction
/api/v1/updateTransaction
/api/v1/deleteTransaction
```

The backend defines:

```javascript
app.use("/api/v1", transactionRoutes);
app.use("/api/auth", userRoutes);
```

Therefore, the `/api` prefix is required.

The Nginx configuration remains:

```nginx
location /api/ {
    proxy_pass http://backend:3000;
}
```

We deliberately **did not** add a trailing `/`.

Without the trailing slash:

```text
/api/v1/getTransaction
        ↓
/api/v1/getTransaction
```

The `/api` prefix is preserved.

With:

```nginx
proxy_pass http://backend:3000/;
```

Nginx could rewrite the request so that:

```text
/api/v1/getTransaction
        ↓
/v1/getTransaction
```

which would not match the backend's `/api/v1` router prefix.

The configuration was therefore left unchanged after verifying the actual frontend and backend routes.

---

## 6. Internal Backend Communication

The frontend Pod successfully accessed:

```bash
wget -qO- http://backend:3000/health
```

and received:

```json
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This confirmed that Kubernetes DNS and the backend Service provide working internal communication.

---

## 7. Failed Test and What It Taught Us

We also attempted:

```bash
kubectl exec -it <frontend-pod-name> -- \
  wget -qO- http://localhost/api/health
```

which returned:

```text
connection refused
```

We did not treat this as a Kubernetes networking failure.

The test had two problems:

1. `localhost` refers to the current Pod.
2. `/api/health` was not the backend health endpoint we had established.

The successful test was:

```bash
wget -qO- http://backend:3000/health
```

This reinforced:

> **Verify Before Assuming.**

---

## 8. Final Architecture

```text
                    Kubernetes Cluster
                           │
                           ▼
                 ┌─────────────────┐
                 │ Frontend Service│
                 │   ClusterIP     │
                 │ 10.109.23.174   │
                 │      :80        │
                 └────────┬────────┘
                          │
                 ┌────────┴────────┐
                 ▼                 ▼
          Frontend Pod 1     Frontend Pod 2
             :80                 :80
                 │                 │
                 └────────┬────────┘
                          ▼
                        Nginx
                       /     \
                      /       \
                 React        /api/*
                               │
                               ▼
                       backend:3000
                               │
                               ▼
                       Backend Service
                               │
                               ▼
                         Backend Pods
```

---

## 9. M05 Completion Checklist

* [x] Frontend Deployment
* [x] Frontend Pods running
* [x] ECR authentication verified
* [x] Nginx serving React
* [x] SPA fallback configured
* [x] Frontend Service created
* [x] Service endpoints verified
* [x] Frontend Service tested
* [x] Frontend API paths verified
* [x] Backend router prefixes verified
* [x] Nginx reverse-proxy configuration verified
* [x] Frontend-to-backend internal communication verified
* [x] M05 complete

---

## 10. Boundary to M06

M05 established the application communication path.

The next milestone introduces configuration and state:

```text
M05
Frontend + Nginx + Backend
        ↓
M06
ConfigMaps + Secrets + Persistent Storage
```


## Key Commands Used

### Create the frontend Kubernetes directory

```bash
mkdir -p kubernetes/frontend
```

### Apply the Frontend Deployment

```bash
kubectl apply -f kubernetes/frontend/deployment.yaml
```

### Check frontend Pods

```bash
kubectl get pods -l app=frontend -o wide
```

Used to verify that the frontend replicas were running and to observe their Pod IP addresses.

### Check the Frontend Deployment

```bash
kubectl get deployment frontend
```

Used to verify the desired and available frontend replicas.

### Check the ECR image-pull secret

```bash
kubectl get secret ecr-secret
```

Used when investigating the initial `ImagePullBackOff`.

### Refresh the ECR authentication secret

```bash
aws ecr get-login-password --region us-east-1 | \
kubectl create secret docker-registry ecr-secret \
  --docker-server=748241639517.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$(cat)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Used to replace the expired ECR authentication token.

### Recreate frontend Pods after refreshing credentials

```bash
kubectl delete pods -l app=frontend
```

The Deployment recreated the Pods using the refreshed registry credentials.

### Inspect a frontend Pod

```bash
kubectl describe pod <frontend-pod-name>
```

Used to verify:

* image
* image digest
* container port
* Pod readiness
* image-pull events
* container start events

### Inspect Nginx configuration

```bash
kubectl exec <frontend-pod-name> -- nginx -T
```

Used to verify the complete Nginx configuration loaded inside the container.

### Check the Nginx processes

```bash
kubectl exec <frontend-pod-name> -- ps aux
```

Used to confirm that the Nginx master and worker processes were running.

### Test Nginx using IPv4 loopback

```bash
kubectl exec <frontend-pod-name> -- wget -qO- http://127.0.0.1
```

Used to confirm that Nginx was serving the React application.

### Create the Frontend Service

```bash
kubectl apply -f kubernetes/frontend/service.yaml
```

### Check the Frontend Service

```bash
kubectl get service frontend
```

Used to verify the Service type, ClusterIP and port.

### Inspect Frontend Service endpoints

```bash
kubectl describe service frontend
```

Used to verify that the Service selector:

```text
app=frontend
```

selected the expected frontend Pods.

### Test the Frontend Service from inside the cluster

```bash
kubectl exec -it <frontend-pod-name> -- \
  wget -qO- http://frontend
```

Used to verify:

```text
Frontend Service
       ↓
Frontend Pod
       ↓
Nginx
       ↓
React application
```

### Inspect frontend API paths

```bash
grep -R "host" app/frontend/src --exclude-dir=node_modules
```

This revealed API paths such as:

```text
/api/auth/login
/api/auth/register
/api/v1/addTransaction
/api/v1/getTransaction
/api/v1/updateTransaction
/api/v1/deleteTransaction
```

### Verify backend router prefixes

```bash
grep -R "Transactions\|/api" app/backend --exclude-dir=node_modules
```

This confirmed:

```javascript
app.use("/api/v1", transactionRoutes);
app.use("/api/auth", userRoutes);
```

This verification established that the `/api` prefix must be preserved by Nginx.

### Test direct frontend-to-backend communication

```bash
kubectl exec -it <frontend-pod-name> -- \
  wget -qO- http://backend:3000/health
```

Successful response:

```json
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This verified:

```text
Frontend Pod
     ↓
Kubernetes DNS
     ↓
backend Service
     ↓
Backend Pod
```


M06 will address:

* ConfigMaps
* Secrets
* PersistentVolumes
* PersistentVolumeClaims
* MongoDB persistence
  """
