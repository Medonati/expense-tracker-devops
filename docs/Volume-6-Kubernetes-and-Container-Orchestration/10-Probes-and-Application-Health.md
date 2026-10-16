# M10 — Probes and Application Health

## 1. Objective

Understand how Kubernetes startup, liveness, and readiness probes work; configure them for the Expense Tracker backend; and investigate repeated backend container restarts using actual Kubernetes events and application health endpoints.

The practical investigation focused on distinguishing application health failures from probe timing problems and broader instability in the Minikube environment.

## 2. Lab Environment

- **Application:** Expense Tracker backend
- **Runtime:** Node.js
- **Container image:** `748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.4`
- **Kubernetes environment:** Minikube
- **Replicas:** 3
- **Backend Service:** `backend`, ClusterIP `10.104.64.114`, port `3000`
- **Database:** MongoDB
- **Configuration:** Kubernetes Deployment, ConfigMap, Secret, and Service

## 3. Probe Concepts

### 3.1 Startup Probe

A startup probe determines whether an application has completed startup. While the startup probe has not succeeded, Kubernetes does not run the container's liveness and readiness probes.

This is useful for applications that need additional time to initialize. In this lab, the backend waits for its initial MongoDB connection before opening its HTTP listening port.

### 3.2 Liveness Probe

A liveness probe determines whether a running container should continue running. If it fails the configured number of consecutive times, Kubernetes restarts the container.

The backend uses `/health` for its liveness check.

### 3.3 Readiness Probe

A readiness probe determines whether the application is ready to receive normal traffic. A failed readiness probe removes the Pod from ready Service endpoints; it does not, by itself, restart the container.

The backend uses `/ready` to check its MongoDB connection state.

## 4. Application Health Endpoints

The health-check implementation is in `app/backend/app.js`.

### `/health`

```javascript
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    message: "Expense Tracker Backend is healthy",
  });
});
```

This endpoint returns HTTP 200 when the handler responds. It does not directly verify MongoDB connectivity.

### `/ready`

```javascript
app.get("/ready", (req, res) => {
  if (mongoose.connection.readyState === 1) {
    return res.status(200).json({
      status: "READY",
      database: "CONNECTED",
    });
  }

  return res.status(503).json({
    status: "NOT READY",
    database: "DISCONNECTED",
  });
});
```

This endpoint returns HTTP 200 when Mongoose reports an active connection and HTTP 503 otherwise.

## 5. Backend Startup Behaviour

The startup logic is in `app/backend/server.js`:

```javascript
const startServer = async () => {
  try {
    await connectDB();

    app.listen(port, () => {
      console.log(`Server is listening on http://localhost:${port}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
};

startServer();
```

The server waits for `connectDB()` to complete before opening its HTTP listening port.

The database connection function in `app/backend/DB/Database.js` calls `mongoose.connect(db)`. If the initial connection fails, it logs the error and calls `process.exit(1)`. The function does not implement an application-level retry loop.

Consequently, a probe can encounter connection refusal while the server is not yet listening. A startup probe can protect a slow but progressing startup; it cannot prevent the application from exiting when its initial database connection fails.

## 6. Initial Problem and Evidence

The backend had three replicas with repeated container restarts. Earlier observations included restart counts of 49, 41, and 50 for the original Pods.

Kubernetes events recorded:

- Liveness probe failures followed by container restarts.
- Readiness probe failures caused by connection refusal.
- Probe request timeouts while waiting for HTTP response headers.
- HTTP 503 responses from `/ready`.
- Periods when the Minikube node changed to `NodeNotReady`, followed by `NodeReady`.
- A node condition reporting that the container runtime was down.

The backend Deployment initially had no declared CPU or memory requests or limits.

The backend's original liveness and readiness probes used `timeoutSeconds: 1`, `periodSeconds: 10`, and `failureThreshold: 3`. No startup probe was configured.

### Host-level investigation

The VM had two vCPUs and approximately 2.4 GiB of memory. The observed load averages were `5.83`, `13.21`, and `11.26`.

Kernel logs contained repeated soft-lockup and RCU scheduler starvation warnings. These findings indicate serious host scheduling instability.

No explicit out-of-memory kill was confirmed in the logs collected. Exit code 137 alone was not sufficient to establish an OOM cause.

### Initial assessment

The evidence showed that liveness failures triggered at least some backend restarts. The strict probe timeout was a plausible contributing factor, especially during periods of VM scheduling instability. The available evidence did not establish that probe timing was the only underlying cause.

## 7. Experiment A — Increase Probe Timeouts

### Hypothesis

Allowing more time for the backend to respond could reduce probe failures caused by temporary scheduling delays.

### Change

Both the liveness and readiness `timeoutSeconds` values were increased from 1 to 5 seconds. Their endpoints, 10-second periods, and failure thresholds of 3 were retained.

The Deployment was patched with:

```bash
kubectl patch deployment backend --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","livenessProbe":{"timeoutSeconds":5},"readinessProbe":{"timeoutSeconds":5}}]}}}}'
```

The rollout completed successfully.

### Observation

The replacement Pods became Running and Ready. One Pod had a restart during the initial observation period, while the other two had zero restarts. A subsequent check reported no further restarts.

This was an encouraging result, but the short observation period did not prove that the timeout change alone resolved the incident.

## 8. Experiment B — Add a Startup Probe

The backend startup code showed that MongoDB must connect before the HTTP server begins listening. A startup probe was therefore added to give the application time to start before liveness and readiness checks take effect.

The startup probe was configured as follows:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 3000
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 12
```

This provides approximately 60 seconds of startup-probe failure allowance under the configured timing. Once the startup probe succeeds, Kubernetes begins enforcing the liveness and readiness probes.

The complete backend probe configuration became:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 3000
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 12

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: 3000
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

The updated Deployment was applied, and Kubernetes reported:

```text
deployment "backend" successfully rolled out
```

### Observation

After the rollout, all three backend Pods were Running and Ready with zero restarts. A later observation, when the Pods were approximately 4–9 minutes old, still showed zero restarts.

This supports the decision to retain the new probe configuration. It does not isolate the effect of the startup probe from the timeout change or rule out intermittent VM-level instability.

## 9. Health Endpoint Verification

The backend Service was confirmed as:

```text
NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
backend   ClusterIP   10.104.64.114   <none>        3000/TCP
```

A temporary diagnostic Pod was used to query the backend through its Kubernetes Service:

```bash
curl -i --max-time 10 http://backend:3000/health
curl -i --max-time 10 http://backend:3000/ready
```

### Results

**Liveness endpoint — `/health`**

Returned HTTP 200 with:

```json
{
  "status": "UP",
  "message": "Expense Tracker Backend is healthy"
}
```

**Readiness endpoint — `/ready`**

Returned HTTP 200 with:

```json
{
  "status": "READY",
  "database": "CONNECTED"
}
```

These checks confirmed that the backend was responding through its Service and that MongoDB was connected at the time of testing.

The temporary diagnostic Pod was deleted after the checks.

## 10. Final Configuration

The repository manifest is:

`kubernetes/backend/deployment.yaml`

The intended final probe configuration is:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 3000
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 12

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: 3000
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

The repository manifest should be checked against the live Deployment to ensure both configurations match.

## 11. Lessons Learned

1. A failed health probe does not automatically mean the application has a permanent fault.
2. A liveness failure can trigger a restart, while a readiness failure alone affects traffic routing.
3. A strict timeout can make health checks vulnerable to temporary scheduling delays.
4. A startup probe protects applications that need additional initialization time.
5. A startup probe cannot correct an application-level failure, such as exiting when the initial database connection fails.
6. MongoDB readiness and HTTP application liveness are different concerns and should be checked separately.
7. Kubernetes events, container logs, restart counts, node conditions, and host kernel logs provide complementary evidence.
8. Exit code 137 is not, by itself, proof of an out-of-memory kill.
9. Successful rollout and a short period without restarts are encouraging, but longer observation is needed before declaring the issue permanently resolved.
10. Troubleshooting should distinguish confirmed facts from hypotheses and avoid changing multiple variables without recording the results.

## 12. Outcome

**Completed in the practical session:**

- Investigated repeated backend restarts.
- Inspected the backend's liveness and readiness endpoints.
- Inspected the database connection and server startup sequence.
- Increased liveness and readiness timeouts from 1 to 5 seconds.
- Added a startup probe with a 60-second approximate failure allowance.
- Successfully rolled out the updated backend Deployment.
- Verified HTTP 200 responses from `/health` and `/ready`.
- Confirmed MongoDB was connected during readiness verification.
- Observed all three backend Pods Running and Ready with zero restarts during the final short observation period.
