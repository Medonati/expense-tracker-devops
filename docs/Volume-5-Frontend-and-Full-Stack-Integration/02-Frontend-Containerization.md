# Milestone 02 — Frontend Containerization

**Volume 5 — Frontend & Full-Stack Application Integration**

---

## 1. Objective

The objective of this milestone was to move the React frontend from a development-only workflow toward a production-ready containerized architecture.

The focus was not simply to create a Dockerfile. The goal was to understand:

* How a React application is converted into a production artifact.
* The difference between development mode and production builds.
* How frontend environment variables behave during the build process.
* How a production frontend is served.
* Why the frontend build stage and runtime stage should be separated.
* How Docker build context affects build performance.
* How to investigate slow Docker builds and container filesystem performance.
* How these concepts translate into a multi-stage Docker architecture.

The intended architecture is:

```text
React Source Code
       │
       ▼
   npm run build
       │
       ▼
Production Artifact
(build/)
       │
       ▼
     Nginx
       │
       ▼
    Browser
```

---

# 2. Starting Point

Milestone 01 established that the Expense Tracker frontend works correctly in local development.

The local application architecture was:

```text
Browser
   │
   │ :3001
   ▼
React Frontend
   │
   │ HTTP API requests
   │ :3000
   ▼
Node.js / Express Backend
   │
   ▼
MongoDB
```

The frontend uses:

```javascript
const host = process.env.REACT_APP_API_URL;
```

for its backend API configuration.

Development configuration was:

```text
REACT_APP_API_URL=http://localhost:3000
```

The frontend successfully communicated with the backend and MongoDB during Milestone 01.

The next engineering question was:

> Can the frontend be converted into a production artifact and eventually packaged into its own container?

---

# 3. Understanding the React Production Build

The first step was to understand what actually happens when the React application is built for production.

The command used was:

```bash
npm run build
```

Unlike:

```bash
npm start
```

which starts the React development server, `npm run build` creates static production files.

Conceptually:

```text
src/
public/
package.json
       │
       ▼
npm run build
       │
       ▼
build/
```

The resulting `build/` directory is the deployable frontend artifact.

Useful commands for inspecting the project and generated artifact included:

```bash
pwd
```

to confirm the current working directory,

```bash
ls
```

to list the current directory,

```bash
ls -la
```

to include hidden files such as `.env.production` and `.dockerignore`,

```bash
find . -maxdepth 2 -type f
```

to inspect files without recursively displaying dependency directories,

```bash
du -sh .
```

to display the total disk usage of the current project,

```bash
du -sh build
```

to display the size of the production artifact, and:

```bash
du -sh node_modules
```

to identify how much space installed dependencies consume.

The `du` command was especially useful during troubleshooting because it helped distinguish application files from large dependency directories.

---

# 4. Initial Production Build Problem

The first attempts to run:

```bash
npm run build
```

on the DevOps VM appeared to hang at:

```text
Creating an optimized production build...
```

The problem was investigated rather than immediately worked around.

Several possible causes were tested, including:

* Node.js memory configuration.
* Source-map generation.
* CI environment configuration.
* ESLint involvement.
* React Scripts execution.
* Dependency investigation.
* Docker as an alternative build environment.
* Docker filesystem performance.

Examples of experiments included:

```bash
CI=true npm run build
```

```bash
GENERATE_SOURCEMAP=false npm run build
```

```bash
DISABLE_ESLINT_PLUGIN=true npm run build
```

and:

```bash
NODE_OPTIONS="--max_old_space_size=4096" npm run build
```

The `NODE_OPTIONS` value alone does not execute the build; it must be applied to the command, as shown above.

Other useful troubleshooting commands included:

```bash
ps aux | grep node
```

to check whether a Node.js build process was still running,

```bash
top
```

or:

```bash
htop
```

to observe CPU and memory usage,

```bash
free -h
```

to inspect available memory,

```bash
df -h
```

to inspect available disk space,

```bash
df -i
```

to inspect inode usage, and:

```bash
du -sh /var/lib/docker
```

to inspect how much disk space Docker was using.

These experiments did not immediately resolve the problem.

---

# 5. Docker Build Investigation

Docker was then introduced as a controlled experiment to determine whether the build behaved differently in another environment.

An initial frontend Dockerfile was created using Node.js as the build environment.

The first Docker build used the repository root as its build context.

A typical command was:

```bash
docker build -t expense-frontend .
```

This exposed an important Docker concept:

> Docker sends the build context to the Docker daemon before the Dockerfile instructions are executed.

The initial build transferred hundreds of megabytes of context.

Useful commands for inspecting Docker state included:

```bash
docker version
```

to verify that the Docker client and daemon were available,

```bash
docker info
```

to inspect Docker's configuration and storage driver,

```bash
docker images
```

to list local images,

```bash
docker ps
```

to list running containers,

```bash
docker ps -a
```

to list all containers, including stopped containers,

```bash
docker system df
```

to inspect Docker disk usage, and:

```bash
docker system df -v
```

to display a more detailed breakdown of images, containers, volumes, and build cache.

Investigation showed that:

```text
app/frontend/node_modules
≈ 913 MB
```

was the major source of unnecessary files.

The directory size was checked with commands such as:

```bash
du -sh app/frontend/node_modules
```

and:

```bash
du -sh app/frontend/*
```

For a more detailed breakdown, the following command was useful:

```bash
du -h --max-depth=1 app/frontend | sort -h
```

On systems where `--max-depth` is unavailable, the equivalent can be approximated with:

```bash
du -sh app/frontend/* app/frontend/.[!.]* 2>/dev/null | sort -h
```

A frontend `.dockerignore` was introduced:

```text
node_modules/
build/
.git/
.env
.env.*
coverage/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.DS_Store
```

The build context was subsequently changed to the frontend directory itself:

```bash
cd app/frontend
docker build -t expense-frontend .
```

This ensured that the frontend `.dockerignore` applied correctly.

The resulting context became approximately:

```text
6.07 MB
```

This demonstrated the importance of **Docker build-context discipline**.

Useful commands for confirming the active build context and project contents included:

```bash
pwd
```

```bash
ls -la
```

```bash
du -sh .
```

and:

```bash
docker build --progress=plain -t expense-frontend .
```

The `--progress=plain` option was useful because it displayed Docker build steps in a more explicit format during troubleshooting.

---

# 6. Docker Filesystem Performance Discovery

Although the build context was corrected, the Docker build remained extremely slow.

The investigation moved toward filesystem performance.

Docker was using:

```text
Storage Driver: overlayfs
```

with Docker's root directory:

```text
/var/lib/docker
```

The storage driver and Docker root directory were checked with:

```bash
docker info
```

The Docker root directory could also be inspected with:

```bash
docker info --format '{{.DockerRootDir}}'
```

A controlled Docker write test was performed:

```bash
docker run --rm node:22-slim \
  sh -c 'dd if=/dev/zero of=/tmp/testfile bs=1M count=100'
```

The test took approximately:

```text
19 minutes
```

for a 100 MB write.

A host filesystem test of the same general operation completed in less than a second:

```bash
time dd if=/dev/zero of=/tmp/host-testfile bs=1M count=100
```

The temporary host test file could then be removed with:

```bash
rm -f /tmp/host-testfile
```

A smaller Docker test also showed unusually high latency:

```bash
time docker run --rm node:22-slim \
  sh -c 'echo hello > /tmp/test'
```

The command:

```bash
time
```

was important because it measured how long the operation actually took rather than relying only on visual observation.

A basic container shell test was also useful:

```bash
docker run --rm -it node:22-slim sh
```

Inside the container, commands such as:

```bash
pwd
```

```bash
df -h
```

```bash
mount
```

and:

```bash
ls -la /tmp
```

could be used to inspect the container environment.

The Docker write test took several minutes for a relatively small amount of data, while the host filesystem completed the equivalent operation almost immediately.

This provided evidence that Docker's container writable layer was experiencing severe I/O latency on the DevOps VM.

The lesson was:

> When a containerized build is unexpectedly slow, investigate the build environment and filesystem rather than assuming the application itself is the problem.

Important diagnostic commands from this investigation included:

```bash
docker info
```

```bash
docker system df
```

```bash
du -sh /var/lib/docker
```

```bash
df -h /var/lib/docker
```

```bash
time docker run --rm node:22-slim \
  sh -c 'dd if=/dev/zero of=/tmp/testfile bs=1M count=100'
```

and:

```bash
time dd if=/dev/zero of=/tmp/host-testfile bs=1M count=100
```

The comparison between container and host write performance was more useful than simply observing that the Docker build was slow.

---

# 7. Successful Production Build

After restarting the VM and continuing the investigation, the production build was attempted again.

This time:

```bash
npm run build
```

completed successfully.

The output confirmed:

```text
Compiled with warnings.
```

and:

```text
The build folder is ready to be deployed.
```

The generated production files included:

```text
build/
├── asset-manifest.json
├── favicon.ico
├── index.html
├── logo192.png
├── logo512.png
├── manifest.json
├── robots.txt
└── static/
    ├── css/
    │   ├── main.ed28a981.css
    │   └── main.ed28a981.css.map
    ├── js/
    │   ├── main.434744ec.js
    │   ├── main.434744ec.js.LICENSE.txt
    │   └── main.434744ec.js.map
    └── media/
        ├── gg.aec3dec33a1e285eb2c3.gif
        └── loader.b40fc3d91ff1f4db53e2.gif
```

The production bundle sizes were:

```text
JavaScript: 260.41 kB gzipped
CSS:         33.77 kB gzipped
```

The artifact could be inspected with:

```bash
ls -lah build
```

and:

```bash
du -sh build
```

The generated JavaScript and CSS files could be located with:

```bash
find build -type f
```

This confirmed that the React application could successfully produce a deployable production artifact.

---

# 8. Production Build Warnings

The successful build reported two existing ESLint warnings:

```text
src/Pages/Avatar/setAvatar.js
'selectedSprite' is assigned a value but never used
```

and:

```text
src/Pages/Home/Home.js
React Hook useEffect has a missing dependency: 'cUser._id'
```

These warnings did not prevent the production build.

They were deliberately not refactored during this milestone because they were unrelated to the current DevOps objective.

A third warning concerned an outdated `caniuse-lite` database used by Browserslist.

Again, this did not prevent the build.

The engineering principle applied was:

> Do not introduce unrelated application changes simply because warnings appear during an infrastructure-focused milestone.

The build result was verified by checking the command exit status:

```bash
echo $?
```

A successful command normally returns:

```text
0
```

This is a useful habit when troubleshooting automated builds because visible output alone does not always clearly indicate success or failure.

---

# 9. Verifying the Production Artifact

The production artifact was then served independently from the React development server.

The command used was:

```bash
npx serve -s build -l 3001
```

The server reported:

```text
Serving!

Local:    http://localhost:3001
Network:  http://10.0.2.15:3001
```

The `-s` option enabled single-page application fallback behavior, allowing routes to resolve through `index.html`.

The `-l 3001` option selected port `3001`.

The server could be stopped with:

```text
Ctrl+C
```

This was an important experiment.

It demonstrated that the generated `build/` directory could be served independently of:

```bash
npm start
```

The architecture was now understood as two separate concerns:

```text
BUILD

Node.js
   │
   ▼
npm run build
   │
   ▼
build/
```

and:

```text
RUNTIME

build/
   │
   ▼
Static HTTP Server
   │
   ▼
Browser
```

Before starting the server, the port could be checked with:

```bash
ss -tulpn | grep 3001
```

or:

```bash
lsof -i :3001
```

This helped identify whether another process was already using the port.

---

# 10. Production Environment Configuration Failure

When the production artifact was initially served, the frontend appeared briefly but then failed to operate correctly.

The server logs contained:

```text
POST /undefined/api/v1/getTransaction
```

This was a significant discovery.

The frontend code uses:

```javascript
const host = process.env.REACT_APP_API_URL;
```

The development environment contained:

```text
.env.development
```

with:

```text
REACT_APP_API_URL=http://localhost:3000
```

The environment files were inspected with:

```bash
ls -la .env*
```

and:

```bash
cat .env.development
```

However, the production build does not use `.env.development` in the same way.

As a result, the production bundle did not have a value for:

```text
REACT_APP_API_URL
```

The important distinction was:

```text
npm start
```

uses the development environment, while:

```text
npm run build
```

uses production build behavior and production environment configuration.

---

# 11. Verifying the Environment Variable Problem

Rather than immediately changing configuration, the compiled JavaScript was inspected.

The generated JavaScript files were located with:

```bash
find build/static/js -type f -name "*.js"
```

The API variable or endpoint could then be searched with:

```bash
grep -R "REACT_APP_API_URL" build/static/js
```

and:

```bash
grep -R "localhost:3000" build/static/js
```

Searching for the API endpoint showed code equivalent to:

```text
Dd = ... .REACT_APP_API_URL
```

The resulting request construction contained:

```text
Dd + "/api/v1/getTransaction"
```

The browser request confirmed the runtime result:

```text
/undefined/api/v1/getTransaction
```

Browser developer tools were useful for this verification:

* Open the **Network** tab.
* Reload the page.
* Inspect the failed request.
* Confirm the request URL.
* Inspect the response status and response body.
* Check the **Console** tab for related errors.

This established that the problem was not Nginx, Docker, or the backend.

It was a **build-time frontend configuration problem**.

---

# 12. Production Environment Configuration

A production environment file was then created:

```text
.env.production
```

containing:

```text
REACT_APP_API_URL=http://localhost:3000
```

The file could be created with:

```bash
cat > .env.production <<'EOF'
REACT_APP_API_URL=http://localhost:3000
EOF
```

Its contents could be verified with:

```bash
cat .env.production
```

The file's presence could be confirmed with:

```bash
ls -la .env.production
```

The production build was run again:

```bash
npm run build
```

The build completed successfully.

The compiled JavaScript was then inspected again:

```bash
grep -R "localhost:3000" build/static/js
```

This time the bundle contained:

```text
Dd="http://localhost:3000"
```

This provided direct evidence that the environment variable had been embedded into the production JavaScript during the build.

The generated artifact could also be compared before and after the configuration change using:

```bash
find build -type f -printf '%s %p\n' | sort -n
```

This was useful for observing generated files and their sizes, although the most important verification remained the presence of the expected API endpoint in the compiled JavaScript.

---

# 13. Build-Time Configuration Mental Model

This experiment established an important frontend DevOps concept.

With the current Create React App architecture:

```text
.env.production
       │
       ▼
npm run build
       │
       ▼
Environment variable injected
       │
       ▼
JavaScript bundle
```

Therefore:

```text
REACT_APP_API_URL
```

is not simply read dynamically by the browser after deployment.

Its value is incorporated into the production bundle during the build process.

The practical implication is:

> The configuration used during the frontend build can become part of the generated application artifact.

This will become increasingly important when the application moves through Docker, AWS, Kubernetes, and eventually production-like deployment environments.

A useful verification sequence is:

```bash
ls -la .env*
```

```bash
cat .env.production
```

```bash
npm run build
```

```bash
grep -R "localhost:3000" build/static/js
```

This sequence demonstrates the complete relationship between the environment file, the build command, and the generated artifact.

---

# 14. Production Frontend Verification

The newly generated production artifact was served again:

```bash
npx serve -s build -l 3001
```

The frontend successfully remained visible and functional.

The production frontend was therefore able to communicate with the backend using:

```text
http://localhost:3000
```

The verified flow became:

```text
Browser
   │
   │ :3001
   ▼
Production React Build
   │
   │ API request
   │ :3000
   ▼
Express Backend
   │
   ▼
MongoDB
```

This confirmed that the production frontend artifact was valid and functional.

Useful verification commands included:

```bash
curl -I http://localhost:3001
```

to inspect the frontend HTTP response headers,

```bash
curl -s http://localhost:3001 | head
```

to inspect the returned HTML, and:

```bash
curl -i http://localhost:3000
```

to confirm that the backend was reachable.

The browser Network tab was then used to verify that API requests were sent to:

```text
http://localhost:3000/api/v1/...
```

rather than:

```text
/undefined/api/v1/...
```

---

# 15. Why `serve` Was Used

The `serve` package was used only as a validation tool.

Its purpose in this experiment was to demonstrate:

> The production `build/` directory can be served as static web content.

`serve` was therefore performing the basic runtime role of a static HTTP server.

Conceptually:

```text
Browser
   │
   ▼
serve
   │
   ▼
build/
```

This is similar to the fundamental role Nginx will perform later.

However, `serve` is **not the final production runtime architecture** for this project.

The intended architecture is:

```text
Browser
   │
   ▼
Nginx
   │
   ▼
React production files
```

The experiment therefore allowed us to prove the runtime concept before introducing Nginx.

Useful commands from this experiment included:

```bash
npx serve -s build -l 3001
```

```bash
curl -I http://localhost:3001
```

```bash
ss -tulpn | grep 3001
```

and:

```bash
lsof -i :3001
```

---

# 16. Build Environment vs Runtime Environment

One of the most important lessons from this milestone was the distinction between the environment used to **build** the frontend and the environment used to **serve** it.

### Build environment

Requires Node.js and npm:

```text
Node.js
   │
   ├── npm ci
   │
   └── npm run build
            │
            ▼
          build/
```

### Runtime environment

Only needs to serve the generated static files:

```text
build/
   │
   ▼
Nginx
   │
   ▼
Browser
```

Node.js does not need to remain in the final frontend runtime image simply to serve static HTML, JavaScript, CSS, and media files.

This leads directly to the multi-stage Docker architecture planned for the next stage.

The distinction can be summarized with:

```bash
npm start
```

for development,

```bash
npm run build
```

for production artifact generation, and:

```bash
npx serve -s build -l 3001
```

for validating the generated artifact independently.

---

# 17. Target Frontend Container Architecture

The target architecture is a multi-stage Docker image.

```text
┌─────────────────────────────────────┐
│            BUILD STAGE              │
│                                     │
│ Node.js                             │
│                                     │
│ COPY package*.json                  │
│ npm ci                              │
│ COPY source                         │
│ npm run build                       │
│                                     │
│              ↓                      │
│            build/                   │
└──────────────────┬──────────────────┘
                   │
                   │ COPY build/
                   ▼
┌─────────────────────────────────────┐
│           RUNTIME STAGE             │
│                                     │
│ Nginx                               │
│                                     │
│ /usr/share/nginx/html               │
│                                     │
│              ↓                      │
│            Browser                  │
└─────────────────────────────────────┘
```

The build stage contains the tools required to compile the application.

The runtime stage contains only what is necessary to serve the compiled frontend.

This separation helps reduce the final image size and separates **build concerns** from **runtime concerns**.

The expected Docker workflow will eventually resemble:

```bash
docker build -t expense-frontend .
```

```bash
docker run --rm -p 3001:80 expense-frontend
```

The exact Dockerfile and Nginx configuration will be introduced in the next milestone.

---

# 18. Environment Consistency Principle

A major principle reinforced by this milestone is:

> **The application should remain the same while environment-specific configuration changes.**

The desired progression is:

```text
Same Application
       │
       ├── Local
       │
       ├── Docker
       │
       ├── AWS
       │
       └── Kubernetes
```

The environment should provide the appropriate configuration rather than requiring different application code for every environment.

For example:

```text
Local
API → localhost:3000
```

while a future deployed environment may use a different backend endpoint.

The important architectural question discovered during this milestone is that Create React App embeds `REACT_APP_*` configuration during the build.

This means that future production-like deployment will require deliberate consideration of how frontend configuration is managed.

That issue will be revisited as the architecture evolves rather than prematurely solving it with unnecessary complexity.

Useful commands for checking environment configuration include:

```bash
env | sort
```

to inspect exported environment variables,

```bash
printenv REACT_APP_API_URL
```

to check whether the variable is exported in the current shell, and:

```bash
ls -la .env*
```

to inspect project environment files.

Care must be taken not to expose secrets through frontend environment variables because values prefixed with `REACT_APP_` become visible in the browser bundle.

---

# 19. Engineering Lessons

## Lesson 1 — A production build is an artifact

The source code is not what the browser ultimately needs.

The browser receives the compiled artifact:

```text
build/
```

The artifact can be inspected with:

```bash
ls -lah build
```

```bash
du -sh build
```

and:

```bash
find build -type f
```

---

## Lesson 2 — Build and runtime are different concerns

Node.js is needed to build the React application.

A static web server is sufficient to serve the resulting files.

The build process is:

```bash
npm run build
```

The runtime validation process is:

```bash
npx serve -s build -l 3001
```

---

## Lesson 3 — Environment variables can be build-time configuration

With Create React App:

```text
REACT_APP_*
```

values are embedded during the production build.

This must be understood before designing the deployment architecture.

The relationship can be verified with:

```bash
cat .env.production
```

```bash
npm run build
```

and:

```bash
grep -R "localhost:3000" build/static/js
```

---

## Lesson 4 — Verify before assuming

Instead of assuming the frontend was broken, the actual browser request was examined:

```text
/undefined/api/v1/getTransaction
```

The compiled JavaScript was then inspected to determine where the value came from.

This allowed the configuration problem to be identified precisely.

Useful verification tools included:

```bash
grep -R "REACT_APP_API_URL" build/static/js
```

```bash
curl -I http://localhost:3001
```

and the browser Network and Console tabs.

---

## Lesson 5 — Don't blame the newest tool

The production build problem initially appeared during the frontend work.

Instead of immediately blaming Docker, React, Node.js, or the application, multiple controlled experiments were performed.

The investigation eventually revealed unusually slow Docker overlay filesystem I/O while the production build also later succeeded.

Useful comparison commands included:

```bash
time docker run --rm node:22-slim \
  sh -c 'dd if=/dev/zero of=/tmp/testfile bs=1M count=100'
```

and:

```bash
time dd if=/dev/zero of=/tmp/host-testfile bs=1M count=100
```

---

## Lesson 6 — Build context matters

Using the repository root as a Docker build context caused unnecessary files such as `node_modules` to be considered.

The size of the dependency directory was checked with:

```bash
du -sh app/frontend/node_modules
```

Changing the context to:

```text
app/frontend
```

and using the frontend `.dockerignore` dramatically reduced the build context.

This reinforced the principle:

> Send only the files the build actually needs.

Useful commands included:

```bash
cd app/frontend
```

```bash
du -sh .
```

```bash
docker build --progress=plain -t expense-frontend .
```

---

## Lesson 7 — Failure is a teacher

The failed production build and broken production configuration were not wasted time.

They exposed two important architectural realities:

```text
Build environment performance
```

and:

```text
Frontend configuration at build time
```

Both will influence future container and deployment design.

---

## Lesson 8 — Disk usage commands are practical diagnostic tools

Commands such as:

```bash
du -sh .
```

```bash
du -sh node_modules
```

```bash
du -h --max-depth=1 . | sort -h
```

```bash
df -h
```

and:

```bash
docker system df
```

help distinguish between:

* Large project directories.
* Dependency directories.
* Docker image and layer usage.
* Available disk space.
* Filesystem capacity problems.
* Build-context problems.

The important distinction is:

```text
du
```

shows how much space files and directories consume, while:

```text
df
```

shows filesystem capacity and available space.

Both are useful, but they answer different questions.

---

## Lesson 9 — Measure before changing architecture

The Docker write test was valuable because it measured the environment directly:

```bash
time docker run --rm node:22-slim \
  sh -c 'dd if=/dev/zero of=/tmp/testfile bs=1M count=100'
```

Without this comparison, it would have been easy to incorrectly conclude that the React application or Dockerfile was inherently defective.

A controlled measurement is often more useful than repeated configuration changes based only on assumptions.

---

# 20. Lab vs Production

### What we used in the lab

```text
npm run build
      ↓
build/
      ↓
npx serve
      ↓
Browser
```

### What we are targeting

```text
Node.js build stage
      ↓
build/
      ↓
Nginx runtime stage
      ↓
Browser
```

The `serve` experiment was therefore a **validation step**, not the final architecture.

The key commands used in the lab were:

```bash
npm run build
```

```bash
npx serve -s build -l 3001
```

```bash
curl -I http://localhost:3001
```

```bash
grep -R "localhost:3000" build/static/js
```

and:

```bash
du -sh build
```

---

# 21. Milestone Outcome

Milestone 02 successfully established that:

* The React frontend can produce a production build.
* The generated `build/` directory is a deployable static artifact.
* The frontend can be served independently of `npm start`.
* Production frontend configuration must be explicitly provided.
* `REACT_APP_API_URL` is embedded during the Create React App build.
* The production frontend can communicate with the local backend.
* Static frontend serving can be separated from the Node.js build environment.
* Docker build context can dramatically affect build performance.
* `node_modules` should not be sent as part of the Docker build context.
* Docker filesystem performance can be tested independently with controlled write operations.
* `du`, `df`, `docker info`, and `docker system df` are valuable troubleshooting commands.
* Nginx is the planned runtime server for the final frontend container.
* A multi-stage Docker image is the next architectural step.

The frontend is now ready to move from:

```text
Production Artifact
```

to:

```text
Production Artifact → Nginx → Docker Container
```

---

# 22. Vital Commands to Remember

The following commands were especially important during this milestone.

## Project and file inspection

```bash
pwd
```

```bash
ls -la
```

```bash
find . -maxdepth 2 -type f
```

```bash
du -sh .
```

```bash
du -h --max-depth=1 . | sort -h
```

## React build commands

```bash
npm start
```

```bash
npm run build
```

```bash
CI=true npm run build
```

```bash
GENERATE_SOURCEMAP=false npm run build
```

```bash
DISABLE_ESLINT_PLUGIN=true npm run build
```

```bash
NODE_OPTIONS="--max_old_space_size=4096" npm run build
```

## Build artifact inspection

```bash
ls -lah build
```

```bash
du -sh build
```

```bash
find build -type f
```

```bash
find build/static/js -type f -name "*.js"
```

```bash
grep -R "REACT_APP_API_URL" build/static/js
```

```bash
grep -R "localhost:3000" build/static/js
```

## Environment configuration

```bash
ls -la .env*
```

```bash
cat .env.development
```

```bash
cat .env.production
```

```bash
env | sort
```

```bash
printenv REACT_APP_API_URL
```

## Static artifact serving

```bash
npx serve -s build -l 3001
```

```bash
curl -I http://localhost:3001
```

```bash
curl -s http://localhost:3001 | head
```

```bash
ss -tulpn | grep 3001
```

```bash
lsof -i :3001
```

## Docker inspection

```bash
docker version
```

```bash
docker info
```

```bash
docker info --format '{{.DockerRootDir}}'
```

```bash
docker images
```

```bash
docker ps
```

```bash
docker ps -a
```

```bash
docker system df
```

```bash
docker system df -v
```

## Docker build commands

```bash
docker build -t expense-frontend .
```

```bash
docker build --progress=plain -t expense-frontend .
```

```bash
docker build --no-cache -t expense-frontend .
```

```bash
du -sh node_modules
```

```bash
du -sh /var/lib/docker
```

## Filesystem and performance tests

```bash
df -h
```

```bash
df -i
```

```bash
free -h
```

```bash
time dd if=/dev/zero of=/tmp/host-testfile bs=1M count=100
```

```bash
time docker run --rm node:22-slim \
  sh -c 'dd if=/dev/zero of=/tmp/testfile bs=1M count=100'
```

```bash
time docker run --rm node:22-slim \
  sh -c 'echo hello > /tmp/test'
```

```bash
rm -f /tmp/host-testfile
```

These commands form a practical troubleshooting toolkit for frontend builds, Docker contexts, disk usage, container performance, environment configuration, and production artifact verification.

---

# 23. Next Milestone

## Milestone 03 — Frontend + Backend Container Integration

The next milestone will build on the knowledge gained here.

The objective will be to run:

```text
Frontend Container
        │
        │
        ▼
Backend Container
        │
        ▼
MongoDB Container
```

and understand how the three application layers communicate when they are no longer running directly on the host.

The key questions will be:

* How does Nginx serve the React artifact?
* How does the browser reach the backend?
* How does the backend reach MongoDB?
* What changes when containers communicate through a Docker network?
* Which configuration belongs to the browser and which belongs to the container?
* How does Docker Compose eventually express the complete application architecture?
* How should frontend build-time configuration be handled when the backend endpoint changes between environments?

The principle remains:

> **Understand → Make it work → Test → Break → Fix → Understand the failure → Automate.**
