# Volume 8 — Milestone 3: Declarative Kubernetes State

## 1. Overview

This milestone establishes how the Expense Tracker project expresses and manages its desired Kubernetes state through version-controlled configuration.

Building on the repository-readiness work in Milestone 2, this milestone extends the Kustomize configuration to manage application image versions centrally.

The objective is to establish a clear relationship between Git, Kustomize, Argo CD, and Kubernetes controllers before implementing the full GitOps delivery workflow.

No Argo CD installation, cluster connection, or application deployment was performed during this milestone. Minikube remained stopped.

## 2. Declarative State

Declarative configuration describes the state that a system should maintain rather than listing every operational step required to achieve it.

The existing Kubernetes manifests express desired state through resource specifications.

For example, the backend Deployment declares three replicas, the frontend Deployment declares two replicas, and the MongoDB Deployment declares one replica.

These values describe the desired replica counts. They do not guarantee that the corresponding number of healthy Pods is currently running.

Kubernetes controllers continuously work to reconcile managed resources with their declared specifications.

## 3. Responsibilities in the GitOps Workflow

The intended architecture separates four responsibilities:

- **Git:** stores the desired Kubernetes configuration and its history.
- **Kustomize:** assembles the application manifests and applies configuration transformations.
- **Argo CD:** compares the declared configuration in Git with the cluster and reconciles differences according to its synchronization policy.
- **Kubernetes controllers:** manage individual resources, such as maintaining the replica count declared by a Deployment.

Argo CD and Kubernetes controllers have related but distinct roles. Argo CD reconciles the cluster with the configuration in Git, while Kubernetes controllers maintain the resources they manage.

Automatic correction of cluster differences depends on the Argo CD application's synchronization settings and policies.

## 4. Centralized Application Image Versions

The root Kustomize configuration is maintained at:

`kubernetes/kustomization.yaml`

An `images` section was added to centralize the desired frontend and backend image tags.

The declared application image versions are:

| Component | Image tag |
|---|---|
| Backend | `1.0.6` |
| Frontend | `1.0.4` |
| MongoDB | `4.4` |

The backend and frontend versions are managed through Kustomize image transformations. MongoDB remains declared directly in its existing Deployment manifest.

The existing Deployment manifests were not rewritten to remove their image references. Kustomize applies the centrally declared tags when rendering the combined configuration.

## 5. Validation Evidence

The updated configuration was validated using:

`kubectl kustomize kubernetes/`

The command completed without errors.

The rendered image references were inspected using:

`kubectl kustomize kubernetes/ | grep 'image:'`

The output confirmed:

- Backend image tag: `1.0.6`
- Frontend image tag: `1.0.4`
- MongoDB image tag: `4.4`

These checks demonstrate that Kustomize accepts the updated configuration and renders the expected image versions.

They do not establish that the images can be pulled successfully, that the application deploys successfully, or that the workloads are healthy.

## 6. Relationship Between CI and GitOps

The existing delivery architecture uses Jenkins to build and publish versioned container images to Amazon ECR.

Publishing an image to ECR does not automatically update the desired image version recorded in Git.

For example, if Jenkins publishes backend image `1.0.7` while Git continues to declare `1.0.6`, the registry and the desired deployment configuration will refer to different versions.

The agreed future workflow is:

1. Jenkins builds and publishes a versioned image to Amazon ECR.
2. The desired image tag is updated in `kubernetes/kustomization.yaml`.
3. The configuration change is committed and pushed to Git.
4. Argo CD detects the Git change and reconciles the cluster according to its synchronization policy.
5. Kubernetes performs the required rollout, after which workload health must be verified.

Jenkins-to-Git automation has not yet been implemented or tested. The current configuration provides the foundation for that integration.

Any future Jenkins integration must authenticate to Git securely and update the desired configuration without bypassing the GitOps deployment path by directly applying Kubernetes manifests.

## 7. Configuration and Operational Safeguards

The repository retains the configuration decisions established in Milestone 2:

- The backend application Secret is excluded from the root Kustomize resource list and must be provisioned separately before deployment.
- The ECR image-pull Secret remains outside Git and requires a credential-refresh procedure because ECR authentication tokens expire.
- The MongoDB PersistentVolumeClaim carries the `argocd.argoproj.io/sync-options: Prune=false` annotation to reduce the risk of automatic pruning by Argo CD.

The PVC annotation does not prevent manual deletion or replace database backups. Storage retention and reclaim behavior still require verification before stronger data-protection guarantees can be made.

## 8. Changes and Evidence

The implementation change for this milestone was made in:

`kubernetes/kustomization.yaml`

The change added centralized image-tag declarations for the backend and frontend.

The updated configuration was rendered successfully, and the resulting image versions were verified.

The implementation change was committed and pushed to the repository. The working tree was subsequently reported as clean.

No live Kubernetes resources were modified, and no Argo CD synchronization was performed.

## 9. Outstanding Work

The following implementation work remains:

1. Install and configure Argo CD for the target Kubernetes cluster.
2. Create an Argo CD Application that references the repository's Kustomize configuration.
3. Provision the backend application Secret and ECR pull Secret securely in the target namespace.
4. Review persistent-storage protection and synchronization policies.
5. Implement and test Jenkins-to-Git image-version updates.
6. Verify synchronization, rollout status, application health, and reconciliation behavior.

These items are planned work and are not represented as completed outcomes of this milestone.

## 10. Milestone Outcome

Milestone 3 established the declarative-state model for the Expense Tracker GitOps workflow and extended Kustomize to manage frontend and backend image versions centrally.

The configuration renders successfully, and the expected image tags have been verified.

The project is prepared for the next stage of GitOps implementation, but it is not yet connected to Argo CD and has not been deployed through GitOps.

**Next milestone:** Volume 8 — Milestone 4: GitOps Tooling and Controller Installation.
