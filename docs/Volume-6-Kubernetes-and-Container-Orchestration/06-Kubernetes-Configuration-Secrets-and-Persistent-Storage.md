# Kubernetes Configuration, Secrets and Persistent Storage

## Objective

The objective of this milestone was to move application configuration and sensitive configuration out of the Kubernetes Deployment specification and introduce persistent storage for MongoDB.

The milestone covered:

- ConfigMaps
- Secrets
- PersistentVolumes
- PersistentVolumeClaims
- MongoDB persistence
- Failure and recovery through Pod deletion

The goal was not simply to configure these resources, but to understand the engineering problem each one solves and verify the resulting behavior in the running cluster.

---

## Engineering Problem

The backend originally contained configuration directly inside the Deployment:

```yaml
env:
  - name: PORT
    value: "3000"

  - name: MONGO_URL
    value: mongodb://mongodb:27017/expense
```

This mixes application configuration with the Deployment definition.

MongoDB also stored its database files inside the container filesystem:

```text
/data/db
```

This creates a lifecycle problem.

A Pod can be deleted and recreated by Kubernetes, but application data should not necessarily disappear with the Pod.

The engineering questions for this milestone were therefore:

1. How should non-sensitive configuration be separated from the Deployment?
2. How should sensitive configuration be represented?
3. Where does MongoDB's data actually live?
4. How can MongoDB data survive Pod deletion and recreation?

---

# 1. ConfigMaps

## Problem

The backend Deployment contained configuration values directly in the Pod specification.

We created:

```text
kubernetes/backend/configmap.yaml
```

with:

```yaml
apiVersion: v1
kind: ConfigMap

metadata:
  name: backend-config

data:
  PORT: "3000"
  MONGO_URL: "mongodb://mongodb:27017/expense"
```

The ConfigMap was applied successfully:

```bash
kubectl apply -f kubernetes/backend/configmap.yaml
```

It was verified with:

```bash
kubectl get configmap
kubectl describe configmap backend-config
```

The backend Deployment was then changed to obtain the values from the ConfigMap:

```yaml
env:
  - name: PORT
    valueFrom:
      configMapKeyRef:
        name: backend-config
        key: PORT

  - name: MONGO_URL
    valueFrom:
      configMapKeyRef:
        name: backend-config
        key: MONGO_URL
```

The resulting Pod environment was verified:

```text
PORT=3000
MONGO_URL=mongodb://mongodb:27017/expense
```

This confirmed that the ConfigMap was successfully injected into the backend Pod.

### Observation

Kubernetes also automatically exposed Service-related environment variables such as:

```text
BACKEND_SERVICE_PORT
MONGODB_SERVICE_PORT
FRONTEND_SERVICE_PORT
KUBERNETES_SERVICE_PORT
```

These were Kubernetes-generated environment variables and were not part of our ConfigMap.

### Lesson

A ConfigMap allows non-sensitive application configuration to be managed separately from the container specification.

---

# 2. Secrets

## Problem

Sensitive configuration should not be represented in the same way as ordinary configuration.

The existing MongoDB connection string was:

```text
mongodb://mongodb:27017/expense
```

It did not contain a username or password, so we did not incorrectly classify it as sensitive.

Instead, we created a lab-only Secret to demonstrate the Kubernetes Secret mechanism.

File:

```text
kubernetes/backend/secret.yaml
```

Content:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: backend-secret

type: Opaque

stringData:
  APP_SECRET: "lab-secret-value"
```

The Secret was applied successfully.

It was verified with:

```bash
kubectl get secrets
```

The backend Deployment was then configured to obtain `APP_SECRET` from the Secret:

```yaml
- name: APP_SECRET
  valueFrom:
    secretKeyRef:
      name: backend-secret
      key: APP_SECRET
```

The Deployment successfully rolled out.

The presence of the environment variable was verified without printing the actual secret value.

### Lesson

The important distinction established was:

```text
ConfigMap → non-sensitive configuration
Secret    → sensitive configuration
```

A Secret should not be treated as ordinary configuration simply because the application needs the value as an environment variable.

---

# 3. Investigating MongoDB Storage

Before creating persistent storage, we investigated where MongoDB was actually storing its data.

The MongoDB Pod was:

```text
mongodb-57994ccb8d-2gq48
```

We inspected its filesystem:

```bash
kubectl exec -it mongodb-57994ccb8d-2gq48 -- df -h
```

The relevant result was:

```text
overlay          39G   27G   12G  69% /
```

There was no dedicated MongoDB persistent volume mounted.

We then inspected MongoDB's actual data directory:

```bash
kubectl exec -it mongodb-57994ccb8d-2gq48 -- sh -c 'du -sh /data/db && ls -lah /data/db'
```

The result showed approximately:

```text
301M    /data/db
```

The directory contained MongoDB storage files including:

```text
WiredTiger
WiredTiger.wt
WiredTigerHS.wt
_mdb_catalog.wt
collection-*.wt
index-*.wt
journal
storage.bson
```

### Observation

MongoDB was actively storing its database files under:

```text
/data/db
```

but `/data/db` was not backed by a Kubernetes PersistentVolume.

This established the storage problem from the actual running application rather than assuming where MongoDB stored its data.

---

# 4. StorageClass Investigation

We inspected the available StorageClasses:

```bash
kubectl get storageclass
```

The cluster had:

```text
NAME                 PROVISIONER                RECLAIMPOLICY
standard (default)   k8s.io/minikube-hostpath   Delete
```

We then inspected the StorageClass:

```bash
kubectl describe storageclass standard
```

Important properties were:

```text
IsDefaultClass:       Yes
Provisioner:          k8s.io/minikube-hostpath
ReclaimPolicy:        Delete
VolumeBindingMode:    Immediate
```

The StorageClass was therefore capable of dynamically provisioning storage for a PVC.

---

# 5. PersistentVolumeClaim

We created:

```text
kubernetes/mongodb/pvc.yaml
```

with:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim

metadata:
  name: mongodb-pvc

spec:
  accessModes:
    - ReadWriteOnce

  resources:
    requests:
      storage: 1Gi
```

The claim was applied:

```bash
kubectl apply -f kubernetes/mongodb/pvc.yaml
```

Initially, the PVC remained:

```text
STATUS: Pending
```

---

# 6. Controlled Storage Provisioning Failure

The PVC remained Pending with the following event:

```text
Waiting for a volume to be created either by the external provisioner
'k8s.io/minikube-hostpath' or manually by the system administrator.
```

This led us to investigate the storage provisioner rather than immediately creating a PV manually.

We checked the Kubernetes system Pods:

```bash
kubectl get pods -n kube-system
```

The storage provisioner was not initially visible.

We then checked Minikube addons:

```bash
minikube addons list
```

This showed:

```text
storage-provisioner   minikube   enabled
```

So the addon was marked enabled, but the provisioner workload was not actually running.

We also checked all Kubernetes resources:

```bash
kubectl get pods -A | grep -i storage
```

Initially there was no output.

We then explicitly enabled the addon:

```bash
minikube addons enable storage-provisioner
```

After this, the provisioner appeared:

```text
kube-system   pod/storage-provisioner   1/1   Running
```

The existing PVC then became:

```text
mongodb-pvc   Bound
```

### Lesson

An addon being reported as enabled does not necessarily mean its workload is currently running.

The important troubleshooting sequence was:

```text
PVC Pending
    ↓
Inspect PVC events
    ↓
Identify provisioner
    ↓
Check provisioner workload
    ↓
Check Minikube addon
    ↓
Provisioner workload missing
    ↓
Enable addon
    ↓
Provisioner Running
    ↓
PVC Bound
```

This was a useful controlled failure because we diagnosed the underlying infrastructure rather than bypassing dynamic provisioning with a manually created PV.

---

# 7. PersistentVolume

After the storage provisioner became available, Kubernetes dynamically created a PersistentVolume.

The PV was:

```text
pvc-4e7115bd-beec-4b31-95c2-a8a02cbb94d2
```

It was verified with:

```bash
kubectl get pv
```

The resulting state was:

```text
CAPACITY:        1Gi
ACCESS MODES:    RWO
RECLAIM POLICY:  Delete
STATUS:          Bound
CLAIM:           default/mongodb-pvc
STORAGECLASS:    standard
```

This demonstrated dynamic provisioning:

```text
PVC
 ↓
StorageClass
 ↓
Provisioner
 ↓
PV
 ↓
PVC becomes Bound
```

A PersistentVolume was therefore created automatically rather than manually.

---

# 8. Establishing the MongoDB Data Baseline

Before attaching the persistent volume to MongoDB, we checked the current application data.

The `expense` database contained:

```text
transactions
users
```

We checked the document counts using the MongoDB `mongo` shell.

Users:

```text
0
```

Transactions:

```text
0
```

Although the MongoDB filesystem contained approximately 301 MB of database files, there were currently no application documents that needed to be migrated.

This meant we could safely introduce the persistent volume without performing a data migration or restore.

---

# 9. Mounting the PVC into MongoDB

The original MongoDB Deployment was:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: mongodb

spec:
  replicas: 1

  selector:
    matchLabels:
      app: mongodb

  template:
    metadata:
      labels:
        app: mongodb

    spec:
      containers:
        - name: mongodb
          image: mongo:4.4
          ports:
            - containerPort: 27017
```

We added a volume mount:

```yaml
volumeMounts:
  - name: mongodb-storage
    mountPath: /data/db
```

and connected the volume to the PVC:

```yaml
volumes:
  - name: mongodb-storage
    persistentVolumeClaim:
      claimName: mongodb-pvc
```

The resulting relationship was:

```text
PVC: mongodb-pvc
       ↓
Pod volume: mongodb-storage
       ↓
Container mount: /data/db
```

The Deployment was applied:

```bash
kubectl apply -f kubernetes/mongodb/deployment.yaml
```

The rollout completed successfully:

```text
deployment "mongodb" successfully rolled out
```

---

# 10. Verifying the Persistent Mount

The new MongoDB Pod was inspected with:

```bash
kubectl describe pod mongodb-7f5cf86ddd-hl92n
```

The Pod reported:

```text
Mounts:
  /data/db from mongodb-storage (rw)
```

and:

```text
Volumes:
  mongodb-storage:
    Type: PersistentVolumeClaim
    ClaimName: mongodb-pvc
```

This proved that `/data/db` was actually backed by the PVC in the running Pod.

---

# 11. Persistence Experiment

Configuration alone does not prove persistence.

We therefore performed a controlled failure experiment.

First, we inserted a known test document:

```bash
kubectl exec -it mongodb-7f5cf86ddd-hl92n -- mongo --quiet --eval 'db.getSiblingDB("expense").users.insertOne({test: "persistent-storage", createdAt: new Date()})'
```

MongoDB returned:

```text
acknowledged: true
insertedId: ObjectId("6ac645feb8d8d4cb752f5e30")
```

We then deliberately deleted the MongoDB Pod:

```bash
kubectl delete pod mongodb-7f5cf86ddd-hl92n
```

The Deployment recreated the Pod:

```text
mongodb-7f5cf86ddd-n5mgv
```

The replacement Pod initially appeared Pending but subsequently became:

```text
1/1 Running
```

We then checked whether the test document survived:

```bash
kubectl exec -it mongodb-7f5cf86ddd-n5mgv -- mongo --quiet --eval 'db.getSiblingDB("expense").users.find({test: "persistent-storage"}).count()'
```

The result was:

```text
1
```

### Result

The document survived the deletion and recreation of the MongoDB Pod.

This demonstrated that the data was stored on the persistent volume rather than being tied exclusively to the original Pod's writable filesystem.

---

# 12. Test Data Cleanup

The temporary test document was removed:

```bash
kubectl exec -it mongodb-7f5cf86ddd-n5mgv -- mongo --quiet --eval 'db.getSiblingDB("expense").users.remove({test: "persistent-storage"})'
```

MongoDB returned:

```text
WriteResult({ "nRemoved" : 1 })
```

The test data was therefore cleaned up after the persistence experiment.

---

# 13. Final Verification

The final cluster state was checked with:

```bash
kubectl get pods,svc,pvc
```

The application was running with:

```text
Backend     3/3 Running
Frontend    2/2 Running
MongoDB     1/1 Running
```

Services remained available:

```text
backend     ClusterIP   3000
frontend     ClusterIP   80
mongodb      ClusterIP   27017
```

The PVC remained:

```text
mongodb-pvc
STATUS:       Bound
CAPACITY:     1Gi
ACCESS MODE:  RWO
STORAGECLASS: standard
```

The final MongoDB Pod still reported:

```text
/data/db from mongodb-storage (rw)
```

and:

```text
mongodb-storage:
  Type:       PersistentVolumeClaim
  ClaimName:  mongodb-pvc
```

The PersistentVolume remained:

```text
pvc-4e7115bd-beec-4b31-95c2-a8a02cbb94d2
```

with:

```text
STATUS:       Bound
CLAIM:        default/mongodb-pvc
CAPACITY:     1Gi
ACCESS MODE:  RWO
```

---

# 14. Final Architecture

The Kubernetes application now has the following storage architecture:

```text
                         ┌──────────────────┐
                         │   Frontend Pod   │
                         │   React + Nginx  │
                         └────────┬─────────┘
                                  │
                                  │ /api/
                                  ▼
                         ┌──────────────────┐
                         │   Backend Pods   │
                         │    3 replicas    │
                         └────────┬─────────┘
                                  │
                                  │ mongodb:27017
                                  ▼
                         ┌──────────────────┐
                         │   MongoDB Pod    │
                         │    1 replica     │
                         └────────┬─────────┘
                                  │
                                  │ /data/db
                                  ▼
                         ┌──────────────────┐
                         │ mongodb-storage  │
                         │   Pod volume     │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  mongodb-pvc     │
                         │      1Gi         │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ PersistentVolume │
                         │      1Gi         │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Minikube         │
                         │ host-path        │
                         └──────────────────┘
```

---

# 15. Key Commands Used

### ConfigMap

```bash
kubectl apply -f kubernetes/backend/configmap.yaml
kubectl get configmap
kubectl describe configmap backend-config
```

### Secret

```bash
kubectl apply -f kubernetes/backend/secret.yaml
kubectl get secrets
```

### Storage investigation

```bash
kubectl exec -it <mongodb-pod> -- df -h

kubectl exec -it <mongodb-pod> -- \
  sh -c 'du -sh /data/db && ls -lah /data/db'
```

### StorageClass

```bash
kubectl get storageclass
kubectl describe storageclass standard
```

### PVC

```bash
kubectl apply -f kubernetes/mongodb/pvc.yaml
kubectl get pvc
kubectl describe pvc mongodb-pvc
```

### Provisioner troubleshooting

```bash
kubectl get pods -n kube-system
minikube addons list
kubectl get pods -A | grep -i storage
minikube addons enable storage-provisioner
kubectl get all -A | grep -i storage
```

### PV

```bash
kubectl get pv
```

### MongoDB deployment

```bash
kubectl apply -f kubernetes/mongodb/deployment.yaml
kubectl rollout status deployment/mongodb
kubectl get pods -l app=mongodb
kubectl describe pod <mongodb-pod>
```

### Persistence experiment

```bash
kubectl delete pod <mongodb-pod>
```

The test document was then queried from the recreated Pod to verify persistence.

---

# 16. Important Observations

### Pod lifecycle and data lifecycle are different

A Kubernetes Pod can be deleted and recreated without requiring application data to be deleted.

```text
Pod lifecycle
     ≠
Data lifecycle
```

Persistent storage allows the data lifecycle to exist independently of the Pod lifecycle.

### PVCs express storage requirements

The application requested:

```text
1Gi
ReadWriteOnce
```

through the PersistentVolumeClaim.

The StorageClass determined how that request was fulfilled.

### Dynamic provisioning

We did not manually create the PersistentVolume.

The StorageClass and provisioner dynamically created the PV after the PVC was processed.

### A successful Deployment rollout does not prove persistence

We verified the actual mount:

```text
/data/db from mongodb-storage (rw)
```

and then performed a Pod deletion/recreation experiment.

The survival of the test document provided stronger evidence than configuration alone.

### Failure is part of the learning

The PVC initially remained Pending because the expected storage provisioner workload was not running, despite the Minikube addon being reported as enabled.

Investigating the failure exposed the relationship between:

```text
PVC
 ↓
StorageClass
 ↓
Provisioner
 ↓
PV
```

---

# 17. Lab vs Production Boundary

The implementation in this milestone is appropriate for the Minikube learning environment.

The cluster uses:

```text
k8s.io/minikube-hostpath
```

with:

```text
ReclaimPolicy: Delete
```

This should not automatically be interpreted as a production MongoDB storage architecture.

A production deployment would require deliberate consideration of:

- Durable storage
- Storage failure
- Backup
- Restore
- Data recovery
- Retention policies
- Availability
- Storage performance
- Database replication
- Disaster recovery

Those concerns are outside the current M06 objective.

---

# 18. Lessons Learned

1. Configuration should be separated from application Deployment definitions where appropriate.
2. ConfigMaps are suitable for non-sensitive configuration.
3. Secrets provide a mechanism for sensitive configuration.
4. MongoDB stores its database files under `/data/db`.
5. A Pod's writable filesystem should not be treated as durable application storage.
6. A PVC represents an application's request for persistent storage.
7. A StorageClass defines how storage can be dynamically provisioned.
8. A PersistentVolume represents the provisioned storage resource.
9. A PVC can become Bound to a dynamically created PV.
10. A volume must be mounted into the container at the location where the application expects its data.
11. Persistence must be tested through failure, not merely assumed from YAML.
12. Deleting and recreating the MongoDB Pod did not destroy the test document because the data was stored through the persistent volume.
13. Troubleshooting should investigate the actual failure rather than bypassing the system with a workaround.

---

# 19. Completion Checklist

- [x] ConfigMap created
- [x] Backend configuration moved to ConfigMap
- [x] ConfigMap injection verified
- [x] Secret created
- [x] Secret injection verified without exposing the value
- [x] MongoDB storage location investigated
- [x] StorageClass investigated
- [x] PVC created
- [x] PVC provisioning failure investigated
- [x] Storage provisioner restored
- [x] PVC became Bound
- [x] PersistentVolume dynamically provisioned
- [x] PVC mounted at `/data/db`
- [x] MongoDB restarted with persistent storage
- [x] Test data created
- [x] MongoDB Pod deliberately deleted
- [x] Replacement Pod created
- [x] Test data survived Pod recreation
- [x] Test data removed
- [x] Final PVC/PV state verified
- [x] Final MongoDB mount verified

---

# 20. Milestone Completion

**M06 — Configuration, Secrets & Persistent Storage: COMPLETE**

The milestone demonstrated the transition from ephemeral container storage to Kubernetes-managed persistent storage.

The final storage relationship is:

```text
MongoDB
   ↓
/data/db
   ↓
Pod volume
   ↓
PersistentVolumeClaim
   ↓
PersistentVolume
   ↓
Minikube host-path storage
```

The persistence mechanism was validated through a deliberate Pod deletion and recreation experiment.

---

# 21. Boundary to M07

The next milestone is:

## M07 — Ingress & External Access

M07 will introduce:

- Ingress
- HTTP routing
- Public application access
- Nginx Ingress Controller

M06 should be considered complete before beginning M07.