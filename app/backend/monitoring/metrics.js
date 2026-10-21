import {
  Registry,
  Counter,
  Histogram,
  collectDefaultMetrics,
  prometheusContentType,
} from "@prometheus-io/client";

export const register = new Registry();

collectDefaultMetrics({ register });

export const httpRequestsTotal = new Counter({
  name: "expense_tracker_http_requests_total",
  help: "Total HTTP requests received by the backend",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

export const httpRequestDurationSeconds = new Histogram({
  name: "expense_tracker_http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

export { prometheusContentType };
