# Helm Milestone 1: Chart Creation and Rendering

## 1. Introduction

This milestone introduced Helm and its role in Kubernetes application deployment.

The practical exercise involved converting the existing Expense Tracker Kubernetes configuration into a Helm Chart.

The objective was to understand how Helm separates configurable application properties from Kubernetes resource definitions, allowing the same application templates to be reused with different configurations.

**Important:** Helm was introduced as a supplemental learning module between Volume 8 (GitOps) and the final Production-Like DevOps Pipeline. It is not a new formal phase in the DevOps mentorship roadmap.

## 2. The Engineering Problem Helm Solves

Before introducing Helm, our Expense Tracker application was deployed using conventional Kubernetes YAML manifests.

Each resource had its configuration embedded directly in its manifest.

For example, our frontend Deployment contained:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: 2

  selector:
    matchLabels:
      app: frontend

  template:
    metadata:
      labels:
        app: frontend

    spec:
      containers:
        - name: frontend
          image: 748241639517.dkr.ecr.us-east-1.amazonaws.com/expense-tracker-dev-frontend:1.0.4

          ports:
            - containerPort: 80
```

Notice that:

- The replica count was explicitly set to 2.
- The image repository was hardcoded.
- The image version was hardcoded.

If we wanted to deploy the application with different replica counts or image versions in different environments, we would need to modify the manifests or maintain separate copies.

This introduces configuration duplication and makes managing multiple deployment environments more difficult.

**The engineering problem:** How can we maintain reusable Kubernetes resource definitions while allowing application configuration to change independently?

Helm provides a solution through Charts, Values and Templates.

## 3. Understanding Helm Architecture

There are four important concepts to understand.

### 3.1 Chart

A Chart is the complete Helm package containing the files and configuration required to define an application deployment.

It includes:

- Chart metadata.
- Default configuration values.
- Kubernetes resource templates.
- Optional dependencies and supporting files.

Our chart is named:

`expense-tracker`

### 3.2 Values

The `values.yaml` file contains the configurable properties supplied to the chart.

Examples include:

- Replica counts.
- Container image repositories.
- Image versions.
- Container ports.
- Resource requests and limits.
- Ingress configuration.
- Storage settings.

For example:

```yaml
frontend:
  replicaCount: 2

  image:
    repository: nginx
    tag: "1.27"
```

These values can be changed without rewriting the Kubernetes resource definition.

### 3.3 Templates

The `templates/` directory contains Kubernetes resource definitions written using Helm's templating syntax.

These templates contain placeholders that Helm processes using the supplied values.

For example:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: {{ .Values.frontend.replicaCount }}

  template:
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
```

An important point: **The Helm developer writes these template expressions. Helm does not automatically identify and convert hardcoded Kubernetes properties into template expressions.**

The chart developer decides which properties should be configurable and writes the corresponding expressions.

### 3.4 Helm

Helm is the tool that processes the chart's templates using the supplied values.

It replaces the template expressions with their corresponding values and produces ordinary Kubernetes YAML manifests.

Kubernetes receives the rendered manifests, not the original Helm template expressions.

## 4. How the Four Concepts Work Together

Consider the following example.

### Step 1: Original Kubernetes manifest

Before introducing Helm, our configuration was combined in one Deployment manifest:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: 2

  template:
    spec:
      containers:
        - name: frontend
          image: nginx:1.27
```

### Step 2: Extract configurable properties into values.yaml

We separate the properties we want to configure:

```yaml
frontend:
  replicaCount: 2

  image:
    repository: nginx
    tag: "1.27"
```

### Step 3: Create the Helm template

We retain the Kubernetes resource definition but replace the hardcoded properties with Helm expressions:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: {{ .Values.frontend.replicaCount }}

  template:
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
```

### Step 4: Helm renders the template

Helm processes the expressions using the configuration in `values.yaml`.

The expression:

```yaml
replicas: {{ .Values.frontend.replicaCount }}
```

becomes:

```yaml
replicas: 2
```

The image expression:

```yaml
image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
```

becomes:

```yaml
image: nginx:1.27
```

The resulting Kubernetes manifest is ordinary YAML again.

### Understanding the expression

Consider:

```yaml
replicas: {{ .Values.frontend.replicaCount }}
```

| Expression | Meaning |
|---|---|
| `.` | Current Helm template context |
| `.Values` | Accesses the values supplied to the chart |
| `frontend` | Refers to the frontend section in values.yaml |
| `replicaCount` | Retrieves the replicaCount property |

The `frontend` name is not automatically generated or understood by Helm. It comes from the configuration structure we define in `values.yaml`.

For example, if the values file contained:

```yaml
backend:
  replicaCount: 3
```

The corresponding template expression would be:

```yaml
replicas: {{ .Values.backend.replicaCount }}
```

The names and paths must match.

### The relationship

- Chart: The complete package.
- Values: The configuration inputs.
- Templates: The Kubernetes resource blueprints.
- Helm: The rendering engine that combines the templates and values.

**Key lesson:** Helm does not replace Kubernetes manifests. It makes their configurable properties reusable by separating configuration from resource definitions.

## 5. Installing Helm

Our lab environment:

| Component | Details |
|---|---|
| Operating system | Ubuntu 22.04.5 LTS |
| Architecture | AMD64 |
| Kubernetes environment | Minikube |
| Helm version | v4.3.0 |

We installed Helm through the Helm APT repository.

The signing key was installed using:

```bash
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
```

The repository was added using:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
```

We updated the package index and installed Helm:

```bash
sudo apt update
sudo apt install helm -y
```

We verified the installation:

```bash
helm version
```

The installed version was:

```text
version.BuildInfo{
  Version:"v4.3.0",
  GitCommit:"bec5b06ed841fe5269972d864d5177944fd5970f",
  GitTreeState:"clean",
  GoVersion:"go1.27.1",
  KubeClientVersion:"v1.37"
}
```

## 6. Preparing the Expense Tracker Helm Chart

Before creating the chart, we confirmed that Helm was targeting our existing Minikube cluster:

```bash
kubectl config current-context
```

Output:

```text
minikube
```

We also confirmed our working directory:

```text
/home/vagrant/projects/expense-tracker-devops
```

The repository already contained the following relevant directories:

- `app/`
- `kubernetes/`
- `terraform/`
- `monitoring/`
- `docs/`

We decided to keep Helm separate from the existing Kubernetes manifests.

The intended location was:

```text
helm/expense-tracker/
```

We created the parent directory:

```bash
mkdir -p helm
```

Then generated the starter chart:

```bash
helm create helm/expense-tracker
```

This generated the initial Helm Chart structure.

## 7. Understanding the Generated Chart Structure

The initial chart contained:

```text
helm/expense-tracker/
├── Chart.yaml
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── httproute.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
└── values.yaml
```

Important files:

| File | Purpose |
|---|---|
| Chart.yaml | Chart metadata and version information |
| values.yaml | Default configuration values |
| templates/ | Kubernetes resource templates |
| _helpers.tpl | Reusable template helper definitions |
| NOTES.txt | Information displayed after installation |
| charts/ | Chart dependencies |

We removed the generated sample templates that were not needed for our application.

## 8. Understanding Chart.yaml

We configured our chart metadata as follows:

```yaml
apiVersion: v2
name: expense-tracker
description: Helm chart for deploying the Expense Tracker application
type: application
version: 0.1.0
appVersion: "1.0.6"
```

Important fields:

- `apiVersion: v2`: Chart metadata format used by Helm 3 and later.
- `name`: Identifies the chart.
- `description`: Describes the chart.
- `type: application`: Indicates that the chart packages deployable application resources.
- `version`: Version of the Helm chart itself.
- `appVersion`: Application version metadata.

**Chart version and application version are different.**

The chart version changes when we update the chart's templates or configuration.

The application version describes the application associated with the chart.

Our frontend and backend image versions are independently configured as `1.0.4` and `1.0.6`. The `appVersion` field is metadata; it does not automatically determine either image tag.

## 9. Configuring values.yaml for the Expense Tracker

The generated values file initially contained sample Nginx configuration.

We replaced it with application-specific configuration.

The major sections were:

### Frontend

- Two replicas.
- ECR image version `1.0.4`.
- Service port 80.
- CPU and memory requests and limits.
- NGINX Ingress configuration.
- Configurable pod labels.
- Configurable Service annotations.

### Backend

- One replica.
- ECR image version `1.0.6`.
- Service port 3000.
- Backend ConfigMap settings.
- Existing Kubernetes Secret reference.
- Startup, readiness and liveness probes.

### MongoDB

- One replica.
- MongoDB image `mongo:4.4`.
- Service port 27017.
- Persistent storage of 1Gi.
- ReadWriteOnce access mode.

### Shared image-pull credentials

We configured:

```yaml
global:
  imagePullSecrets:
    - name: ecr-secret
```

This allows the frontend and backend templates to reference the existing ECR image-pull Secret.

### Security consideration

We did not place actual secret values inside `values.yaml`.

Instead, the backend template references the existing Kubernetes Secret:

```yaml
secretKeyRef:
  name: backend-secret
  key: APP_SECRET
```

This keeps sensitive application configuration outside the Helm chart values.

## 10. Creating the Kubernetes Resource Templates

We created nine application resource templates.

| Template | Kubernetes resource |
|---|---|
| frontend-deployment.yaml | Frontend Deployment |
| frontend-service.yaml | Frontend Service |
| frontend-ingress.yaml | Frontend Ingress |
| backend-deployment.yaml | Backend Deployment |
| backend-service.yaml | Backend Service |
| backend-configmap.yaml | Backend ConfigMap |
| mongodb-deployment.yaml | MongoDB Deployment |
| mongodb-service.yaml | MongoDB Service |
| mongodb-pvc.yaml | MongoDB PersistentVolumeClaim |

We also retained:

- `_helpers.tpl`
- `NOTES.txt`

The helper file contains reusable naming and labeling definitions.

## 11. Preserving Existing Kubernetes Configuration

We used the original Kubernetes manifests as our reference rather than creating an unrelated sample application.

Important configurations preserved included:

- Frontend replica count and resource requests/limits.
- Backend health probes.
- Existing ECR image versions.
- Existing Secret references.
- MongoDB persistence configuration.
- Frontend Ingress host.
- Frontend Service annotations.
- Frontend pod label `rollout-experiment: "m09"`.
- MongoDB PVC annotation `argocd.argoproj.io/sync-options: Prune=false`.

We initially missed the frontend Service annotations and the `rollout-experiment` pod label. We subsequently restored both and verified their presence in the rendered output.

We deliberately excluded `gitops-pruning-demo.yaml` because it is a GitOps experiment rather than a normal application resource.

The original `kubernetes/` directory remained untouched.

## 12. Helm Validation and Troubleshooting

### 12.1 Helm lint

We validated the chart:

```bash
helm lint helm/expense-tracker
```

Our first attempt failed:

```text
ERROR templates/: expense-tracker/templates/deployment.yaml
executing at <.Values.autoscaling.enabled>:
nil pointer evaluating interface {}.enabled
```

**Cause:**

The original sample `deployment.yaml` template generated by `helm create` was still present.

It expected an `autoscaling` configuration in `values.yaml`, which we had replaced with our application-specific configuration.

**Resolution:**

We removed the unnecessary generated template:

```bash
rm helm/expense-tracker/templates/deployment.yaml
```

We ran lint again:

```bash
helm lint helm/expense-tracker
```

Result:

```text
==> Linting helm/expense-tracker
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

The icon message was only a recommendation, not a failure.

### 12.2 Rendering the Helm chart

We rendered the chart:

```bash
helm template expense-tracker helm/expense-tracker
```

This generated ordinary Kubernetes manifests using our chart templates and values.

Helm successfully generated nine resources.

### 12.3 Saving the rendered output

We saved the generated manifests outside the repository:

```bash
helm template expense-tracker helm/expense-tracker \
  > /tmp/expense-tracker-rendered.yaml
```

We checked the output length:

```bash
wc -l /tmp/expense-tracker-rendered.yaml
```

Result:

```text
272 /tmp/expense-tracker-rendered.yaml
```

### 12.4 Kubernetes client-side dry-run

We validated the rendered manifests:

```bash
kubectl apply --dry-run=client -f /tmp/expense-tracker-rendered.yaml
```

All nine resources passed:

```text
configmap/backend-config configured (dry run)
persistentvolumeclaim/mongodb-pvc configured (dry run)
service/backend configured (dry run)
service/frontend configured (dry run)
service/mongodb configured (dry run)
deployment.apps/backend configured (dry run)
deployment.apps/frontend configured (dry run)
deployment.apps/mongodb configured (dry run)
ingress.networking.k8s.io/frontend-ingress configured (dry run)
```

This confirmed that the generated manifests passed the Kubernetes client-side dry-run validation.

It did not prove that the application had been deployed or that the resources would operate successfully in a live deployment.

## 13. Important Commands Learned

| Command | Purpose |
|---|---|
| `helm version` | Checks the installed Helm version |
| `helm --help` | Displays Helm commands and usage |
| `helm create` | Generates a starter chart |
| `helm lint` | Checks chart structure and common issues |
| `helm template` | Renders a chart into Kubernetes manifests |
| `kubectl apply --dry-run=client` | Validates manifests without applying them |
| `helm list` | Lists Helm releases |
| `helm history` | Displays release revision history |
| `helm upgrade` | Upgrades an installed release |
| `helm rollback` | Reverts a release to an earlier revision |

The final four commands are included as upcoming learning objectives; they have not yet been exercised in this milestone.

## 14. Important Lessons Learned

1. Helm does not automatically convert Kubernetes YAML into templates. The chart developer writes the template expressions.
2. `values.yaml` holds configuration, while `templates/` holds Kubernetes resource definitions.
3. The names and paths used in `.Values` expressions must match the structure in `values.yaml`.
4. Helm renders templates into ordinary Kubernetes YAML.
5. A successful `helm lint` does not by itself prove that the rendered resources are valid.
6. Rendering and dry-run validation are useful before attempting deployment.
7. Existing Kubernetes Secrets should be referenced rather than exposing secret values in chart configuration.
8. Helm charts should be built around the actual application architecture rather than blindly retaining generated examples.
9. Helm can make the same resource templates reusable across environments through different values files.
10. Helm and Argo CD can work together, but we must avoid creating conflicting ownership over resources already managed by Argo CD.

### Scope limitation

The chart has not been installed into Minikube.

No Helm release has been created for this chart, and the existing Argo CD-managed Expense Tracker application has not been replaced or modified by Helm.

### Next milestone

**Milestone 2 — Helm Configuration and Environments**

The next learning objective is to understand how different values files allow the same Helm chart to support different environments, such as development and production, without duplicating Kubernetes templates.

---

**Key takeaway:**

Helm makes Kubernetes application deployment more reusable and configurable by separating resource definitions from the values that control them. The chart developer defines this separation, and Helm renders the final Kubernetes manifests.