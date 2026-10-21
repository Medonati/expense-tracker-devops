import express from "express";
import mongoose from "mongoose";
import cors from "cors";
import bodyParser from "body-parser";
import helmet from "helmet";
import morgan from "morgan";
import transactionRoutes from "./Routers/Transactions.js";
import userRoutes from "./Routers/userRouter.js";
import {
  register,
  httpRequestsTotal,
  httpRequestDurationSeconds,
  prometheusContentType,
} from "./monitoring/metrics.js";

const app = express();

const allowedOrigins = [
  "https://main.d1sj7cd70hlter.amplifyapp.com",
  "https://expense-tracker-app-three-beryl.vercel.app",
  "http://localhost:3001",
];

// Middleware
app.use(express.json());
app.use(
  cors({
    origin: allowedOrigins,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE"],
  })
);

app.use(helmet());
app.use(helmet.crossOriginResourcePolicy({ policy: "cross-origin" }));
app.use(morgan("dev"));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

// Prometheus HTTP metrics middleware
app.use((req, res, next) => {
  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const durationSeconds =
      Number(process.hrtime.bigint() - start) / 1e9;

    const route = req.route?.path
      ? `${req.baseUrl}${req.route.path}`
      : req.path === "/metrics"
        ? "/metrics"
        : "unmatched";

    const labels = {
      method: req.method,
      route,
    };

    httpRequestsTotal.inc({
      ...labels,
      status_code: String(res.statusCode),
    });

    httpRequestDurationSeconds.observe(labels, durationSeconds);
  });

  next();
});


// Routes
app.use("/api/v1", transactionRoutes);
app.use("/api/auth", userRoutes);

// Prometheus metrics endpoint
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", prometheusContentType);
    res.end(await register.metrics());
  } catch (error) {
    console.error("Failed to collect Prometheus metrics:", error);
    res.status(500).send("Failed to collect metrics");
  }
});

app.get("/", (req, res) => {
  res.send("Hello World!");
});


// Health Check
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    message: "Expense Tracker Backend is healthy",
  });
});

// Readiness Check
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

export default app;
