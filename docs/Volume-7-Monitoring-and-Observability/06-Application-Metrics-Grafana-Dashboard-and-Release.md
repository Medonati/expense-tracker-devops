# Volume 7 — Monitoring and Observability
## 06 — Application Metrics, Prometheus, Grafana, and Release

## 1. Purpose of This Milestone

This milestone extends the Expense Tracker DevOps project by introducing application metrics and visual monitoring.

The objective is not merely to install monitoring tools. It is to understand how an operator can observe an application, identify abnormal behaviour, investigate performance problems, and verify that the application is operating as expected.

This document serves two purposes:

1. **Portfolio evidence:** Demonstrates practical monitoring, observability, troubleshooting, container operations, and artifact management skills to prospective recruiters.
2. **Personal technical reference:** Records the reasoning behind our implementation, important commands, configuration locations, validation procedures, and troubleshooting steps for future use.

## 2. Why Monitoring and Observability Matter

A running container does not necessarily mean an application is healthy. A container may be running while the application responds slowly, returns HTTP errors, or fails to serve requests correctly.

Monitoring helps us observe measurable indicators of system behaviour. Observability helps us investigate that behaviour using available evidence, including metrics, logs, and traces.

In this milestone, we concentrated on metrics.

Examples of questions our monitoring setup should help us answer include:

- Is the backend receiving requests?
- Which routes are receiving traffic?
- Are HTTP errors increasing?
- Is average request latency increasing?
- Are Prometheus, Node Exporter, and the backend metrics endpoint reachable?
- Can we verify the running monitoring stack after a restart?

Metrics do not explain every possible failure. Logs remain important for understanding individual errors, while distributed tracing can help investigate requests that cross multiple services.

## 3. Why Prometheus?

Prometheus is the metrics collection and querying component of our monitoring stack.

It periodically scrapes configured HTTP endpoints, stores the collected time-series data, and provides PromQL for querying and analysing that data.

We use Prometheus because it allows us to:

- Collect metrics from our application and infrastructure.
- Store historical measurements for comparison.
- Query request rates and latency over time.
- Check whether configured monitoring targets are reachable.
- Supply metric data to Grafana dashboards.

In this project, Prometheus collects metrics from three targets:

| Target | Purpose |
|---|---|
| Prometheus | Monitors Prometheus itself. |
| Node Exporter | Exposes host-level metrics, such as CPU, memory, and filesystem statistics. |
| Expense Tracker backend | Exposes application request counters, latency measurements, and runtime metrics. |

**Important distinction:** Node Exporter provides host metrics; it does not automatically provide detailed application request metrics. Those come from the backend instrumentation we added.

Prometheus is responsible for collecting and querying metrics. It is not, by itself, a complete visual dashboarding solution.

## 4. Why Grafana?

Grafana is the visualization and dashboarding component of our stack.

It connects to Prometheus as a data source and presents queried metrics in panels, making trends and unusual behaviour easier to interpret.

We use Grafana because raw metric values and PromQL queries are useful to engineers, but dashboards make recurring operational checks more convenient.

Our dashboard, **Expense Tracker — Infrastructure Monitoring**, provides a central place to inspect the application's monitored behaviour.

Prometheus and Grafana have different responsibilities:

- **Prometheus:** Collects, stores, and queries metrics.
- **Grafana:** Visualizes those metrics in dashboards.
- **Node Exporter:** Exposes host-level measurements.
- **Backend instrumentation:** Produces application-specific measurements.

Grafana does not replace Prometheus, and installing Grafana alone does not generate application metrics.

## 5. How the Monitoring Flow Works

1. The Expense Tracker backend receives an HTTP request.
2. The backend middleware measures request duration and records request details when the response finishes.
3. The `/metrics` endpoint exposes the recorded measurements in Prometheus format.
4. Prometheus periodically scrapes the configured endpoints and stores the results.
5. Grafana queries Prometheus using PromQL.
6. The dashboard displays the resulting metrics so an operator can inspect trends and investigate possible problems.

This is a pull-based metrics collection design: Prometheus retrieves measurements from the configured endpoints.

## 6. Application Metrics Implemented

### 6.1 HTTP request counter

Metric:

`expense_tracker_http_requests_total`

This counter records completed HTTP responses, grouped by:

- `method`
- `route`
- `status_code`

It can help us identify request volume and observe how many responses use particular HTTP status codes.

Example query — request rate by route and method:

```promql
sum by (route, method) (
  rate(expense_tracker_http_requests_total[5m])
)
```

**How to interpret it:** This estimates the average number of requests per second over the previous five minutes, grouped by route and HTTP method.

A sudden increase may indicate increased traffic. A decrease might reflect reduced traffic or an application issue. The query alone cannot distinguish between those explanations.

### 6.2 HTTP request duration histogram

Metric:

`expense_tracker_http_request_duration_seconds`

This histogram records response durations in seconds, grouped by method and route.

The configured bucket boundaries are:

`0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5`

Histograms allow us to calculate averages and estimate latency percentiles when the appropriate bucket data is available.

Example query — average latency in milliseconds by route:

```promql
1000 *
sum by (route) (
  rate(expense_tracker_http_request_duration_seconds_sum[5m])
)
/
sum by (route) (
  rate(expense_tracker_http_request_duration_seconds_count[5m])
)
```

**Important:** This query calculates average latency, not maximum latency or a percentile such as p95. The multiplication by `1000` converts seconds to milliseconds.

### 6.3 Runtime metrics

The backend also collects default runtime metrics through the Prometheus client library. These provide additional information about the Node.js process.

The available metrics depend on the client library and runtime.

### 6.4 Label cardinality

Metric labels must be chosen carefully. Using arbitrary request URLs, user identifiers, or other unbounded values as labels can create excessive numbers of time series.

Our middleware uses route information where available and falls back to controlled values for unmatched routes. This helps avoid creating a unique time series for every arbitrary URL.

## 7. Important Configuration and Code Locations

| Location | Responsibility |
|---|---|
| `app/backend/monitoring/metrics.js` | Defines the metrics registry, counter, histogram, and runtime collection. |
| `app/backend/app.js` | Measures request duration and exposes `/metrics`. |
| `monitoring/prometheus.yml` | Defines Prometheus scrape configuration and targets. |
| `monitoring/alert-rules.yml` | Stores the project's Prometheus alert-rule configuration. |
| `monitoring/compose.yml` | Defines the monitoring services. |
| `docker-compose.yml` | Defines the application services and their integration with monitoring. |
| `scripts/start-stack.sh` | Starts the application and monitoring stack. |
| Grafana dashboard | Presents the selected metrics as visual panels. |

## 8. Handy Commands Reference

Run Docker Compose commands from the repository root unless otherwise specified.

### 8.1 Start and inspect the stack

Start the application and monitoring stack using the project script:

```bash
./scripts/start-stack.sh
```

Inspect running containers:

```bash
docker ps
```

Show all containers, including stopped ones:

```bash
docker ps -a
```

Inspect the monitoring Compose configuration:

```bash
docker compose -f monitoring/compose.yml ps
```

Validate the application Compose configuration:

```bash
docker compose config --quiet
```

Validate the monitoring Compose configuration:

```bash
docker compose -f monitoring/compose.yml config --quiet
```

### 8.2 Inspect container logs

Follow Prometheus logs:

```bash
docker logs -f prometheus
```

Follow Grafana logs:

```bash
docker logs -f grafana
```

Follow Node Exporter logs:

```bash
docker logs -f node-exporter
```

Follow backend logs:

```bash
docker logs -f expense-tracker-backend
```

If the actual container name differs, obtain it from `docker ps` and substitute that name.

Display the most recent 100 log lines:

```bash
docker logs --tail 100 expense-tracker-backend
```

Stop following logs with `Ctrl+C`. This stops the log display, not the container.

### 8.3 Check backend endpoints

Check application health:

```bash
curl -i http://localhost:3000/health
```

Check readiness:

```bash
curl -i http://localhost:3000/ready
```

Inspect the metrics endpoint:

```bash
curl -s http://localhost:3000/metrics
```

Filter for our custom application metrics:

```bash
curl -s http://localhost:3000/metrics \
  | grep -E 'expense_tracker_http_requests_total|expense_tracker_http_request_duration_seconds'
```

A successful metrics response should contain Prometheus-formatted metric output. If a custom metric has not yet been observed, generate a request and inspect the endpoint again.

### 8.4 Check Prometheus targets

Open Prometheus in a browser:

`http://localhost:9090`

Open the targets page:

`http://localhost:9090/targets`

The targets page shows whether Prometheus can scrape each configured target.

Alternatively, query the targets API:

```bash
curl -s http://localhost:9090/api/v1/targets
```

A target with an `UP` health status is currently being scraped successfully. This does not guarantee that the application itself is behaving correctly.

### 8.5 Query metrics in Prometheus

Open:

`http://localhost:9090/graph`

Try these queries individually:

Total number of observed requests:

```promql
sum(expense_tracker_http_requests_total)
```

Request rate over five minutes:

```promql
sum(rate(expense_tracker_http_requests_total[5m]))
```

Average latency by route in milliseconds:

```promql
1000 *
sum by (route) (
  rate(expense_tracker_http_request_duration_seconds_sum[5m])
)
/
sum by (route) (
  rate(expense_tracker_http_request_duration_seconds_count[5m])
)
```

Host CPU, memory, and filesystem metrics can also be queried when exposed by Node Exporter. The exact metric names depend on the exporter version and configuration.

### 8.6 Check Grafana

Open Grafana:

`http://localhost:3001`

Use the configured credentials for this project. Do not put passwords or other secrets in this document.

If the dashboard is empty, investigate in this order:

1. Confirm Prometheus is running.
2. Check `http://localhost:9090/targets`.
3. Confirm the backend `/metrics` endpoint returns metrics.
4. Confirm Grafana's Prometheus data source points to the correct Prometheus service address from within the container network.
5. Run the relevant PromQL query directly in Prometheus.
6. Check the Grafana panel's time range and refresh settings.

A browser URL and a container-to-container URL are not necessarily the same. Inside a container, `localhost` refers to that container itself.

### 8.7 Validate backend changes

From the backend directory:

```bash
cd app/backend
npm run validate
node --check monitoring/metrics.js
```

The first command runs the project's configured validation script. The second checks the metrics module's JavaScript syntax.

Return to the repository root before running repository-level commands:

```bash
cd ../..
```

### 8.8 Inspect images and container identity

List local images:

```bash
docker images
```

Inspect the image used by a running container:

```bash
docker inspect expense-tracker-backend \
  --format '{{.Image}}'
```

Compare that image ID with the expected local image ID when verifying a release.

### 8.9 Clean up safely

Stop the monitoring Compose services:

```bash
docker compose -f monitoring/compose.yml down
```

**Caution:** Do not add `-v` casually. Removing volumes can delete persisted Prometheus history and Grafana state. Also, this command only acts on the services and networks managed by the specified Compose project; it does not necessarily stop the complete application stack.

Use the project's documented shutdown procedure when stopping the entire application and monitoring environment together.

## 9. Troubleshooting Guide

### Prometheus target is DOWN

Check:

1. Is the target container running?
2. Can the target endpoint be reached from the Prometheus container?
3. Does the scrape path match the endpoint?
4. Are the services connected to the intended Docker network?
5. Do the target's container logs show an error?

A successful `curl` from the host does not prove that the same endpoint is reachable from another container.

### Custom metrics are missing

Check:

1. Is the metrics module imported by the backend?
2. Is the middleware registered?
3. Is the `/metrics` route available?
4. Has a request been made to generate observations?
5. Is Prometheus scraping the correct backend address and path?

### Grafana dashboard is empty

Check target health and query results in Prometheus before investigating the Grafana panel. If Prometheus has no matching series, changing dashboard styling will not solve the underlying problem.

### Latency appears as zero or has no data

Rate-based latency queries need observations in the selected time window. Generate requests and allow Prometheus to scrape the endpoint. Check the dashboard time range and the denominator of the average-latency query.

### Container is running but the application is failing

Inspect the container logs and test the health, readiness, and metrics endpoints independently. Container state alone is not proof of application health.

## 10. Validation and Completion Evidence

The milestone validation recorded the following results:

- Backend validation and JavaScript syntax checks passed.
- Application and monitoring Compose configurations validated.
- Health and readiness endpoints returned HTTP 200.
- The backend metrics endpoint exposed the configured metrics.
- All six expected containers were running, with the backend healthy.
- Prometheus reported all three configured targets as healthy.
- The relevant PromQL query returned time-series data.
- The built backend image ID matched the running container image ID.

These checks provide evidence that the monitoring stack was integrated and operational at validation time. They do not guarantee that every future deployment or runtime condition will remain healthy.

## 11. Release and Artifact Management

The backend image was pushed to Amazon ECR:

`748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-backend:1.0.6`

The pushed image was verified against the expected local image.

During cleanup, backend version `1.0.0` was deleted. Backend version `1.0.4` and its rollback alias `a432179` were retained, together with `1.0.6` as the current release. Frontend version `1.0.4` was retained.

Some untagged OCI image-index or attestation entries remained because they were associated with image indexes or attestations. No lifecycle policy was configured as part of this cleanup.

**Operational lesson:** Image cleanup should preserve known rollback versions and account for image manifests, indexes, and attestations. Do not delete artifacts solely because they appear untagged.

## 12. Key Lessons

- Monitoring should answer operational questions, not simply display attractive charts.
- Prometheus collects and queries metrics; Grafana visualizes them.
- Node Exporter provides host metrics, while application instrumentation provides application-specific measurements.
- A healthy scrape target confirms collection connectivity, not overall application correctness.
- Histograms support latency analysis, but averages do not reveal the full latency distribution.
- Metric labels should avoid unbounded values that create excessive time series.
- Container health, application readiness, metrics availability, and dashboard visibility are separate checks.
- Persistent monitoring data needs deliberate lifecycle management.
- Artifact cleanup must preserve necessary rollback options and account for OCI metadata.

## 13. Final Reference

When troubleshooting this stack, follow this sequence:

1. **Containers:** `docker ps`
2. **Application:** check `/health` and `/ready`
3. **Metrics:** inspect `/metrics`
4. **Collection:** inspect Prometheus `/targets`
5. **Query:** test PromQL in Prometheus
6. **Visualization:** inspect Grafana's data source, panel query, and time range
7. **Logs:** inspect the affected service's logs
8. **Release identity:** verify the running container's image ID and expected artifact

This sequence moves from the running environment toward the data and visualization layers, helping isolate the source of a monitoring problem rather than changing several components at once.
