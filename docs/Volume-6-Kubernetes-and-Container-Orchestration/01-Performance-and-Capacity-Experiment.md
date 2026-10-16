# Milestone 01 - Performance and Capacity Experiment

## 1. Objective

Before introducing Kubernetes, this experiment was conducted to understand how the existing single-instance Docker deployment behaves as application demand increases.

The objective was not to determine a universal capacity figure for the application. Instead, the experiment was designed to:

* establish a performance baseline;
* observe the relationship between concurrency, throughput, and latency;
* identify performance degradation under increasing load;
* compare a lightweight application endpoint with a database-backed operation;
* understand why a single application instance has practical capacity limits;
* establish the engineering problem that Kubernetes scaling will address.

The guiding principle was:

> **You don't know application capacity from architecture; you know it by measuring under controlled load.**

---

## 2. Environment

The experiment used the Expense Tracker application deployed as a Docker Compose stack on a temporary AWS EC2 instance.

### Application components

```text
EC2 Instance
│
├── Nginx / Frontend
├── Node.js Backend
└── MongoDB
```

The backend exposed port `3000` internally to the Docker network, while the frontend exposed HTTP on port `80`.

### Relevant backend endpoints

Lightweight endpoint:

```text
GET /health
```

Database-backed endpoint:

```text
POST /api/v1/getTransaction
```

The transaction endpoint executes application logic and queries MongoDB.

The request body used for the database-backed test was:

```json
{
  "userId": "6aa98ee7e322478486eeb772",
  "type": "all",
  "frequency": "30"
}
```

The user ID was obtained from the MongoDB instance rather than being invented.

---

## 3. Testing Method

ApacheBench (AB) version 2.3 was used as the load-testing tool.

The experiment followed a gradual increase in concurrency rather than immediately applying extreme load.

The `/health` endpoint was tested first to isolate the Node.js HTTP/application layer from database activity.

The database-backed `/getTransaction` endpoint was then tested separately to observe the additional effect of database-backed application work.

Resource utilization was observed using:

```bash
docker stats
```

and host-level utilization was observed using:

```bash
top
```

---

# 4. Experiment 1 — Lightweight `/health` Endpoint

The first test targeted:

```text
GET /health
```

This endpoint was intentionally selected because it does not represent a database-backed transaction. It provided a relatively isolated measurement of backend HTTP handling.

## Test 1 — 10 Concurrent Requests

Command:

```bash
ab -n 100 -c 10 http://172.18.0.3:3000/health
```

Results:

| Metric          |   Result |
| --------------- | -------: |
| Total requests  |      100 |
| Concurrency     |       10 |
| Failed requests |        0 |
| Requests/sec    |   886.34 |
| Mean latency    | 11.28 ms |
| Median          |    10 ms |
| P95             |    14 ms |
| Maximum         |    14 ms |

The application successfully completed all requests.

---

## Test 2 — 25 Concurrent Requests

Command:

```bash
ab -n 1000 -c 25 http://172.18.0.3:3000/health
```

Results:

| Metric          |   Result |
| --------------- | -------: |
| Total requests  |    1,000 |
| Concurrency     |       25 |
| Failed requests |        0 |
| Requests/sec    | 1,071.55 |
| Mean latency    | 23.33 ms |
| Median          |    21 ms |
| P95             |    38 ms |
| Maximum         |    51 ms |

Throughput increased, but latency also increased.

---

## Test 3 — 100 Concurrent Requests

Command:

```bash
ab -n 5000 -c 100 http://172.18.0.3:3000/health
```

Results:

| Metric          |   Result |
| --------------- | -------: |
| Total requests  |    5,000 |
| Concurrency     |      100 |
| Failed requests |        0 |
| Requests/sec    | 1,125.54 |
| Mean latency    | 88.85 ms |
| Median          |    77 ms |
| P95             |   166 ms |
| P99             |   246 ms |
| Maximum         |   266 ms |

At this point, increasing concurrency produced only a modest increase in throughput while latency increased substantially.

---

## Test 4 — 200 Concurrent Requests

Command:

```bash
ab -n 5000 -c 200 http://172.18.0.3:3000/health
```

Results:

| Metric          |    Result |
| --------------- | --------: |
| Total requests  |     5,000 |
| Concurrency     |       200 |
| Failed requests |         0 |
| Requests/sec    |  1,203.73 |
| Mean latency    | 166.15 ms |
| Median          |    142 ms |
| P95             |    292 ms |
| P99             |    495 ms |
| Maximum         |    505 ms |

The increase from 100 to 200 concurrent requests produced only a modest throughput increase while mean and tail latency continued to rise.

---

## Test 5 — 500 Concurrent Requests

Command:

```bash
ab -n 10000 -c 500 http://172.18.0.3:3000/health
```

Results:

| Metric          |    Result |
| --------------- | --------: |
| Total requests  |    10,000 |
| Concurrency     |       500 |
| Failed requests |         0 |
| Requests/sec    |  1,573.52 |
| Mean latency    | 317.76 ms |
| Median          |    318 ms |
| P95             |    330 ms |
| P99             |    334 ms |
| Maximum         |    335 ms |

Throughput increased again, but latency had become significantly higher than at lower concurrency.

---

## Test 6 — 1,000 Concurrent Requests

Command:

```bash
ab -n 10000 -c 1000 http://172.18.0.3:3000/health
```

Results:

| Metric          |   Result |
| --------------- | -------: |
| Total requests  |   10,000 |
| Concurrency     |    1,000 |
| Failed requests |        0 |
| Requests/sec    | 1,062.70 |
| Mean latency    |   941 ms |
| Median          |   338 ms |
| P95             | 1,771 ms |
| P99             | 7,618 ms |
| Maximum         | 8,752 ms |

This was the most significant result from the `/health` experiment.

Increasing concurrency from 500 to 1,000 did not increase throughput. Instead:

```text
Throughput:
1,573.52 req/s → 1,062.70 req/s

Mean latency:
317.76 ms → 941 ms

P99 latency:
334 ms → 7,618 ms
```

The application still reported:

```text
Failed requests: 0
```

Therefore, the system experienced **severe performance degradation without outright request failure**.

---

# 5. Resource Observations

During the experiments, Docker resource utilization was monitored using:

```bash
docker stats
```

At one observed point following the high-concurrency tests:

```text
frontend   0.00% CPU    3.633 MiB
backend    0.00% CPU   62.25 MiB
mongodb    0.40% CPU   69.57 MiB
```

Host-level monitoring with `top` showed the EC2 host returning to approximately:

```text
99.3% idle CPU
```

after the workload had completed.

During the active high-concurrency test, CPU utilization was observed to rise to approximately **54–56%**.

This demonstrated that CPU utilization increased under load, but the experiment did not produce sustained 100% CPU utilization.

Therefore, the experiment did **not** establish CPU saturation as the definitive bottleneck.

---

# 6. Experiment 2 — Database-Backed API

The second experiment tested:

```text
POST /api/v1/getTransaction
```

Unlike `/health`, this endpoint performs application and database work.

The controller:

1. receives the request;
2. extracts `userId`, `type`, `frequency`, `startDate`, and `endDate`;
3. verifies the user using MongoDB;
4. constructs the transaction query;
5. queries the transaction data;
6. returns the result.

A valid request was first verified manually and returned:

```json
{
  "success": true,
  "transactions": []
}
```

This confirmed that the endpoint was functioning before load testing.

---

## Test 7 — 25 Concurrent Database Requests

Command:

```bash
ab -n 1000 -c 25 \
  -p /tmp/get-transactions.json \
  -T application/json \
  http://172.18.0.2:3000/api/v1/getTransaction
```

Results:

| Metric          |   Result |
| --------------- | -------: |
| Total requests  |    1,000 |
| Concurrency     |       25 |
| Failed requests |        0 |
| Requests/sec    |   322.09 |
| Mean latency    | 77.62 ms |
| Median          |    72 ms |
| P95             |   103 ms |
| Maximum         |   135 ms |

Compared with the `/health` test at the same concurrency, the database-backed operation had substantially lower throughput and higher latency.

---

## Test 8 — 500 Concurrent Database Requests

A further test was performed with:

```text
10,000 requests
500 concurrent requests
```

Results:

| Metric          |      Result |
| --------------- | ----------: |
| Total requests  |      10,000 |
| Concurrency     |         500 |
| Failed requests |           0 |
| Requests/sec    |      498.34 |
| Mean latency    | 1,003.33 ms |
| Median          |      943 ms |
| P95             |    1,253 ms |
| P99             |    1,392 ms |
| Maximum         |    1,506 ms |

The increase from 25 to 500 concurrent requests produced only a moderate throughput increase while mean latency increased dramatically.

---

# 7. Key Observations

### 7.1 Capacity is workload-dependent

The `/health` endpoint and `/getTransaction` endpoint behaved very differently.

At 25 concurrent requests:

```text
/health
≈ 1,071 req/s
≈ 23 ms mean latency

/getTransaction
≈ 322 req/s
≈ 78 ms mean latency
```

Therefore, there is no single meaningful statement such as:

> "This server can handle X requests per second."

The workload being performed matters.

---

### 7.2 Throughput does not increase indefinitely

As concurrency increased, throughput initially increased.

However, eventually the additional concurrency produced diminishing throughput gains and substantially higher latency.

The `/health` experiment demonstrated this particularly clearly at 1,000 concurrent requests, where throughput actually fell compared with the 500-concurrency test.

---

### 7.3 Performance degradation can happen before request failure

Even at 1,000 concurrent `/health` requests:

```text
Failed requests: 0
```

However:

```text
P99 latency: 7.6 seconds
```

This demonstrates that an application can remain technically available while providing increasingly poor performance.

---

### 7.4 CPU and memory utilization alone do not define capacity

CPU utilization increased during the high-concurrency tests, reaching approximately 54–56% in the observed host-level measurements.

However, the experiment did not show sustained CPU saturation, and memory also remained below the available container limit.

Therefore, the experiment does not justify claiming that CPU or memory was the sole bottleneck.

Further performance investigation would be required to identify the exact limiting mechanism.

---

### 7.5 A single instance has practical limits

The experiment demonstrated that increasing demand against a single application instance eventually resulted in substantially higher latency and diminishing throughput gains.

This provides the engineering motivation for investigating mechanisms that allow application workloads to be distributed across multiple instances.

---

# 8. Limitations

This experiment was deliberately designed as a controlled learning exercise rather than a production benchmark.

Important limitations include:

* ApacheBench was used rather than a comprehensive production load-testing platform.
* The `/health` endpoint is much simpler than a real user workflow.
* The database-backed test used a user with no transactions in the test database.
* The tests were performed against the backend container inside the Docker network rather than through the complete public Internet → Nginx → frontend → backend path.
* The load generator and application environment were not designed as a production-grade distributed benchmarking system.
* CPU observations from `docker stats` and `top` were snapshots/observations rather than a continuous metrics collection system.
* Network latency between real users and the application was not measured.
* The experiment does not establish a universal maximum number of users or requests the EC2 instance can support.

Consequently, the measured values should be treated as **observations from this specific controlled environment**, not production capacity guarantees.

---

# 9. Engineering Conclusion

The experiment established a clear relationship between increasing concurrency and application performance.

At low concurrency, the application responded quickly and maintained successful requests.

As concurrency increased:

```text
Demand
  ↓
Concurrency increases
  ↓
Latency increases
  ↓
Throughput gains diminish
  ↓
Eventually throughput decreases
  ↓
Application performance degrades
```

The database-backed endpoint also demonstrated that real application operations can have significantly different capacity characteristics from lightweight health checks.

The key lesson is:

> **Application capacity must be measured against the workload being performed. Increasing demand against a single application instance eventually produces diminishing throughput and increasing latency.**

This creates the engineering problem that the next stage of the project will address:

> **How can we run, manage, distribute, and scale multiple instances of our containerized application reliably?**

This leads into **Kubernetes and container orchestration**.
