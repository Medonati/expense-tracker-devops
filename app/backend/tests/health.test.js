import request from "supertest";
import app from "../app.js";

describe("Health Endpoint", () => {
  test("GET /health should return HTTP 200", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("UP");
    expect(response.body.message).toBe("Expense Tracker Backend is healthy");
  });
});
