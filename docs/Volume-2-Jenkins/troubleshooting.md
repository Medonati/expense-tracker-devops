# Troubleshooting

This document records issues encountered while building the Jenkins pipeline and how they were resolved.

---

## Issue 1 – Repository Branch Not Found

### Error

```text
Couldn't find any revision to build.
Verify the repository and branch configuration.
```

### Cause

Jenkins attempted to build the default `master` branch, while the repository uses `main`.

### Resolution

Specify the branch explicitly in the pipeline.

```groovy
git branch: 'main',
    url: 'https://github.com/Medonati/expense-tracker-devops.git'
```

---

## Issue 2 – Node.js Not Found

### Error

```text
node: command not found
npm: command not found
```

### Cause

Node.js was installed using **NVM** for the `vagrant` user. Jenkins runs as the `jenkins` user, so it could not access the developer's Node.js installation.

### Investigation

Verified the environments using:

```bash
sudo -u jenkins which node
sudo -u jenkins which npm
sudo -u jenkins env | grep PATH
```

The Jenkins user did not have access to the NVM installation.

### Resolution

Installed and configured the **NodeJS Plugin**, then created a managed Node.js installation (`node22`) using Jenkins Tool Management.

The pipeline now requests the managed tool instead of relying on the operating system.

---

## Key Lessons

* Read the console output carefully before making changes.
* Validate assumptions before applying fixes.
* Build logs provide valuable information for troubleshooting.
* Root cause analysis is more effective than trial-and-error debugging.
* Good CI pipelines are improved incrementally through observation and testing.
