# Milestone 7 — Alerting and Incident Investigation

## 1. Purpose

This milestone builds on the monitoring foundation established in Volume 7. The objective is to understand how Prometheus alert rules detect abnormal conditions and how metrics, application logs, and health endpoints support incident investigation.

Rather than introducing another monitoring stack, this milestone reuses the existing Prometheus, Node Exporter, Grafana, and Expense Tracker backend configuration.

## 2. Objectives

By the end of this milestone, we aimed to:

- Understand how Prometheus alert rules define abnormal conditions.
- Validate the existing CPU alert configuration.
- Test alert behavior using simulated metric data.
- Investigate application health using logs, health endpoints, and Prometheus metrics.
- Distinguish infrastructure monitoring failures from application-level problems.
- Document the evidence, limitations, and lessons from the investigation.

## 3. Existing monitoring architecture

The monitoring stack already contains the following components:

| Component | Responsibility |
|---|---|
| Prometheus | Collects metrics, evaluates queries, and evaluates alert rules |
| Node Exporter | Exposes host-level metrics, including CPU usage |
| Expense Tracker backend | Exposes application metrics through `/metrics` |
| Grafana | Visualizes infrastructure and application metrics |

Prometheus is configured to scrape itself, Node Exporter, and the backend. The alert rules are stored in `monitoring/alert-rules.yml` and referenced by `monitoring/prometheus.yml`.

The existing configuration was reused without adding another exporter or changing the production alert configuration.

## 4. Existing CPU alert rule

The existing rule is named `HighCPUUsage`.

```yaml
groups:
  - name: host-monitoring
    rules:
      - alert: HighCPUUsage
        expr: 100 * (1 - avg by(instance, cpu) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }} CPU {{ $labels.cpu }}"
          description: "CPU usage has exceeded 80% for 5 minutes."
```

### How the rule works

**Metric source:** `node_cpu_seconds_total`, supplied by Node Exporter.

**Calculation:** The rule uses the rate of change of CPU idle time over a five-minute window to estimate CPU utilization.

**Threshold:** CPU utilization must exceed 80%.

**Grouping:** The expression groups by `instance` and `cpu`, meaning utilization is evaluated separately for each CPU core on each instance.

**Pending period:** The condition must remain true for five minutes before the alert fires.

**Severity:** The alert carries a `warning` severity label.

### Understanding the timing

The Prometheus rule group reported an evaluation interval of 60 seconds. The rule's `for: 5m` setting is separate from that interval: the condition must remain active for the configured duration before the alert transitions to `firing`.

The five-minute rate window is also distinct from the five-minute pending period. One is used to calculate CPU utilization; the other determines how long the threshold must remain exceeded.

## 5. Validating the alert configuration

### 5.1 Confirming that Prometheus loaded the rule

The Prometheus rules API was queried:

```bash
curl -s http://localhost:9090/api/v1/rules
```

The response confirmed:

- Rule group: `host-monitoring`
- Alert: `HighCPUUsage`
- Rule health: `ok`
- Initial state: `inactive`
- Pending duration: 300 seconds

The `inactive` state meant the alert condition was not currently met. It did not mean that the rule was disabled or broken.

### 5.2 Inspecting current CPU utilization

The CPU expression was queried without its threshold comparison:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=100 * (1 - avg by(instance, cpu) (rate(node_cpu_seconds_total{mode="idle"}[5m])))'
```

Observed values at the time of the check:

| CPU core | Utilization |
|---|---:|
| Core 0 | 32.82% |
| Core 1 | 46.14% |

Neither core exceeded the 80% threshold, consistent with the alert's inactive state.

These figures represent the observed environment at that time, not a permanent baseline.

### 5.3 Validating the rules file

The existing rule file was validated using the `promtool` executable available in the running Prometheus container:

```bash
docker exec prometheus promtool check rules /etc/prometheus/alert-rules.yml
```

The command returned:

```text
Checking /etc/prometheus/alert-rules.yml
  SUCCESS: 1 rules found
```

This confirmed that the rule file could be parsed and contained one valid rule.

## 6. Simulated alert testing

A separate test file was created at:

`monitoring/alert-rules.test.yml`

The test file referenced the existing `alert-rules.yml` rather than duplicating the production alert rule.

Two scenarios were defined:

1. CPU usage below the threshold should leave the alert inactive.
2. Sustained CPU usage above the threshold should cause the alert to fire after its configured pending period.

Synthetic counter samples were used to test the rate calculation without deliberately consuming CPU resources on the VM.

### Running the test

The running Prometheus container did not have the test file mounted. Instead of modifying the production Compose configuration, a temporary container was used with the monitoring directory mounted read-only:

```bash
docker run --rm \
  --entrypoint=/bin/promtool \
  -v "$PWD/monitoring:/etc/prometheus:ro" \
  prom/prometheus:v3.15.0 \
  test rules /etc/prometheus/alert-rules.test.yml
```

The command completed successfully.

### What this established

The rule-testing workflow could execute against the existing rule file and synthetic input data without changing the running monitoring stack.

This is useful because rule behavior can be tested before deploying changes to a live environment.

**Scope limitation:** This was a simulated rule test. It was not a live CPU incident, and it did not demonstrate notification delivery. Those activities were not performed as part of this exercise.

## 7. Incident investigation exercise

The next exercise used the existing Expense Tracker backend to establish a healthy baseline and investigate the information available from its logs and metrics.

### 7.1 Verify application health

Command:

```bash
curl -i http://localhost:3000/health
```

Observed result:

```text
HTTP 200 OK
{"status":"UP","message":"Expense Tracker Backend is healthy"}
```

This confirmed that the health endpoint returned a successful response at the time of testing.

### 7.2 Inspect recent application logs

Command:

```bash
docker compose logs --tail=30 backend
```

The logs showed successful requests to `/ready`, `/metrics`, and `/health`.

Examples included:

```text
GET /ready 200
GET /metrics 200
GET /health 200
```

Request durations varied. One metrics request took approximately 127.8 ms, while several other requests completed in a few milliseconds.

A single slower request is not sufficient evidence of an incident. It should be interpreted alongside request rates, latency trends, errors, and the expected behavior of the endpoint.

### 7.3 Verify Prometheus can scrape the backend

Command:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up{job="expense-tracker-backend"}'
```

Observed result:

```text
instance="backend:3000"
job="expense-tracker-backend"
value="1"
```

A value of `1` confirmed that Prometheus was successfully scraping the backend's metrics endpoint.

This does not guarantee that every application function or database operation is working. It confirms that the scrape succeeded.

### 7.4 Identify the correct application metrics

An initial query used a metric name that did not match the backend's instrumentation:

```promql
rate(http_request_duration_seconds_count{job="expense-tracker-backend"}[5m])
```

The query returned an empty vector. This did not establish that the application lacked metrics; it meant that no matching time series was available for that exact query.

The backend's actual metrics were inspected with:

```bash
curl -s http://localhost:3000/metrics \
  | grep -E 'http_request|request_duration|http_requests'
```

The output identified these metrics:

```text
expense_tracker_http_requests_total
expense_tracker_http_request_duration_seconds
```

The request counter includes labels for method, route, and HTTP status code. The duration metric is a histogram that exposes bucket counts, cumulative duration sums, and observation counts.

This was a useful troubleshooting lesson: **verify the actual metric names and labels exposed by an application before constructing PromQL queries.**

### 7.5 Query the correct request-rate metric

The corrected query was:

```bash
curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=rate(expense_tracker_http_requests_total{route="/health"}[5m])'
```

The query returned a value of `0` for the `/health` route.

This indicated that the observed request counter had no measurable increase over the selected five-minute window at the time of the query. It did not mean that the endpoint was unhealthy.

The backend's cumulative metrics included 103 recorded requests to `/health`, but cumulative request counts and recent request rates answer different questions.

## 8. Incident investigation workflow

The checks above establish a practical investigation sequence that can be reused when an alert or unexpected behavior occurs.

1. **Establish the symptom.** Identify what appears to be failing or behaving abnormally.
2. **Check application health.** Query the relevant health endpoint and record the HTTP response.
3. **Inspect logs.** Look for errors, failed requests, unusual response codes, and relevant timestamps.
4. **Check scrape health.** Use the Prometheus `up` metric to determine whether the monitoring system can collect metrics from the target.
5. **Inspect application metrics.** Confirm the actual metric names and labels before writing queries.
6. **Compare trends.** Examine request rates, latency, error rates, and infrastructure utilization in context.
7. **Form a hypothesis.** Use the combined evidence to identify likely causes rather than relying on one metric.
8. **Verify the outcome.** After a remediation, repeat the relevant health checks and metric queries.

A successful scrape does not prove the application is fully functional. Similarly, a healthy CPU reading does not rule out database failures, application exceptions, or other dependencies.

## 9. Handy commands

| Purpose | Command or query |
|---|---|
| Inspect loaded alert rules | `curl -s http://localhost:9090/api/v1/rules` |
| Validate alert rule syntax | `docker exec prometheus promtool check rules /etc/prometheus/alert-rules.yml` |
| Test alert rules | `docker run --rm --entrypoint=/bin/promtool -v "$PWD/monitoring:/etc/prometheus:ro" prom/prometheus:v3.15.0 test rules /etc/prometheus/alert-rules.test.yml` |
| Check application health | `curl -i http://localhost:3000/health` |
| Inspect backend logs | `docker compose logs --tail=30 backend` |
| Check scrape health | `up{job="expense-tracker-backend"}` |
| Query recent health-request rate | `rate(expense_tracker_http_requests_total{route="/health"}[5m])` |
| Inspect backend metric names | `curl -s http://localhost:3000/metrics` |

Run the Docker commands from the repository root, where the relative `monitoring/` path resolves correctly.

## 10. Operational considerations

### Alert thresholds need context

An 80% CPU threshold is a configured starting point, not a universal definition of an incident. Production thresholds should account for workload characteristics, resource limits, expected traffic, and the consequences of sustained utilization.

### Avoid noisy alerts

The pending duration helps avoid firing the alert for short-lived CPU spikes. However, the appropriate duration depends on the workload and how quickly intervention is needed.

### Separate alert definition from notification delivery

A rule can be loaded, evaluated, and enter the firing state without any notification being delivered. Notification routing and delivery require their own configuration and validation.

### Keep test artifacts separate

Rule tests should remain separate from production rule configuration. Using a temporary test container with a read-only mount also avoids changing the running stack merely to execute a test.

### Interpret metrics in context

A metric value is evidence, not automatically a diagnosis. Empty query results can indicate a wrong metric name or label, missing series, or insufficient recent samples. A zero request rate can be normal when an endpoint receives no traffic.

## 11. Lessons learned

This milestone reinforced several practical lessons:

- Prometheus alert rules should be validated before relying on them.
- Rule-testing tools allow alert behavior to be tested with synthetic inputs.
- A live scrape succeeding does not guarantee all application functions are healthy.
- Metric names and labels must be verified before writing queries.
- Logs, metrics, and health endpoints provide complementary evidence.
- Cumulative counters, request rates, and latency histograms must be interpreted differently.
- A controlled test can validate a rule without unnecessarily stressing a development VM.
- Incident investigation should follow evidence and testable hypotheses, not assumptions.

## 12. Evidence and completion record

| Check | Recorded result |
|---|---|
| Existing CPU alert loaded by Prometheus | Verified |
| Rule health | `ok` |
| Rule syntax validation | Passed; one rule found |
| Simulated rule test | Command completed successfully |
| Backend health endpoint | HTTP 200 |
| Backend Prometheus scrape | `up = 1` |
| Backend metric names | Inspected and identified |
| Correct application request-rate query | Executed successfully; returned `0` for the selected five-minute window |
| Live CPU alert firing | Not tested |
| Notification delivery | Not configured or tested |
| Real application failure and recovery | Not performed |

### Milestone outcome

The existing alert configuration was validated, simulated alert testing was executed successfully, and the available application logs, health endpoint, and Prometheus metrics were used to practise a basic incident investigation.

This document records the checks performed and their limitations. The remaining volume README and overall Volume 7 release decision will be handled after all eight milestones have been reviewed and completed.
