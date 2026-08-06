import express from "express";
import mongoose from "mongoose";
import cors from "cors";
import bodyParser from "body-parser";
import helmet from "helmet";
import morgan from "morgan";
import transactionRoutes from "./Routers/Transactions.js";
import userRoutes from "./Routers/userRouter.js";

const app = express();

const allowedOrigins = [
  "https://main.d1sj7cd70hlter.amplifyapp.com",
  "https://expense-tracker-app-three-beryl.vercel.app",
  // Add more origins as needed
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

// Routes
app.use("/api/v1", transactionRoutes);
app.use("/api/auth", userRoutes);

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
