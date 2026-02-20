# CKA Complete Study Guide — Kubernetes v1.34 (2026 Exam)
> Based on: *Kubernetes Course – Certified Kubernetes Administrator Exam Preparation (2026 Update)*

---

## Table of Contents
1. [Course & Exam Overview](#1-course--exam-overview)
2. [Kubernetes Architecture](#2-kubernetes-architecture)
3. [Core Kubernetes Objects](#3-core-kubernetes-objects)
4. [Cluster Setup — Single Node](#4-cluster-setup--single-node)
5. [Cluster Setup — Multi-Node (Production)](#5-cluster-setup--multi-node-production)
6. [Cluster Lifecycle — Upgrades & Backups](#6-cluster-lifecycle--upgrades--backups)
7. [High Availability Control Plane](#7-high-availability-control-plane)
8. [RBAC — Role-Based Access Control](#8-rbac--role-based-access-control)
9. [Application Management — Helm & Kustomize](#9-application-management--helm--kustomize)
10. [Kubernetes Extensibility](#10-kubernetes-extensibility)
11. [Workloads & Scheduling](#11-workloads--scheduling)
12. [Networking](#12-networking)
13. [Storage](#13-storage)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Course & Exam Overview

### Objective
Understand the CKA exam format, scoring weights, and mindset required to pass.

### CKA Exam Facts
- **Format:** Online proctored, 100% hands-on CLI tasks
- **Duration:** 2 hours
- **Environment:** Remote Ubuntu desktop (browser-based), Kubernetes v1.34
- **Allowed resources:** One tab for the exam + one tab for `kubernetes.io/docs`
- **No memorization:** Docs are accessible; speed and accuracy are tested

### Exam Curriculum Weights
| Domain | Weight |
|--------|--------|
| Troubleshooting | **30%** |
| Cluster Architecture, Installation & Configuration | **25%** |
| Services & Networking | **20%** |
| Workloads & Scheduling | **15%** |
| Storage | **10%** |

> **Why this matters:** Troubleshooting (30%) + Cluster Architecture (25%) = **55% of your score**. Prioritize these.

### The Declarative Model (Core Principle)
- **Imperative:** "Run this container NOW" — one-off commands
- **Declarative:** "Here is my desired state" — written in YAML manifests
- Kubernetes **control loops** continuously compare actual state vs. desired state and reconcile differences
- A CKA must think declaratively and be fluent in YAML

### Exam Day Tips

**Terminal Shortcuts (browser-based desktop):**
- Copy: `Ctrl+Shift+C`
- Paste: `Ctrl+Shift+V`
- ⚠️ NEVER press `Ctrl+W` — it closes your browser tab
- Cursor movement: `Alt+B` (back one word), `Alt+F` (forward one word)

**Node Hopping Rule:**
- Most tasks require SSH-ing into a specific node
- Always verify your prompt to know which node you're on
- After SSH, immediately run `sudo -i` to get root access

**Speed Tips:**
- Never write YAML from scratch — generate base manifests with dry-run:
  ```bash
  kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml
  ```
- Configure Vim for YAML editing (set in `~/.vimrc`):
  ```
  set tabstop=2 shiftwidth=2 expandtab
  ```
- Navigate docs by search bar, not bookmarks (environment may not have your bookmarks)

---

## 2. Kubernetes Architecture

### Objective
Understand all components in a Kubernetes cluster, their roles, and how they communicate.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                   CONTROL PLANE                      │
│  ┌─────────────┐  ┌──────┐  ┌──────────┐  ┌──────┐ │
│  │ kube-apiserver│  │ etcd │  │ scheduler│  │ ctrl │ │
│  │ (front door) │  │ (DB) │  │(matchmaker│  │ mgr  │ │
│  └──────┬──────┘  └──────┘  └──────────┘  └──────┘ │
│         │  All components talk through API server    │
└─────────┼───────────────────────────────────────────┘
          │  (network)
┌─────────┼───────────────────────────────────────────┐
│         │         WORKER NODE(S)                     │
│  ┌──────┴───┐  ┌────────────┐  ┌──────────────────┐ │
│  │  kubelet │  │ kube-proxy │  │ Container Runtime│ │
│  │(node agent│  │(networking)│  │(containerd/cri-o)│ │
│  └──────────┘  └────────────┘  └──────────────────┘ │
│         │                                            │
│  [Pod][Pod][Pod] ← Actual workloads run here         │
└─────────────────────────────────────────────────────┘
```

### Control Plane Components

#### kube-apiserver
- **Role:** Central hub, front-end of the control plane
- **All communication** to/from the cluster goes through it
- Validates and processes API requests
- Coordinates all control plane ↔ worker node processes
- **Think of it as:** The receptionist of the cluster

#### etcd
- **Role:** Cluster's single source of truth
- Distributed key-value store
- Stores ALL cluster data: config, state, metadata
- ⚠️ Direct access to etcd is **restricted** — only go through kube-apiserver
- **Think of it as:** The database/brain memory

#### kube-scheduler
- **Role:** Assigns pods to nodes
- Watches for newly created pods with no assigned node
- Picks the best node based on: resource requirements, hardware constraints, affinity/anti-affinity rules, data locality
- **Think of it as:** The matchmaker

#### kube-controller-manager
- **Role:** Autopilot — runs control loop processes
- Contains: Node Controller (handles failures), Replication Controller (maintains pod count), and many others
- Each controller watches cluster state via API server and acts to match desired state
- **Think of it as:** The autopilot

### Worker Node Components

#### kubelet
- **Role:** Primary agent on each worker node
- Communicates with API server to receive pod specs
- Manages lifecycle of containers on its node
- Reports node and container health back to control plane

#### kube-proxy
- **Role:** Network proxy on each node
- Maintains network rules enabling pod-to-pod and external communication
- Implements the Service concept — routes traffic to correct backend pods

#### Container Runtime
- **Role:** Actually runs the containers
- Kubernetes supports: `containerd`, `CRI-O` (Docker is no longer used directly)
- kubelet talks to runtime via **CRI** (Container Runtime Interface)

---

## 3. Core Kubernetes Objects

### Pods
- **Smallest deployable unit** in Kubernetes
- Encapsulates one or more tightly coupled containers
- Containers in a pod share: network IP, storage volumes, run options
- Most common pattern: **one container per pod**
- Pods are **ephemeral** — they can be killed and replaced

### ReplicaSets & Deployments
- **ReplicaSet:** Maintains a stable set of replica pods — guarantees N identical pods are running
- **Deployment:** Higher-level object that manages ReplicaSets
  - Provides declarative updates to pods
  - Handles rolling updates and rollbacks
  - ✅ **Always use Deployments for stateless apps** (never raw ReplicaSets)

### Services
- Pods are ephemeral and have changing IPs
- Service provides a **stable virtual IP (ClusterIP)** and DNS name
- Automatically **load-balances** traffic to matching backend pods
- Uses **selectors** to find backend pods (by labels)

### Namespaces
- Mechanism to **isolate resources** within a cluster
- Resource names must be unique within a namespace, but not across namespaces
- Common use: separate teams, environments (dev/staging/prod)

---

## 4. Cluster Setup — Single Node

### Objective
Install all prerequisites and bootstrap a functional single-node Kubernetes cluster using kubeadm.

### Setup Flow

```
[All Nodes] Load kernel modules
     ↓
[All Nodes] Configure sysctl (IP tables)
     ↓
[All Nodes] Install containerd (container runtime)
     ↓
[All Nodes] Configure containerd (systemd cgroup)
     ↓
[All Nodes] Disable swap
     ↓
[All Nodes] Install kubeadm + kubelet + kubectl
     ↓
[Control Plane] kubeadm init
     ↓
[Control Plane] Configure kubectl
     ↓
[Control Plane] Remove control-plane taint (single-node only)
     ↓
[Control Plane] Install CNI plugin (Flannel)
     ↓
[Verify] kubectl get nodes + pods
```

---

### Step 1: Load Kernel Modules

**Why:** Kubernetes networking requires the kernel to see bridge traffic.

```bash
# Create persistent config file — modules loaded on every boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Activate immediately without reboot
sudo modprobe overlay
sudo modprobe br_netfilter
```

**Module explanations:**
- `overlay` — Storage driver used by containerd; allows containers to share read-only base image layers with a writable layer on top (fast, space-efficient)
- `br_netfilter` — Enables kernel to process network packets coming from a bridged network (required for kube-proxy and CNI)

---

### Step 2: Configure sysctl for Networking

**Why:** Ensures iptables correctly processes bridge traffic — critical for kube-proxy and CNI.

```bash
# Create persistent sysctl config
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply immediately
sudo sysctl --system
```

---

### Step 3: Install containerd

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

---

### Step 4: Configure containerd

**Why:** kubelet and container runtime MUST use the same **cgroup driver**. Mismatch = cluster instability.

```bash
# Generate default config
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Change SystemdCgroup to true (match kubelet)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable
sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

### Step 5: Install Kubernetes Binaries

```bash
# Disable swap — kubelet requires this for predictable resource management
sudo swapoff -a
# Make persistent (comment out swap line in /etc/fstab)
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install prerequisites
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Create directory for signing key
sudo mkdir -p /etc/apt/keyrings

# Add Kubernetes signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Pin versions to prevent accidental upgrades
sudo apt-mark hold kubelet kubeadm kubectl
```

> **Why `apt-mark hold`?** Prevents accidental upgrades that could break cluster stability. Cluster upgrades must be done deliberately and in order.

---

### Step 6: Initialize Control Plane (Single Node)

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

- `--pod-network-cidr` — Required by most CNI plugins; specifies IP range for pod networking

---

### Step 7: Configure kubectl

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Why:** After this, the current non-root user can run `kubectl` commands without `sudo`.

---

### Step 8: Remove Control-Plane Taint (Single-node only)

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**Why:** By default, the control plane node is tainted to prevent workload pods from running on it. For a single-node cluster, this taint must be removed.

---

### Step 9: Install CNI Plugin (Flannel)

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

**Why CNI is required:** Without a CNI plugin, pods cannot communicate with each other and CoreDNS will not start.

---

### Step 10: Verify

```bash
kubectl get nodes             # Should show: Ready
kubectl get pods -n kube-system  # All pods should be Running
```

---

## 5. Cluster Setup — Multi-Node (Production)

### Objective
Build a production-style multi-node cluster with separate control plane and worker nodes.

### Architecture

```
┌──────────────────┐         ┌──────────────────┐
│  CONTROL PLANE   │ ←──── → │   WORKER NODE    │
│  (manages)       │ network  │   (runs workloads│
│  kubeadm init    │         │   kubeadm join   │
└──────────────────┘         └──────────────────┘
```

### Prerequisites (ALL nodes)
- Unique hostnames, MAC addresses, and product UUIDs
- Swap disabled
- Kernel modules configured
- containerd installed and configured with `SystemdCgroup = true`
- kubeadm, kubelet, kubectl installed and held

### Step 1: Initialize Control Plane

```bash
# Get the control plane node's IP
ip addr show  # note the private IP

sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<CONTROL_PLANE_IP>
```

- `--pod-network-cidr=192.168.0.0/16` — Default CIDR for Calico CNI
- `--apiserver-advertise-address` — Private IP of this node; worker nodes use this to connect

> ⚠️ **SAVE the `kubeadm join` command** from the output — needed to add worker nodes.

### Step 2: Install Calico CNI (Control Plane)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

**Why Calico?** Calico supports network policies, which appear in CKA tasks. Calico = networking + firewall.

### Step 3: Verify Control Plane

```bash
kubectl get pods -n kube-system    # All Running
kubectl get nodes                   # Status: Ready
```

### Step 4: Join Worker Node (run on WORKER)

```bash
sudo kubeadm join <CONTROL_PLANE_IP>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

This command was output from `kubeadm init` — paste and run with `sudo`.

### Step 5: Verify from Control Plane

```bash
kubectl get nodes -o wide    # See both nodes + their IPs
```

---

## 6. Cluster Lifecycle — Upgrades & Backups

### Objective
Upgrade a cluster safely (control plane first, then workers) and backup/restore etcd.

### Upgrade Order
```
Control Plane → Worker 1 → Worker 2 → ...
(never upgrade workers before control plane)
```

### Upgrade Control Plane

```bash
# 1. Unhold kubeadm
sudo apt-mark unhold kubeadm

# 2. Install target version
sudo apt-get install -y kubeadm=1.X.Y-*

# 3. Re-hold
sudo apt-mark hold kubeadm

# 4. Check upgrade plan
sudo kubeadm upgrade plan

# 5. Apply upgrade (upgrades static pod manifests for API server, etcd, etc.)
sudo kubeadm upgrade apply v1.X.Y

# 6. Upgrade kubelet and kubectl on same node
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.X.Y-* kubectl=1.X.Y-*
sudo apt-mark hold kubelet kubectl

# 7. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Upgrade Worker Nodes

> First step runs on the **control plane** — drain the worker node first.

```bash
# On CONTROL PLANE: drain worker (evicts all pods)
kubectl drain <worker-node-name> --ignore-daemonsets
```

```bash
# On WORKER NODE: upgrade binaries
sudo apt-mark unhold kubeadm kubelet
sudo apt-get install -y kubeadm=1.X.Y-* kubelet=1.X.Y-*
sudo apt-mark hold kubeadm kubelet

# Update local kubelet config
sudo kubeadm upgrade node

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

```bash
# On CONTROL PLANE: uncordon worker (allow pods again)
kubectl uncordon <worker-node-name>
```

---

### Backing Up etcd

**Why:** etcd stores ALL cluster state. If lost, the cluster cannot be recovered without a backup.

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

- `snapshot save` — Creates a point-in-time backup
- TLS certificates are required because etcd restricts access
- Output: a `.db` snapshot file

### Restoring etcd

> ⚠️ **Destructive operation** — replaces all cluster state.

```bash
# 1. Stop kubelet to prevent interference
sudo systemctl stop kubelet

# 2. Restore snapshot to new directory
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# 3. Edit etcd static pod manifest to point to new data dir
sudo nano /etc/kubernetes/manifests/etcd.yaml
# Find the hostPath for etcd data and change path to: /var/lib/etcd-restored

# 4. Restart kubelet
sudo systemctl start kubelet
```

**Why edit the manifest?** etcd runs as a static pod managed by kubelet. Changing the manifest triggers kubelet to restart the etcd pod with the new data directory.

---

## 7. High Availability Control Plane

### Objective
Eliminate single points of failure by running multiple control plane nodes.

### Two HA Topologies

| Topology | Description | When to Use |
|----------|-------------|-------------|
| **Stacked etcd** | etcd runs on same nodes as control plane | Simpler, common in CKA tasks |
| **External etcd** | etcd on separate dedicated nodes | Production with strict isolation |

### HA Architecture (Stacked)

```
                    ┌──────────────┐
                    │  Load Balancer│  ← stable IP for all nodes
                    └──────┬───────┘
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌───────────┐ ┌───────────┐ ┌───────────┐
     │ CP Node 1 │ │ CP Node 2 │ │ CP Node 3 │
     │ API+etcd  │ │ API+etcd  │ │ API+etcd  │
     └───────────┘ └───────────┘ └───────────┘
              │            │            │
         ┌────┴────────────┴────────────┴────┐
         │           Worker Nodes            │
         └───────────────────────────────────┘
```

### Load Balancer Setup
- Provision a load balancer in front of all control plane nodes
- Configure TCP forwarding on port `6443` to all control plane node IPs
- Health check: TCP on port `6443`

### Initialize First Control Plane Node

```bash
sudo kubeadm init \
  --control-plane-endpoint="<LOAD_BALANCER_IP>:6443" \
  --upload-certs \
  --apiserver-advertise-address=<THIS_NODE_IP> \
  --pod-network-cidr=192.168.0.0/16
```

- `--control-plane-endpoint` — Load balancer IP:port; all nodes use this as the API endpoint
- `--upload-certs` — Securely shares cluster certificates with other control plane nodes joining later

> Output provides two join commands:
> - One for **additional control plane nodes**
> - One for **worker nodes** (same as before but now points to load balancer)

---

## 8. RBAC — Role-Based Access Control

### Objective
Control who can do what inside the cluster using least-privilege principles.

### RBAC Building Blocks

```
Who?             What permissions?    Where?
(Subject)  ──→   (Role/ClusterRole)  ──→ (Namespace/Cluster)
    ↑                                           ↑
RoleBinding / ClusterRoleBinding connects them
```

| Object | Scope | Purpose |
|--------|-------|---------|
| **Role** | Namespaced | Permissions within one namespace |
| **ClusterRole** | Cluster-wide | Permissions across all namespaces or cluster-scoped resources |
| **RoleBinding** | Namespaced | Binds a Role to subjects in one namespace |
| **ClusterRoleBinding** | Cluster-wide | Binds a ClusterRole to subjects across the whole cluster |

**Subjects** = Users, Groups, or ServiceAccounts

### Hands-on: Least-Privilege ServiceAccount

#### Step 1: Create Namespace

```bash
kubectl create namespace rbac-test
```

#### Step 2: Create ServiceAccount

```bash
kubectl create serviceaccount dev-user -n rbac-test
```

**Why ServiceAccount?** In Kubernetes, you don't give permissions to pods directly — you give them to a ServiceAccount, then tell the pod to use that account.

#### Step 3: Create Role (define permissions)

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-test
  name: pod-reader
rules:
- apiGroups: [""]          # "" = core API group (pods, services, etc.)
  resources: ["pods"]      # Only affects pods
  verbs: ["get", "list", "watch"]   # Read-only — no create/delete/update
```

```bash
kubectl apply -f role.yaml
```

**Verbs explained:**
- `get` — read a single pod
- `list` — list all pods
- `watch` — watch for changes
- NOT included: `create`, `delete`, `update`, `patch`

#### Step 4: Create RoleBinding (connect user + role)

```yaml
# rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: rbac-test
subjects:
- kind: ServiceAccount
  name: dev-user             # The identity we created
  namespace: rbac-test
roleRef:
  kind: Role
  name: pod-reader           # The permissions we defined
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f rolebinding.yaml
```

#### Step 5: Verify Permissions

```bash
# Can dev-user list pods? → YES
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-test:dev-user \
  -n rbac-test

# Can dev-user delete pods? → NO
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-test:dev-user \
  -n rbac-test
```

> `kubectl auth can-i` — most powerful RBAC testing command. Use it to verify any policy.

---

## 9. Application Management — Helm & Kustomize

### Objective
Manage complex Kubernetes applications efficiently using package managers and overlay tools.

### Comparison: Helm vs Kustomize

| Feature | Helm | Kustomize |
|---------|------|-----------|
| Approach | Templating (Go templates) | Patch/overlay (no templates) |
| Complexity | Higher (learning curve) | Lower (just YAML) |
| Packaging | Charts (reusable packages) | Base + overlays |
| Built into kubectl | No | Yes (`kubectl apply -k`) |
| Best for | Installing 3rd-party apps | Environment-specific configs |

### Helm

**Key concepts:**
- **Chart** — A package of Kubernetes manifests + default config
- **Values** — Configurable parameters in `values.yaml`, overridable at install time
- **Release** — A running instance of a chart in the cluster

#### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

#### Use Helm

```bash
# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Fetch latest chart list
helm repo update

# Install a chart (creates a Release named "my-nginx")
helm install my-nginx bitnami/nginx --set service.type=NodePort

# Lifecycle management
helm upgrade my-nginx bitnami/nginx --set replicaCount=3
helm rollback my-nginx 1
helm uninstall my-nginx
```

- `--set key=value` — Override default values from values.yaml at install time

---

### Kustomize

**Key concepts:**
- **Base** — Standard, environment-agnostic YAML files
- **Overlay** — Patches that customize the base for a specific environment
- **kustomization.yaml** — Required config file in each directory

#### Setup: Base Configuration

```bash
mkdir -p my-app/base
```

```yaml
# my-app/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: nginx
        image: nginx
```

```yaml
# my-app/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
```

#### Setup: Production Overlay

```bash
mkdir -p my-app/overlays/production
```

```yaml
# my-app/overlays/production/patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3     # Override: 1 → 3 for production
```

```yaml
# my-app/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
patches:
- path: patch.yaml
```

#### Deploy Production Configuration

```bash
kubectl apply -k my-app/overlays/production
```

- `-k` flag — Tells kubectl to process Kustomize directory
- Reads base, applies production patch, sends merged result to API server

**Power:** Base files never change. Each environment only defines its differences.

---

## 10. Kubernetes Extensibility

### Objective
Understand how Kubernetes is extended via standard interfaces and custom resources.

### Key Interfaces

| Interface | Full Name | Purpose |
|-----------|-----------|---------|
| **CRI** | Container Runtime Interface | Allows kubelet to use different container runtimes (containerd, CRI-O) |
| **CNI** | Container Network Interface | Allows different networking solutions (Calico, Flannel, Cilium) |
| **CSI** | Container Storage Interface | Allows 3rd-party storage providers to integrate with K8s |

**Why interfaces matter:** They allow pluggable implementations without changing Kubernetes core code.

### CRDs and Operators

- **CRD (Custom Resource Definition)** — Extends the K8s API with your own resource types
  - Example: Define a `Database` CRD → then run `kubectl get databases`
  - Interact with it just like built-in resources

- **Operator** — A custom controller that uses a CRD to automate complex operational tasks
  - Follows the Kubernetes control loop pattern
  - Example: A database operator automates backups, failovers, and upgrades

```
CRD = defines new resource type
Operator = watches that resource and acts on it (control loop)
```

---

## 11. Workloads & Scheduling

### Objective
Manage application lifecycle, inject config, auto-scale, set health probes, and control pod placement.

---

### Rolling Updates & Rollbacks

#### Rolling Update Strategy
- **Default strategy** for Deployments
- Replaces pods incrementally — no downtime
- Controlled by two parameters:

| Parameter | Meaning |
|-----------|---------|
| `maxUnavailable` | Max pods that can be down during update |
| `maxSurge` | Max extra pods created above desired replica count |

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.24.0
```

```bash
kubectl apply -f deployment.yaml
```

#### Trigger a Rolling Update

```bash
# Update container image (triggers rolling update)
kubectl set image deployment/nginx-deployment nginx=nginx:1.25.0

# Watch rollout progress (live)
kubectl rollout status deployment/nginx-deployment

# Watch individual pods change (live)
kubectl get pods -l app=nginx -w
```

#### Rollback

```bash
# View revision history
kubectl rollout history deployment/nginx-deployment

# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=1
```

---

### ConfigMaps & Secrets

**Why decouple config from code?** Changing config should not require rebuilding the container image.

| Object | For | Encoding |
|--------|-----|----------|
| ConfigMap | Non-sensitive data | Plain text |
| Secret | Sensitive data | Base64 (not encryption!) |

> ⚠️ Base64 is NOT encryption. Real secret security requires: etcd encryption at rest + RBAC to restrict access.

#### ConfigMap — All Creation Methods

```bash
# Imperative: from literals
kubectl create configmap app-config \
  --from-literal=app.color=blue \
  --from-literal=app.mode=production

# Imperative: from file
echo "retries=3" > config.properties
kubectl create configmap app-config --from-file=config.properties
```

```yaml
# Declarative: configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "mysql://db:3306"
  ui.theme: "dark"
```

```bash
kubectl apply -f configmap.yaml
```

#### Secret — All Creation Methods

```bash
# Imperative (K8s auto base64-encodes the values)
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=S3cR3T
```

```yaml
# Declarative: secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:        # Use stringData for plain text — K8s encodes it automatically
  username: admin
  password: S3cR3T
```

#### Using ConfigMap and Secret in Pods

**Method 1: Environment Variables**

```yaml
# pod-config.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-demo-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Theme=$THEME Password=$DB_PASSWORD"]
    env:
    - name: THEME
      valueFrom:
        configMapKeyRef:
          name: app-config     # ConfigMap name
          key: ui.theme        # Key inside ConfigMap
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials  # Secret name
          key: password          # Key inside Secret
```

**Method 2: Volume Mount**

```yaml
# pod-vol.yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo-pod
spec:
  volumes:
  - name: config-volume
    configMap:
      name: app-config       # Each key becomes a file in the mounted dir
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "cat /config/retries"]
    volumeMounts:
    - name: config-volume
      mountPath: /config     # ConfigMap keys appear as files here
```

---

### Horizontal Pod Autoscaler (HPA)

**What it does:** Automatically scales the number of pods based on resource utilization.

#### Architecture

```
[Metric Server] → collects CPU/memory from kubelet
      ↓
[HPA Controller] → queries metrics, compares to target
      ↓
[Deployment] → adjusts replica count up/down
```

#### Install Metric Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

If you get TLS errors (common in self-hosted clusters):
```bash
kubectl edit deployment metrics-server -n kube-system
# Add under args:
# - --kubelet-insecure-tls
```

Verify:
```bash
kubectl top nodes
kubectl top pods -A
```

#### Create HPA

**⚠️ Critical prerequisite:** Target pods MUST have `resources.requests.cpu` defined. Without it, HPA cannot calculate utilization percentage.

```yaml
# hpa-demo-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        resources:
          requests:
            cpu: "200m"      # REQUIRED for HPA — HPA measures % of this value
```

```bash
kubectl apply -f hpa-demo-deployment.yaml
kubectl expose deployment php-apache --port=80 --name=php-apache
```

```bash
# Create HPA
kubectl autoscale deployment php-apache \
  --cpu-percent=50 \   # Target: keep avg CPU at 50% of request
  --min=1 \            # Never go below 1 pod
  --max=10             # Never exceed 10 pods (protects against runaway scaling)
```

Monitor HPA:
```bash
kubectl get hpa -w    # -w = live watch
```

---

### Health Probes

| Probe | Purpose | On Failure |
|-------|---------|-----------|
| **Readiness** | Is the app ready to serve traffic? | Removed from Service endpoints |
| **Liveness** | Is the app still running correctly? | Container is killed and restarted |
| **Startup** | Has the app finished starting? | Disables readiness+liveness until success (protects slow starts) |

```yaml
# pod-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-demo
spec:
  containers:
  - name: app
    image: nginx
    readinessProbe:
      httpGet:
        path: /          # Sends HTTP GET to this path
        port: 80
      initialDelaySeconds: 5   # Wait 5s after start before first check
      periodSeconds: 10         # Check every 10s
    livenessProbe:
      tcpSocket:
        port: 80          # Just tries to open a TCP connection
      initialDelaySeconds: 15
      periodSeconds: 20
```

---

### Resource Requests & Limits

| Setting | Description | Effect if Exceeded |
|---------|-------------|-------------------|
| `requests.cpu` | Guaranteed CPU for scheduling | — |
| `requests.memory` | Guaranteed memory for scheduling | — |
| `limits.cpu` | Max CPU allowed | Throttled |
| `limits.memory` | Max memory allowed | OOMKilled (killed) |

```yaml
resources:
  requests:
    cpu: "200m"       # 0.2 CPU cores guaranteed
    memory: "64Mi"    # 64 MB guaranteed
  limits:
    cpu: "500m"       # Max 0.5 CPU cores
    memory: "128Mi"   # Max 128 MB — exceed this → OOMKilled
```

> **Causal chain to understand:**
> - No requests → HPA won't work
> - Requests too high → Pod stuck in `Pending` (no node has enough free resources)
> - Limits too low → App killed under load (`OOMKilled`)

---

### Node Affinity

**Purpose:** Attract pods to specific nodes based on node labels.

```bash
# Label a node
kubectl label node ks-worker disk-type=ssd
```

```yaml
# affinity-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ssd-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # HARD requirement
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk-type
            operator: In
            values:
            - ssd        # Pod MUST go to a node with disk-type=ssd
  containers:
  - name: app
    image: nginx
```

| Affinity Type | Behavior |
|--------------|---------|
| `requiredDuringScheduling...` | Hard — scheduler ONLY places pod on matching node |
| `preferredDuringScheduling...` | Soft — scheduler TRIES matching node, but schedules elsewhere if none found |

---

### Taints & Tolerations

**Taints** are applied to **nodes** — they repel pods. **Tolerations** are applied to **pods** — they bypass taints.

```
Node taint = "No trespassing" sign
Pod toleration = "I have a permit to enter"
```

#### Taint Effects

| Effect | Behavior |
|--------|---------|
| `NoSchedule` | New pods without toleration will NOT be scheduled here |
| `PreferNoSchedule` | Scheduler tries to avoid placing pods here |
| `NoExecute` | New pods blocked AND existing pods without toleration are evicted |

```bash
# Taint a node (reserve it for GPU workloads)
kubectl taint nodes ks-worker dedicated=gpu:NoSchedule

# Remove a taint
kubectl taint nodes ks-worker dedicated=gpu:NoSchedule-
```

```yaml
# toleration-pod.yaml — pod that CAN run on GPU node
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"    # Must match the taint's effect
  containers:
  - name: app
    image: nginx
```

---

## 12. Networking

### Objective
Understand pod networking, Services (all types), Ingress, Gateway API, Network Policies, and CoreDNS.

### Kubernetes Networking Model
- Every pod gets a **unique IP address**
- All pods can communicate with all other pods **without NAT**
- This flat network is implemented by the **CNI plugin** (Calico, Flannel, etc.)
- Problem: Pod IPs change when pods restart → use **Services** for stable access

---

### Service Types

```
ClusterIP (internal only)
    ↑
NodePort (external via node IP:port)
    ↑
LoadBalancer (external via cloud load balancer)
    ↑
Ingress / Gateway API (L7 HTTP routing)
```

#### ClusterIP (Default)

- Internal only — accessible within the cluster
- Provides stable virtual IP + DNS name
- Standard for microservice-to-microservice communication

```yaml
# cluster-ip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: ClusterIP         # Default (can omit this line)
  selector:
    app: my-app           # Routes traffic to pods with this label
  ports:
  - port: 80              # Service port
    targetPort: 80        # Pod port
```

```bash
kubectl apply -f cluster-ip-service.yaml

# Test from inside the cluster
kubectl run tmp --image=busybox --rm -it -- wget my-app-service
```

#### NodePort

- Exposes app on a static port on every node's IP
- Accessible from outside the cluster
- Auto-creates a ClusterIP service underneath

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nodeport
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080      # Port on each node (range: 30000-32767), optional (K8s assigns if omitted)
```

```bash
# Access from outside: <NodeIP>:<NodePort>
curl http://192.168.1.161:30080
```

#### LoadBalancer
- Provisions a cloud load balancer (GKE, AWS, Azure)
- Auto-creates NodePort + ClusterIP underneath
- Each service gets its own load balancer (can be costly for many services)

---

### Ingress

**Problem LoadBalancer solves vs. what Ingress solves:**
- LoadBalancer: 1 service = 1 external IP (expensive)
- Ingress: Many services = 1 external IP, with L7 (HTTP path-based) routing

**Components:**
- **Ingress resource** — Defines routing rules (YAML manifest)
- **Ingress controller** — The actual proxy that implements the rules (e.g., nginx-ingress-controller)

```
Client → Ingress Controller → /app1 → Service A
                            → /app2 → Service B
```

#### Install nginx Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
```

#### Deploy Two Apps

```bash
kubectl create deployment app1 --image=ealen/echo-server
kubectl expose deployment app1 --port=80

kubectl create deployment app2 --image=ealen/echo-server
kubectl expose deployment app2 --port=80
```

#### Create Ingress Resource

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
```

```bash
kubectl apply -f ingress.yaml

# Test
curl http://<NodeIP>:<IngressNodePort>/app1
curl http://<NodeIP>:<IngressNodePort>/app2
```

---

### Gateway API

The **next generation** of Ingress — more expressive and role-oriented.

| Resource | Scope | Role |
|----------|-------|------|
| **GatewayClass** | Cluster | Defines type of load balancer (set by infrastructure team) |
| **Gateway** | Namespace | Where and how traffic is received |
| **HTTPRoute** | Namespace | Routing rules (managed by app teams) |

**Key advantage:** Separation of concerns — infra team owns Gateway, dev teams own Routes.

---

### Network Policies

**Default:** All pods can talk to all pods (no restrictions).
**Network Policy:** Acts as a firewall — restrict traffic by pod labels, namespaces, ports.

**⚠️ Requires a CNI that supports network policies** (Calico ✅, Flannel ❌, Cilium ✅)

#### Best Practice: Default Deny First

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}       # {} = select ALL pods
  policyTypes:
  - Ingress             # Block all incoming traffic (no ingress rules = deny all)
```

```bash
kubectl apply -f deny-all.yaml
```

#### Allow Specific Traffic

```yaml
# allow-access.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-access-label
spec:
  podSelector:
    matchLabels:
      app: nginx        # This policy protects nginx pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          access: "true"   # Only pods with this label can reach nginx
```

```bash
# Test: pod WITHOUT label (fails - blocked)
kubectl run test --image=busybox --rm -it -- wget --timeout=2 nginx-service

# Test: pod WITH label (succeeds - allowed)
kubectl run test --image=busybox --labels=access=true --rm -it -- wget nginx-service
```

---

### CoreDNS

**Role:** Default DNS server for Kubernetes — provides service discovery within the cluster.

**DNS record patterns:**
- Service: `<service-name>.<namespace>.svc.cluster.local`
- Pod: `<pod-ip-dashes>.<namespace>.pod.cluster.local`

**Configuration:** ConfigMap `coredns` in `kube-system` namespace (contains a `Corefile`).

Key plugins in default CoreDNS config:
- `kubernetes` — Resolves cluster services and pods
- `forward` — Forwards external DNS queries to upstream (node's DNS servers)
- `cache` — Caches responses for performance
- `reload` — Auto-applies config changes without restart

#### Customize CoreDNS — Add Internal Domain

```bash
kubectl edit configmap coredns -n kube-system
```

Add a new server block for your internal domain:

```
# Add BEFORE the closing } of the main block
mycorp.com:53 {
    errors
    cache 30
    forward . 10.10.0.53    # Your internal DNS server IP
}
```

- `mycorp.com:53` — CoreDNS handles all DNS queries for `*.mycorp.com`
- `cache 30` — Cache responses 30 seconds to reduce load
- `forward . 10.10.0.53` — Forward these queries to internal DNS server

CoreDNS auto-reloads config (due to `reload` plugin) — no restart needed.

---

## 13. Storage

### Objective
Understand Kubernetes persistent storage — PV, PVC, StorageClass — and how to provision storage statically and dynamically.

### Volume vs. Persistent Volume

| Concept | Lifecycle | Use Case |
|---------|-----------|---------|
| **Volume** | Tied to pod — deleted with pod | Temporary/shared data between containers in same pod |
| **Persistent Volume (PV)** | Independent of pods | Data that must survive pod deletion |
| **Persistent Volume Claim (PVC)** | Request for storage | How developers request PV without knowing the infrastructure |

### Storage Flow

```
[StorageClass]          ← Admin defines: "here's how to provision storage"
      ↓
[PersistentVolume]      ← Actual storage resource (static: admin creates it; dynamic: auto-created)
      ↓
[PersistentVolumeClaim] ← Developer requests storage (binds 1:1 to a PV)
      ↓
[Pod]                   ← References PVC to use the storage
```

### Access Modes

| Mode | Abbreviation | Description |
|------|-------------|-------------|
| ReadWriteOnce | RWO | Read-write by ONE node at a time (most common) |
| ReadOnlyMany | ROX | Read-only by MANY nodes |
| ReadWriteMany | RWX | Read-write by MANY nodes (requires NFS/CephFS) |
| ReadWriteOncePod | RWOP | Read-write by ONE pod (most restrictive) |

### Reclaim Policies

| Policy | Behavior when PVC deleted |
|--------|--------------------------|
| **Retain** | PV remains — admin must clean up manually (safest for production) |
| **Delete** | PV and underlying storage are auto-deleted |
| **Recycle** | Basic scrub, makes available again (deprecated) |

---

### Static Provisioning

**Admin creates PV, developer creates PVC to claim it.**

#### Step 1: Admin Creates PV

```yaml
# pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: manual        # Label — PVCs use this to find matching PVs
  hostPath:
    path: /mnt/data               # ⚠️ Only for demos — ties data to single node
```

```bash
kubectl apply -f pv.yaml
kubectl get pv    # Status: Available
```

#### Step 2: Developer Creates PVC

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual        # Must match PV's storageClassName
  accessModes:
  - ReadWriteOnce                 # Must match PV's access mode
  resources:
    requests:
      storage: 2Gi                # Request ≤ PV capacity (5Gi here)
```

```bash
kubectl apply -f pvc.yaml
kubectl get pv,pvc    # Status: Bound (PVC found and claimed the PV)
```

#### Step 3: Pod Uses PVC

```yaml
# pod-storage.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-pod
spec:
  volumes:
  - name: my-storage
    persistentVolumeClaim:
      claimName: task-pv-claim    # Reference the PVC
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: my-storage
      mountPath: /usr/share/nginx/html   # Files written here persist
```

---

### Dynamic Provisioning

**Admin creates StorageClass (template). PVs are auto-created when PVCs are submitted.**

#### Why Dynamic?
- No pre-provisioning of PVs
- Storage is created on-demand
- Scales automatically

Cloud providers (GKE, AWS) provide a default StorageClass automatically. For local clusters:

```bash
# Install local-path provisioner (for lab/dev use only)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

kubectl get storageclass    # Should now show 'local-path'
```

#### Developer Creates PVC (Dynamic)

```yaml
# my-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-dynamic-pvc
spec:
  storageClassName: local-path    # Matches installed StorageClass
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f my-pvc.yaml
kubectl get pvc    # Status: Pending (waiting for a pod to use it — then auto-binds)
```

---

## 14. Troubleshooting

### Objective
Systematically diagnose and fix issues in a live Kubernetes cluster. (Highest-weighted exam domain: 30%)

### 5-Step Troubleshooting Methodology

```
1. IDENTIFY    → What is broken? (kubectl get pods / nodes)
2. GATHER      → Collect context (kubectl describe, logs, events)
3. ANALYZE     → Form hypothesis from evidence
4. FIX         → Apply targeted solution
5. VERIFY      → Confirm fix worked, no new problems introduced
```

**Work top-to-bottom:** Pod → Service → Node → Cluster Components

---

### Pod Failure States

| Status | Meaning | Common Cause |
|--------|---------|-------------|
| `Pending` | Scheduled but not running | Insufficient resources, affinity failure, no PVC |
| `ContainerCreating` | Scheduled, runtime starting container | Pulling image |
| `ImagePullBackOff` / `ErrImagePull` | Cannot pull image | Wrong image name, auth issue, registry unreachable |
| `CrashLoopBackOff` | Container crashes and keeps restarting | App error, bad config, failing liveness probe |
| `Error` | Container failed and stopped | Application exit code non-zero |
| `OOMKilled` | Out of memory | Container exceeded memory limit |

#### Debug: Pending Pod

```bash
kubectl describe pod <pod-name>
# Look at "Events" section — will show reason like:
# "0/3 nodes are available: 3 Insufficient cpu"

kubectl describe node <node-name>  # Check node capacity
```

#### Debug: ImagePullBackOff

```bash
kubectl describe pod <pod-name>
# Events will show: "Failed to pull image ... : not found" or "unauthorized"
```
Common fixes: Correct image name/tag, add imagePullSecrets for private registry.

#### Debug: CrashLoopBackOff

```bash
kubectl logs <pod-name>              # Current logs
kubectl logs <pod-name> --previous   # Logs from last crashed instance
kubectl describe pod <pod-name>      # Check exit code in "Last State"
```

If container crashes too fast to capture logs:
```bash
# Override command to keep container alive for debugging
kubectl edit pod <pod-name>
# Change command to: ["sleep", "3600"]

kubectl exec -it <pod-name> -- /bin/sh  # Then investigate inside
```

#### Termination Messages
- Containers can write failure messages to a file
- Kubernetes surfaces this in `kubectl describe pod` under `Last State: Terminated: Message`
- Useful when logs are too verbose

---

### Node Troubleshooting

| State | Meaning | Debug |
|-------|---------|-------|
| `NotReady` | kubelet not reporting healthy | SSH to node, check `systemctl status kubelet` |
| `SchedulingDisabled` | Admin cordoned the node | `kubectl uncordon <node-name>` |

```bash
# On the affected node
ssh <node-ip>
sudo systemctl status kubelet     # Is kubelet running?
sudo systemctl start kubelet      # Start it if down
sudo journalctl -u kubelet -f     # View kubelet logs
```

---

### Control Plane Component Troubleshooting

**Control plane components run as static pods** — manifests in `/etc/kubernetes/manifests/` on the control plane node.

#### API Server Down

```bash
# Symptom: kubectl commands fail with "connection refused"
ssh <control-plane-ip>
sudo crictl ps | grep kube-apiserver   # Is the container running?
sudo crictl logs <container-id>         # Check logs
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml  # Check for syntax errors
```

#### Scheduler or Controller Manager Failure

- **Scheduler down** → New pods stay `Pending` indefinitely
- **Controller Manager down** → Deployments don't create new pods

```bash
# Same debug process as API server
ssh <control-plane-ip>
sudo crictl ps | grep kube-scheduler
sudo crictl logs <container-id>
```

---

### Service Connectivity Troubleshooting

**Systematic check when a pod cannot reach a service:**

```
Step 1: DNS Resolution
  → kubectl exec -it <client-pod> -- nslookup <service-name>
  → If fails: CoreDNS problem

Step 2: Service & Endpoints
  → kubectl describe service <service-name>
  → If Endpoints: <none> → selector doesn't match pod labels → fix labels

Step 3: Pod Connectivity
  → kubectl exec -it <client-pod> -- curl <pod-ip>:<port>
  → If fails: CNI or Network Policy issue

Step 4: Network Policies
  → kubectl get networkpolicy
  → Temporarily delete policies to test if they're the blocker
  → Adjust policy to allow required traffic
```

---

### Resource Usage Monitoring

```bash
# Node resource usage (requires metrics-server)
kubectl top nodes

# Pod resource usage
kubectl top pods -A

# Narrow to specific namespace
kubectl top pods -n <namespace>
```

**Use cases:**
- `OOMKilled` errors → compare pod memory usage to memory limit
- HPA tuning → observe typical CPU usage under load
- Throttling issues → check if pods are hitting CPU limits

---

## Quick Reference — Essential Commands

```bash
# Generate YAML fast (never write from scratch)
kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment myapp --image=nginx --dry-run=client -o yaml > deploy.yaml

# Apply and inspect
kubectl apply -f <file.yaml>
kubectl describe pod/node/service <name>
kubectl logs <pod> [--previous] [-c container-name]
kubectl exec -it <pod> -- /bin/sh

# Rollouts
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>

# Scaling
kubectl scale deployment <name> --replicas=5
kubectl autoscale deployment <name> --cpu-percent=50 --min=1 --max=10

# Node management
kubectl cordon <node>      # Stop new pods from being scheduled
kubectl uncordon <node>    # Re-enable scheduling
kubectl drain <node> --ignore-daemonsets  # Evict pods for maintenance

# RBAC testing
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>

# etcd backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

*Good luck on your CKA exam! Focus heavily on troubleshooting (30%) and cluster architecture (25%) — they make up over half the exam score.*
