# Volume 5 — Frontend & Full-Stack Application Integration

## Milestone 01 — Frontend Foundation & Local Full-Stack Integration

### Milestone Objective

Establish a working local full-stack environment by connecting the existing React frontend to the existing Node.js/Express backend and MongoDB database.

The goal of this milestone was not to become a frontend developer, but to understand how the frontend participates in the overall application architecture and how user actions travel through the system.

The guiding principle remained:

> **Understand before automating.**

---

# 1. Starting Point

Before this milestone, the backend portion of the Expense Tracker had already been developed, containerized, integrated with MongoDB, deployed to AWS EC2, and incorporated into the CI/CD workflow.

The frontend, however, was still configured to communicate with an externally hosted Render backend.

The frontend therefore needed to be brought into the local development environment before it could eventually become part of the containerized and production-like platform.

---

# 2. Frontend Application Overview

The frontend is a React application using:

* React 18
* React Router
* Axios
* Bootstrap
* Material UI
* React Toastify
* React Date Range
* React Datepicker
* Other supporting React libraries

The application contains major areas for:

* Authentication
* User registration
* Login
* Avatar selection
* Transaction management
* Transaction analytics
* Transaction filtering

The main routes identified were:

```text
/           → Home
/login      → Login
/register   → Register
/setAvatar  → Set Avatar
```

The frontend communicates with the backend through HTTP API requests using Axios.

---

# 3. Local Port Architecture

The backend was already using port `3000`.

When the React application was started, it detected that port `3000` was occupied and therefore required a separate port.

The frontend was run on:

```text
Frontend → localhost:3001
Backend  → localhost:3000
```

The Vagrant environment was updated to forward:

```text
Guest 3001 → Host 3001
```

The resulting development environment included:

```text
Host
 │
 ├── 3000 → Backend
 ├── 3001 → Frontend
 ├── 8080 → Jenkins
 └── 80   → Existing service
```

This allowed the browser on the host machine to access the React application running inside the DevOps VM.

---

# 4. Frontend Local Startup

The initial attempt to start the React application produced:

```text
react-scripts: not found
```

This indicated that the frontend dependencies had not yet been installed.

Running:

```text
npm install
```

installed the required dependencies.

The application was subsequently started successfully with:

```text
npm start
```

The React development server compiled successfully.

Two existing ESLint warnings were observed:

* `selectedSprite` assigned but never used
* Missing `cUser._id` dependency in a `useEffect`

These warnings were deliberately left unchanged because they were unrelated to the current DevOps milestone.

### Engineering Principle

> Do not modify unrelated application code simply because a warning appears during infrastructure or integration work.

---

# 5. Environment-Specific API Configuration

The frontend originally contained a hardcoded Render backend:

```text
https://expense-tracker-app-knl1.onrender.com
```

It also contained a commented localhost backend.

Rather than maintaining separate hardcoded source-code versions, environment-specific configuration was introduced.

A development environment file was created:

```text
.env.development
```

with:

```text
REACT_APP_API_URL=http://localhost:3000
```

The API utility was then changed so that the backend host comes from the environment:

```js
const host = process.env.REACT_APP_API_URL;
```

The API paths themselves remained unchanged:

```text
/api/auth/setAvatar
/api/auth/register
/api/auth/login
/api/v1/addTransaction
/api/v1/getTransaction
/api/v1/updateTransaction
/api/v1/deleteTransaction
```

This established the important separation:

```text
Application code
      +
Environment configuration
```

rather than embedding the environment directly into application logic.

---

# 6. CORS Discovery and Troubleshooting

After changing the frontend API URL to localhost, the browser successfully attempted to communicate with the local backend.

However, the request initially failed because the backend's CORS configuration did not allow:

```text
http://localhost:3001
```

The backend's allowed origins were inspected and the local frontend origin was added.

The running backend container initially continued using the previous image, so the new CORS configuration was not immediately reflected.

The backend container was therefore recreated and rebuilt.

After rebuilding, the preflight request returned:

```text
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://localhost:3001
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET,POST,PUT,DELETE
```

The browser was then able to communicate with the backend.

### Engineering Principle

The configuration existing in source code is not necessarily the configuration running in a container.

Therefore:

> **Verify the running system, not just the source code.**

---

# 7. Authentication Flow Verification

The local login request initially returned:

```text
401 Unauthorized
```

This proved that the request was reaching the backend successfully.

The problem was then investigated rather than incorrectly treating it as a connectivity issue.

The MongoDB volumes were examined because the existing user data was important to the login test.

The running MongoDB container was found to be using:

```text
expense-tracker-devops_mongo-data
```

while another volume existed:

```text
mongo-data
```

The unused volume was safely tested and contained the expected user:

```text
med@example.com
```

This demonstrated that the original user data existed in the standalone `mongo-data` volume.

---

# 8. MongoDB Volume Correction

The Docker Compose configuration originally declared:

```yaml
volumes:
  mongo-data:
```

Docker Compose had automatically prefixed the volume name with the Compose project name.

To ensure that the application explicitly used the intended persistent volume, the Compose configuration was changed to:

```yaml
volumes:
  mongo-data:
    name: mongo-data
```

The MongoDB container was recreated using the correct volume.

Verification confirmed:

```text
mongo-data → /data/db
```

The existing user data was then accessible to the application.

### Engineering Principle

Docker Compose resource names can differ from the names developers expect because Compose applies project-based naming.

Therefore:

> **Never assume which volume a container is using. Inspect the actual mount.**

---

# 9. Authentication Successfully Verified

A new user was successfully registered through the browser.

The user then:

1. Registered
2. Set an avatar
3. Logged out
4. Logged back in
5. Received the expected welcome message
6. Reached the Home page

This verified the local authentication workflow.

The backend uses bcrypt for password handling.

Registration hashes the password before storing it, while login compares the submitted password against the stored hash.

The Network tab also demonstrated that the browser sends the password as part of the login request.

This led to an important security distinction:

```text
Password in HTTP request
        ≠
Password stored in database
```

The browser must submit the credential to the authentication API, while the database should contain the password hash rather than the plaintext password.

The local environment currently uses HTTP because this is a development laboratory. Production deployment requires encrypted transport such as HTTPS.

---

# 10. Transaction Creation Verification

The Add Transaction interface was tested successfully.

A transaction was created with:

```text
Date:        2026-09-06
Title:       school fees
Amount:      200
Type:        expense
Category:    Other
Description: School
```

The transaction appeared in the application table:

```text
2026-09-06 | school fees | 200 | expense | Other
```

This demonstrated successful communication between the frontend, backend, and database.

---

# 11. Network-Level API Investigation

The browser Developer Tools Network tab was used to inspect the actual HTTP requests generated by the frontend.

### Transaction Retrieval

The frontend made:

```text
POST http://localhost:3000/api/v1/getTransaction
```

with:

```json
{
  "userId": "6a9dc4268376a157279c877b",
  "frequency": "7",
  "startDate": null,
  "endDate": null,
  "type": "all"
}
```

This showed that the frontend sends filtering information to the backend rather than directly communicating with MongoDB.

### Transaction Creation

The frontend made:

```text
POST http://localhost:3000/api/v1/addTransaction
```

with:

```json
{
  "title": "school fees",
  "amount": "200",
  "description": "School",
  "category": "Other",
  "date": "2026-09-06",
  "transactionType": "expense",
  "userId": "6a9dc4268376a157279c877b"
}
```

---

# 12. Tracing the Frontend Code

The network request was traced back into the React source.

In `Home.js`, the transaction form extracts values from React state:

```js
const { title, amount, description, category, date, transactionType } =
  values;
```

The frontend then sends them through Axios:

```js
await axios.post(addTransaction, {
  title: title,
  amount: amount,
  description: description,
  category: category,
  date: date,
  transactionType: transactionType,
  userId: cUser._id,
});
```

The `addTransaction` endpoint is defined in:

```text
src/utils/ApiRequest.js
```

as:

```js
export const addTransaction =
  `${host}/api/v1/addTransaction`;
```

This allowed the network request observed in the browser to be connected directly to its source code.

---

# 13. Verified Backend Transaction Path

The backend code was subsequently inspected to verify the other side of the request.

The transaction API is mounted under:

```text
/api/v1
```

The transaction router maps:

```text
/addTransaction
```

to the transaction controller.

Therefore:

```text
/api/v1 + /addTransaction
```

produces:

```text
/api/v1/addTransaction
```

The controller receives the transaction information from:

```text
req.body
```

and validates the required fields and user.

The transaction is then created through the Mongoose model and persisted to MongoDB.

The transaction is associated with the user through the user ID.

---

# 14. Complete Application Data Flow

The investigation produced the following verified mental model:

```text
                         USER
                          │
                          ▼
                  React Frontend
                   localhost:3001
                          │
                          │ Axios
                          │ HTTP
                          ▼
                  Express Backend
                   localhost:3000
                          │
                          ▼
                    API Routes
                          │
                          ▼
                     Controller
                          │
                          ▼
                       Mongoose
                          │
                          ▼
                       MongoDB
                          │
                          ▼
                      mongo-data
                    Persistent Storage
```

For a transaction:

```text
User
 ↓
Add Transaction form
 ↓
React state
 ↓
Axios POST
 ↓
/api/v1/addTransaction
 ↓
Express route
 ↓
Transaction controller
 ↓
Mongoose
 ↓
MongoDB
 ↓
Persistent volume
```

After successful creation, the frontend refreshes the transaction data:

```text
Backend success
 ↓
React refresh
 ↓
/api/v1/getTransaction
 ↓
MongoDB
 ↓
Transactions returned
 ↓
React renders transaction table
```

---

# 15. Layer Responsibilities

The milestone established the following separation of responsibilities:

| Layer         | Responsibility                        |
| ------------- | ------------------------------------- |
| React         | User interface and interaction        |
| Axios         | HTTP communication                    |
| Express       | HTTP server and routing               |
| Controllers   | Application/business logic            |
| Mongoose      | MongoDB interaction and data modeling |
| MongoDB       | Persistent data storage               |
| Docker        | Service packaging and execution       |
| Docker Volume | Database persistence                  |

This separation is important for later container orchestration because each layer represents a different operational concern.

---

# 16. DevOps Mental Model

The most important outcome of this milestone was not simply getting the frontend to work.

It was understanding that a user action travels through multiple layers of the system.

For example:

```text
"Add Transaction"
       ↓
React
       ↓
HTTP
       ↓
Express
       ↓
Controller
       ↓
Mongoose
       ↓
MongoDB
       ↓
Persistent Storage
```

The frontend does not communicate directly with MongoDB.

The backend does not render the React interface.

MongoDB does not know anything about the browser.

Each component has a responsibility.

This provides the architectural foundation required for the later Kubernetes and production-like stages.

---

# 17. Engineering Lessons

### 1. Verify Before Assuming

The application behavior was repeatedly confirmed through:

* Browser
* Network requests
* Docker inspection
* MongoDB inspection
* Container recreation
* Health checks

### 2. Running Configuration Matters

Changing source code does not automatically mean a running container is using that change.

### 3. Persistent Storage Must Be Verified

A named volume in Compose does not necessarily mean the running container is using the volume one expects.

### 4. Client-Side Validation Is Not a Security Boundary

React can improve user experience, but backend validation remains necessary.

### 5. HTTP APIs Create Service Boundaries

The frontend and backend communicate through an API contract rather than sharing direct database access.

### 6. Understand Before Automating

Before introducing Kubernetes, the application must first be understood as a system.

---

# 18. Lab vs Production

This milestone represents a development laboratory.

The current local architecture intentionally uses:

```text
HTTP
localhost
React development server
Docker Compose
MongoDB container
```

These choices are appropriate for understanding and testing the application locally.

They should not automatically be treated as production architecture.

Future production-oriented stages will introduce concerns such as:

* Production frontend builds
* Web servers
* HTTPS
* Secure configuration
* Containerized frontend
* Service discovery
* Kubernetes networking
* Persistent storage strategies
* Monitoring
* GitOps
* Production deployment practices

The purpose of the laboratory is to understand these concepts before introducing additional infrastructure.

---

# 19. Milestone Outcome

### Status: COMPLETE ✅

At the end of Milestone 01:

* ✅ React frontend runs locally
* ✅ Frontend is accessible through `localhost:3001`
* ✅ Backend remains available through `localhost:3000`
* ✅ Environment-specific API configuration implemented
* ✅ CORS issue identified and resolved
* ✅ Correct MongoDB persistent volume identified
* ✅ Docker Compose updated to explicitly use `mongo-data`
* ✅ Registration verified
* ✅ Login verified
* ✅ Avatar flow verified
* ✅ Transaction creation verified
* ✅ Transaction retrieval verified
* ✅ Frontend API requests inspected through browser DevTools
* ✅ Frontend request traced into React source
* ✅ Backend transaction path verified
* ✅ Full-stack architecture understood

---

# 20. Next Milestone

With the frontend now working locally, the next problem is no longer:

> "Can we run the frontend?"

We have already answered that.

The next DevOps problem is:

> **How do we package the frontend so that it can run as a portable container rather than requiring Node.js and `npm start` on the host?**

This leads to:

# Milestone 02 — Frontend Containerization

The progression will be:

```text
Frontend works locally
        ↓
Understand React production build
        ↓
Build frontend
        ↓
Understand static assets
        ↓
Introduce web server
        ↓
Create frontend Docker image
        ↓
Run frontend container
        ↓
Test container independently
        ↓
Integrate with backend
```

The principle remains:

> **Make it work locally. Understand it. Then package it.**
