# Milestone 05 — Prometheus Monitoring and Alerting

## 1. Objective

Deploy Prometheus for metrics collection, integrate Node Exporter for host-level monitoring, practise PromQL queries, and configure and validate an alerting rule.

The monitoring stack was deployed separately from the existing application Compose stack to avoid disrupting the application services.

## 2. Architecture

The monitoring environment consists of:

- **Prometheus:** Collects and stores time-series metrics and evaluates alerting rules.
- **Node Exporter:** Exposes host operating-system metrics, including CPU, memory, and filesystem statistics.
- **Prometheus web interface:** Provides access to metrics queries, targets, rules, and alerts.

Prometheus and Node Exporter were managed using `monitoring/compose.yml`, with Prometheus data stored in a named Docker volume.

## 3. Configuration

### Prometheus scrape configuration

The configuration in `monitoring/prometheus.yml` includes a 15-second scrape interval and two scrape targets:

- `localhost:9090` — Prometheus's own metrics.
- `node-exporter:9100` — host metrics exposed by Node Exporter.

The configuration loads alerting rules from `alert-rules.yml`.

### Storage and retention

Prometheus uses a persistent volume at `/prometheus` and a configured retention period of three days. This limits the intended retention window, although actual disk usage still depends on the volume's contents and metrics ingestion rate.

### Node Exporter

Node Exporter was deployed as a separate service with read-only host filesystem mounts for access to system metrics. It was not configured as a privileged container.

## 4. Deployment and Validation

The monitoring stack was started with:

```bash
docker compose -f monitoring/compose.yml up -d
```

The Prometheus health endpoint returned:

```text
Prometheus Server is Healthy.
```

The Prometheus targets API and the `up` query confirmed that both Prometheus and Node Exporter were reporting a value of `1` during verification.

The monitoring Compose configuration was validated with:

```bash
docker compose -f monitoring/compose.yml config --quiet
```

No configuration errors were reported.

## 5. PromQL Practice

### Memory availability

The query:

```promql
node_memory_MemAvailable_bytes
```

returned `1465761792` bytes, approximately **1.36 GiB** available at the time of the observation.

### Root filesystem capacity

The following query returned the total capacity of the root filesystem:

```promql
node_filesystem_size_bytes{mountpoint="/",fstype="ext4"}
```

Observed value: `41555521536` bytes, approximately **38.70 GiB**.

Available space was queried with:

```promql
node_filesystem_avail_bytes{mountpoint="/",fstype="ext4"}
```

Observed value: `12081631232` bytes, approximately **11.25 GiB**.

These observations indicated that the root filesystem was approximately 71% used at the time of measurement. They are point-in-time observations, not permanent capacity measurements.

### CPU utilisation

The following expression was used to estimate CPU utilisation per logical CPU over a five-minute rate window:

```promql
100 * (
  1 - avg by(instance, cpu) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  )
)
```

Grouping by `instance` and `cpu` produces separate utilisation estimates for each CPU.

A threshold query was also used to identify CPUs above 20% utilisation:

```promql
100 * (
  1 - avg by(instance, cpu) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  )
) > 20
```

The results demonstrated how PromQL can filter metric series based on a condition.

## 6. Alerting Rule

The file `monitoring/alert-rules.yml` contains the `HighCPUUsage` rule:

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

The rule identifies a CPU whose estimated utilisation exceeds 80%. The condition must remain true for five minutes before the alert transitions from pending to firing.

The rule file was validated using `promtool`. The final validation reported:

```text
SUCCESS: 1 rules found
```

The Prometheus rules API subsequently showed `HighCPUUsage` as `inactive` with its health reported as `ok`. This means the rule was loaded and evaluated successfully, but its firing condition was not met during that observation.

## 7. Controlled Alert Lifecycle Test

A temporary rule named `AlertTestAlwaysFires` was added to test the alert lifecycle without deliberately generating CPU load.

Its expression was:

```promql
vector(1)
```

The rule was configured with a one-minute pending period. After the rule was loaded, the Prometheus rules API showed it as pending. A subsequent alerts API response showed the test alert as firing.

This confirmed the transition from pending to firing and demonstrated that Prometheus was evaluating loaded alert rules.

The temporary rule was then removed. After validating the file again, `promtool` reported one remaining rule. Prometheus was restarted and the rules API showed only `HighCPUUsage`.

Final verification of the alerts API returned:

```json
{
  "status": "success",
  "data": {
    "alerts": []
  }
}
```

This confirmed that no active alerts remained after the test rule was removed.

**Scope limitation:** This test verified Prometheus's alert lifecycle, not an actual CPU-threshold alert firing. Alertmanager delivery and external notifications were not tested.

## 8. Troubleshooting and Lessons Learned

During setup, the rules API initially returned an empty rule group even though the rule file existed on the host.

Inspection showed that the running Prometheus container did not have the expected configuration and rule-file bind mounts. The Prometheus service was force-recreated, after which inspection confirmed that both configuration files were mounted at their expected container paths. The rule group then appeared in the API.

Key lessons:

- A file existing on the host does not prove that a running container can access it.
- Validate the rendered Compose configuration and inspect the running container's mounts when configuration changes do not take effect.
- Validate rule files with `promtool` before loading them into Prometheus.
- Use the rules and alerts APIs to distinguish a loaded rule, a pending alert, a firing alert, and an empty alert list.
- A successful alert lifecycle test does not prove that every alert expression or notification path works.

A temporary CPU workload also encountered Docker stop/removal issues during experimentation. The workload eventually disappeared, and subsequent checks confirmed that Prometheus and Node Exporter remained running. No further CPU stress test was required for the rule-lifecycle objective.

## 9. Outcome

The practical objectives for this milestone were achieved:

- Prometheus deployed in a dedicated monitoring stack.
- Node Exporter integrated as a host metrics source.
- Prometheus targets and metric queries verified.
- CPU utilisation expression explored using PromQL.
- `HighCPUUsage` configured and validated.
- Alert pending-to-firing lifecycle demonstrated with a temporary test rule.
- Temporary rule removed and final alert state verified.

## 10. Vital Commands Reference

### A. Deploy and manage the monitoring stack

**Validate the Docker Compose configuration**

```bash
docker compose -f monitoring/compose.yml config --quiet
```

Checks whether the rendered Compose configuration is valid without printing the full configuration.

**Start the monitoring services**

```bash
docker compose -f monitoring/compose.yml up -d
```

Creates and starts Prometheus and Node Exporter in detached mode.

**Check the monitoring services**

```bash
docker compose -f monitoring/compose.yml ps
```

Displays the status of services managed by the monitoring Compose file.

**Restart Prometheus**

```bash
docker compose -f monitoring/compose.yml restart prometheus
```

Restarts Prometheus after a configuration or rule-file change. A restart does not recreate the container or refresh its bind mounts.

**Recreate Prometheus**

```bash
docker compose -f monitoring/compose.yml up -d --force-recreate prometheus
```

Recreates the Prometheus container. This was necessary when the expected configuration-file mounts were missing from the running container.

### B. Validate the alert rules

**Validate the rule file using `promtool`**

```bash
docker run --rm \
  --entrypoint promtool \
  -v "$PWD/monitoring/alert-rules.yml:/etc/prometheus/alert-rules.yml:ro" \
  prom/prometheus:latest \
  check rules /etc/prometheus/alert-rules.yml
```

Runs Prometheus's rule validator against the local alert-rule file using a temporary container. It checks the rule syntax and structure before loading the rules into Prometheus.

### C. Check Prometheus health and targets

**Check Prometheus health**

```bash
curl -s http://localhost:9090/-/healthy
```

Checks whether Prometheus reports itself as healthy.

**Inspect scrape targets**

```bash
curl -s http://localhost:9090/api/v1/targets
```

Displays the configured scrape targets and their reported status.

**Check whether targets are up**

Open the Prometheus expression interface at `http://localhost:9090/graph` and run:

```promql
up
```

A value of `1` indicates a successful scrape for that target; `0` indicates a failed scrape.

### D. Query system metrics

**Available memory**

```promql
node_memory_MemAvailable_bytes
```

Returns the host's estimated available memory in bytes.

**Root filesystem capacity**

```promql
node_filesystem_size_bytes{mountpoint="/",fstype="ext4"}
```

Returns the total capacity of the selected root filesystem in bytes.

**Available filesystem space**

```promql
node_filesystem_avail_bytes{mountpoint="/",fstype="ext4"}
```

Returns the filesystem space available to unprivileged users, in bytes.

**CPU utilisation per logical CPU**

```promql
100 * (
  1 - avg by(instance, cpu) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  )
)
```

Estimates CPU utilisation as a percentage over a five-minute rate window.

**Find CPUs above 20% utilisation**

```promql
100 * (
  1 - avg by(instance, cpu) (
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  )
) > 20
```

Filters the CPU utilisation results to show only series above 20%.

### E. Inspect alert rules and active alerts

**Inspect loaded alert rules**

```bash
curl -s http://localhost:9090/api/v1/rules
```

Shows loaded rule groups, expressions, evaluation health, and alert states.

**Inspect current alerts**

```bash
curl -s http://localhost:9090/api/v1/alerts
```

Returns alerts currently known to Prometheus, including pending or firing alerts.

**Inspect the mounted configuration and rule files**

```bash
docker inspect prometheus
```

Use the `Mounts` section to verify that the expected host files map to `/etc/prometheus/prometheus.yml` and `/etc/prometheus/alert-rules.yml` inside the container.

### F. Key lesson

Validate configuration before applying it, verify that the running container can access the intended files, and inspect the Prometheus APIs to confirm the actual runtime state. A successful command alone does not prove that the complete monitoring or notification workflow works.


The next monitoring steps should build on this foundation without treating untested notification delivery or real CPU-threshold firing as completed work.
