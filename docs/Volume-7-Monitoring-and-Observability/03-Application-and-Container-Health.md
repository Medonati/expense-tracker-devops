# Milestone 03 — Application and Container Health

**Volume:** 7 — Monitoring & Observability  
**Project:** Expense Tracker DevOps  
**Repository:** `Medonati/expense-tracker-devops`  
**Status:** Practical investigation completed; documentation awaiting review

## 1. Objective

The objective of this milestone was to understand how Docker health checks help assess application health, distinguish a running container from a healthy application, investigate readiness failures, and verify the availability of the Expense Tracker application's services.

The practical work focused on the backend, frontend, MongoDB, Docker Compose health checks, and the frontend's Nginx proxy configuration.

## 2. Environment and Architecture

The application runs locally through Docker Compose and consists of three services:

| Service | Container port | Host port | Purpose |
|---|---:|---:|---|
| `frontend` | 80 | 3001 | Serves the frontend through Nginx |
| `backend` | 3000 | 3000 | Node.js application and API |
| `mongodb` | 27017 | 27017 | Application database |

MongoDB uses a named Docker volume, `mongo-data`, to persist database files.

The backend connects to MongoDB using the internal Compose service address:

`mongodb://mongodb:27017/expense`

The backend has an explicit Docker health check. At the beginning of the investigation, the health check called `/health`. During this milestone, it was changed to call `/ready`.

The frontend and MongoDB services do not have explicit health checks in the Compose configuration.

## 3. Understanding Container Health

### 3.1 Running does not mean healthy

A container can have a running main process while the condition defined by its health check is failing.

Docker's health status provides additional information about the condition being tested. It does not automatically repair an unhealthy application.

### 3.2 Controlled health-check experiment

To demonstrate this behavior without disrupting the Expense Tracker application, an isolated container named `health-lab` was created using the existing `node:22-slim` image.

The container's health check tested whether the file `/tmp/healthy` existed.

Initially, the file was absent, and Docker reported:

- Container state: `running`
- Health state: `unhealthy`
- Failing streak: `3`

The file was then created inside the container:

`docker exec health-lab sh -c 'touch /tmp/healthy'`

Subsequent health checks succeeded, and the container returned to `healthy`. The health-check history showed successful exit codes.

The temporary container was removed after the experiment.

**Lesson:** A health check detects whether its configured condition is satisfied. It does not itself repair the condition. Recovery occurred because the condition being tested was corrected.

## 4. Comparing the Backend Health Endpoints

The backend exposes two endpoints with different purposes.

### 4.1 `/health`

The endpoint returns HTTP 200 with a response similar to:

`{"status":"UP","message":"Expense Tracker Backend is healthy"}`

The handler reports that the backend can respond to the request. It does not check MongoDB connectivity.

During the controlled MongoDB outage, `/health` continued to return HTTP 200.

This demonstrated that a successful response from `/health` alone did not establish that the backend was ready to perform database-dependent operations.

### 4.2 `/ready`

The readiness endpoint checks Mongoose's connection state:

`mongoose.connection.readyState === 1`

When connected, it returns HTTP 200 with:

`{"status":"READY","database":"CONNECTED"}`

When disconnected, it returns HTTP 503 with:

`{"status":"NOT READY","database":"DISCONNECTED"}`

During the MongoDB outage, `/ready` returned the not-ready response. After MongoDB was restored and the application re-established its connection, `/ready` returned HTTP 200.

**Important limitation:** This readiness check verifies the reported Mongoose connection state. It does not guarantee that every database query will succeed, that all application dependencies are functioning, or that every user operation will work.

## 5. Updating the Docker Health Check

### 5.1 Reason for the change

The original backend health check called `/health`. Because this endpoint continued to return HTTP 200 while MongoDB was disconnected, it could report the backend as healthy even when a critical dependency was unavailable.

For this milestone, the chosen improvement was to use `/ready` as the Docker health-check endpoint.

### 5.2 Configuration

The health-check command was changed to:

`fetch('http://localhost:3000/ready').then(r => { if (!r.ok) process.exit(1) }).catch(() => process.exit(1))`

The existing health-check timing settings were preserved:

| Setting | Value |
|---|---|
| Interval | 30 seconds |
| Timeout | 10 seconds |
| Retries | 3 |
| Start period | 20 seconds |

These settings control how frequently Docker runs the check, how long it waits for a result, how many consecutive failures are required before the container is marked unhealthy, and the initial grace period.

### 5.3 Validation and application

The Compose configuration was validated using:

`docker compose config --quiet`

The command completed without displaying an error.

A dry run was used to inspect the proposed changes before applying them. The actual backend was then recreated without recreating its dependencies:

`docker compose up -d --no-deps backend`

The running backend's health-check configuration was inspected and confirmed to reference `/ready`.

The frontend and MongoDB were not recreated by this backend-only operation.

## 6. Investigating Transient Health-Check Failures

After the change, the backend was observed in a healthy state, but its health-check history contained transient failures.

The logs included:

- An HTTP 503 response from `/ready`.
- A health-check timeout reported by Docker.
- Subsequent successful readiness responses.

One observed readiness request returned HTTP 503 in approximately 0.310 milliseconds. A later health-check record reported that the check exceeded its 10-second timeout, while a nearby backend log entry showed a successful `/ready` response.

A direct request subsequently returned:

`HTTP/1.1 200 OK`

with:

`{"status":"READY","database":"CONNECTED"}`

The final health-state inspection reported:

`Status=running Health=healthy FailingStreak=0`

### Interpretation

The evidence confirms that a readiness failure and a health-check timeout were observed, followed by successful checks and a reset failing streak.

However, the precise cause of the timeout was not established. The available evidence does not justify attributing it to MongoDB, CPU pressure, or any other specific cause.

**Lesson:** Health-check history and application logs should be examined together. A single health result shows the condition at a particular time; the history helps reveal transient failures and recovery.

## 7. Final Service Verification

### 7.1 Docker Compose service status

The final `docker compose ps` output showed:

| Service | Observed status | Interpretation |
|---|---|---|
| `backend` | `Up (healthy)` | The configured `/ready` health check was passing, with a failing streak of zero in the separate final inspection |
| `frontend` | `Up` | The frontend container was running |
| `mongodb` | `Up` | The MongoDB container was running |

Only the backend had an explicit Compose health check. Therefore, the running states of the frontend and MongoDB must not be interpreted as independent confirmation of their complete application-level health.

### 7.2 Frontend HTTP test

The frontend was tested with:

`curl -I --max-time 10 http://localhost:3001`

The response was:

`HTTP/1.1 200 OK`

The response headers identified Nginx as the server and HTML as the content type.

This confirmed that the frontend's HTTP endpoint was serving a response. It did not, by itself, verify every frontend feature or API interaction.

### 7.3 Nginx proxy investigation

The active Nginx configuration contained:

`location /api/ { proxy_pass http://backend:3000; }`

The frontend therefore forwards matching `/api/` requests to the backend service over the Compose network.

The initial test used:

`GET /api/v1/getTransaction`

It returned HTTP 404 with `Cannot GET /api/v1/getTransaction`.

Inspection of the backend route definition revealed:

`router.route("/getTransaction").post(getAllTransactionController);`

The router was mounted at `/api/v1`, making the route a POST endpoint rather than a GET endpoint.

A subsequent POST request through Nginx returned HTTP 400 with the JSON response:

`{"success":false,"message":"User not found"}`

This was an application-level response consistent with the request reaching the intended handler. Because the test did not include the expected user context, it did not establish that a complete authenticated transaction request would succeed.

The same path tested directly against the backend with GET also returned HTTP 404. These observations helped distinguish an incorrect HTTP method from a gateway connectivity failure.

**Scope note:** The transaction endpoint investigation was supplementary to this milestone. The endpoint was not modified, and no user or transaction data was created or changed during these tests.

## 8. Important Concepts Learned

### Health checks report; they do not repair

Docker health checks evaluate a configured condition. A failed check does not automatically restart or fix an application.

### Readiness and liveness answer different questions

A basic health endpoint can indicate that the application process responds. A readiness endpoint can additionally check whether the application is ready to handle work.

The current `/ready` endpoint provides a database-connection signal. It is not a complete liveness/readiness strategy for every possible failure.

### Dependency startup order is not readiness

The Compose configuration uses short-form `depends_on` entries. These establish service startup ordering, but they do not by themselves wait for a dependency's application-level readiness.

### Health-check scope matters

A health check is only as meaningful as the condition it evaluates. An endpoint that ignores a critical dependency may give a misleading view of application readiness.

### Logs provide diagnostic evidence

Health status identifies the observed state. Health-check history and application logs provide additional evidence for investigating failures, but correlation alone does not prove a root cause.

### Container status is not full service validation

A running container, a successful HTTP response, a healthy backend, and a successful end-to-end user workflow are different levels of verification.

## 9. Limitations and Outstanding Work

The following items were not completed as part of this milestone:

- Adding explicit health checks for the frontend and MongoDB.
- Verifying MongoDB with a dedicated database-level health check.
- Testing a complete authenticated transaction workflow.
- Establishing the exact cause of the transient backend health-check timeout.
- Building automated alerts or dashboards for health-check failures.
- Designing separate, comprehensive liveness and readiness probes.

These are potential follow-up activities, not claims that the current implementation is broken.

## 10. Milestone Outcome

The practical investigation demonstrated how Docker health checks work, why endpoint selection matters, how readiness changes during a database outage, and how to use logs and HTTP responses to investigate unexpected behavior.

The backend health check was changed from `/health` to `/ready`, and the final observed backend state was running and healthy with a failing streak of zero. The frontend returned HTTP 200, and all three containers were running at the final Compose status check.

The transient failures remain documented without an unsupported root-cause claim.

**Milestone status:** Practical investigation completed; documentation review and repository workflow remain pending.

## 11. Suggested Follow-Up

Proceed to **Milestone 04 — Metrics and Resource Monitoring** after reviewing and committing this milestone's documentation. The next milestone can build on health-state observations by examining resource usage and establishing a baseline for CPU, memory, and container behavior.

