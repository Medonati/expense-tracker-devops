# Volume 8 — Milestone 2: Repository and Configuration Readiness

## 1. Overview

This milestone prepares the existing Expense Tracker Kubernetes manifests for GitOps management using Kustomize and Argo CD.

The objective is to establish a single entry point for the application's Kubernetes resources, review configuration dependencies, and introduce a safeguard for MongoDB's persistent storage before connecting the repository to a GitOps controller.

All work in this milestone was performed at the repository level. Minikube remained stopped, and no Kubernetes resources were deployed or modified in a running cluster.

## 2. Existing Kubernetes Resource Structure

The application manifests are organized into three component directories:

- `kubernetes/backend/` — backend Deployment, Service, ConfigMap and Secret.
- `kubernetes/frontend/` — frontend Deployment, Service and Ingress.
- `kubernetes/mongodb/` — MongoDB Deployment, Service and PersistentVolumeClaim.

The backend uses the `mongodb` Service for database discovery. The frontend and backend Deployments reference the `ecr-secret` image-pull Secret to access private Amazon ECR images.

## 3. Kustomize Entry Point

A root Kustomize configuration was created at:

`kubernetes/kustomization.yaml`

The configuration references nine existing Kubernetes resources:

1. Backend ConfigMap
2. Backend Deployment
3. Backend Service
4. Frontend Deployment
5. Frontend Service
6. Frontend Ingress
7. MongoDB Deployment
8. MongoDB Service
9. MongoDB PersistentVolumeClaim

The configuration reuses the existing manifests rather than duplicating their contents.

### Validation

The following command successfully rendered the configuration:

`kubectl kustomize kubernetes/`

The rendered output was also counted, confirming nine resources.

A subsequent build redirected the rendered configuration to a temporary file and returned:

`Kustomize build successful`

These checks establish that Kustomize can assemble the configured resources. They do not establish that the resources can be successfully deployed or that the application is healthy.

## 4. Secret Management Considerations

### Application Secret

The backend Deployment references `backend-secret` for the `APP_SECRET` environment variable.

The existing `kubernetes/backend/secret.yaml` contains a lab placeholder. It was deliberately excluded from the root Kustomize resource list while the secret-provisioning approach remains to be finalized.

The Secret must be provisioned separately before the backend is deployed through GitOps.

### Amazon ECR Image-Pull Secret

Both the frontend and backend reference `ecr-secret`.

Previous lab work established a procedure for creating and refreshing this Secret using AWS CLI authentication and `kubectl`. ECR authentication tokens expire, so credential refresh remains necessary.

The credential Secret is not included in the Kustomize resource list. Automated renewal has not yet been implemented in the work recorded for this milestone.

Neither the application Secret nor registry credentials should be exposed in Git.

## 5. Persistent Storage Protection

The MongoDB Deployment uses the `mongodb-pvc` PersistentVolumeClaim to request 1 GiB of persistent storage.

The PVC manifest was updated with this annotation:

`argocd.argoproj.io/sync-options: Prune=false`

This option instructs Argo CD not to prune the annotated resource automatically during synchronization.

This is a safeguard against one class of accidental deletion. It does not prevent manual deletion, guarantee the retention of the underlying volume, or replace database backups.

The behavior of the storage provisioner and its reclaim policy still needs to be verified before making stronger claims about data retention.

## 6. GitOps Architecture Direction

The intended implementation separates responsibilities:

- **GitHub Actions:** validates and tests Terraform configuration through the existing Terraform CI workflow.
- **Jenkins and Amazon ECR:** support the existing application image build and distribution workflow.
- **Kustomize:** assembles the Kubernetes manifests into a single deployable configuration.
- **Argo CD:** will later monitor the selected Git repository path and reconcile the target Kubernetes cluster with the declared configuration.

No Argo CD Application has been created or connected to the repository in this milestone.

## 7. Changes and Evidence

The repository changes confirmed by `git status --short` were:

- Modified: `kubernetes/mongodb/pvc.yaml`
- Untracked: `kubernetes/kustomization.yaml`

Validation evidence included:

- Successful `kubectl kustomize kubernetes/` execution.
- Nine rendered Kubernetes resources.
- Successful subsequent Kustomize build.

No cluster deployment or runtime verification was performed.

## 8. Outstanding Prerequisites

Before the application is deployed through Argo CD, the following work remains:

1. Decide and implement safe provisioning for `backend-secret`.
2. Ensure `ecr-secret` exists in the target namespace and can be refreshed when required.
3. Verify the target namespace and supporting-resource requirements.
4. Review persistent-storage behavior and deletion safeguards.
5. Validate the rendered manifests and prepare the Argo CD Application configuration.

These items are prerequisites for deployment and further reconciliation testing.

## 9. Milestone Outcome

Milestone 2 established a Kustomize entry point for the existing Kubernetes application manifests, verified that nine resources render successfully, and added an Argo CD pruning safeguard to the MongoDB PVC.

The repository is better prepared for GitOps integration, but it is not yet connected to Argo CD and the application has not been deployed through GitOps.

**Next milestone:** Volume 8 — Milestone 3: Declarative Kubernetes State.
