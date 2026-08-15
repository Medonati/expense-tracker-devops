# 08 — Artifact Lifecycle & Cleanup

## Objective

Understand how artifacts, build cache, and persistent Docker data should be retained or cleaned throughout their lifecycle.

## Docker Storage

Docker storage was examined with:

```bash
docker system df
docker system df -v
````

The lab contained Docker images, build cache, and persistent MongoDB volumes.

`docker system df -v` helped distinguish shared image layers from each image's unique storage.

## Retention Decisions

Our lab policy:

* Release images → retain for versioning and rollback.
* Temporary test images → remove when no longer required.
* Build cache → retain while actively developing because it speeds up rebuilds.
* MongoDB volumes → protect because they contain persistent data.
* Unused anonymous volumes → remove after confirming they contain no useful data.

## Volume Cleanup

Unused volumes were identified with:

```bash
docker volume ls -qf dangling=true
```

The anonymous volumes were inspected before removal. They had no containers attached and contained essentially no data.

After cleanup:

```text
Local Volumes: 18 → 3
```

The remaining volumes were named MongoDB volumes containing approximately 948MB of persistent data.

The cleanup reclaimed `0B` because the removed anonymous volumes were effectively empty.

## Key Lesson

Artifact cleanup should be **intentional and evidence-based**.

Do not delete artifacts simply because Docker reports them as reclaimable. Consider whether the artifact is required for:

* rollback
* build caching
* testing
* persistent application data

Use targeted cleanup rather than blindly running broad commands such as:

```bash
docker system prune -a
```

Artifact lifecycle management is about knowing **what to retain, what to remove, and why**.