# Metrics and Resource Monitoring

## 1. Objective

Establish a baseline for CPU, memory, process activity, container resource consumption, pressure indicators, and filesystem capacity in the DevOps lab.

The objective was to learn how to interpret native Linux and Docker metrics before introducing a dedicated monitoring stack.

## 2. Environment

- Operating system: Ubuntu 22.04.5 LTS
- Virtual machine memory: approximately 2.4 GiB
- Virtual CPUs: 2
- Swap: disabled
- Container runtime: Docker
- Application containers: backend, MongoDB, and frontend
- Additional service: Jenkins

## 3. Container Resource Baseline

The initial `docker stats --no-stream` output showed:

| Container | CPU | Memory usage | Memory percentage |
|---|---:|---:|---:|
| Backend | 0.00% | 77.68 MiB | 3.15% |
| MongoDB | 8.44% | 161.2 MiB | 6.54% |
| Frontend | 0.00% | 7.445 MiB | 0.30% |

A subsequent live sample showed MongoDB CPU usage at 0.73%, while backend and frontend usage remained low.

### Interpretation

- Container resource consumption varied between samples.
- The initial MongoDB CPU reading was not sustained in the later sample.
- Network and block I/O counters accumulated over the container's lifetime; they were not instantaneous throughput measurements.
- A single sample was insufficient to establish sustained resource pressure.

Inspection of the container configuration returned:

```text
/backend Memory=0 CPUQuota=0 NanoCpus=0
/mongodb Memory=0 CPUQuota=0 NanoCpus=0
/frontend Memory=0 CPUQuota=0 NanoCpus=0
```

These values indicate that no explicit per-container memory limit or CPU quota was configured through the inspected fields.

## 4. VM Memory Baseline

The `free -h` output showed:

| Metric | Observation |
|---|---:|
| Total memory | 2.4 GiB |
| Used memory | Approximately 807–808 MiB |
| Free memory | Approximately 356–360 MiB |
| Available memory | Approximately 1.4 GiB |
| Swap | 0 B |

### Interpretation

Linux uses otherwise available memory for buffers and cache. Therefore, the `free` column alone does not represent the amount of memory available to applications. The `available` estimate is more useful for assessing whether the system can accommodate additional memory demand.

The observed available memory was approximately 1.4 GiB. There was no swap configured.

## 5. CPU Load and Scheduling

The observed load averages were:

| Time | 1-minute | 5-minute | 15-minute |
|---|---:|---:|---:|
| 14:52:55 | 3.84 | 4.16 | 13.63 |
| 14:53:34 | 1.97 | 3.64 | 13.05 |
| 14:56:47 | 2.14 | 2.71 | 10.87 |

The VM has two virtual CPUs. The 15-minute load average declined from 13.63 to 10.87 during the observations, while the 5-minute average declined from 4.16 to 2.71.

A `top` snapshot reported 100% CPU idle, despite the elevated load averages. The process inspection identified a Jenkins Java process, but the evidence did not establish Jenkins as the cause of the historical load.

### Interpretation

Load average is not equivalent to CPU utilization. It reflects runnable tasks and tasks in certain uninterruptible wait states, averaged over time.

The declining load averages and mostly idle CPU samples suggested that the earlier load was not necessarily sustained CPU saturation. Further evidence would be required to attribute the load to a particular process or resource.

## 6. CPU Pressure

The memory-independent CPU pressure report contained:

```text
some avg10=32.52 avg60=23.26 avg300=24.01 total=5348145728
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
```

The `some` values indicated that runnable tasks had experienced CPU scheduling delays over the reported rolling windows. CPU pressure is not a direct measurement of CPU utilization, and these figures alone did not identify the responsible process.

## 7. Memory Pressure

The memory pressure report contained:

```text
some avg10=0.00 avg60=0.00 avg300=0.08 total=1019148921
full avg10=0.00 avg60=0.00 avg300=0.00 total=511678938
```

Recent rolling averages were low. Combined with approximately 1.4 GiB of available memory and zero swap activity in the sampled `vmstat` output, these observations did not indicate significant current memory pressure.

The cumulative `total` values were recorded as counters, not interpreted as current pressure percentages.

## 8. Short-Interval System Sampling

The command `vmstat 1 5` collected five samples. Its first row represented averages since boot; the subsequent rows provided short-interval observations.

The recent samples showed:

- One brief runnable-task spike to 22 tasks.
- Runnable-task counts of zero in the following three samples.
- CPU idle values of 99%, 93%, 100%, and 100% across the later samples.
- I/O wait values of 0%, 2%, 0%, and 0%.
- No swap-in or swap-out activity.

### Interpretation

The sample suggested intermittent scheduling activity rather than demonstrating sustained CPU saturation. The short sampling window did not establish the cause of the earlier load averages.

## 9. Filesystem Capacity

The filesystem inspection returned:

| Mount point | Filesystem type | Size | Used | Available | Usage |
|---|---|---:|---:|---:|---:|
| `/` | ext4 | 39 GB | 28 GB | 12 GB | 70% |
| `/vagrant` | vboxsf | 466 GB | 430 GB | 36 GB | 93% |
| `/home/vagrant/workspace/expense-tracker-devops` | vboxsf | 466 GB | 430 GB | 36 GB | 93% |

### Interpretation

The VM root filesystem and the shared workspace are different filesystem mounts.

Both workspace paths use the `vboxsf` filesystem type and report identical capacities and usage. They likely expose the same underlying shared storage, so their available space must not be added together.

The shared workspace is at 93% usage and warrants attention. This is a capacity observation, not evidence of disk failure. Any cleanup should begin with identifying what consumes the space and confirming which files are safe to remove.

## 10. Key Findings

1. Docker's built-in statistics provided a baseline for CPU, memory, network I/O, block I/O, and process counts.
2. Container resource consumption varied across samples.
3. The VM had approximately 1.4 GiB of available memory and no configured swap.
4. CPU load averages were elevated but declined during observation.
5. CPU utilization was mostly low in the short-interval samples.
6. CPU pressure and load average could not, by themselves, identify a responsible process.
7. Recent memory pressure readings were low.
8. No explicit per-container CPU quotas or memory limits were configured through the inspected Docker fields.
9. The root filesystem was at 70% usage, while shared workspace storage was at 93%.

## 11. Limitations

This exercise established a baseline rather than a complete monitoring solution.

- The observations covered short intervals and snapshots, not long-term trends.
- The cause of the historical elevated load average remains unconfirmed.
- The baseline did not include a configured metrics collection system, dashboard, or alerting rules.
- The high shared-folder usage needs separate investigation before any cleanup action.

## 12. Conclusion

This milestone established a practical foundation for resource monitoring using `docker stats`, `free`, `top`, `uptime`, `ps`, `/proc/pressure`, `vmstat`, and `df`.

The key lesson is that no single metric is sufficient to diagnose system health. CPU utilization, load average, scheduling pressure, memory availability, I/O activity, container health, and filesystem capacity must be interpreted together.

The next step is to continue through the Monitoring and Observability roadmap, building on this baseline before introducing dedicated metrics collection and visualization.
