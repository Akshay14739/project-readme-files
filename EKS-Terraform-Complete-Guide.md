# Provisioning Production-Grade AWS EKS Cluster Using Terraform

---

## Section Objective

> **Goal:** Build a production-grade Amazon EKS (Elastic Kubernetes Service) cluster with managed worker nodes inside a custom VPC, using Terraform — covering everything from why Kubernetes exists to running workloads on the cluster.

---

## Part 1: Why Kubernetes? (Foundation)

### Docker Alone vs Kubernetes

- **Docker** = Containerization engine — packages your app into a portable container
- **Problem:** Docker alone only solves *packaging + runtime* — NOT orchestration
- **Orchestration problems Docker can't solve:**
  - Scaling hundreds of containers across multiple servers
  - Load balancing traffic intelligently
  - Self-healing when containers crash
  - Multi-node cluster management

### What Kubernetes Adds (Orchestration Superpowers)

| Feature | Docker Alone | Kubernetes |
|---|---|---|
| Packaging | ✅ | ✅ |
| Auto-scaling | ❌ | ✅ (HPA, VPA, Cluster Autoscaler) |
| Load Balancing | Basic | Advanced (ClusterIP, NodePort, Ingress, Gateway API) |
| Self-healing | ❌ | ✅ (restarts/reschedules crashed pods) |
| Multi-node | Limited (Swarm) | ✅ (1000s of nodes) |
| Rolling updates | ❌ | ✅ (zero downtime) |
| Desired State Mgmt | ❌ | ✅ ("I want 5 replicas → always 5 run") |
| Cloud Integration | ❌ | ✅ (EKS, AKS, GKE) |

---

## Part 2: Why Kubernetes over Docker Swarm?

### Docker Swarm

- Built into Docker, started with `docker swarm init`
- Simple, beginner-friendly
- **Best for:** Small dev/test environments only

### Kubernetes vs Docker Swarm — Full Comparison

| Feature | Docker Swarm | Kubernetes |
|---|---|---|
| Scalability | Small clusters | Thousands of nodes |
| Ecosystem | Very limited community | Industry standard, massive ecosystem |
| Load Balancing | Basic round-robin | Intelligent, advanced service discovery |
| Auto Scaling | ❌ Native support | ✅ HPA + VPA + Cluster Autoscaler |
| High Availability | Basic failover | Self-healing (restart/reschedule) |
| Storage/Networking | Basic volumes | Persistent Volumes, Storage Classes, CNI |
| Cloud Managed Service | ❌ No provider offers managed Swarm | ✅ EKS (AWS), AKS (Azure), GKE (GCP) |

> **Rule of thumb:** Swarm = simplicity. Kubernetes = power, scalability, production reliability.

---

## Part 3: Kubernetes Architecture — How It Works

### The City Analogy

```
Kubernetes Cluster = A Well-Organized City
├── Master Node = City Council (Brain / Decision Maker)
└── Worker Nodes = Construction Workers (Do actual work)
```

### Master Node Components

```
┌─────────────────────────────────────────────────────┐
│                   MASTER NODE (Brain)               │
│                                                     │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │   etcd   │  │  Kube API    │  │ Kube Scheduler│ │
│  │(Record   │  │  Server      │  │(Job Board -   │ │
│  │  Book /  │  │(Front Desk - │  │ assigns pods  │ │
│  │   DB)    │  │  all requests│  │  to nodes)    │ │
│  └──────────┘  │  go here)    │  └───────────────┘ │
│                └──────────────┘                     │
│  ┌─────────────────────────┐  ┌──────────────────┐  │
│  │  Kube Controller Manager│  │ Cloud Controller │  │
│  │  ├─ Replication Ctrl    │  │ Manager          │  │
│  │  ├─ Node Controller     │  │ ├─ Node Lifecycle │  │
│  │  ├─ Endpoints Ctrl      │  │ ├─ Route Ctrl    │  │
│  │  └─ Namespace Ctrl      │  │ ├─ Service Ctrl  │  │
│  └─────────────────────────┘  │ └─ Volume Ctrl   │  │
│                                └──────────────────┘  │
└─────────────────────────────────────────────────────┘
```

- **etcd** — Cluster's entire state database (what exists, where, who owns what)
- **Kube API Server** — Every request (deploy, scale, delete) goes through here first
- **Kube Scheduler** — Matches pods (tasks) to worker nodes (workers) based on available resources
- **Kube Controller Manager** — Collection of controllers watching actual vs desired state:
  - *Replication Controller* — If 3 pods requested but 2 running → creates missing pod
  - *Node Controller* — Marks unhealthy nodes, shifts workloads to healthy ones
  - *Endpoints/Namespace Controllers* — Manage service endpoints and namespaces
- **Cloud Controller Manager** — Ambassador to cloud provider (AWS/Azure/GCP):
  - *Node Lifecycle* — Registers new cloud VMs into cluster
  - *Route Controller* — Configures cloud networking routes
  - *Service Controller* — Provisions cloud load balancers
  - *Volume Controller* — Attaches/detaches EBS volumes

### Worker Node Components

```
┌─────────────────────────────────────┐
│           WORKER NODE               │
│                                     │
│  ┌──────────┐  ┌──────────────────┐ │
│  │ Kubelet  │  │   Kube Proxy     │ │
│  │(Site     │  │  (Traffic Cop -  │ │
│  │Supervisor│  │  routes requests │ │
│  │- ensures │  │  to right pods)  │ │
│  │containers│  └──────────────────┘ │
│  │  run)    │  ┌──────────────────┐ │
│  └──────────┘  │Container Runtime │ │
│                │(Docker/ContainerD│ │
│                │- actually runs   │ │
│                │  containers)     │ │
│                └──────────────────┘ │
│  ┌─────────────────────────────┐    │
│  │  POD │ POD │ POD │ POD      │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Request Flow (Deploy Shopping App with 3 Replicas)

```
Admin runs kubectl → API Server → stored in etcd
                                      ↓
                              Kube Scheduler assigns
                              pods to worker nodes
                                      ↓
                         Kubelet on each node runs containers
                                      ↓
                         Kube Proxy routes traffic to pods
                                      ↓
                         Users reach correct container ✅
```

---

## Part 4: Amazon EKS Architecture on AWS

### High-Level Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        AWS CLOUD                                     │
│                                                                      │
│  ┌─────────────────────┐      ┌──────────────────────────────────┐  │
│  │  AWS Managed VPC    │      │      Customer VPC (10.0.0.0/16)  │  │
│  │                     │      │                                  │  │
│  │  EKS Control Plane  │◄────►│  ┌──────────────────────────┐   │  │
│  │  ├─ API Server      │      │  │   Public Subnets (3 AZs) │   │  │
│  │  ├─ etcd            │      │  │   ├─ ALB / NLB            │   │  │
│  │  ├─ Scheduler       │      │  │   └─ NAT Gateways         │   │  │
│  │  └─ Controllers     │      │  └──────────────────────────┘   │  │
│  │                     │      │              │                   │  │
│  │  (Fully Managed      │      │              ▼                   │  │
│  │   by AWS)            │      │  ┌──────────────────────────┐   │  │
│  └─────────────────────┘      │  │  Private Subnets (3 AZs) │   │  │
│                                │  │  ├─ Worker Node 1        │   │  │
│         ▲                      │  │  ├─ Worker Node 2        │   │  │
│         │ kubectl (admin)      │  │  └─ Worker Node 3        │   │  │
│         │                      │  │      [Pods running here] │   │  │
│  ┌──────┴──────┐               │  └──────────────────────────┘   │  │
│  │ Local       │               └──────────────────────────────────┘  │
│  │ Desktop     │                                                      │
│  │ kubectl CLI │                                                      │
│  └─────────────┘                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Three Key Traffic Flows

- **Flow 1 — User Traffic (Inbound):** Internet → Internet Gateway → ALB (Public Subnet) → Worker Nodes (Private Subnet) → Pods
- **Flow 2 — Admin Access:** Local Desktop (kubectl) → EKS Control Plane API Endpoint → Worker Nodes
- **Flow 3 — Image Pull (Outbound):** Worker Nodes → NAT Gateway → Internet Gateway → DockerHub / Public ECR

### Why This Architecture?

- **High Availability** — Worker nodes spread across 3 AZs
- **Security** — Worker nodes in private subnets (no public IPs)
- **Flexibility** — Control plane fully managed by AWS

---

## Part 5: Terraform Project Structure

### Two Projects in This Section

```
07-Terraform-EKS-Cluster/
├── 01-VPC-Terraform-Manifests/     ← Copy of previous VPC project (Project 1)
│   └── (same as 06-07 VPC module)
│
└── 02-EKS-Terraform-Manifests/     ← EKS cluster creation (Project 2)
    ├── c1-versions.tf
    ├── c2-variables.tf
    ├── c3-remote-state.tf
    ├── c4-datasources-locals.tf
    ├── c5-eks-tags.tf
    ├── c6-eks-cluster-iam-role.tf
    ├── c7-eks-cluster.tf
    ├── c8-eks-nodegroup-iam-role.tf
    ├── c9-eks-nodegroup-private.tf
    ├── c10-outputs.tf
    └── terraform.tfvars
```

---

## Part 6: Key Concept — Terraform Remote State Data Source

### The Problem

```
Project 1 (VPC)          Project 2 (EKS)
─────────────────        ─────────────────
Creates:                 Needs:
 ├─ VPC ID        ────►   ├─ VPC ID
 ├─ Private Subnet IDs ►  ├─ Private Subnet IDs
 └─ Public Subnet IDs ►   └─ Public Subnet IDs
```

- Project 2 (EKS) needs the VPC/subnet info from Project 1 — but they're separate Terraform projects
- **Solution:** Terraform Remote State Data Source — reads outputs from another project's state file stored in S3

### How It Works

```
Project 1 (VPC)                    S3 Bucket
  terraform apply    →  saves state file  →  s3://bucket/vpc/terraform.tfstate
                                                    │
Project 2 (EKS)                                     │
  data "terraform_remote_state" "vpc" ──────────────►  reads outputs from state file
                                                    │
                                         outputs:
                                          ├─ vpc_id
                                          ├─ private_subnet_ids
                                          └─ public_subnet_ids
```

> **Key Insight:** Outputs are not just for reading in terminal — they're the mechanism for *sharing data between Terraform projects*.

---

## Part 7: File-by-File Code Explanation

---

### c1-versions.tf — Provider & Backend Configuration

**What it does:**
- Declares required Terraform CLI version
- Specifies AWS provider version
- Configures S3 remote backend for state storage

**Why:** Ensures consistent Terraform/provider versions across team; remote state enables collaboration

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {
    bucket = "YOUR-S3-BUCKET-NAME"   # Must match bucket created in demo 0605
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}
```

---

### c2-variables.tf — Input Variables

**Variables defined and why each exists:**

- `aws_region` — Tells Terraform which region to deploy in (default: `us-east-1`)
- `environment` — Separates dev/staging/prod environments in naming/tags
- `business_division` — Tags resources with team ownership (e.g., "retail") for cost tracking
- `cluster_name` — Base name for EKS cluster (default: `eks-demo`)
- `cluster_version` — Kubernetes version; `null` = use AWS default latest
- `cluster_service_ipv4_cidr` — IP range for Kubernetes services; `null` = AWS default
- `cluster_endpoint_private_access` — Allow access from inside VPC (default: `false`)
- `cluster_endpoint_public_access` — Allow access from internet (default: `true`)
- `cluster_endpoint_public_access_cidrs` — Which IPs can access API server (default: `0.0.0.0/0`)
- `node_instance_types` — EC2 instance type for worker nodes (default: `t3.medium`)
- `node_capacity_type` — `ON_DEMAND` (stable) or `SPOT` (cheaper)
- `node_disk_size` — Root volume size per worker node (default: `20` GB)

> **Security Note:** In production, set `cluster_endpoint_public_access_cidrs` to specific IP ranges, not `0.0.0.0/0`

```hcl
variable "aws_region" {
  default = "us-east-1"
}
variable "environment" {
  default = "dev"
}
variable "business_division" {
  default = "retail"
}
variable "cluster_name" {
  default = "eks-demo"
}
variable "cluster_version" {
  default = null   # null = AWS picks latest default version
}
variable "cluster_service_ipv4_cidr" {
  default = null
}
variable "cluster_endpoint_private_access" {
  default = false
}
variable "cluster_endpoint_public_access" {
  default = true
}
variable "cluster_endpoint_public_access_cidrs" {
  default = ["0.0.0.0/0"]
}
variable "node_instance_types" {
  default = ["t3.medium"]
}
variable "node_capacity_type" {
  default = "ON_DEMAND"
}
variable "node_disk_size" {
  default = 20
}
variable "tags" {
  default = {
    "Project"   = "EKS-Learning"
    "ManagedBy" = "Terraform"
  }
}
```

---

### c3-remote-state.tf — Remote State Data Source

**What it does:**
- Reads the outputs from Project 1 (VPC) state file stored in S3
- Makes VPC ID and subnet IDs available to Project 2

**Line-by-line explanation:**

- `data "terraform_remote_state" "vpc"` — declares a data source of type remote_state, named "vpc"
- `backend = "s3"` — specifies that the remote state is stored in S3
- `bucket` — the S3 bucket where Project 1 saved its state
- `key` — exact file path within the bucket for Project 1's state file
- `region` — region where S3 bucket lives
- `.outputs.vpc_id` — accesses a specific named output from Project 1 (must match the exact output name defined there)

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "YOUR-S3-BUCKET-NAME"         # Same S3 bucket where VPC state is stored
    key    = "vpc/terraform.tfstate"       # Exact path of VPC project's state file
    region = var.aws_region
  }
}

# Outputs to verify remote state is working (optional but useful during testing)
output "vpc_id" {
  value = data.terraform_remote_state.vpc.outputs.vpc_id
}
output "private_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}
output "public_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}
```

---

### c4-datasources-locals.tf — Locals (Naming Convention)

**What it does:** Defines reusable values to enforce consistent naming across all resources

**Why use locals:**
- Avoids repeating the same expression in multiple places
- Enforces company-wide naming standards automatically
- Prevents mismatched tags or names across environments

**Example output of locals:**

- `local.owners` → `retail`
- `local.environment` → `dev`
- `local.name` → `retail-dev`
- `local.eks_cluster_name` → `retail-dev-eks-demo`

```hcl
locals {
  owners           = var.business_division                          # e.g., "retail"
  environment      = var.environment                               # e.g., "dev"
  name             = "${local.owners}-${local.environment}"        # e.g., "retail-dev"
  eks_cluster_name = "${local.name}-${var.cluster_name}"          # e.g., "retail-dev-eks-demo"
}
```

---

### c5-eks-tags.tf — Subnet Tags for EKS

**Why subnet tags are CRITICAL:**
- When you deploy a Kubernetes `Service` of type `LoadBalancer`, EKS looks for specific subnet tags to know *where* to place the load balancer
- **Without these tags → Load balancer creation will fail silently**

### Tags Explained

| Tag Key | Value | Subnet Type | Meaning |
|---|---|---|---|
| `kubernetes.io/role/elb` | `1` | Public | This subnet can host internet-facing LBs |
| `kubernetes.io/cluster/<cluster-name>` | `shared` | Public | Associates subnet with EKS cluster |
| `kubernetes.io/role/internal-elb` | `1` | Private | This subnet hosts internal-only LBs |
| `kubernetes.io/cluster/<cluster-name>` | `shared` | Private | Associates subnet with EKS cluster |

> `shared` = multiple EKS clusters can use the same subnet if needed

**Why `for_each` is used:**
- Without `for_each`, you'd need to write 12 separate `aws_ec2_tag` resources (4 tags × 3 subnets each)
- `for_each` iterates over the subnet IDs list automatically, creating one resource per subnet
- `toset()` converts the list to a set (required by `for_each`)
- `each.value` gives the current subnet ID in each iteration

```hcl
# Public Subnets — Internet-facing LB tag
resource "aws_ec2_tag" "public_subnets_elb_tag" {
  for_each    = toset(data.terraform_remote_state.vpc.outputs.public_subnet_ids)
  resource_id = each.value   # each.value = one subnet ID per iteration
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Public Subnets — Cluster association tag
resource "aws_ec2_tag" "public_subnets_cluster_tag" {
  for_each    = toset(data.terraform_remote_state.vpc.outputs.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.eks_cluster_name}"
  value       = "shared"
}

# Private Subnets — Internal LB tag
resource "aws_ec2_tag" "private_subnets_internal_elb_tag" {
  for_each    = toset(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# Private Subnets — Cluster association tag
resource "aws_ec2_tag" "private_subnets_cluster_tag" {
  for_each    = toset(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.eks_cluster_name}"
  value       = "shared"
}
```

---

### c6-eks-cluster-iam-role.tf — EKS Control Plane IAM Role

**Why this role is needed:**
- EKS control plane lives in **AWS's own account** (not yours)
- To manage resources **in your account** (attach LBs, configure networking, manage EC2s), it needs permissions
- This IAM role is **assumed by the EKS service** to act on your behalf

```
AWS Account (Control Plane) ──assumes IAM role──► Your AWS Account resources
```

**Policies attached and why:**

| Policy | Purpose | Mandatory? |
|---|---|---|
| `AmazonEKSClusterPolicy` | Basic permissions for control plane to function | ✅ Yes |
| `AmazonEKSVPCResourceController` | For Fargate/Karpenter node provisioning | Recommended for production |

**Line-by-line explanation:**

- `assume_role_policy` — Trust policy: defines *who* can assume this role
- `Service = "eks.amazonaws.com"` — ONLY the EKS service (not EC2, not a user) can assume this role
- `aws_iam_role_policy_attachment` — Attaches a pre-built AWS managed policy to the role

```hcl
# IAM Role for EKS Control Plane
resource "aws_iam_role" "eks_cluster" {
  name = "${local.name}-eks-cluster-role"

  # Trust policy — ONLY EKS service can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"   # Only EKS service, not EC2 or any other
      }
    }]
  })
  tags = var.tags
}

# Attach mandatory EKS cluster policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Attach VPC resource controller (recommended for production)
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}
```

---

### c7-eks-cluster.tf — EKS Cluster Resource

**What this creates:** The Kubernetes control plane (API server, etcd, scheduler, controllers) — all managed by AWS

**Line-by-line explanation of key arguments:**

- `name` — Uses `local.eks_cluster_name` (e.g., `retail-dev-eks-demo`) from locals
- `version` — Kubernetes version; `null` → AWS picks latest
- `role_arn` — The IAM role created in c6 that EKS assumes
- `subnet_ids` — Private subnets from remote state where control plane ENIs are created
- `endpoint_private_access` — `false` = no access from inside VPC (can be enabled for production security)
- `endpoint_public_access` — `true` = API server accessible from internet (needed for kubectl from laptop)
- `public_access_cidrs` — Which source IPs can reach the API; restrict in production
- `service_ipv4_cidr` — IP range Kubernetes uses for services internally
- `enabled_cluster_log_types` — Which control plane component logs to send to CloudWatch
- `authentication_mode = "API_AND_CONFIG_MAP"` — Hybrid: supports both old and new access management
- `bootstrap_cluster_creator_admin_permissions = true` — The user running terraform apply gets cluster admin
- `depends_on` — Meta-argument ensuring IAM policies are fully attached before cluster creation starts

**Access Config Options Explained:**

| Mode | Meaning |
|---|---|
| `CONFIG_MAP` | Old way — `aws-auth` ConfigMap manages access |
| `API` | New way — EKS Access Entries API |
| `API_AND_CONFIG_MAP` | Hybrid — both work (future-ready + backwards compatible) |

> **Why `bootstrap_cluster_creator_admin_permissions = true`?** Without it, no one has admin access to the newly created cluster — you'd be locked out.

> **Why `depends_on`?** Prevents race condition where cluster starts creating before IAM policies are fully attached. Also ensures proper destruction order (cluster deleted before IAM resources).

```hcl
resource "aws_eks_cluster" "main" {
  name     = local.eks_cluster_name        # e.g., "retail-dev-eks-demo"
  version  = var.cluster_version           # null = AWS picks latest
  role_arn = aws_iam_role.eks_cluster.arn  # The IAM role we just created

  vpc_config {
    # Where to place control plane's elastic network interfaces
    subnet_ids              = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access  # false
    endpoint_public_access  = var.cluster_endpoint_public_access   # true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs  # ["0.0.0.0/0"]
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr  # null = AWS default
  }

  # Enable all control plane log types for observability/troubleshooting
  enabled_cluster_log_types = [
    "api",               # API server logs
    "audit",             # Who did what — security auditing
    "authenticator",     # Authentication logs
    "controllerManager", # Controller decisions
    "scheduler"          # Pod scheduling decisions
  ]

  # Access management — hybrid mode (old + new both supported)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    # true = person running terraform apply gets cluster admin rights automatically
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = var.tags

  # Meta-argument: ensures IAM policies attached BEFORE cluster creation
  # Also ensures correct destruction order (cluster first, then IAM)
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]
}
```

---

### c8-eks-nodegroup-iam-role.tf — Worker Node IAM Role

**Why worker nodes need their own IAM role:**
- When EC2 instances launch as worker nodes, they need permissions to:
  - Register with the Kubernetes control plane
  - Manage networking (create/manage ENIs for pod IP addresses)
  - Pull container images from ECR

**Key difference from cluster IAM role:**

| Role | Assumed By | Purpose |
|---|---|---|
| EKS Cluster Role (c6) | `eks.amazonaws.com` | Control plane manages your AWS resources |
| Node Group Role (c8) | `ec2.amazonaws.com` | Worker EC2 nodes act in your account |

**Three policies and why each is needed:**

| Policy | Purpose |
|---|---|
| `AmazonEKSWorkerNodePolicy` | Basic permissions to join and function in EKS cluster |
| `AmazonEKS_CNI_Policy` | Allows nodes to manage ENIs for pod IP addressing via VPC CNI plugin. Without this, pods won't get proper IPs. |
| `AmazonEC2ContainerRegistryReadOnly` | Pull Docker images from private ECR repositories |

```hcl
resource "aws_iam_role" "eks_node_group" {
  name = "${local.name}-eks-node-group-role"

  # Trust policy — ONLY EC2 service can assume this (worker nodes are EC2 instances)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"   # Worker nodes are EC2 instances
      }
    }]
  })
  tags = var.tags
}

# Policy 1: Basic worker node permissions to join/function in cluster
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

# Policy 2: VPC CNI — allows nodes to manage ENIs for pod networking
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

# Policy 3: Pull Docker images from private ECR repositories
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}
```

---

### c9-eks-nodegroup-private.tf — EKS Managed Node Group

**What is a Managed Node Group?**
- AWS fully manages provisioning, updating, patching, and replacing worker nodes
- You only manage *what workloads* run on them
- All worker nodes in this group live in **private subnets** (no public IPs)

**Scaling Config explained:**

- `min_size` — Cluster never goes below this number (floor)
- `max_size` — Maximum nodes during peak load (ceiling)
- `desired_size` — How many nodes are created at launch time

**Update Config explained:**

- `max_unavailable_percentage = 33` — During upgrades, at most 1/3 of nodes can be unavailable at once — ensures zero downtime for running workloads

**AMI Type note:**

- From Kubernetes 1.30+, AWS mandates migration to **Amazon Linux 2023** (`AL2023`)
- Amazon Linux 2 (AL2) is being deprecated — do not use for 1.30+ clusters

**ON_DEMAND vs SPOT:**

| Type | Cost | Stability | Use Case |
|---|---|---|---|
| ON_DEMAND | Higher | Stable, no interruption | Production workloads |
| SPOT | Up to 90% cheaper | Can be interrupted by AWS | Batch jobs, dev/test |

**Labels explained:**
- Labels are applied inside Kubernetes on the worker nodes
- Used for advanced pod scheduling (e.g., "only run this pod on nodes with label `Environment=dev`")
- Optional but useful for large multi-team clusters

**`force_update_version = true`:**
- When AWS releases a new EKS-optimized AMI, node group automatically rolls out the update to worker nodes

**`depends_on` here:**
- Ensures IAM policies are attached before the node group is created
- Ensures node group is destroyed before IAM role is deleted (prevents destroy failures)

```hcl
resource "aws_eks_node_group" "private_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-private-ng"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  # Worker nodes go into PRIVATE subnets (fetched via remote state)
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # EC2 instance configuration
  instance_types = var.node_instance_types         # ["t3.medium"]
  capacity_type  = var.node_capacity_type          # ON_DEMAND or SPOT
  disk_size      = var.node_disk_size              # 20 GB root volume
  ami_type       = "AL2023_x86_64_STANDARD"        # Amazon Linux 2023 (mandatory for K8s 1.30+)

  scaling_config {
    min_size     = 1   # Never fewer than 1 node
    max_size     = 6   # Can scale to 6 nodes maximum
    desired_size = 3   # Launch with 3 nodes initially
  }

  update_config {
    # Max 1/3 of nodes unavailable during updates = zero downtime upgrades
    max_unavailable_percentage = 33
  }

  # Auto roll out when AWS releases a new EKS-optimized AMI
  force_update_version = true

  # Kubernetes labels on worker nodes (used for pod scheduling)
  labels = {
    Environment = var.environment   # e.g., "dev"
    NodeGroup   = "private"
  }

  tags = var.tags

  # Ensures IAM role policies are attached BEFORE node group creation
  # Also ensures node group is destroyed BEFORE IAM role during terraform destroy
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly
  ]
}
```

---

### c10-outputs.tf — Cluster Outputs

**Why outputs matter here:**
- Provide key cluster info immediately after creation
- `configure_kubectl` output gives the exact command to connect kubectl to the new cluster
- Outputs from this project can also be consumed by future Terraform projects (same remote state pattern)

```hcl
output "eks_cluster_endpoint" {
  description = "EKS Cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_id" {
  description = "EKS Cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_certificate_authority_data" {
  description = "Certificate authority data for cluster authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "private_node_group_name" {
  description = "Name of the private managed node group"
  value       = aws_eks_node_group.private_nodes.node_group_name
}

output "configure_kubectl" {
  description = "Run this command locally to configure kubectl to connect to your EKS cluster"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.main.name}"
}
```

---

### terraform.tfvars — Variable Values

**What it does:** Provides concrete values for all variables, overriding defaults

```hcl
aws_region        = "us-east-1"
environment       = "dev"
business_division = "retail"
cluster_name      = "eks-demo1"
cluster_version   = "1.34"         # Specify exact version, or remove for AWS default
node_instance_types = ["t3.medium"]
node_capacity_type  = "ON_DEMAND"
node_disk_size      = 20
```

---

## Part 8: Deployment Workflow

### Step-by-Step Commands

```bash
# ── STEP 1: Create VPC (Project 1) ──────────────────────────────────
cd 01-VPC-Terraform-Manifests/
# IMPORTANT: Update c1-versions.tf with your S3 bucket name first!

terraform init            # Download providers, configure S3 backend
terraform validate        # Check syntax errors
terraform plan            # Preview what will be created
terraform apply -auto-approve   # Create VPC (~2-3 min, NAT gateway takes time)

# ── STEP 2: Create EKS Cluster (Project 2) ──────────────────────────
cd ../02-EKS-Terraform-Manifests/
# IMPORTANT: Update c1-versions.tf with your S3 bucket name!
# IMPORTANT: Update c3-remote-state.tf with correct bucket/key for VPC state!

terraform init
terraform validate
terraform plan            # Review all 21 resources before applying
terraform apply           # Type 'yes' when prompted
                          # EKS Control Plane creation: ~8-9 minutes
                          # Node Group creation: ~3 minutes
                          # Total: ~10-15 minutes

# ── STEP 3: Configure kubectl ────────────────────────────────────────
# Copy the "configure_kubectl" output printed after apply, then run it:
aws eks --region us-east-1 update-kubeconfig --name retail-dev-eks-demo1
# This updates ~/.kube/config so kubectl knows how to reach your EKS cluster

# ── STEP 4: Verify cluster is working ───────────────────────────────
kubectl version                          # Shows client version + server version
kubectl get nodes                        # Shows 3 worker nodes in Ready state
kubectl get nodes -o wide               # Shows internal IPs only (no external = private subnets ✅)
kubectl get namespaces                   # Lists: default, kube-system, kube-public, kube-node-lease
kubectl get all -n kube-system          # Shows all system pods, services, daemonsets
kubectl get pods -n kube-system         # All system pods running
kubectl get ds -n kube-system           # Daemonsets: aws-node (CNI) and kube-proxy
```

---

## Part 9: Resources Created (21 Total)

```
EC2 Tags (Subnet Tags):          12   (4 tag types × 3 subnets each)
├─ public_subnets_elb_tag         3   (one per public subnet)
├─ public_subnets_cluster_tag     3   (one per public subnet)
├─ private_subnets_internal_tag   3   (one per private subnet)
└─ private_subnets_cluster_tag    3   (one per private subnet)

IAM Role (EKS Control Plane):     1
IAM Role (Node Group):            1
IAM Policy Attachments:           5   (2 for cluster role + 3 for node group role)
EKS Cluster:                      1
EKS Node Group:                   1
─────────────────────────────────────
Total:                           21
```

---

## Part 10: Complete Component Connection Map

```
terraform.tfvars
      │
      ▼
c2-variables.tf ─────────────────────────────────────────────────────┐
      │                                                               │
      ▼                                                               ▼
c4-locals.tf                                                  c1-versions.tf
(local.eks_cluster_name)                                      (S3 backend config)
      │
      ├──────────────────────────────────────────────────────────────┐
      ▼                                                              │
c3-remote-state.tf                                                   │
(reads VPC outputs from S3)                                          │
      │                                                              │
      ├─► private_subnet_ids ──► c7-eks-cluster.tf                  │
      │                          c9-eks-nodegroup.tf                 │
      └─► public_subnet_ids ──► c5-eks-tags.tf                      │
                                                                     │
c6-eks-cluster-iam-role.tf ─────► c7-eks-cluster.tf ◄───────────────┘
(IAM Role for control plane)       (EKS Cluster resource)

c8-eks-nodegroup-iam-role.tf ───► c9-eks-nodegroup.tf
(IAM Role for worker nodes)        (Node Group + EC2 workers)

All resources ──────────────────► c10-outputs.tf
                                  (cluster endpoint, configure_kubectl cmd)
```

---

## Part 11: AWS Console Verification Checklist

After `terraform apply` completes, verify in the AWS Console:

- **VPC → Subnets → Tags tab:**
  - Private subnets: `kubernetes.io/role/internal-elb = 1` ✅
  - Public subnets: `kubernetes.io/role/elb = 1` ✅
  - Both subnet types: `kubernetes.io/cluster/<cluster-name> = shared` ✅

- **EKS Console → Cluster:**
  - Status: **Active** ✅
  - Kubernetes version: `1.34` ✅
  - Authentication mode: `API_AND_CONFIG_MAP` ✅

- **EKS Console → Compute tab:**
  - Node group `retail-dev-private-ng` exists ✅
  - 3 nodes of type `t3.medium` running ✅

- **EKS Console → Access tab:**
  - Your IAM user listed with `AmazonEKSClusterAdminPolicy` ✅

- **EC2 Console → Instances:**
  - 3 worker node instances running ✅
  - No public IPs assigned (private subnets) ✅

- **EKS Console → Add-ons tab:**
  - Note this for later — load balancer controller add-on will be added in future demos

---

## Key Takeaways Summary

- **Docker** packages, **Kubernetes** orchestrates at scale — both are needed, neither replaces the other
- **Docker Swarm** = simple but limited (dev/test only); **Kubernetes** = industry standard for production
- **EKS Control Plane** is fully managed by AWS in AWS's own VPC — you never provision or maintain it
- **Worker Nodes** live in your private subnets — you manage *what* runs on them via kubectl
- **Remote State Data Source** is how one Terraform project reads outputs from another project's state
- **Subnet Tags** are mandatory glue for EKS load balancer provisioning — missing tags = silent failures
- **Two IAM Roles needed:**
  - Cluster Role → assumed by `eks.amazonaws.com` (control plane manages your account resources)
  - Node Group Role → assumed by `ec2.amazonaws.com` (worker EC2 nodes act in your account)
- **`depends_on` meta-argument** prevents race conditions during both creation and destruction
- **`bootstrap_cluster_creator_admin_permissions = true`** ensures the Terraform executor gets cluster admin — never set to false unless you've already added other admins
- **`authentication_mode = "API_AND_CONFIG_MAP"`** gives hybrid access management — future-ready while keeping backwards compatibility
- **Amazon Linux 2023 (AL2023)** is mandatory for Kubernetes 1.30+ clusters — do not use AL2
- **`desired_size`** controls how many nodes launch initially; **`min_size`/`max_size`** control the autoscaling boundaries
- **`max_unavailable_percentage = 33`** during node group updates ensures rolling updates with zero downtime
