# Git Troubleshooting

This document records Git issues encountered during the project and how they were resolved.

---

## Non-Fast-Forward Push Rejected

### Error

```text
! [rejected] main -> main (non-fast-forward)
```

### Cause

The latest commit had already been pushed to GitHub, then it was modified using:

```bash
git commit --amend
```

This rewrote the local commit history, causing it to differ from the remote branch.

### Resolution

```bash
git push --force-with-lease origin main
```

### Lesson Learned

* Avoid amending commits that have already been shared unless you intentionally want to rewrite history.
* Prefer `--force-with-lease` over `--force` because it performs a safety check before updating the remote branch.

---

## Documentation Rule

Whenever a new Git issue is encountered during this mentorship:

1. Record the error.
2. Identify the root cause.
3. Document the solution.
4. Capture the lesson learned.

This creates a growing troubleshooting guide based on real engineering experience rather than theoretical examples.
