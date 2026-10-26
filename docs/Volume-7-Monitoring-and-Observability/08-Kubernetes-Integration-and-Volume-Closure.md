# Milestone 08 — Kubernetes Integration and Volume Closure

## 1. Objective

Integrate the existing Docker-hosted Prometheus monitoring stack with the Expense Tracker backend running in Kubernetes, without migrating the monitoring stack or unnecessarily disrupting existing application services.

The objective was to demonstrate that Prometheus could scrape metrics from the Kubernetes backend, investigate the networking challenges between Docker and Minikube, and document the limitations of the temporary integration.

This milestone focused on a controlled proof of integration rather than a production-ready monitoring migration.

## 2. Existing Architecture

Before the integration, the monitoring components were running in Docker, while the application was running in Minikube.

### Monitoring stack

- Prometheus — metrics collection and storage.
- Grafana — metrics visualization and dashboards.
- Node Exporter — host-level metrics.
- Prometheus configuration — `monitoring/prometheus.yml`.
- Alert rules — `monitoring/alert-rules.yml`.

### Kubernetes application

- Backend Deployment with three replicas.
- Backend ClusterIP Service on port `3000`.
- Backend metrics endpoint at `/metrics`.
- Health endpoint at `/health`.
- Readiness endpoint at `/ready`.

The existing backend Service was preserved as a ClusterIP Service. We did not migrate Prometheus or Grafana into Kubernetes.

## 3. Engineering Problem

Prometheus could not directly reach the Kubernetes backend using its ClusterIP address.

The investigation established that Prometheus and Minikube were attached to different Docker networks.

Observed network details:

| Component | Address |
|---|---|
| Prometheus container | `172.19.0.2` |
| Prometheus Docker gateway | `172.19.0.1` |
| Minikube node | `192.168.49.2` |
| Backend ClusterIP | `10.104.64.114` |

The VM had a route to the Minikube node network, but that did not automatically make Kubernetes Service addresses reachable from the Prometheus container.

The existing backend Service was confirmed to be a ClusterIP Service, with port `3000` targeting port `3000`. It had no NodePort assigned.

## 4. Troubleshooting and Investigation

### 4.1 Inspecting the Kubernetes Service

The live Service configuration was inspected with:

```bash
kubectl get service backend -o yaml
```

The repository manifest was also reviewed:

```bash
cat kubernetes/backend/service.yaml
```

Both confirmed that the backend used a ClusterIP Service.

### 4.2 Inspecting network connectivity

The following commands were used to investigate the network configuration:

```bash
docker inspect prometheus --format '{{json .NetworkSettings.Networks}}'
```

```bash
docker inspect minikube --format '{{json .NetworkSettings.Networks}}'
```

```bash
docker exec minikube ip route
```

```bash
ip route
```

```bash
docker port minikube
```

The inspection confirmed separate Docker networks and clarified the route between the VM and the Minikube node.

Attempts to reach the Kubernetes API server on `192.168.49.2:8443` and the backend ClusterIP on port `3000` from the Prometheus container timed out. A test against `192.168.49.2:30080` was refused because that port was not exposed by the existing backend Service.

These failures helped distinguish application health from network reachability.

## 5. Verifying the Metrics Endpoint

A temporary Kubernetes port-forward was established using a different local port because port `3000` was already occupied:

```bash
kubectl port-forward service/backend 3001:3000
```

The endpoint was tested from the VM:

```bash
curl -i --connect-timeout 5 http://127.0.0.1:3001/metrics
```

The response returned HTTP `200 OK` and Prometheus-formatted metrics.

Examples included:

```text
process_cpu_seconds_total
process_resident_memory_bytes
nodejs_eventloop_lag_seconds
expense_tracker_http_requests_total
expense_tracker_http_request_duration_seconds
```

This established that the Kubernetes backend was exporting metrics successfully.

## 6. Making the Temporary Endpoint Reachable from Prometheus

The initial port-forward listened only on loopback addresses:

```text
127.0.0.1:3001
[::1]:3001
```

The Prometheus container could not reach the forwarded endpoint through its Docker gateway while the listener was restricted to loopback.

The temporary port-forward was therefore restarted with:

```bash
kubectl port-forward --address 0.0.0.0 service/backend 3001:3000
```

This allowed the Prometheus container to retrieve the metrics through:

```text
http://172.19.0.1:3001/metrics
```

The endpoint returned Prometheus metrics successfully from inside the Prometheus container.

**Security consideration:** Binding the port-forward to `0.0.0.0` exposes the forwarded port through the VM's network interfaces. This was used only for the controlled lab experiment. It should not be treated as a permanent or unrestricted access method.

## 7. Updating the Prometheus Scrape Configuration

The existing `monitoring/prometheus.yml` contained jobs for:

- `prometheus`
- `node-exporter`
- `expense-tracker-backend`

A separate Kubernetes backend job was added:

```yaml
  - job_name: expense-tracker-kubernetes-backend
    metrics_path: /metrics
    static_configs:
      - targets: ["172.19.0.1:3001"]
```

This preserved the existing scrape jobs and introduced a separate target for the Kubernetes-hosted backend.

The configuration was validated with:

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

Validation succeeded:

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
SUCCESS: 1 rules found
```

Prometheus was restarted to load the updated configuration:

```bash
docker restart prometheus
```

## 8. Integration Verification

Prometheus targets were inspected through its API:

```bash
curl -s http://localhost:9090/api/v1/targets
```

The Kubernetes backend target initially reported `DOWN` with a scrape timeout. Further investigation showed that the temporary port-forward had stopped listening.

After restarting the port-forward, connectivity from the Prometheus container was tested again. The metrics endpoint responded successfully.

The subsequent targets API output confirmed:

```text
job: expense-tracker-kubernetes-backend
instance: 172.19.0.1:3001
health: up
lastError: ""
lastScrapeDuration: approximately 0.146 seconds
```

The same observation showed Prometheus and Node Exporter as `UP`.

The existing Docker Compose backend target remained `DOWN`, with the error indicating that Docker DNS could not resolve the hostname `backend`. This was not resolved as part of the Kubernetes integration experiment.

## 9. Cleanup and Final Lab State

Once the successful scrape had been demonstrated, the temporary port-forward was stopped with `Ctrl+C`.

The listener was checked with:

```bash
ss -lntp | grep ':3001' || echo "Port 3001 is closed"
```

The observed result confirmed that port `3001` was closed.

Stopping the port-forward removed the temporary access route. It did not stop the Kubernetes backend Pods or migrate the monitoring stack.

The Kubernetes scrape target is therefore expected to report `DOWN` while its configured target depends on the stopped port-forward. This is a known consequence of cleanup, not evidence that the backend itself has failed.

## 10. Lessons Learned

### Network boundaries matter

Docker containers and Kubernetes Services do not automatically share a network. Successful communication from the VM does not guarantee communication from a container.

### A working endpoint is not the same as a working scrape

The backend exposed valid metrics, but Prometheus could collect them only after a reachable network path was established.

### Temporary access methods have lifecycle limitations

A port-forward depends on a running process. If the process stops, Prometheus loses access to the target.

### Verify the actual target status

A valid configuration file does not prove that a scrape is successful. The Prometheus targets API provided the evidence needed to distinguish configuration validity from runtime connectivity.

### Preserve the existing architecture when appropriate

A Kubernetes-native Prometheus deployment was considered but not implemented. Migrating the monitoring stack would introduce additional scope and was unnecessary for the intended soft-integration experiment.

## 11. Known Limitations and Future Improvements

The following work remains outside the completed proof of integration:

- Replace the temporary port-forward with a durable, controlled network path if ongoing cross-environment scraping is required.
- Investigate the Docker Compose backend target's DNS-resolution error.
- Recheck all targets after the next monitoring-stack startup.
- Consider Kubernetes-native Prometheus deployment only when there is a clear architectural reason to migrate.
- Do not treat a successful temporary scrape as evidence of production readiness.

The integration was demonstrated in a controlled lab environment. It is not a persistent production-style connection.

## 12. Milestone Outcome

The practical objective of Milestone 8 was achieved: Prometheus successfully scraped metrics from the Kubernetes-hosted Expense Tracker backend without migrating Prometheus or Grafana and without changing the existing backend Service type.

The temporary connection was then removed, leaving the lab in a clean state.

**Milestone 8 — Kubernetes Integration and Volume Closure: COMPLETE, with the temporary integration limitation documented.**

The Volume 7 repository documentation and release workflow remain to be finalized after this document is approved, saved, reviewed, committed, and pushed.