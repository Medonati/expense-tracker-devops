import request from "supertest";
import app from "../app.js";

describe("Readiness Endpoint", () => {
  test("GET /ready should return 503 when database is disconnected", async () => {
    const response = await request(app).get("/ready");

    expect(response.statusCode).toBe(503);
    expect(response.body.status).toBe("NOT READY");
    expect(response.body.database).toBe("DISCONNECTED");
  });
});
