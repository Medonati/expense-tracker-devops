# Volume 8 — Milestone 5: Connect Git to Kubernetes

**Project:** Expense Tracker DevOps Portfolio  
**Repository:** [Medonati/expense-tracker-devops](https://github.com/Medonati/expense-tracker-devops)  
**Phase:** Volume 8 — GitOps  
**Milestone:** 5 — Connect Git to Kubernetes  
**Status:** Practical implementation completed  
**GitOps Tool:** Argo CD v3.5.6  
**Kubernetes Environment:** Minikube v1.39.0  
**Kubernetes Version:** v1.37.0

---

## 1. Milestone Overview

The objective of this milestone was to establish and demonstrate the connection between a Git repository and a Kubernetes cluster through Argo CD.

The exercise focused on understanding how Argo CD monitors a Git repository, detects changes to Kubernetes manifests, compares the desired configuration with the live cluster state, and reconciles differences through synchronization.

We used the existing Expense Tracker application and its Argo CD Application rather than creating a new application or reinstalling Argo CD.

The milestone also included troubleshooting and establishing reliable access to the Argo CD dashboard without depending on a temporary `kubectl port-forward` process.

### Learning objectives

By the end of this milestone, the following concepts were demonstrated:

- Connecting Argo CD to a GitHub repository.
- Understanding Git as the source of truth for declarative Kubernetes configuration.
- Understanding desired state versus live state.
- Detecting configuration changes through Argo CD.
- Understanding the OutOfSync status.
- Performing manual synchronization.
- Understanding reconciliation.
- Verifying changes directly against Kubernetes resources.
- Establishing persistent dashboard access using NodePort, Vagrant port forwarding, Docker networking and a systemd-managed TCP proxy.

---

## 2. Existing Argo CD Application Configuration

We reused the existing Argo CD Application named `expense-tracker`.

The application was configured with the following details:

| Configuration | Value |
|---|---|
| Application name | expense-tracker |
| Namespace | argocd |
| Git repository | https://github.com/Medonati/expense-tracker-devops |
| Target revision | HEAD |
| Manifest path | kubernetes |
| Destination cluster | https://kubernetes.default.svc |
| Destination namespace | default |
| Argo CD project | default |
| Automated synchronization | Disabled |

The repository was public, so no Git repository credentials were required.

### Verify the Application

```bash
kubectl get application expense-tracker -n argocd
```

Inspect its complete configuration:

```bash
kubectl get application expense-tracker -n argocd -o yaml
```

The application was configured to monitor the `kubernetes` directory in the GitHub repository.

This means changes committed and pushed to the configured Git revision could be detected by Argo CD.

---

## 3. Argo CD Dashboard Access: Troubleshooting and Permanent Solution

One significant part of this milestone involved resolving an access problem with the Argo CD dashboard.

Our initial dashboard access depended on `kubectl port-forward`. Although functional, this required the forwarding process to remain active in a terminal.

We wanted a more persistent solution that did not depend on manually running a port-forward command.

### 3.1 Initial access using port-forward

The earlier access method was:

```bash
kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8081:443
```

The dashboard was accessible through:

```text
https://localhost:8081
```

However, the process was temporary. Closing the terminal or losing the forwarding session interrupted access.

We therefore decided to expose Argo CD through a Kubernetes NodePort.

### 3.2 Creating a dedicated NodePort service

We inspected the existing Kubernetes services and identified available ports.

Port `30080` was selected because it was unused and falls within Kubernetes' default NodePort range of `30000–32767`.

We created a separate service without modifying the original Argo CD ClusterIP service.

```bash
kubectl expose svc argocd-server \
  -n argocd \
  --name=argocd-server-nodeport \
  --type=NodePort \
  --port=443 \
  --target-port=8080 \
  --overrides='{"apiVersion":"v1","spec":{"ports":[{"port":443,"targetPort":8080,"nodePort":30080,"protocol":"TCP"}]}}'
```

Verification:

```bash
kubectl get svc -n argocd
```

The resulting service was:

```text
NAME                     TYPE       PORT(S)
argocd-server-nodeport   NodePort   443:30080/TCP
```

The original `argocd-server` ClusterIP service remained unchanged.

### 3.3 Understanding the port configuration

| Port | Purpose |
|---|---|
| 443 | HTTPS service port |
| 8080 | Argo CD server container target port |
| 30080 | Kubernetes NodePort |
| 30080 | Selected Ubuntu and Windows host forwarding port |

The NodePort was successfully created, but accessing it through Windows initially failed.

### 3.4 Configuring Vagrant port forwarding

The Vagrantfile was updated with:

```ruby
config.vm.network "forwarded_port", guest: 30080, host: 30080, host_ip: "127.0.0.1"
```

Existing forwarded ports were preserved.

We reloaded the existing Vagrant VM:

```bash
vagrant reload
```

After the restart, Minikube was verified:

```bash
minikube status
```

The output confirmed:

```text
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

We also verified that the existing Argo CD components were running.

```bash
kubectl get pods,svc -n argocd
```

### 3.5 Troubleshooting the NodePort connection

We tested the NodePort directly from Ubuntu:

```bash
curl -kI https://192.168.49.2:30080
```

Result:

```text
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
```

This confirmed that Argo CD was responding successfully through the Minikube NodePort.

However, accessing the dashboard through Windows using:

```text
https://localhost:30080
```

still failed.

Further testing showed that Ubuntu's localhost interface was not listening on port `30080`.

```bash
curl -kI https://localhost:30080
```

Result:

```text
curl: (7) Failed to connect to localhost port 30080:
Connection refused
```

The reason was the network architecture.

Minikube was running with the Docker driver. Its NodePort was accessible through the Minikube container's network address, but the port was not automatically published on the Ubuntu VM's localhost interface.

### 3.6 Inspecting Docker networking

We checked the Minikube container's published ports:

```bash
docker port minikube
```

Observed output:

```text
22/tcp    -> 127.0.0.1:32768
2376/tcp  -> 127.0.0.1:32769
5000/tcp  -> 127.0.0.1:32770
8443/tcp  -> 127.0.0.1:32771
32443/tcp -> 127.0.0.1:32772
```

Port `30080` was not published.

We then inspected the container's network mode:

```bash
docker inspect minikube --format '{{.HostConfig.NetworkMode}}'
```

Result:

```text
minikube
```

We retrieved its IP address:

```bash
docker inspect minikube --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

Result:

```text
192.168.49.2
```

This confirmed the network boundary between the Ubuntu VM and the Minikube Docker container.

Rather than recreate Minikube or risk disturbing the existing cluster, we chose to bridge the network connection at the Ubuntu VM level.

### 3.7 Installing socat

We checked whether `socat` was installed:

```bash
command -v socat
```

It was not installed.

We checked package availability:

```bash
apt-cache policy socat
```

The Ubuntu Jammy repository provided:

```text
Candidate: 1.7.4.1-3ubuntu4
```

We installed it:

```bash
sudo apt-get install -y socat
```

### 3.8 Testing the TCP bridge

We temporarily started a TCP proxy:

```bash
sudo socat TCP-LISTEN:30080,bind=0.0.0.0,reuseaddr,fork TCP:192.168.49.2:30080
```

This established the following connection:

- Listened on Ubuntu port `30080`.
- Forwarded incoming TCP connections to Minikube at `192.168.49.2:30080`.
- Allowed Vagrant to forward Windows traffic to the Ubuntu listener.

The Windows browser successfully accessed:

```text
https://localhost:30080
```

This confirmed that the TCP bridge resolved the connectivity problem.

### 3.9 Making the TCP bridge persistent with systemd

The temporary `socat` process still depended on an open terminal.

To make the solution persistent, we created a systemd service.

```bash
sudo nano /etc/systemd/system/argocd-nodeport-proxy.service
```

The service configuration:

```ini
[Unit]
Description=Argo CD NodePort TCP Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:30080,bind=0.0.0.0,reuseaddr,fork TCP:192.168.49.2:30080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

We registered and started the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now argocd-nodeport-proxy
```

We verified the service:

```bash
sudo systemctl status argocd-nodeport-proxy
```

Observed state:

```text
Active: active (running)
```

We also checked automatic startup:

```bash
sudo systemctl is-enabled argocd-nodeport-proxy
```

Result:

```text
enabled
```

Finally, we tested the dashboard again through:

```text
https://localhost:30080
```

The dashboard opened successfully without manually running `kubectl port-forward` or starting `socat` in the foreground.

### 3.10 Final dashboard network architecture

```text
Windows Browser
      |
      | https://localhost:30080
      |
Vagrant Port Forwarding
      |
      | Host 30080 -> Guest 30080
      |
Ubuntu VM
      |
      | systemd-managed socat service
      |
      | TCP proxy
      |
Minikube Docker Container
      |
      | 192.168.49.2:30080
      |
Kubernetes NodePort Service
      |
      | argocd-server-nodeport
      |
Argo CD Server
      |
Argo CD Dashboard
```

**Important operational note:**

The systemd service starts automatically with Ubuntu. However, it still depends on Minikube being operational and retaining its expected network address. If the Minikube container IP or NodePort changes, the proxy configuration may need updating.

This solution avoids a temporary Kubernetes port-forward process and preserves the existing Minikube cluster.

---

## 4. Git Change Detection Exercise

After establishing dashboard access, we proceeded with the main GitOps exercise.

The objective was to make a harmless change to a Kubernetes manifest, push it to GitHub and observe how Argo CD detected the new desired state.

### 4.1 Establishing the baseline

Before making changes, we inspected the Argo CD Application.

The baseline revision was:

```text
70c09ed20ac4bc4bbc962b43eab380bcc9c6026f
```

The application status was:

| Property | Baseline |
|---|---|
| Sync status | Synced |
| Health status | Healthy |
| Git revision | 70c09ed |
| Automated sync | Disabled |

Automated synchronization was intentionally disabled.

This was important because we wanted to observe the difference between detecting a Git change and automatically applying that change.

### 4.2 Selecting the Kubernetes manifest

We inspected the Kubernetes directory:

```bash
ls -R kubernetes/
```

The frontend Service manifest was selected:

```text
kubernetes/frontend/service.yaml
```

Original manifest:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: frontend

spec:
  selector:
    app: frontend

  ports:
    - port: 80
      targetPort: 80
```

### 4.3 Adding a harmless annotation

We added an annotation under the Service metadata:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: frontend
  annotations:
    gitops-demo: "milestone-5-change-detection"

spec:
  selector:
    app: frontend

  ports:
    - port: 80
      targetPort: 80
```

The annotation does not change the Service's traffic-routing configuration.

It provides additional metadata and allows us to demonstrate how Argo CD detects changes to a Kubernetes resource.

### 4.4 Reviewing the Git diff

We inspected the modification:

```bash
git diff -- kubernetes/frontend/service.yaml
```

The verified change was:

```diff
 metadata:
   name: frontend
+  annotations:
+    gitops-demo: "milestone-5-change-detection"
```

We also checked the working tree:

```bash
git status --short
```

The only modified file was:

```text
 M kubernetes/frontend/service.yaml
```

### 4.5 Committing and pushing

The change was staged and committed:

```bash
git add kubernetes/frontend/service.yaml

git commit -m "gitops: add annotation for change detection"
```

The commit was pushed to GitHub.

We verified the local commit:

```bash
git rev-parse --short HEAD
```

Result:

```text
1ec6dd1
```

### 4.6 Argo CD detects the new Git revision

After the push, we checked the application:

```bash
kubectl get application expense-tracker -n argocd
```

The application transitioned from:

```text
Synced
```

to:

```text
OutOfSync
```

The dashboard subsequently displayed:

```text
OutOfSync from HEAD (1ec6dd1)
```

This confirmed that Argo CD had detected the new Git revision.

We also noticed that the dashboard did not display the updated status immediately. Running the Kubernetes Application status command showed the updated state.

The important distinction is that the command queried the current Application status; it did not itself cause Git synchronization.

Argo CD's application controller monitors the repository and compares the desired configuration with the live cluster state. The dashboard displays the resulting application status, which may not appear immediately in the browser.

### 4.7 Inspecting the resource difference

We opened the frontend Service resource in the Argo CD dashboard and inspected the DIFF tab.

Argo CD compared:

**Live state:** The existing Kubernetes Service did not contain our custom annotation.

**Desired state:** The Git repository contained:

```yaml
annotations:
  gitops-demo: "milestone-5-change-detection"
```

The dashboard showed the annotation as an addition to the desired configuration.

The resource counts showed:

| Status | Resources |
|---|---:|
| Synced | 8 |
| OutOfSync | 1 |

Only the frontend Service was OutOfSync.

This demonstrated that Argo CD could identify a specific resource-level difference rather than treating the entire application as unavailable.

### 4.8 Understanding OutOfSync versus Healthy

At this point, the application showed:

| Property | State |
|---|---|
| Sync status | OutOfSync |
| Health status | Healthy |
| Automated synchronization | Disabled |

This distinction is important.

**OutOfSync does not mean the application is unhealthy.**

It means that the desired configuration in Git differs from the live configuration in Kubernetes.

The application continued running because we had not yet applied the new annotation.

---

## 5. Manual Synchronization and Reconciliation

After observing the difference, we proceeded with manual synchronization.

Automated synchronization remained disabled throughout the exercise.

### 5.1 Initiating manual synchronization

From the Argo CD dashboard, we selected the `expense-tracker` application and initiated the SYNC operation.

The synchronization was performed manually.

We did not enable pruning, force, or replace.

Argo CD applied the desired configuration from Git to Kubernetes.

### 5.2 Verifying the synchronization result

After synchronization, the dashboard showed:

| Property | Result |
|---|---|
| Application health | Healthy |
| Sync status | Synced |
| Git revision | 1ec6dd1 |
| Synced resources | 9 |
| OutOfSync resources | 0 |
| Automated synchronization | Disabled |

The application had successfully returned to a synchronized state.

### 5.3 Verifying the live Kubernetes resource

We then checked the actual Kubernetes Service:

```bash
kubectl get service frontend -n default -o yaml
```

Under `metadata.annotations`, we observed:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: expense-tracker:/Service:default/frontend
    gitops-demo: milestone-5-change-detection
```

This confirmed that the annotation had been applied to the live Kubernetes resource.

The two annotations serve different purposes:

**Argo CD tracking annotation**

```yaml
argocd.argoproj.io/tracking-id: expense-tracker:/Service:default/frontend
```

This is maintained by Argo CD to associate the resource with its Application.

**Custom demonstration annotation**

```yaml
gitops-demo: milestone-5-change-detection
```

This was our own annotation, introduced through Git and applied through manual synchronization.

---

## 6. Final Validation

We performed a final Application status check:

```bash
kubectl get application expense-tracker -n argocd
```

Observed result:

```text
NAME              SYNC STATUS   HEALTH STATUS
expense-tracker   Synced        Healthy
```

We also verified the proxy service:

```bash
sudo systemctl is-enabled argocd-nodeport-proxy
```

Result:

```text
enabled
```

And its running state:

```bash
sudo systemctl status argocd-nodeport-proxy
```

Result:

```text
Active: active (running)
```

The Argo CD dashboard remained accessible at:

```text
https://localhost:30080
```

without manually running a port-forward process.

---

## 7. Key GitOps Concepts Learned

### Git as the source of truth

The Kubernetes manifests stored in Git represent the desired configuration for the application.

Changes should be made through the repository and delivered through Git commits.

### Desired state versus live state

- Desired state: What the Git repository declares should exist.
- Live state: What currently exists in the Kubernetes cluster.

Argo CD compares these states to identify differences.

### OutOfSync

An application becomes OutOfSync when its desired configuration differs from its live configuration.

This does not automatically mean the application is unhealthy.

### Reconciliation

Reconciliation is the process of bringing the live Kubernetes environment into alignment with the desired configuration.

In this exercise, reconciliation was triggered through manual synchronization.

### Automated versus manual synchronization

Manual synchronization requires an operator to initiate the sync operation.

Automated synchronization allows Argo CD to apply detected changes automatically, subject to its configuration and synchronization policies.

We deliberately kept automated synchronization disabled so that we could observe change detection independently of applying the change.

### Continuous monitoring

Argo CD continuously monitors the configured Git repository and evaluates whether the live cluster matches the desired state.

A Git change can therefore be detected even when no synchronization has taken place.

---

## 8. Important Commands Reference

### Minikube and Kubernetes

```bash
minikube status

kubectl get pods,svc -n argocd

kubectl get application expense-tracker -n argocd

kubectl get application expense-tracker -n argocd -o yaml

kubectl get service frontend -n default -o yaml
```

### NodePort and networking

```bash
kubectl get svc -n argocd

curl -kI https://192.168.49.2:30080

docker port minikube

docker inspect minikube --format '{{.HostConfig.NetworkMode}}'

docker inspect minikube --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

vagrant port

vagrant reload
```

### socat and systemd

```bash
sudo apt-get install -y socat

sudo systemctl daemon-reload

sudo systemctl enable --now argocd-nodeport-proxy

sudo systemctl status argocd-nodeport-proxy

sudo systemctl is-enabled argocd-nodeport-proxy
```

### Git operations

```bash
git diff -- kubernetes/frontend/service.yaml

git status --short

git add kubernetes/frontend/service.yaml

git commit -m "gitops: add annotation for change detection"

git push

git rev-parse --short HEAD
```

---


## 9. Milestone Outcome

The milestone successfully demonstrated the connection between Git and Kubernetes through Argo CD.

We established persistent dashboard access without relying on a temporary Kubernetes port-forward, connected the existing Application to GitHub, introduced a harmless Kubernetes manifest change, observed Argo CD detect the new revision, inspected the difference between desired and live state, and performed manual reconciliation.

The final validation confirmed:

- Argo CD Application: `expense-tracker`
- Git revision: `1ec6dd1`
- Sync status: `Synced`
- Health status: `Healthy`
- Automated synchronization: Disabled
- Live frontend Service annotation: Verified
- Dashboard access: Working through `https://localhost:30080`
- TCP proxy: Active and enabled

**Milestone 5 practical implementation is complete.**

The documentation and evidence are now ready for review. The milestone should only be formally closed after the documentation has been reviewed, saved, committed and pushed according to the established repository workflow.

---

## 10. Lessons Learned

1. A GitOps controller can detect a configuration change without immediately applying it.
2. OutOfSync and Healthy describe different aspects of an application.
3. Desired state and live state must be understood separately.
4. Manual synchronization provides control over when Git changes are applied.
5. Kubernetes networking and Docker networking are separate layers that must be understood when exposing services.
6. A NodePort does not automatically guarantee that the port is published through every underlying network boundary.
7. Systemd can manage long-running infrastructure processes and configure them for automatic startup.
8. Troubleshooting should preserve existing infrastructure and avoid unnecessary cluster recreation.

**End of Milestone 5 Documentation.**