# 01 — Observability Fundamentals

## 1. Overview

This milestone establishes the foundations of monitoring and observability using the Expense Tracker application.

The objective was to understand how to determine whether a deployed application is functioning correctly, distinguish component health from end-to-end functionality, and adopt an evidence-driven approach to troubleshooting.

The practical work used Docker Compose. Minikube remained stopped to conserve lab resources.

## 2. Learning Objectives

- Distinguish monitoring, observability, and telemetry.
- Understand the difference between container status, application health, and end-to-end functionality.
- Establish an initial application baseline.
- Interpret Docker Compose service status and backend health-check status.
- Use observations to form hypotheses without prematurely assuming a root cause.

## 3. Core Concepts

### 3.1 Monitoring

Monitoring involves collecting and evaluating signals from a system to determine whether known conditions or thresholds indicate a problem.

Examples include monitoring container availability, CPU consumption, memory usage, and application response times.

### 3.2 Observability

Observability is the ability to investigate a system's internal behaviour using the evidence it exposes.

When an application fails, observability helps us investigate what happened and why instead of relying on assumptions.

### 3.3 Telemetry

Telemetry is the data emitted or collected from an application and its supporting infrastructure.

The main signals introduced in this mentorship are:

- **Logs:** Records of events and application behaviour.
- **Metrics:** Measurements collected over time, such as CPU usage, memory consumption, and request duration.
- **Traces:** Records that help follow a request across application components.

Logs and metrics will be explored in the practical milestones that follow.

## 4. Monitoring Architecture

The Expense Tracker consists of three principal components:

1. **Frontend** — presents the user interface.
2. **Backend** — processes application requests.
3. **MongoDB** — stores application data.

The expected request path for retrieving expense records is:

`User → Frontend → Backend → MongoDB`

A failure anywhere along this path may affect the user's ability to retrieve records.

## 5. Component Health vs. End-to-End Functionality

A container reporting a running status does not prove that its application is functioning correctly.

Similarly, a successful health endpoint only confirms the condition tested by that endpoint. It does not automatically prove that every application feature or dependency is working.

For this project, we distinguished four observations:

- **Container status:** Is the container running?
- **Component health:** Is the component responding according to its defined health check?
- **Dependency availability:** Can the application access required services such as MongoDB?
- **End-to-end functionality:** Can a user complete a representative operation and receive the expected result?

A successful expense retrieval provides evidence that the tested operation worked at that time. It does not guarantee that all features work or that the system will remain healthy under every condition.

## 6. Practical Environment

### 6.1 Tools and Application

- Docker
- Docker Compose
- Expense Tracker frontend
- Node.js backend
- MongoDB
- Minikube kept stopped during this milestone

### 6.2 Docker Compose Configuration

| Service | Image or build | Host port | Health check |
|---|---|---|---|
| Frontend | Locally built image | 3001 | No explicit Compose health check |
| Backend | Locally built image | 3000 | HTTP request to `/health` |
| MongoDB | `mongo:4.4` | 27017 | No explicit Compose health check |

Additional configuration observations:

- The backend connects to MongoDB using `mongodb://mongodb:27017/expense`.
- MongoDB data is stored in the named volume `mongo-data`.
- All three services use `restart: unless-stopped`.
- The backend and frontend use `depends_on` to establish startup ordering.
- The configuration does not make the frontend wait for the backend to become healthy.
- The backend health check uses an interval of 30 seconds, a timeout of 10 seconds, three retries, and a start period of 20 seconds.

These are configuration observations, not proof that every service or dependency is healthy.

## 7. Practical Experiment — Establishing the Baseline

### 7.1 Initial Environment Inspection

The first `docker ps` command returned no running containers.

The subsequent `docker ps -a` output showed a stopped container named `minikube`, using the image `gcr.io/k8s-minikube/kicbase:v0.0.51`, with exit code 137.

The application containers had not been started in this environment because the previous practical work had focused on Kubernetes.

No root-cause investigation of the Minikube exit code was performed as part of this milestone.

### 7.2 Starting the Application

The application was started using Docker Compose:

`docker compose up -d`

The resulting `docker compose ps` output showed all three services running.

The initial observed statuses were:

- Frontend: running on host port 3001.
- Backend: running on host port 3000, with health status `starting`.
- MongoDB: running on host port 27017.

### 7.3 Observing the Backend Health Transition

After waiting and checking the service status again, the backend was still reporting `health: starting`.

The application frontend was accessible at `http://localhost:3001/`.

The user successfully viewed existing expense records through the frontend.

A subsequent `docker compose ps` check reported:

- Backend: `Up 6 minutes (healthy)`.
- Frontend: running.
- MongoDB: running.

The backend health status therefore transitioned from `starting` to `healthy` during the observation period.

The precise cause or timing of that transition was not investigated further because the application was functioning normally.

## 8. Baseline Results

| Check | Observed result | Interpretation |
|---|---|---|
| Frontend accessibility | Frontend accessible at `localhost:3001` | Frontend responded to access from the lab environment |
| Backend container | Running | Container was running |
| Backend health check | `healthy` | The configured `/health` check was passing when inspected |
| MongoDB container | Running | MongoDB container was running |
| Expense retrieval | Existing records were visible | The tested end-to-end operation succeeded |
| Frontend health check | Not configured in Compose | No Docker health status was available for this service |
| MongoDB health check | Not configured in Compose | Container status alone did not verify database readiness or query success |

## 9. Troubleshooting Principles Learned

### 9.1 Do Not Assume the Root Cause

A user-reported failure is a symptom, not a complete diagnosis.

The symptom should guide the initial investigation, but evidence must support the eventual conclusion.

### 9.2 Establish a Baseline

Before introducing a failure or changing configuration, observe the application's normal state.

A baseline provides a reference point for comparison during later experiments.

### 9.3 Combine Signals

Container status, health checks, logs, metrics, and successful user operations provide different kinds of evidence.

No single signal necessarily explains the entire system's condition.

### 9.4 Distinguish Observation from Interpretation

For example:

- **Observation:** Docker reports the backend as `healthy`.
- **Interpretation:** The configured backend health check is succeeding.
- **Unsupported conclusion:** Every application feature and dependency is guaranteed to be healthy.

Keeping these distinctions clear improves troubleshooting accuracy.

## 10. Limitations and Outstanding Work

This milestone established an initial functional baseline; it did not complete a comprehensive monitoring implementation.

The following work remains for later milestones:

- Inspect application logs and interpret error messages.
- Investigate a controlled application failure.
- Verify application and dependency health beyond container status.
- Establish CPU and memory baselines.
- Introduce Prometheus and Grafana when their purpose and resource requirements are understood.
- Configure and test alerting.
- Perform brief Kubernetes monitoring integration later in the volume.

No controlled failure was introduced during this milestone.

No Prometheus, Grafana, or additional monitoring software was installed.

## 11. Milestone Completion Criteria

- Explain monitoring, observability, and telemetry.
- Distinguish component health from end-to-end functionality.
- Start the Expense Tracker using Docker Compose.
- Observe the status of all three containers.
- Observe the backend transition to `healthy`.
- Verify that expense records can be retrieved.
- Explain why evidence should precede remediation.
- Record the practical findings and limitations.

## 12. Conclusion

This milestone established the foundation for monitoring the Expense Tracker without requiring Minikube to remain running.

The application was observed in a functioning state, the backend health check was passing, and a representative user operation successfully retrieved expense records.

The key lesson is that effective troubleshooting begins with a known baseline, clear hypotheses, and evidence from the system. A running container or passing health endpoint is useful information, but neither independently guarantees complete application health.

The next milestone will build on this foundation by investigating application logs and errors.