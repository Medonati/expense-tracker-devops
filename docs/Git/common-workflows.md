# Common Git Workflows

A quick reference for Git commands used throughout this DevOps project.

---

## Check Repository Status

```bash
git status
```

Displays the current state of the working directory and staging area.

---

## Stage Changes

```bash
git add .
```

Stages all modified and new files.

---

## Create a Commit

```bash
git commit -m "your commit message"
```

Creates a new commit with the staged changes.

---

## Amend the Last Commit

```bash
git commit --amend
```

Updates the most recent commit.

**Use when:**

* The last commit message needs correction.
* You forgot to include a file.
* The commit has **not** been shared, or you intentionally want to rewrite history.

---

## Push Changes

```bash
git push origin main
```

Pushes local commits to the remote repository.

---

## Safe Force Push

```bash
git push --force-with-lease origin main
```

Use after intentionally rewriting the latest commit (for example, with `git commit --amend`).

Preferred over `git push --force` because it verifies the remote branch has not changed unexpectedly.

---

## Pull Latest Changes

```bash
git pull origin main
```

Fetches and merges the latest changes from the remote repository.

---

## View Commit History

```bash
git log --oneline --graph --decorate --all
```

Displays a compact visual history of commits and branches.

---

## Repository Workflow

```text
Edit Files
    │
    ▼
git status
    │
    ▼
git add .
    │
    ▼
git commit -m "message"
    │
    ▼
git push origin main
```

---

## If You Amend a Commit

```text
git commit --amend
        │
        ▼
git push --force-with-lease origin main
```

---

## Lessons Learned

* Prefer creating a new commit after a commit has already been pushed.
* Use `git commit --amend` only when you intentionally want to modify the latest commit.
* Prefer `--force-with-lease` over `--force` when rewriting commit history.
* Read Git error messages before applying a fix—most errors clearly indicate the problem.
