# Reflection — Volume 1: Docker

## Looking Back

When I began this volume, I thought learning Docker meant learning Docker commands.

I now realize that Docker is only one piece of a much larger engineering discipline.

The greatest lesson from this volume was not how to build containers—it was how to think about systems.

---

# What I Believed Before

At the beginning of this journey, I believed:

* Docker was mainly a tool for running applications.
* Containers and images were almost the same thing.
* Health checks simply determined whether an application was running.
* Docker Compose was just a convenient way to avoid typing multiple Docker commands.
* Learning DevOps meant learning tools.

As the volume progressed, each of these assumptions evolved.

---

# My Biggest Mindset Shifts

## 1. Understand Before Automating

One principle shaped the entire volume:

> **"I can't automate what I don't understand."**

Rather than rushing into automation, every concept was understood manually first.

This changed how I approach every new technology.

---

## 2. Verification Is Better Than Assumption

One of the most valuable habits I developed was learning not to assume.

Instead of believing a tool existed inside a container, I verified it.

Instead of assuming Docker behaved a certain way, I tested it.

Instead of trusting theory, I observed reality.

This simple mindset will remain valuable long after Docker.

---

## 3. Failure Is Part of Learning

One of my favorite moments in this volume came when I suggested:

> **"Let's intentionally disrupt the health and see what happens."**

That experiment changed how I think about learning.

Rather than avoiding failure, I learned to use it as an engineering tool.

Stopping MongoDB taught me more about health checks than reading documentation ever could.

---

## 4. Running Does Not Mean Ready

This became one of the most important engineering lessons.

A process can be running while users are still unable to use the application.

Understanding the difference between:

* Liveness
* Readiness

completely changed how I think about application health.

---

## 5. DevOps Is More Than Tools

Perhaps the biggest realization of this volume was that DevOps is not about Docker.

It is about solving engineering problems.

Docker simply happens to be one solution.

Every future technology should be viewed through the same lens.

---

# Habits I Developed

Throughout this volume I began developing habits that I want to carry into every future milestone.

These include:

* Asking "Why?" before "How?"
* Thinking about architecture before implementation.
* Verifying assumptions.
* Reading official documentation.
* Connecting concepts instead of memorizing commands.
* Looking for engineering principles instead of tool-specific tricks.

---

# Moments That Changed My Thinking

Several moments stand out as turning points.

### Build Context

Learning that the build context affects image size and build speed made me realize that small implementation details often have larger engineering consequences.

---

### Service Discovery

Understanding why `mongodb` works while `localhost` does not fundamentally changed how I think about networking inside containers.

---

### Named Volumes

Learning that containers are disposable but data should persist taught me to separate infrastructure from application state.

---

### Health Checks

Implementing both `/health` and `/ready` showed me that infrastructure needs more than a simple "running" status.

Operational systems require meaningful signals.

---

# What I'm Most Proud Of

I am proud that this volume was not completed by copying commands from tutorials.

Every concept was questioned.

Every implementation was discussed.

Several ideas were intentionally broken to understand their behaviour.

Most importantly, the project was documented alongside the implementation so that the reasoning behind every decision is preserved.

---

# My Engineering Philosophy So Far

If I had to summarize what I have learned into a few principles, they would be:

* Understand before automating.
* Verify before assuming.
* Build confidence through experimentation.
* Containers are disposable.
* Data should outlive containers.
* Running is not the same as Ready.
* Every technology exists to solve an engineering problem.
* Good engineering is built on understanding, not memorization.

---

# Mentor's Influence

One of the defining characteristics of this mentorship has been its emphasis on reasoning rather than repetition.

Instead of being told what command to run, I was consistently challenged to think first.

Questions such as:

* "What problem are we solving?"
* "What do you think will happen?"
* "Why do you think Docker behaves this way?"

helped me build confidence in my own reasoning instead of depending on memorized steps.

That approach has become just as valuable as the technical knowledge itself.

---

# Looking Ahead

Completing Docker does not feel like finishing a tool.

It feels like building the foundation for everything that comes next.

Networking will lead naturally into Kubernetes.

Health checks will evolve into Kubernetes probes.

Docker images will become artifacts in CI pipelines.

Volumes will become persistent storage in Kubernetes.

Rather than starting over with every technology, I now see each new topic as an extension of concepts I already understand.

---

# Final Reflection

At the beginning of this volume, my goal was to learn Docker.

By the end of this volume, I realized my real goal is much bigger.

I want to become the kind of engineer who understands **why** systems are designed the way they are, who verifies rather than assumes, who learns through experimentation, and who can confidently design, troubleshoot, and improve production systems.

Docker was simply the first chapter in that journey.

The journey continues.
