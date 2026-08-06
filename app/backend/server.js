import fs from "fs";
import dotenv from "dotenv";
import app from "./app.js";
import { connectDB } from "./DB/Database.js";

const appEnv = process.env.APP_ENV || "local";
const envPath = `./config/config.${appEnv}.env`;

if (!fs.existsSync(envPath)) {
  console.error(`Configuration file not found: ${envPath}`);
  process.exit(1);
}

dotenv.config({ path: envPath });

console.log(`Starting application with '${appEnv}' configuration`);

const port = process.env.PORT;

const startServer = async () => {
  try {
    await connectDB();

    app.listen(port, () => {
      console.log(`Server is listening on http://localhost:${port}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
};

startServer();
