# Interview Preparation Guide: Part 1
## Enterprise-Grade EKS Infrastructure Foundation
**Sections 7-13, 15: Terraform EKS, Foundation, Secrets, Storage, Ingress, ExternalDNS**

**Date**: February 9, 2026  
**Status**: Complete Interview Preparation Guide

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Complete Infrastructure Architecture](#complete-infrastructure-architecture)
3. [Section 7: Terraform EKS Cluster Provisioning](#section-7-terraform-eks-cluster-provisioning)
4. [Section 8-10: Kubernetes Foundation](#section-8-10-kubernetes-foundation)
5. [Section 9: Kubernetes Secrets Management](#section-9-kubernetes-secrets-management)
6. [Section 10: Kubernetes Storage Management](#section-10-kubernetes-storage-management)
7. [Section 11: Kubernetes Ingress Controller](#section-11-kubernetes-ingress-controller)
8. [Section 13: EKS Cluster with Add-ons](#section-13-eks-cluster-with-add-ons)
9. [Section 15: External DNS Integration](#section-15-external-dns-integration)
10. [Interview Q&A - Part 1](#interview-qa---part-1)

---

## Executive Summary

You have implemented a **production-ready, enterprise-grade Kubernetes infrastructure** that demonstrates:

✅ **Infrastructure-as-Code (IaC)** - Terraform-based EKS provisioning with remote state management  
✅ **Network Security** - VPC with private subnets, security groups, network segmentation  
✅ **Kubernetes Ecosystem** - Pods, Deployments, Services, ConfigMaps, StatefulSets  
✅ **Secret Management** - AWS Secrets Manager + CSI Driver integration  
✅ **Persistent Storage** - EBS CSI Driver for dynamic volume provisioning  
✅ **External Traffic** - ALB Ingress Controller with HTTP/HTTPS  
✅ **Add-ons & Extensions** - Pod Identity, Secrets Store CSI, EBS CSI, External DNS  
✅ **Enterprise Patterns** - High availability, auto-scaling, disaster recovery  

---

## Complete Infrastructure Architecture

### Layer-by-Layer Architecture Diagram

```
═══════════════════════════════════════════════════════════════════════════════
                    ENTERPRISE EKS INFRASTRUCTURE
                          (COMPLETE STACK)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS CLOUD (Top View)                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 0: IAM & NETWORK FOUNDATION                                           │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AWS Account (123456789)                                                   │
│  ├─ IAM Roles                                                              │
│  │  ├─ eks-cluster-role (EKS control plane)                               │
│  │  ├─ eks-node-role (EC2 worker nodes)                                   │
│  │  ├─ pod-identity-agent-role (Pod authentication)                       │
│  │  ├─ lbc-controller-role (Ingress controller)                           │
│  │  ├─ ebscsi-controller-role (Storage provisioning)                      │
│  │  ├─ secretstorecsi-controller-role (Secret injection)                  │
│  │  └─ externaldns-controller-role (DNS automation)                       │
│  │                                                                         │
│  └─ VPC: 10.0.0.0/16                                                      │
│     ├─ Public Subnets (for ALB):                                          │
│     │  ├─ 10.0.1.0/24 (AZ: us-east-1a)                                   │
│     │  └─ 10.0.2.0/24 (AZ: us-east-1b)                                   │
│     │                                                                      │
│     ├─ Private Subnets (for EKS nodes):                                   │
│     │  ├─ 10.0.11.0/24 (AZ: us-east-1a)                                  │
│     │  └─ 10.0.12.0/24 (AZ: us-east-1b)                                  │
│     │                                                                      │
│     └─ Security Groups:                                                   │
│        ├─ ALB SG (0.0.0.0/0 → 80,443)                                     │
│        └─ Node SG (VPC traffic, container runtime)                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: EKS CONTROL PLANE                                                  │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AWS-Managed Kubernetes Control Plane                                     │
│  ├─ Kubernetes API Server (kube-apiserver)                               │
│  ├─ Scheduler (kube-scheduler)                                           │
│  ├─ Controller Manager (kube-controller-manager)                         │
│  ├─ etcd (distributed key-value store, encrypted)                        │
│  └─ Cloud Controller Manager (AWS integration)                           │
│                                                                             │
│  EKS Add-ons (installed via Terraform/Helm):                            │
│  ├─ Pod Identity Agent (OIDC token provider)                            │
│  ├─ VPC CNI (Calico networking plugin)                                   │
│  ├─ CoreDNS (DNS for services)                                           │
│  ├─ metrics-server (resource metrics for HPA)                            │
│  └─ kube-proxy (network rules)                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: EKS DATA PLANE (Worker Nodes)                                      │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Managed Node Group: "on-demand" (Baseline Nodes)                        │
│  ├─ 2x EC2 instances (t3.medium, on-demand)                             │
│  ├─ AMI: Amazon EKS Optimized (Ubuntu)                                   │
│  ├─ Auto Scaling Group managed by AWS                                    │
│  └─ Node IAM Role: eks-node-role (ECR pull, CloudWatch, SSM)            │
│                                                                             │
│  ┌─────────────────────────┬──────────────────────────┐                 │
│  │   NODE 1 (us-east-1a)   │   NODE 2 (us-east-1b)   │                 │
│  ├─────────────────────────┼──────────────────────────┤                 │
│  │ kubelet daemon          │ kubelet daemon           │                 │
│  │ container runtime       │ container runtime        │                 │
│  │ (containerd/Docker)     │ (containerd/Docker)      │                 │
│  │                         │                          │                 │
│  │ System Pods:            │ System Pods:             │                 │
│  │ ├─ coredns              │ ├─ coredns               │                 │
│  │ ├─ kube-proxy           │ ├─ kube-proxy            │                 │
│  │ ├─ aws-node (CNI)       │ ├─ aws-node              │                 │
│  │ ├─ ebs-csi-node         │ ├─ ebs-csi-node          │                 │
│  │ ├─ secretstorecsi       │ ├─ secretstorecsi        │                 │
│  │ ├─ aws-load-balancer... │ ├─ aws-load-balancer...  │                 │
│  │ └─ external-dns         │ └─ external-dns          │                 │
│  │                         │                          │                 │
│  │ Application Pods:       │ Application Pods:        │                 │
│  │ ├─ catalog-5d4f8c       │ ├─ orders-abc123         │                 │
│  │ ├─ cart-7h8j2k          │ ├─ checkout-xyz789       │                 │
│  │ └─ ui-9m3n4p            │ └─ ui-5k6l7m            │                 │
│  └─────────────────────────┴──────────────────────────┘                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: DATA PLANE INFRASTRUCTURE                                          │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Persistent Storage:                                                      │
│  ├─ EBS Volumes (for stateful workloads)                                 │
│  │  ├─ orders-data: 20GB gp3 (encrypted with KMS)                       │
│  │  ├─ catalog-cache: 10GB gp3 (encrypted)                              │
│  │  └─ Auto-provisioned by EBS CSI Driver                               │
│  │                                                                        │
│  Secrets Vault:                                                           │
│  ├─ AWS Secrets Manager (encrypted with KMS)                            │
│  │  ├─ catalog-db-secret (MySQL credentials)                            │
│  │  ├─ orders-db-secret (PostgreSQL credentials)                        │
│  │  ├─ checkout-redis-secret (Redis password)                           │
│  │  └─ Rotated automatically every 30 days                              │
│  │                                                                        │
│  Databases (External to Kubernetes):                                     │
│  ├─ AWS RDS MySQL (Catalog backend)                                     │
│  ├─ AWS RDS PostgreSQL (Orders backend)                                 │
│  ├─ AWS ElastiCache Redis (Checkout session store)                      │
│  ├─ AWS DynamoDB (Cart backend - NoSQL)                                 │
│  └─ AWS SQS (Orders queue for async processing)                         │
│                                                                             │
│  DNS:                                                                      │
│  ├─ AWS Route53 (DNS records)                                            │
│  ├─ External DNS Controller (auto-updates DNS on deployment)             │
│  └─ Domains: catalog.example.com, orders.example.com, app.example.com   │
│                                                                             │
│  Load Balancing:                                                           │
│  ├─ AWS ALB (Application Load Balancer)                                 │
│  ├─ AWS Load Balancer Controller (auto-provisions ALB on Ingress)       │
│  └─ Target groups map to EKS nodes                                       │
│                                                                             │
│  Monitoring:                                                               │
│  ├─ CloudWatch (logs, metrics)                                           │
│  ├─ OpenTelemetry (traces, logs, metrics)                                │
│  ├─ AWS Application Insights                                             │
│  └─ Prometheus + Grafana (optional on-cluster)                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 4: KUBERNETES OBJECTS & SERVICES                                      │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Namespaces:                                                               │
│  ├─ default (application workloads)                                       │
│  ├─ kube-system (system add-ons: DNS, CNI, CSI, etc.)                   │
│  ├─ external-dns (External DNS controller)                               │
│  └─ argocd (ArgoCD operator - for CI/CD)                                │
│                                                                             │
│  Core Objects:                                                             │
│  ├─ Deployments (stateless microservices)                               │
│  │  ├─ catalog (3 replicas, API for product catalog)                   │
│  │  ├─ orders (2 replicas, order processing)                           │
│  │  ├─ cart (3 replicas, cart management)                              │
│  │  ├─ checkout (2 replicas, payment processing)                       │
│  │  └─ ui (3 replicas, frontend website)                               │
│  │                                                                       │
│  ├─ Services (internal networking)                                      │
│  │  ├─ ClusterIP (for internal pod-to-pod communication)               │
│  │  └─ ExternalName (for RDS/external databases)                       │
│  │                                                                       │
│  ├─ Ingress (HTTP/HTTPS routing)                                        │
│  │  └─ ALB-based ingress:                                              │
│  │     ├─ / → UI service                                               │
│  │     ├─ /api/v1/catalog → Catalog service                            │
│  │     ├─ /api/v1/orders → Orders service                              │
│  │     └─ /api/v1/checkout → Checkout service                          │
│  │                                                                       │
│  ├─ ConfigMaps (configuration data)                                      │
│  │  ├─ catalog-config (DB_HOST, DATABASE_NAME)                         │
│  │  ├─ orders-config (LOG_LEVEL, TIMEOUT)                              │
│  │  └─ app-config (API_ENDPOINTS, FEATURES)                            │
│  │                                                                       │
│  ├─ Secrets (sensitive data)                                             │
│  │  ├─ Docker credentials (ECR pull)                                    │
│  │  ├─ TLS certificates (HTTPS)                                         │
│  │  └─ API keys (external service access)                               │
│  │                                                                       │
│  ├─ ServiceAccounts (pod identity)                                       │
│  │  ├─ catalog (linked to catalog-pod-iam-role via Pod Identity)        │
│  │  ├─ orders (linked to orders-pod-iam-role)                          │
│  │  ├─ cart (linked to cart-pod-iam-role)                              │
│  │  └─ checkout (linked to checkout-pod-iam-role)                      │
│  │                                                                       │
│  ├─ StatefulSets (stateful workloads with persistence)                  │
│  │  └─ kafka-broker (if used for event streaming)                       │
│  │                                                                       │
│  ├─ PersistentVolumeClaims (storage requests)                           │
│  │  ├─ orders-data (20Gi gp3 EBS)                                      │
│  │  └─ catalog-cache (10Gi gp3 EBS)                                    │
│  │                                                                       │
│  ├─ StorageClasses (provisioner definitions)                            │
│  │  └─ gp3-ebs (EBS CSI driver, encrypted, auto-expand)                │
│  │                                                                       │
│  └─ HorizontalPodAutoscalers (auto-scaling)                             │
│     ├─ catalog-hpa (scale 3-10 pods based on CPU)                       │
│     ├─ orders-hpa (scale 2-8 pods)                                      │
│     ├─ cart-hpa (scale 3-10 pods)                                       │
│     ├─ checkout-hpa (scale 2-8 pods)                                    │
│     └─ ui-hpa (scale 3-12 pods)                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 5: CI/CD PIPELINE                                                     │
┼─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  GitHub Repository (Source of Truth)                                      │
│  ├─ .github/workflows/ (GitHub Actions)                                   │
│  │  └─ build-push-ui.yaml (triggered on code change)                     │
│  │                                                                         │
│  GitHub Actions (Continuous Integration)                                 │
│  ├─ Service: Build and push Docker images                                │
│  ├─ Authentication: OIDC (no hardcoded AWS keys)                         │
│  ├─ Target: Amazon ECR (Elastic Container Registry)                      │
│  └─ Output: Container images tagged with git commit SHA                  │
│                                                                             │
│  Amazon ECR (Container Registry)                                          │
│  ├─ Repository: retail-store/ui                                          │
│  ├─ Repository: retail-store/catalog                                     │
│  ├─ Repository: retail-store/orders                                      │
│  ├─ Repository: retail-store/cart                                        │
│  ├─ Repository: retail-store/checkout                                    │
│  └─ Images encrypted with KMS                                             │
│                                                                             │
│  ArgoCD (Continuous Deployment - GitOps)                                 │
│  ├─ Controller: Monitors Git repository for changes                       │
│  ├─ Target: EKS cluster                                                  │
│  ├─ Sync Strategy: Automatic, prune, self-heal                           │
│  ├─ Helm Integration: Deploys via Helm charts                            │
│  └─ GitOps Flow:                                                         │
│     ├─ Git change detected (commit new image tag)                       │
│     ├─ ArgoCD syncs (deploys new version)                               │
│     ├─ Ingress updated (or existing route updated)                      │
│     └─ Users see new version (zero-downtime rolling update)             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Section 7: Terraform EKS Cluster Provisioning

### Overview

You implemented a **production-ready EKS cluster** using Infrastructure-as-Code (Terraform) with:
- Remote state management (S3 + DynamoDB)
- VPC with public/private subnets across 2 AZs
- EKS cluster with managed control plane
- Node groups for worker nodes
- IAM roles & policies for security

### Architecture: VPC → EKS Cluster

```
VPC: 10.0.0.0/16
├─ Public Subnets (2 AZs) - For ALB
│  ├─ 10.0.1.0/24 (us-east-1a)
│  │  └─ NAT Gateway (for private nodes to access internet)
│  └─ 10.0.2.0/24 (us-east-1b)
│     └─ NAT Gateway
│
├─ Private Subnets (2 AZs) - For EKS nodes
│  ├─ 10.0.11.0/24 (us-east-1a)
│  │  └─ EKS Node 1 (EC2 instance)
│  └─ 10.0.12.0/24 (us-east-1b)
│     └─ EKS Node 2 (EC2 instance)
│
└─ Security Groups
   ├─ ALB SG: 0.0.0.0/0 → 80/443 (public internet)
   └─ Node SG: VPC CIDR → all ports (internal)

EKS Cluster (AWS-managed control plane)
├─ API Server (accessible via kubeconfig)
├─ Scheduler
├─ Controller Manager
└─ etcd (encrypted key-value store)
```

### Terraform Structure

**Code File Dependencies:**

```
c1_versions.tf ─→ c2_variables.tf ─→ c3_remote-state.tf ─→ c4_vpc.tf
     ↓                ↓                     ↓                 ↓
(versions)      (input vars)          (state mgmt)        (networking)
     │                │                     │                 │
     └────────────────┴─────────────────────┴─────────────────┘
                          │
     ┌────────────────────┴─────────────────────┬──────────────────┐
     ↓                                          ↓                  ↓
c5_iam-roles.tf                          c6_eks-cluster.tf   c7_node-groups.tf
  (IAM setup)    ←─ depends on c2 vars ← (control plane)  ← (compute nodes)
     │                                         │                  │
     └─────────────────────────┬───────────────┴──────────────────┘
                               ↓
                        c8_outputs.tf
                     (exports DNS, endpoints)

Flow: Versions → Variables → Remote State ↓
      ↓─────────────────────────────────────
      VPC → IAM Roles ↓
      ↓──────────────
      EKS Cluster + Node Groups → Outputs
```

**File**: `07_Terraform_EKS_Cluster/02_EKS_terraform-manifests/`

```hcl
# c1_versions.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = ">= 5.0"
  }
}

provider "aws" {
  region = var.aws_region
}

# c2_variables.tf
variable "cluster_name" {
  default = "retail-dev-eksdemo"
}

variable "cluster_version" {
  default = "1.30"
}

variable "aws_region" {
  default = "us-east-1"
}

# c3_remote-state.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"  # Update this!
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

# c4_datasources_and_locals.tf
data "aws_availability_zones" "available" {
  state = "available"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  cluster_name = "${var.cluster_name}-1"
  vpc_id       = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids   = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

# c6_eks_cluster_iamrole.tf
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# c7_eks_cluster.tf
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster_role.arn
  
  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# c8_eks_nodegroup_iamrole.tf
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach required AWS managed policies
resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# c9_eks_nodegroup_private.tf
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "on-demand"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = local.subnet_ids
  
  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 2
  }
  
  instance_types = ["t3.medium"]
  
  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.registry_policy
  ]
}

# c10_eks_outputs.tf
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}
```

### Terraform Provisioning Workflow

**How Terraform Creates Your EKS Infrastructure:**

```
Step 1: INITIALIZATION (terraform init)
  ├─ Download Terraform AWS provider
  ├─ Initialize S3 remote state bucket
  ├─ Lock state with DynamoDB table
  └─ Ready for configuration

Step 2: PLANNING (terraform plan)
  ├─ Parse all .tf files
  ├─ Dependency analysis:
  │  ├─ c2_variables.tf (inputs)
  │  ├─ c3_remote-state.tf (state location)
  │  ├─ c4_vpc.tf depends on c2
  │  ├─ c5_iam-roles.tf depends on c2
  │  ├─ c6_eks-cluster.tf depends on c4, c5
  │  └─ c7_node-groups.tf depends on c5, c6
  │
  ├─ Create execution plan:
  │  ├─ AWS Account resources to create/modify/destroy
  │  ├─ Resource 1: VPC (10.0.0.0/16)
  │  ├─ Resource 2: Subnets (public & private)
  │  ├─ Resource 3: IAM roles (EKS, Nodes)
  │  ├─ Resource 4: EKS Control Plane
  │  ├─ Resource 5: Node Groups (2-4 nodes)
  │  └─ Resource 6: Security groups
  │
  └─ Output: tfplan (saved blueprint)

Step 3: APPLY (terraform apply tfplan)
  ├─ Read tfplan (what to create)
  ├─ Call AWS APIs in order:
  │  ├─ aws_vpc_create() → VPC created ✅
  │  ├─ aws_subnet_create() × 4 → Subnets created ✅
  │  ├─ aws_iam_role_create() × 7 → IAM roles created ✅
  │  │  ├─ eks-cluster-role
  │  │  ├─ eks-node-role
  │  │  └─ 5 add-on roles
  │  │
  │  ├─ aws_eks_cluster_create() → Control Plane provisioned
  │  │  └─ AWS starts Kubernetes masters
  │  │  └─ Takes 10-15 minutes...
  │  │  └─ Kubernetes API endpoint ready: https://xxx.eks.amazonaws.com
  │  │
  │  ├─ aws_eks_node_group_create() → Worker nodes added
  │  │  ├─ EC2 instances launch
  │  │  ├─ kubelet service starts
  │  │  ├─ Container runtime (containerd) starts
  │  │  ├─ Nodes register with API server
  │  │  └─ Ready to schedule pods
  │  │
  │  └─ aws_security_group_rules() → Network rules

Step 4: SAVE STATE (S3 + DynamoDB)
  ├─ Store: terraform.tfstate (JSON with all resources)
  ├─ Lock: DynamoDB item (prevents concurrent changes)
  └─ Enable: Team collaboration (shared state)

Step 5: OUTPUT ENDPOINTS (c10_eks_outputs.tf)
  ├─ eks_cluster_endpoint
  │  └─ https://xxx.eks.us-east-1.amazonaws.com
  ├─ eks_cluster_ca_certificate
  │  └─ Base64 encoded for kubectl authentication
  └─ saved to: kubeconfig file

Step 6: CONFIGURE KUBECTL
  ├─ aws eks update-kubeconfig --name retail-dev-eksdemo-1
  ├─ kubectl adds cluster config to ~/.kube/config
  └─ kubectl ready to use

Step 7: VERIFY (kubectl commands)
  ├─ kubectl get nodes → Lists 2-4 worker nodes ✅
  ├─ kubectl get pods -n kube-system → System pods running ✅
  └─ Kubernetes cluster ready for workloads ✅
```

### Terraform Workflow

```bash
# 1. Initialize Terraform (download providers, create S3 remote state)
terraform init

# 2. Validate configuration syntax
terraform validate

# 3. Plan creation (preview changes)
terraform plan -out=tfplan

# 4. Apply changes (creates EKS cluster and resources)
terraform apply tfplan

# 5. Configure kubectl to access cluster
aws eks update-kubeconfig --name retail-dev-eksdemo-1 --region us-east-1

# 6. Verify cluster is running
kubectl get nodes
kubectl get pods -n kube-system

# 7. Cleanup (when done)
terraform destroy -auto-approve
```

### Key Concepts Explained

**Remote State Management**: 
- Stores Terraform state in S3 (not locally)
- DynamoDB locks state (prevents concurrent changes)
- Allows team collaboration without conflicts

**IAM Roles for EKS**:
- **Cluster Role**: Allows EKS control plane to manage resources
- **Node Role**: Allows worker nodes to access ECR, CloudWatch, etc.
- Permissions follow "least privilege" principle

**Managed Node Group**:
- AWS manages the Auto Scaling Group
- Nodes auto-register with EKS cluster
- Updates happen with zero downtime

---

## Section 8-10: Kubernetes Foundation

### Overview

You deployed core Kubernetes objects that form the foundation of microservices:
- **Pods**: Smallest deployable unit
- **Deployments**: Manage replicas of pods with rolling updates
- **Services**: Expose pods for internal/external traffic
- **ConfigMaps**: Non-sensitive configuration data
- **StatefulSets**: For stateful workloads

### Kubernetes Object Hierarchy

```
Deployment (defines desired state)
│
├─ Replica Set (ensures X pod copies)
│  │
│  ├─ Pod (actual container)
│  │  └─ Container 1 (catalog application)
│  │  └─ Container 2 (sidecar - logging)
│  │
│  ├─ Pod
│  │  └─ Container 1
│  │  └─ Container 2
│  │
│  └─ Pod
│     └─ Container 1
│     └─ Container 2
│
Service (ClusterIP)
│
└─ Endpoints (list of Pod IPs to route traffic to)
   └─ Pod 1 (10.0.0.10:8080)
   └─ Pod 2 (10.0.0.11:8080)
   └─ Pod 3 (10.0.0.12:8080)
```

### Example: Catalog Microservice Deployment

```yaml
# ServiceAccount (pod identity)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: default

---
# ConfigMap (configuration)
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog-config
  namespace: default
data:
  DB_HOST: "catalog-mysql.default.svc.cluster.local"
  DB_PORT: "3306"
  DATABASE_NAME: "catalogdb"
  LOG_LEVEL: "INFO"

---
# Deployment (3 replicas of catalog pods)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: default
spec:
  replicas: 3
  strategy:
    type: RollingUpdate  # New pods before old pods die
    rollingUpdate:
      maxSurge: 1        # Max 1 extra pod during update
      maxUnavailable: 0  # Keep all pods available
  
  selector:
    matchLabels:
      app: catalog
  
  template:
    metadata:
      labels:
        app: catalog
    spec:
      serviceAccountName: catalog  # Link to ServiceAccount
      
      containers:
      - name: catalog
        image: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/catalog:v1.0.0
        imagePullPolicy: IfNotPresent
        
        ports:
        - containerPort: 8080
          name: http
        
        # Load config from ConfigMap
        envFrom:
        - configMapRef:
            name: catalog-config
        
        # Additional environment variables
        env:
        - name: APP_VERSION
          value: "1.0.0"
        
        # Resource requests and limits
        resources:
          requests:
            cpu: "100m"      # Minimum CPU needed
            memory: "256Mi"  # Minimum memory
          limits:
            cpu: "500m"      # Maximum CPU allowed
            memory: "512Mi"  # Maximum memory
        
        # Liveness probe (restart if unhealthy)
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Readiness probe (ready to receive traffic)
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 2

---
# Service (expose deployment)
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: default
spec:
  type: ClusterIP  # Internal-only (no external IP)
  selector:
    app: catalog
  ports:
  - port: 80          # Service port (external)
    targetPort: 8080  # Pod port (internal)
    protocol: TCP
    name: http
```

### Kubernetes Networking

```
┌─────────────────────────────────────────┐
│  External User (Internet)               │
└──────────────┬──────────────────────────┘
               │
               ↓
        ┌──────────────┐
        │   AWS ALB    │ (Public facing)
        └──────┬───────┘
               │ /api/v1/catalog
               ↓
        ┌──────────────────┐
        │ Kubernetes       │
        │ Ingress Service  │ (HTTP routing rules)
        └──────┬───────────┘
               │
               ↓
        ┌──────────────────┐
        │ Service:catalog  │ (Port 80)
        │ Type: ClusterIP  │
        └──────┬───────────┘
               │
        ┌──────┴──────────┐
        │                 │
        ↓                 ↓
    ┌────────┐        ┌────────┐       ┌────────┐
    │ Pod 1  │        │ Pod 2  │  ...  │ Pod 3  │
    │ :8080  │        │ :8080  │       │ :8080  │
    └────────┘        └────────┘       └────────┘
```

---

## Section 9: Kubernetes Secrets Management

### Problem: Secure Credential Storage

```
❌ BEFORE (Insecure):
- Secrets in code (source code repository) - DANGEROUS
- Environment variables with DB passwords
- ConfigMaps storing credentials (etcd unencrypted)
- No rotation mechanism
- No audit trail

✅ AFTER (Secure):
- AWS Secrets Manager (encrypted vault)
- Secrets mounted as files (not env vars)
- Pod Identity for AWS authentication
- CSI Driver for just-in-time secret injection
- Auto-rotation every 30 days
- Complete CloudTrail audit log
```

### Solution Architecture: Secrets Flow

```
APPLICATION POD
│
├─ /mnt/secrets/username (mounted file)
├─ /mnt/secrets/password (mounted file)
└─ Application reads files at connection time

                    ↑
                    │ (CSI Driver mounts files)
                    │
        ┌───────────────────────┐
        │ Secrets Store CSI     │
        │ Driver (DaemonSet)    │ (on every node)
        └───────────┬───────────┘
                    │
                    │ (fetch secret)
                    ↓
        ┌──────────────────────────────┐
        │ AWS Secrets & Config         │
        │ Provider (ASCP)              │ (AWS helper)
        └───────────┬──────────────────┘
                    │
                    │ (get temp credentials)
                    ↓
        ┌──────────────────────────────┐
        │ Pod Identity Agent           │
        │ (authenticates pod)          │ (on every node)
        └───────────┬──────────────────┘
                    │
                    │ (assumes IAM role)
                    ↓
        ┌──────────────────────────────┐
        │ AWS IAM + STS                │
        │ (manages credentials)        │ (AWS service)
        └───────────┬──────────────────┘
                    │
                    │ (stores secret)
                    ↓
        ┌──────────────────────────────┐
        │ AWS Secrets Manager          │
        │ (encrypted vault)            │ (AWS service)
        └──────────────────────────────┘
```

**Step-by-Step: Secret Retrieval and Mounting (Pod Startup)**

```
STEP 1: ARCHITECT DEFINES SECRET IN AWS SECRETS MANAGER
└─ AWS Secrets Manager stores: catalog-db-secret
   ├─ Key: username → Value: catalog_user
   ├─ Key: password → Value: Tr0pical!Mang0#2024 (encrypted)
   ├─ Key: endpoint → Value: catalog-mysql.c0ekrzzmkxqd.us-east-1.rds.amazonaws.com
   ├─ Encryption: AWS KMS (key-00001234567890abcdef)
   ├─ Rotation: 30-day automatic rotation enabled
   └─ Access: restricted to catalog-pod-iam-role only

STEP 2: POD STARTS, KUBELET PROCESSES VOLUME MOUNTS
└─ Developer applies: kubectl apply -f catalogdeployment.yaml
└─ Deployment manifest specifies:
   ├─ spec.serviceAccountName: catalog
   │  └─ (linked to IAM role: catalog-pod-iam-role)
   └─ spec.containers[0].volumeMounts:
      └─ name: secrets, mountPath: /mnt/secrets
└─ Deployment also specifies volume:
   └─ spec.volumes[0]:
      ├─ name: secrets
      └─ csi:
         ├─ driver: secrets-store.csi.k8s.io
         ├─ readOnly: true
         └─ volumeAttributes:
            ├─ secretProviderClass: catalog-secrets
            └─ region: us-east-1

STEP 3: KUBELET CALLS CSI DRIVER: MOUNT VOLUME
└─ Kubelet detects: This is a CSI volume, not local storage
└─ Kubelet API call: NodePublishVolume (to CSI Driver)
   ├─ Parameters:
   │  ├─ volumeId: pv-catalog-secrets-1a2b3c4d
   │  ├─ targetPath: /var/lib/kubelet/pods/[podUID]/volumes/kubernetes.io~csi/secrets/mount
   │  ├─ volumeContext: 
   │  │  ├─ secretProviderClass=catalog-secrets
   │  │  └─ region=us-east-1
   │  └─ readOnly: true
   │
   └─ CSI Driver (Secrets Store CSI): "I need to fetch secrets from AWS"

STEP 4: SECRETS STORE CSI DRIVER CHECKS SECRETPROVIDERCLASS CONFIG
└─ CSI Driver reads: SecretProviderClass "catalog-secrets"
   ├─ Provider: aws
   ├─ Objects to fetch:
   │  ├─ objectName: catalog-db-secret
   │  ├─ path: db-secret
   │  └─ objectType: secretsmanager
   │
   ├─ How to authenticate?
   │  ├─ Pod has ServiceAccount: catalog
   │  ├─ ServiceAccount annotation: eks.amazonaws.com/role-arn
   │  └─ IAM role: catalog-pod-iam-role (with Secrets Manager permissions)
   │
   └─ Decision: "Ask Pod Identity Agent for AWS credentials"

STEP 5: CSI DRIVER REQUESTS AWS CREDENTIALS VIA POD IDENTITY AGENT
└─ Query: Who is making this request?
   ├─ Pod UID: [podUID]
   ├─ Container UID: 1000
   ├─ Network namespace: net:[netnsID]
   ├─ Kubernetes API query: Which pod+namespace?
   └─ Answer: Pod "catalog-5dcb7bb4f-abc", Namespace "retail-products"

└─ Query: Which IAM role for this service account?
   ├─ ServiceAccount: catalog
   ├─ Annotation: eks.amazonaws.com/role-arn = arn:aws:iam::123456789:role/catalog-pod-iam-role
   └─ Answer: Use catalog-pod-iam-role

└─ Pod Identity Agent provides:
   ├─ AccessKeyId: AKIA7JXYZ123456ABCD
   ├─ SecretAccessKey: wJalrXUtnFEMI/K7MDENG+39j0A58/...
   ├─ SessionToken: FQoDYXdzEMj//...
   └─ Expiration: 1 hour from now

STEP 6: CSI DRIVER CALLS AWS SECRETS MANAGER API
└─ AWS SDK call: GetSecretValue
   ├─ Credentials: temporary, from Pod Identity Agent
   ├─ SecretId: catalog-db-secret
   ├─ VersionId: (latest version, auto-rotated 30 days ago)
   │
   └─ AWS validation:
      ├─ Credentials active? ✅ (1 hour expiration)
      ├─ Signature valid? ✅ (request authenticity verified)
      ├─ IAM policy check:
      │  ├─ Action: secretsmanager:GetSecretValue
      │  ├─ Resource: arn:aws:secretsmanager:us-east-1:123456789:secret:catalog-db-secret
      │  ├─ Is catalog-pod-iam-role allowed? ✅ (policy attached)
      │  └─ Condition check: allowed from us-east-1? ✅
      │
      └─ Encryption: Decrypt secret with KMS key
         ├─ KMS key: key-00001234567890abcdef
         ├─ Decrypt secret value: Tr0pical!Mang0#2024
         └─ Send decrypted value to CSI Driver

STEP 7: CSI DRIVER RECEIVES DECRYPTED SECRETS
└─ Response from AWS Secrets Manager:
   ├─ SecretString: {
   │    "username": "catalog_user",
   │    "password": "Tr0pical!Mang0#2024",
   │    "endpoint": "catalog-mysql.c0ekrzzmkxqd.us-east-1.rds.amazonaws.com",
   │    "port": 3306
   │  }
   │
   ├─ CreatedDate: 2024-01-01T00:00:00Z
   ├─ LastAccessedDate: 2024-01-15T10:30:00Z
   └─ LastChangedDate: 2024-01-01T00:00:00Z (last rotation)

STEP 8: CSI DRIVER WRITES SECRETS TO MOUNTED VOLUME
└─ Destination: /var/lib/kubelet/pods/[podUID]/volumes/kubernetes.io~csi/secrets/mount/
└─ Files created:
   ├─ username (file):
   │  └─ Content: catalog_user
   │  └─ Permissions: 0600 (readable by container only)
   │
   ├─ password (file):
   │  └─ Content: Tr0pical!Mang0#2024
   │  └─ Permissions: 0600 (readable by container only)
   │
   ├─ endpoint (file):
   │  └─ Content: catalog-mysql.c0ekrzzmkxqd.us-east-1.rds.amazonaws.com
   │  └─ Permissions: 0600
   │
   └─ port (file):
      └─ Content: 3306
      └─ Permissions: 0600

STEP 9: KUBELET CONFIRMS MOUNT COMPLETE
└─ CSI Driver returns success:
   ├─ volumeId: pv-catalog-secrets-1a2b3c4d
   ├─ status: PUBLISHED
   └─ message: "Secret volume mounted successfully"
│
└─ Kubelet bind-mounts volume into container:
   ├─ Host path: /var/lib/kubelet/pods/[podUID]/volumes/kubernetes.io~csi/secrets/mount/
   ├─ Container path: /mnt/secrets
   └─ Options: read-only, no exec

STEP 10: CONTAINER STARTS, CAN READ SECRETS
└─ Container application starts:
   ├─ Python Flask app: catalog/views.py
   └─ Initialization code:
      ├─ with open('/mnt/secrets/username', 'r') as f:
      │  └─ db_user = f.read().strip() → "catalog_user"
      │
      ├─ with open('/mnt/secrets/password', 'r') as f:
      │  └─ db_password = f.read().strip() → "Tr0pical!Mang0#2024"
      │
      ├─ with open('/mnt/secrets/endpoint', 'r') as f:
      │  └─ db_host = f.read().strip() → "catalog-mysql.c0ekrzzmkxqd.us-east-1.rds.amazonaws.com"
      │
      └─ Connection: pymysql.connect(host, user, passwd) ✅ (connected!)

STEP 11: APPLICATION QUERIES DATABASE
└─ SQL query (executed with credentials from Step 10):
   ├─ SELECT * FROM products WHERE category='Electronics'
   ├─ Database responds with results
   └─ Application processes data

STEP 12: AUTOMATIC SECRET ROTATION (EVERY 30 DAYS)
└─ AWS Secrets Manager initiates rotation:
   ├─ Time: Day 30 (every 30 days)
   ├─ Action: Create new secret version
   │  ├─ New password: Y3llo0w!P3ppAr#2024 (rotated)
   │  └─ Old password: Tr0pical!Mang0#2024 (still active for grace period)
   │
   ├─ Database updated:
   │  ├─ MySQL user password changed to new value
   │  └─ Both passwords work (7-day grace period)
   │
   ├─ Existing connections: still work
   │  └─ Application reuses connection pool with old credentials
   │
   └─ New connections after 15 minutes:
      ├─ CSI Driver detects secret version changed
      ├─ Refreshes file on disk: /mnt/secrets/password
      │  └─ Content: Y3llo0w!P3ppAr#2024 (new value)
      │
      └─ Application opens new connection pool
         └─ Uses new credentials automatically ✅

STEP 13: MONITORING & AUDIT
└─ AWS CloudTrail logs every secret access:
   ├─ EventName: GetSecretValue
   ├─ PrincipalId: AKIA7JXYZ123456ABCD (from Pod Identity)
   ├─ SourceIP: 10.0.11.100 (pod IP)
   ├─ EventTime: 2024-01-15T10:30:45Z
   ├─ RequestParameters: secretId=catalog-db-secret
   └─ ResponseElements: success
│
└─ Kubernetes audit log:
   ├─ EventType: get
   ├─ ObjectRef: secretproviderlasses/catalog-secrets
   ├─ User: system:serviceaccount:retail-products:catalog
   └─ Result: success

SECURITY GUARANTEES:
✅ Pod isolation: Secrets only accessible to intended pod (service account)
✅ Encryption at rest: AWS KMS encryption in Secrets Manager vault
✅ Encryption in transit: TLS 1.2+ for all API calls
✅ No environment variables: Secrets mounted as files, never in memory
✅ Automatic rotation: Password changes every 30 days, no manual intervention
✅ Grace period: 7 days for old credentials to work during rotation
✅ Just-in-time access: Secrets fetched at pod startup, not pre-created
✅ Zero disk trace: Secrets never written to node disk permanently
✅ Audit trail: CloudTrail logs all secret accesses
✅ Pod crash protection: Secrets refreshed when pod restarts

PERFORMANCE:
- Time to mount secrets: 500ms - 2 seconds (depends on AWS latency)
- Application startup: 2-10 seconds (with secret mounting)
- Secret refresh frequency: every 15 minutes (background auto-refresh)
```

### Implementation: SecretProviderClass

```yaml
---
# ServiceAccount (linked to IAM role via Pod Identity)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789:role/catalog-pod-iam-role"

---
# SecretProviderClass (defines which secrets to mount)
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: catalog-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "catalog-db-secret"
        objectType: "secretsmanager"
        objectAlias: "db-credentials"

---
# Deployment (mounts secrets as files)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
spec:
  template:
    spec:
      serviceAccountName: catalog
      
      containers:
      - name: catalog
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
      
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          volumeAttributes:
            secretProviderClass: "catalog-secrets"
```

---

## Section 10: Kubernetes Storage Management

### Problem: Persistent Data for Stateful Workloads

```
❌ BEFORE (Without Storage):
- Pod crashes → Data loss (no persistence)
- Database data on pod local disk → Lost on restart
- Each pod needs its own database copy (inefficient)

✅ AFTER (With EBS Storage):
- Pod crashes → EBS volume stays (data preserved)
- Any pod can attach to same volume
- Snapshots = automatic backups
- Encryption = data security
- Expansion = no downtime needed
```

### Storage Solution: EBS CSI Driver

```
PersistentVolumeClaim (PVC)
    │ (requests storage)
    ├─ Storage Class: gp3-ebs
    ├─ Size: 20Gi
    └─ Access Mode: ReadWriteOnce

                    ↓ (EBS CSI Driver watches PVC)

EBS CSI Controller
    │ (sees new PVC)
    ├─ Calls AWS EC2 API
    ├─ CreateVolume(Size=20Gi, Type=gp3, Encrypted=true)
    └─ AWS creates EBS volume

                    ↓

EBS Volume Created
    ├─ Volume ID: vol-0123456789abcdef0
    ├─ Size: 20GB
    ├─ Region: us-east-1a
    └─ Encryption: enabled (KMS key)

                    ↓

PersistentVolume (PV)
    │ (created automatically by CSI)
    ├─ Status: Bound
    ├─ Capacity: 20Gi
    └─ Linked to PVC

                    ↓

Pod Scheduled
    ├─ Node: us-east-1a (same AZ as volume)
    ├─ Volume attached to node
    ├─ kubelet mounts to pod path (/data/orders)
    └─ Container writes to /data/orders

                    ↓

DATA PERSISTS
    ├─ On pod restart: volume reattaches
    ├─ On pod move: volume follows to new node (same AZ)
    └─ Data always available
```

### Storage Binding & Provisioning Workflow

**How Kubernetes Provisions EBS Volumes:**

```
Step 1: DEVELOPER CREATES PVCLAIM
  ├─ Define: PersistentVolumeClaim (orders-storage)
  │  ├─ accessModes: ReadWriteOnce (single pod)
  │  ├─ size: 20Gi
  │  ├─ storageClassName: gp3-ebs
  │  └─ status: Pending (waiting)
  │
  └─ Apply: kubectl apply -f pvc.yaml

Step 2: SCHEDULER WAITS (WaitForFirstConsumer)
  ├─ PersistentVolumeClaim created ✅
  ├─ Status remains: Pending
  │  └─ Why? No pod using it yet
  ├─ StorageClass binding mode: WaitForFirstConsumer
  │  └─ "Don't provision until a pod needs it"
  └─ Reason: Cost optimization + zone affinity

Step 3: DEVELOPER CREATES DEPLOYMENT
  ├─ Deployment spec includes:
  │  ├─ containers[0].volumeMounts:
  │  │  └─ /data/orders → orders-storage
  │  │
  │  └─ volumes:
  │     └─ name: orders-storage
  │        persistentVolumeClaim: orders-storage
  │
  └─ kubectl apply -f deployment.yaml

Step 4: SCHEDULER PLACES POD
  ├─ Pod needs storage: orders-storage
  ├─ Scheduler checks:
  │  ├─ Which nodes have capacity?
  │  ├─ Which zones are allowed?
  │  └─ StorageClass binding mode: WaitForFirstConsumer ✓
  │
  ├─ Scheduler decision:
  │  ├─ Place pod on node-2 (us-east-1b)
  │  └─ Now storage needed in us-east-1b
  │
  └─ Pod status: Pending (needs volume first)

Step 5: EBS CSI DRIVER PROVISIONS
  ├─ EBS CSI Controller watches PVCs
  ├─ Triggers on: Pod placement + same AZ
  │
  ├─ Create EBS volume:
  │  ├─ API: aws ec2 create-volume
  │  ├─ Type: gp3 (general purpose SSD)
  │  ├─ Size: 20Gi (20 GB)
  │  ├─ IOPS: 3000
  │  ├─ Throughput: 125 MB/s
  │  ├─ Encrypted: Yes (KMS key)
  │  ├─ AZ: us-east-1b (same as pod)
  │  └─ Tags: kubernetes.io/pvc=orders-storage
  │
  └─ EBS volume created in AWS ✅

Step 6: EBS CSI NODE PLUGIN ATTACHES
  ├─ Node plugin runs on target node (node-2)
  ├─ Gets: "Attach volume vol-0abc123 to this node"
  │
  ├─ Attachment process:
  │  ├─ API: aws ec2 attach-volume
  │  ├─ EBS volume → EC2 instance (node-2)
  │  ├─ Appears as: /dev/nvme1n1
  │  └─ Attachment time: 5-10 seconds
  │
  └─ Volume attached ✅

Step 7: KUBELET FORMATS & MOUNTS
  ├─ kubelet (on node-2) detects new device
  ├─ Format:
  │  ├─ ext4 filesystem created
  │  └─ Takes: ~1-2 seconds
  │
  ├─ Mount:
  │  ├─ Mount point: /var/lib/kubelet/pods/xxx/volumes/kubernetes.io~csi/orders-storage/mount
  │  └─ Pod sees: /data/orders → mounted EBS volume
  │
  └─ Volume ready ✅

Step 8: POD STARTS USING STORAGE
  ├─ Pod transitions: Pending → Running
  ├─ Application code:
  │  ├─ fopen("/data/orders/order.db")
  │  ├─ Writes directly to EBS volume
  │  └─ Data persists on EBS (not container ephemeral storage)
  │
  └─ Pod running & storing data ✅

Step 9: POD CRASHES, DATA PERSISTS
  ├─ Pod dies (OOM, crash, eviction)
  ├─ Kubernetes reschedules to node-3
  ├─ EBS volume:
  │  ├─ Detached from node-2
  │  ├─ Attached to node-3 (same AZ requirement)
  │  └─ Data still intact ✅
  │
  └─ New pod reads old data ✅

Step 10: POD DELETED, RECLAIM POLICY
  ├─ User: kubectl delete pod orders-xyz
  ├─ Check PersistentVolumeClaim:
  │  ├─ Still exists! (not deleted with pod)
  │  └─ Still has 20GB EBS volume
  │
  ├─ User: kubectl delete pvc orders-storage
  ├─ Reclaim Policy: Delete
  │  ├─ API: aws ec2 delete-volume
  │  ├─ EBS volume deleted from AWS
  │  └─ Billing stopped
  │
  └─ Cleanup complete ✅
```

### Implementation: Storage Setup

```yaml
---
# StorageClass (defines how volumes are provisioned)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-ebs
provisioner: ebs.csi.aws.com
allowVolumeExpansion: true  # Can grow volume later

parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kms_key_id: "alias/aws/ebs"

volumeBindingMode: WaitForFirstConsumer  # Bind on pod create

---
# PersistentVolumeClaim (request storage)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: orders-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-ebs
  resources:
    requests:
      storage: 20Gi

---
# Deployment (uses the storage)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
spec:
  replicas: 1  # EBS is single-writer (ReadWriteOnce)
  template:
    spec:
      containers:
      - name: orders
        volumeMounts:
        - name: orders-data
          mountPath: "/data/orders"
      
      volumes:
      - name: orders-data
        persistentVolumeClaim:
          claimName: orders-storage
```

---

## Section 11: Kubernetes Ingress Controller

### Problem: How External Users Access Applications

```
❌ BEFORE (No Ingress):
- Services only work within cluster
- No HTTP/HTTPS routing
- No domain names
- No path-based routing (/api, /images, etc.)
- Manual load balancer management

✅ AFTER (With Ingress + ALB Controller):
- Single entry point (AWS ALB)
- HTTP/HTTPS support
- Domain names (DNS)
- Path-based routing
- Auto-provisioned load balancer
```

### Ingress Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Internet                            │
│                   0.0.0.0/0 → 80/443                    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
         ┌─────────────────────────┐
         │    AWS ALB              │
         │ (Application Load Balancer)
         │                         │
         ├─ Listener: 80 (HTTP)    │
         ├─ Listener: 443 (HTTPS)  │
         └────────┬────────────────┘
                  │
          ┌───────┴────────────────────────────┐
          │                                    │
          ↓                                    ↓
     Path: /api/*            Path: /images/*
          │                                    │
          ↓                                    ↓
    catalog-service          ui-service
    (port 80)                (port 80)
          │                                    │
    ┌─────┴──────┐                   ┌────────┴──────┐
    │             │                   │                │
   Pod 1        Pod 2                Pod 3           Pod 4
  :8080         :8080               :8080           :8080
```

**Step-by-Step: Ingress Request Routing (Internet to Pod)**

```
STEP 1: ARCHITECT DEFINES INGRESS ROUTING RULES
└─ Create Ingress manifest: /11_Kubernetes_Ingress/01_ingress.yaml
└─ Configuration:
   ├─ Host: api.retail.example.com
   ├─ Paths:
   │  ├─ /api → service: catalog-service, port: 8080
   │  ├─ /orders → service: orders-service, port: 8080
   │  └─ /ui → service: ui-service, port: 3000
   │
   ├─ TLS:
   │  ├─ Certificate: issued by AWS ACM
   │  ├─ Domain: api.retail.example.com
   │  └─ Listener port: 443 (HTTPS)
   │
   └─ Annotations (AWS ALB specific):
      ├─ alb.ingress.kubernetes.io/group.name: retail-api
      ├─ alb.ingress.kubernetes.io/scheme: internet-facing
      ├─ alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
      └─ alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...

STEP 2: APPLY INGRESS TO KUBERNETES
└─ Execute: kubectl apply -f 11_Kubernetes_Ingress/01_ingress.yaml
└─ Kubernetes stores Ingress resource:
   ├─ API version: networking.k8s.io/v1
   ├─ Kind: Ingress
   ├─ Metadata: name=retail-api, namespace=retail-products
   └─ Status: unknown (waiting for controller to process)

STEP 3: AWS LOAD BALANCER CONTROLLER DETECTS INGRESS
└─ AWS Load Balancer Controller watches Ingress resources
   ├─ Deployment: aws-load-balancer-controller (in kube-system)
   ├─ Permissions: IAM role to create/manage ALBs in AWS
   ├─ Watch trigger: Ingress created in retail-products namespace
   └─ Action: "I see a new Ingress, let me create an AWS ALB"
│
└─ Controller analysis:
   ├─ Ingress host: api.retail.example.com
   ├─ Service backend: catalog-service:8080
   ├─ Check: Does this service exist? kubectl get svc catalog-service
   │  └─ Response: Yes, ClusterIP: 10.100.50.15, endpoints: [10.0.11.45, 10.0.12.46]
   ├─ Check: Does the pod exist? kubectl get pods -l app=catalog
   │  └─ Response: Yes, 2 pods running, healthy
   └─ Decision: All prerequisites met, create AWS ALB

STEP 4: AWS LOAD BALANCER CONTROLLER CREATES AWS ALB
└─ IAM-authenticated API call to AWS ELBv2 service:
   ├─ Action: CreateLoadBalancer
   ├─ Name: k8s-retailpr-retailapi-abc123def456g (auto-generated)
   ├─ Type: application (ALB)
   ├─ Scheme: internet-facing (public IP, accessible from internet)
   ├─ Subnets:
   │  ├─ subnet-1a2b3c4d (us-east-1a) [passed by Terraform]
   │  └─ subnet-2b3c4d5e (us-east-1b) [passed by Terraform]
   │
   ├─ SecurityGroups:
   │  ├─ sg-1a2b3c4d (created by Terraform)
   │  └─ Inbound rules:
   │     ├─ Port 80 from 0.0.0.0/0 (allow HTTP)
   │     └─ Port 443 from 0.0.0.0/0 (allow HTTPS)
   │
   └─ Result: AWS creates ALB (takes 20-30 seconds)
      └─ ALB status: active, provisioning
      └─ Public DNS: k8s-retailpr-retailapi-abc123def456g-1234567890.us-east-1.elb.amazonaws.com

STEP 5: AWS LOAD BALANCER CONTROLLER CREATES LISTENERS
└─ Listener Configuration:
   ├─ Listener 1 (HTTP):
   │  ├─ Protocol: HTTP
   │  ├─ Port: 80
   │  ├─ Default action: redirect to HTTPS (443)
   │  └─ Rule: IF incoming port=80 THEN forward to port 443 (SSL)
   │
   └─ Listener 2 (HTTPS):
      ├─ Protocol: HTTPS (TLS 1.2+)
      ├─ Port: 443
      ├─ Certificate: uploaded to AWS (from ACM arn:aws:acm:...)
      └─ Default action: route based on rules

STEP 6: AWS LOAD BALANCER CONTROLLER CREATES TARGET GROUPS
└─ Target Group 1: catalog-service-8080
   ├─ Protocol: HTTP (internal to cluster, unencrypted)
   ├─ Port: 8080
   ├─ VPC: vpc-1a2b3c4d (same as cluster)
   ├─ Health check:
   │  ├─ Path: /api/health
   │  ├─ Interval: 30 seconds
   │  ├─ Timeout: 5 seconds
   │  ├─ Healthy threshold: 2 consecutive successful checks
   │  └─ Unhealthy threshold: 2 consecutive failed checks
   │
   ├─ Targets: [10.0.11.45:8080, 10.0.12.46:8080]
   │  └─ These are pod IPs (from service endpoints)
   │  └─ Updated automatically when pods scale up/down
   │
   └─ Status: active, health checks starting

STEP 7: HTTP LISTENER CREATES RULES & PATH-BASED ROUTING
└─ Listener 443 (HTTPS) creates routing rules:
   ├─ Rule 1:
   │  ├─ Condition: Host header = api.retail.example.com
   │  ├─ AND Path = /api/*
   │  ├─ Action: Forward to Target Group "catalog-service-8080"
   │  └─ Priority: 1
   │
   ├─ Rule 2:
   │  ├─ Condition: Host header = api.retail.example.com
   │  ├─ AND Path = /orders/*
   │  ├─ Action: Forward to Target Group "orders-service-8080"
   │  └─ Priority: 2
   │
   ├─ Rule 3:
   │  ├─ Condition: Host header = api.retail.example.com
   │  ├─ AND Path = /ui/*
   │  ├─ Action: Forward to Target Group "ui-service-3000"
   │  └─ Priority: 3
   │
   └─ Default rule:
      ├─ Condition: none (catch-all)
      ├─ Action: return 404 Not Found
      └─ Priority: 100 (lowest, evaluated last)

STEP 8: REGISTER POD IPS WITH AWS ALB
└─ pods running: catalog-5dcb7bb4f-abc (10.0.11.45:8080)
└─ AWS registers in Target Group "catalog-service-8080":
   ├─ Target: 10.0.11.45:8080
   ├─ Status: initial (health check pending)
   ├─ Health check: GET http://10.0.11.45:8080/api/health
   │  └─ Response: 200 OK (pod is ready)
   └─ Status: healthy ✅ (ready to receive traffic)

STEP 9: UPDATE KUBERNETES INGRESS STATUS
└─ Ingress resource updated with ALB information:
   ├─ spec.status.loadBalancer.ingress[0]:
   │  ├─ hostname: k8s-retailpr-retailapi-abc123def456g-1234567890.us-east-1.elb.amazonaws.com
   │  └─ AWS ALB is now associated with this Ingress
   │
   └─ kubectl get ingress → shows:
      ├─ NAME: retail-api
      ├─ CLASS: alb
      ├─ HOSTS: api.retail.example.com
      └─ ADDRESS: k8s-retailpr-retailapi-abc123def456g-1234567890.us-east-1.elb.amazonaws.com

STEP 10: EXTERNAL DNS UPDATES DNS RECORD (OPTIONAL)
└─ External DNS controller watches Ingress resources
└─ If annotation: external-dns.alpha.kubernetes.io/hostname: api.retail.example.com
   ├─ External DNS queries Route53 (AWS DNS service)
   ├─ Creates A record: api.retail.example.com → ALB IP address
   │  └─ Actually: CNAME: api.retail.example.com → ALB DNS name
   │  └─ Users can now access: https://api.retail.example.com ✅
   │
   └─ Result: Domain name points to AWS ALB

STEP 11: USER REQUESTS DATA FROM APPLICATION
└─ User in browser: https://api.retail.example.com/api/products
└─ DNS resolution: api.retail.example.com → ALB IP (e.g., 52.123.45.67)
└─ HTTPS connection established:
   ├─ TLS handshake: client ↔ ALB (port 443)
   ├─ Certificate verification: acm.amazonaws.com/arn:aws:acm:...
   ├─ Encryption: TLS 1.2
   └─ Connection: secure, user's data encrypted

STEP 12: ALB ROUTES REQUEST TO APPROPRIATE SERVICE
└─ ALB receives request:
   ├─ Host header: api.retail.example.com ✅
   ├─ Path: /api/products ✅ (matches rule 1: /api/*)
   ├─ Method: GET
   └─ Routing decision: Forward to Target Group "catalog-service-8080"
│
└─ ALB selects target (load balancing algorithm):
   ├─ Available targets:
   │  ├─ Target 1: 10.0.11.45:8080 (healthy, 40% usage)
   │  └─ Target 2: 10.0.12.46:8080 (healthy, 35% usage)
   ├─ Algorithm: least outstanding requests (select target 2)
   └─ Forward: connection → 10.0.12.46:8080

STEP 13: ALB CONNECTS TO POD SERVICE ENDPOINT
└─ ALB makes HTTP request to: 10.0.12.46:8080/api/products
├─ Connection goes through Kubernetes network (CNI plugin)
├─ Request reaches Pod: orders-5dcb7bb4f-xyz
├─ Container listens on port 8080 (Flask app)
├─ Flask application receives: GET /api/products
└─ Application logic:
   ├─ Query database: SELECT * FROM products
   ├─ Format response: JSON array of products
   └─ HTTP response: 200 OK + body

STEP 14: RESPONSE FLOWS BACK TO ALB
└─ Pod response: HTTP 200 OK
├─ Body: {"products": [{"id": 1, "name": "Widget", "price": 9.99}, ...]}
├─ ALB receives response
└─ ALB marks target as healthy (successful request)

STEP 15: ALB RETURNS RESPONSE TO USER
└─ ALB forwards response to user's client (encrypted over HTTPS)
├─ Response: 200 OK (TLS encrypted)
├─ Body: {"products": [...]}
├─ Timing: 50-100ms from ALB to pod + network latency
└─ User sees: product list in browser ✅

ONGOING MONITORING:
└─ ALB continuously health checks:
   ├─ Every 30 seconds: GET http://10.0.12.46:8080/api/health
   ├─ If pod crashes: health check fails → unhealthy status
   ├─ ALB stops routing traffic to crashed pod ✅ (automatic)
   ├─ Kubernetes controller detects missing pod → creates new one
   └─ New pod added to target group → health checks pass → active

SCALABILITY:
└─ When Deployment scales: 2 pods → 3 pods
   ├─ New pod created: catalog-5dcb7bb4f-def (10.0.13.47)
   ├─ Service endpoint updated to include new pod IP
   ├─ AWS Load Balancer Controller detects change
   ├─ New target registered: 10.0.13.47:8080
   ├─ ALB health check succeeds
   └─ ALB starts load balancing traffic to new pod ✅

COST OPTIMIZATION:
└─ Single ALB serves multiple services:
   ├─ /api → catalog-service (path-based routing)
   ├─ /orders → orders-service (path-based routing)
   └─ /ui → ui-service (path-based routing)
└─ Benefits:
   ├─ ✅ One ALB instead of three (save $0.0225/hour per ALB)
   ├─ ✅ One public IP instead of three
   ├─ ✅ Unified TLS certificate (one HTTPS setup)
   └─ ✅ Consolidated security group rules

COMPLETE REQUEST LATENCY BREAKDOWN:
- User browser → ALB: 1-5ms (AWS backbone network)
- ALB health check: <1ms (internal)
- ALB → Pod selection: <1ms (in-memory lookup)
- TCP connection: 2-3ms (new connection) or <1ms (connection pooling)
- HTTP request: 1-2ms (TLS overhead if re-handshake)
- Pod processing: 10-50ms (application logic)
- Response transmission: 2-10ms
- TOTAL: 20-70ms (typical, depends on application processing)
```

### Implementation: Ingress + ALB Controller

**Ingress Controller Workflow:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Kubernetes Ingress Resource (Just YAML)                        │
│ - Defines routing rules                                        │
│ - Specifies backends (Services)                                │
└──────────────────────┬──────────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ↓                         ↓
┌──────────────────────┐  ┌──────────────────────┐
│ LBC Pod (DaemonSet)  │  │ AWS API              │
│ Watches Ingress      │  │ (Creates ALB)        │
│ in this cluster      │  │                      │
└──────────────────────┘  └──────────────────────┘
          │                       ↑
          │ (Ingress CRD) → STS call (assume IAM role)
          │                       ↑
          └─ Pod Identity Agent ──┘
                   ↓
          ┌────────────────────┐
          │ AWS Load Balancer  │
          │ (ALB created)      │
          │ Internet → 80/443  │
          └────────────────────┘
                   ↑
                   │ (routes to)
       ┌───────────┴──────────┐
       ↓                      ↓
   Services              Services
   (Pods)               (Pods)
```

```yaml
---
# AWS Load Balancer Controller Service Account (with IAM role)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789:role/lbc-controller-role"

---
# Ingress (HTTP/HTTPS routing rules)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: retail-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    # If HTTPS:
    # alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
    # alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    # alb.ingress.kubernetes.io/ssl-redirect: '{"HTTP": "HTTPS"}'

spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api/v1/catalog
        pathType: Prefix
        backend:
          service:
            name: catalog
            port:
              number: 80
      
      - path: /api/v1/orders
        pathType: Prefix
        backend:
          service:
            name: orders
            port:
              number: 80
      
      - path: /api/v1/cart
        pathType: Prefix
        backend:
          service:
            name: cart
            port:
              number: 80
      
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ui
            port:
              number: 80
```

### How ALB Controller Works

```
1. User deploys Ingress object
   ├─ kubectl apply -f ingress.yaml

2. AWS Load Balancer Controller watches Ingress
   ├─ Sees: Ingress "retail-ingress" created
   ├─ Reads: rules, paths, annotations

3. ALB Controller calls AWS API
   ├─ Creates Application Load Balancer (ALB)
   ├─ Creates target groups (for each service)
   ├─ Creates listener rules (HTTP/HTTPS)
   ├─ Registers pod IPs as targets

4. AWS ALB is ready
   ├─ Public DNS: retail-ingress-123456789.us-east-1.elb.amazonaws.com
   ├─ Listening on port 80/443
   └─ Routing traffic to K8s services

5. External DNS updates Route53
   ├─ If using External DNS
   ├─ Creates DNS record: app.example.com → ALB DNS
   └─ Users can access via domain
```

---

## Section 13: EKS Cluster with Add-ons

**EKS Add-ons Architecture:**

```
AWS EKS Control Plane
    ├─ Kubernetes API         ← Manages cluster
    ├─ Scheduler              ← Places pods
    └─ Controller Manager     ← Watches resources
           ↓
    ┌──────┴──────────────────────────────────────┐
    ↓      ↓         ↓          ↓         ↓        ↓
  Pod    VPC      Core       Metrics  Load      Secrets
 Identity CNI     DNS       Server   Balancer   Store
 Agent   Plugin   (DNS)     (HPA)    Controller  CSI
  │       │        │         │        │          │
  └──────┬┴────┬───┴────┬────┴───┬───┴──────┬───┴─────────┐
         ↓    ↓        ↓        ↓        ↓        ↓        ↓
     Installed in kube-system namespace (system pods)
         Each DaemonSet/Deployment manages its feature
```

**Step-by-Step: Pod Identity Authentication (Pod → AWS Service)**

```
STEP 1: CONFIGURE POD IDENTITY ASSOCIATION (BEFORE POD RUNS)
└─ As cluster admin, set up the association:
   ├─ AWS IAM role: catalog-service-role
   │  └─ Attached policy: AmazonRDSDataFullAccess (for RDS)
   ├─ Service account: catalog (in retail-products namespace)
   │  └─ Annotation: eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/catalog-service-role
   ├─ Pod Identity Association created:
   │  ├─ Cluster: kalyan-cluster
   │  ├─ Namespace: retail-products
   │  ├─ ServiceAccount: catalog
   │  ├─ IAM role: catalog-service-role
   │  └─ Status: ACTIVE
   │
   └─ Result: When pods use this ServiceAccount, they'll get AWS credentials

STEP 2: POD STARTS, KUBELET MOUNTS SERVICE ACCOUNT TOKEN
└─ Developer applies: kubectl apply -f catalogdeployment.yaml
└─ Deployment contains:
   ├─ spec.serviceAccountName: catalog (references the configured SA)
   ├─ spec.containers[0].volumeMounts:
   │  └─ name: ksa-token, mountPath: /var/run/secrets/pods.eks.amazonaws.com/
   └─ spec.volumes:
      └─ name: ksa-token (serviceAccountToken with projected TokenRequest)
│
└─ Kubelet startup sequence:
   ├─ Request OIDC token from Kubernetes API (service account token)
   ├─ Kubernetes generates JWT token for service account "catalog"
   │  └─ Token claims:
   │     ├─ "sub": "system:serviceaccount:retail-products:catalog"
   │     ├─ "aud": ["sts.amazonaws.com"]
   │     ├─ "iat": 1705328462
   │     ├─ "exp": 1705332062 (1 hour expiration)
   │     └─ "kubernetes.io/claim": "catalog" (unique claim for pod)
   │
   ├─ Mount token file: /var/run/secrets/pods.eks.amazonaws.com/token
   │  └─ File content: eyJhbGciOiJSUzI1NiIsImtpZCI6ImFiYzEyMyJ9...
   └─ Pod container can now read this token

STEP 3: CONTAINER NEEDS AWS CREDENTIALS (E.G., RDS ACCESS)
└─ Application code (Python Flask) needs to connect to RDS:
   ├─ import boto3
   ├─ rds_client = boto3.client('rds-data', region_name='us-east-1')
   ├─ query = "SELECT COUNT(*) FROM products"
   └─ response = rds_client.execute_statement(...)
│
└─ boto3 SDK initialization:
   ├─ Looks for AWS credentials in this order:
   │  ├─ 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) ❌ Not set
   │  ├─ 2. ~/.aws/credentials (local file) ❌ Not available in pod
   │  ├─ 3. Container IAM Role (ECS task credentials) ❌ Not applicable
   │  └─ 4. IMDSv2 (EC2 instance metadata) ❌ Not on EC2
   │
   └─ Result: **Credential chain reaches "POST to magic IP 169.254.169.254"**

STEP 4: POD IDENTITY AGENT INTERCEPTS REQUEST (IPTABLES REDIRECT)
└─ Network request destination: 169.254.169.254:80/latest/api/auth/v2/credentials
└─ Linux iptables rule (installed by Pod Identity Agent):
   └─ Redirect: 169.254.169.254:80 → 127.0.0.1:9090 (Pod Identity Agent port)
│
└─ Pod Identity Agent listens on 127.0.0.1:9090
   ├─ Daemon: eks-pod-identity-agent (runs in kube-system)
   ├─ Installed via: EKS add-on (AWS managed)
   └─ Architecture: one agent per node, all pods use it

STEP 5: POD IDENTITY AGENT VALIDATES POD IDENTITY
└─ Pod Identity Agent receives request on 127.0.0.1:9090
└─ Request metadata (from kernel):
   ├─ Source IP: 10.0.3.145 (pod's network namespace)
   ├─ Source port: 54721
   ├─ Destination: 127.0.0.1:9090
   └─ Process UID: 1000 (container process)
│
└─ Pod Identity Agent mapping:
   ├─ Query: Which pod is making this request?
   ├─ Analysis: network namespace → container → pod metadata
   │  ├─ cgroup lookup: /proc/[PID]/cgroup → find pod
   │  ├─ Kubernetes API query: get pod by IP 10.0.3.145
   │  └─ Found: Pod "catalog-5dcb7bb4f-xyz" in namespace "retail-products"
   │
   ├─ Validation checks:
   │  ├─ ServiceAccount: "catalog" ✅ (matches service account name)
   │  ├─ Is this ServiceAccount configured for Pod Identity? ✅ (checked in step 1)
   │  └─ Which IAM role is associated? ✅ (catalog-service-role)
   │
   └─ Result: **Pod identity validated, proceed to get AWS credentials**

STEP 6: POD IDENTITY AGENT REQUESTS AWS TEMPORARY CREDENTIALS
└─ Pod Identity Agent now calls AWS STS API (from EC2 instance role!)
   ├─ EC2 instance role: eks-worker-node-role (assigned to EC2 instance)
   │  ├─ Permissions: sts:AssumeRole for service account roles
   │  ├─ Trust policy: allows eks-pod-identity-agent-operator service
   │  └─ This role is the "entry point" for Pod Identity
   │
   └─ AWS STS API call: assume-role-with-web-identity
      ├─ Request:
      │  ├─ Action: sts:AssumeRole
      │  ├─ RoleArn: arn:aws:iam::123456789:role/catalog-service-role
      │  ├─ WebIdentityToken: JWT token from step 2
      │  ├─ RoleSessionName: catalog@retail-products
      │  ├─ DurationSeconds: 3600 (1 hour)
      │  └─ SessionTags: [pod=catalog, namespace=retail-products]
      │
      └─ AWS validates:
         ├─ Token verification: JWT signature valid? ✅ (checked against OIDC provider)
         ├─ Token not expired? ✅ (exp: 1705332062, current time: 1705328462)
         ├─ Token audience? ✅ (aud: sts.amazonaws.com)
         ├─ Trust policy check: Does catalog-service-role allow this? ✅
         │  └─ Condition: oidc:sub = "system:serviceaccount:retail-products:catalog"
         └─ All checks passed ✅

STEP 7: AWS ISSUES TEMPORARY CREDENTIALS
└─ AWS STS returns credentials to Pod Identity Agent:
   ├─ AccessKeyId: AKIA7JXYZ123456ABCD
   ├─ SecretAccessKey: wJalrXUtnFEMI/K7MDENG+39j0A58/a1b2c3d4e5f6
   ├─ SessionToken: FQoDYXdzEMj//////////wEaDId1i2L3N4O5P6...
   ├─ Expiration: 1705332462 (1 hour from now)
   └─ Restrictions:
      ├─ Service: RDS only (catalog-service-role policy)
      ├─ Actions: DescribeDBClusters, ExecuteStatement (limited)
      └─ Resources: arn:aws:rds:us-east-1:123456789:cluster/retail-products-mysql

STEP 8: POD IDENTITY AGENT RETURNS CREDENTIALS TO CONTAINER
└─ Response to container (HTTP 200 OK):
   ├─ Body: JSON response mimicking EC2 metadata API
      ├─ {
      │   "AccessKeyId": "AKIA7JXYZ123456ABCD",
      │   "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG+39j0A58/a1b2c3d4e5f6",
      │   "Token": "FQoDYXdzEMj//////////wEaDId1i2L3N4O5P6...",
      │   "Expiration": "2024-01-15T11:34:22Z"
      │ }
      │
      └─ Container application (boto3) extracts credentials from JSON

STEP 9: APPLICATION USES CREDENTIALS FOR AWS API CALLS
└─ boto3 now has credentials (from step 8):
   ├─ AccessKeyId: AKIA7JXYZ123456ABCD
   ├─ SecretAccessKey: wJalrXUtnFEMI/K7MDENG+39j0A58/a1b2c3d4e5f6
   ├─ SessionToken: FQoDYXdzEMj...
   └─ Expiration: 1 hour
│
└─ Application makes AWS API call with these credentials:
   ├─ rds_client.execute_statement(
   │  ├─ secretArn: arn:aws:secretsmanager:us-east-1:123456789:secret/rds-password
   │  ├─ database: retail_products_db
   │  ├─ sql: "SELECT COUNT(*) FROM products"
   │  └─ )
   │
   └─ AWS validates request:
      ├─ AccessKey validation: AKIA7JXYZ123456ABCD ✅ (active, not revoked)
      ├─ Signature verification: ✅ (request signed with secret)
      ├─ Policy check: catalog-service-role allows RDS actions? ✅
      ├─ Session token valid? ✅ (not expired)
      └─ Result: API call succeeds, RDS returns results

STEP 10: PERIODIC CREDENTIAL ROTATION (AUTOMATIC)
└─ Container maintains connection to Pod Identity Agent
└─ Agent monitors token expiration:
   ├─ Original token expiration: 1705332062 (1 hour)
   ├─ 15 minutes before expiration:
   │  ├─ Pod Identity Agent automatically refreshes
   │  ├─ New STS API call: assume-role-with-web-identity
   │  ├─ New credentials issued (24-hour window)
   │  └─ Old credentials still valid for 15 minutes (grace period)
   │
   ├─ Container notices new credentials:
   │  └─ boto3 SDK detects new credentials from agent (updates in memory)
   │
   └─ Result: Credentials never expire for long-running pods
      └─ Zero application downtime, automatic refresh

SECURITY GUARANTEES:
✅ Pod credentials: specific to pod's service account
✅ No hardcoded keys: credentials generated on-demand
✅ Least privilege: IAM policy limits what pod can do (RDS only)
✅ Audit trail: AWS CloudTrail logs all API calls to "assumed-role/catalog-service-role"
✅ Automatic rotation: credentials refresh before expiration
✅ Immediate revocation: delete Pod Identity Association → pod loses access
✅ No cross-pod sharing: each service account gets unique credentials
✅ Network isolation: credentials only valid within pod's container
```

### Overview

You installed **4 critical EKS add-ons** that extend cluster functionality:

```
Add-ons Deployed:
├─ Pod Identity Agent (AWS authentication)
├─ AWS Load Balancer Controller (Ingress support)
├─ EBS CSI Driver (persistent storage)
├─ Secrets Store CSI Driver (secret injection)
├─ External DNS (automatic DNS updates)
└─ Metrics Server (pod metrics for HPA)
```

### Add-on Installation via Terraform

```hcl
# c11-podidentityagent-eksaddon.tf
resource "aws_eks_addon" "pod_identity" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "eks-pod-identity-agent"
  addon_version            = "1.2.0-eksbuild.1"
  preserve                 = false
  resolve_conflicts        = "OVERWRITE"
  
  timeouts {
    create = "15m"
    delete = "15m"
  }
}

---

# c14-02-lbc-iam-policy-and-role.tf
# AWS Load Balancer Controller IAM role
resource "aws_iam_role" "lbc_role" {
  name = "aws-load-balancer-controller-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Grant ALB permissions
resource "aws_iam_role_policy" "lbc_policy" {
  name = "lbc-policy"
  role = aws_iam_role.lbc_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elbv2:CreateLoadBalancer",
        "elbv2:CreateTargetGroup",
        "elbv2:CreateListener",
        "elbv2:ModifyLoadBalancerAttributes",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets"
      ]
      Resource = "*"
    }]
  })
}

# c14-03-lbc-eks-pod-identity-association.tf
# Link LBC ServiceAccount to IAM role
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc_role.arn
}

# c14-04-lbc-helm-install.tf
# Install ALB Controller via Helm
resource "helm_release" "lbc" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  namespace       = "kube-system"
  create_namespace = false
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc_role.arn
  }
  
  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }
}

---

# c15-xx-ebscsi-eksaddon.tf
# EBS CSI Driver for persistent storage
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "1.24.2-eksbuild.1"
  preserve                 = false
  resolve_conflicts        = "OVERWRITE"
  
  timeouts {
    create = "15m"
    delete = "15m"
  }
}

---

# c16-01-secretstorecsi-helm-install.tf
# Secrets Store CSI Driver
resource "helm_release" "secrets_store_csi" {
  name            = "secrets-store-csi-driver"
  repository      = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart           = "secrets-store-csi-driver"
  namespace       = "kube-system"
  create_namespace = false
}

# c16-02-secretstorecsi-ascp-helm-install.tf
# AWS Secrets & Configuration Provider
resource "helm_release" "ascp" {
  name            = "aws-secrets-store-csi-driver-provider-aws"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "csi-secrets-store-provider-aws"
  namespace       = "kube-system"
  create_namespace = false
}
```

---

## Section 15: External DNS Integration

### Problem: Manual DNS Management

```
❌ BEFORE:
- Create Ingress → ALB created → Manual DNS record creation
- Record points to ALB DNS (hard to remember)
- Update ALB → Need to update DNS
- Multiple microservices → Multiple manual DNS updates

✅ AFTER (External DNS):
- Create Ingress with hostname annotation
- External DNS watches Ingress
- Automatically creates Route53 DNS record
- Points to ALB DNS
- Updates happen automatically
```

### External DNS Flow

```
1. Developer creates Ingress with domain

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: retail-ingress
spec:
  rules:
  - host: app.example.com  ← External DNS reads this
    http:
      paths:
      - path: /
        backend:
          service:
            name: ui
            port:
              number: 80

2. ALB Controller creates AWS ALB
   └─ ALB DNS: retail-ingress-abc123.us-east-1.elb.amazonaws.com

3. External DNS watches Ingress
   ├─ Detects: Ingress with host "app.example.com"
   ├─ Calls AWS Route53 API
   ├─ Creates DNS record: app.example.com → ALB DNS
   └─ Users can now access via domain

4. Users access application
   └─ browser: app.example.com
      DNS lookup → Route53 returns ALB IP
      ALB routes to service → UI pod returns content
```

**Step-by-Step: External DNS Automatic DNS Record Creation**

```
STEP 1: ARCHITECT DEFINES INGRESS WITH DOMAIN
└─ Create Ingress manifest: /15_ExternalDNS/retail-ingress.yaml
└─ Configuration:
   ├─ API version: networking.k8s.io/v1
   ├─ Kind: Ingress
   ├─ Metadata:
   │  ├─ name: retail-ingress
   │  ├─ namespace: retail-products
   │  └─ annotations:
   │     └─ external-dns.alpha.kubernetes.io/hostname: api.retail.example.com
   │
   └─ Spec:
      ├─ ingressClassName: alb
      ├─ rules:
      │  ├─ host: api.retail.example.com
      │  └─ paths:
      │     ├─ /api → catalog-service:8080
      │     ├─ /orders → orders-service:8080
      │     └─ /ui → ui-service:3000
      │
      └─ tls:
         ├─ hosts: [api.retail.example.com]
         └─ secretName: retail-api-cert (AWS ACM)

STEP 2: APPLY INGRESS TO KUBERNETES
└─ Execute: kubectl apply -f 15_ExternalDNS/retail-ingress.yaml
└─ Kubernetes creates Ingress resource:
   ├─ API storage: etcd
   ├─ Event: Ingress.created
   └─ Watchers notified:
      ├─ AWS Load Balancer Controller: "New Ingress, create ALB"
      └─ External DNS Controller: "New Ingress, check hostname annotation"

STEP 3: AWS LOAD BALANCER CONTROLLER CREATES ALB
└─ (Same as Ingress flow from earlier)
└─ Creates AWS ALB in ELBv2 service
└─ ALB gets DNS name: k8s-retailpr-shopapi-abc123def456-1234567890.us-east-1.elb.amazonaws.com
└─ Listeners created: port 80 (HTTP), port 443 (HTTPS)
└─ Target groups created: catalog-service, orders-service, ui-service
└─ Health checks configured & passing

STEP 4: EXTERNAL DNS CONTROLLER DETECTS INGRESS
└─ External DNS deployment running in kube-system namespace:
   ├─ Deployment: external-dns (version 1.13.0+)
   ├─ Pod: external-dns-5c9f7b2d1-xyz
   ├─ Container: external-dns
   └─ RBAC permissions: read Ingress, Services, manage Route53
│
└─ Watches Ingress resources cluster-wide:
   ├─ Event: Ingress.retail-ingress created
   ├─ Extract hostname from annotation:
   │  └─ external-dns.alpha.kubernetes.io/hostname: api.retail.example.com
   ├─ Extract backend targets:
   │  ├─ Service: catalog-service (port 8080)
   │  ├─ Service: orders-service (port 8080)
   │  └─ Service: ui-service (port 3000)
   │
   └─ Decision: "I need to create DNS records in Route53"

STEP 5: EXTERNAL DNS QUERIES INGRESS STATUS
└─ Waits for AWS Load Balancer Controller to complete:
   ├─ Poll Ingress.status.loadBalancer.ingress[0]:
   │  ├─ Initially: status.loadBalancer.ingress = [] (empty)
   │  ├─ Wait up to 5 minutes for ALB creation
   │  ├─ After ALB created: status.loadBalancer.ingress[0].hostname = ALB DNS name
   │  └─ external-dns sees: k8s-retailpr-shopapi-abc123def456-1234567890.us-east-1.elb.amazonaws.com
   │
   └─ Check: Is target ALB ready?
      ├─ ALB listeners active? ✅
      ├─ Target groups healthy? ✅
      ├─ Health checks passing? ✅
      └─ Ready to receive Route53 traffic

STEP 6: EXTERNAL DNS AUTHENTICATES TO AWS
└─ Pod Identity Agent (configured in external-dns Deployment):
   ├─ ServiceAccount: external-dns-sa
   ├─ IAM role: external-dns-role
   │  ├─ Trust policy: allows Pod Identity Agent
   │  └─ Permissions: route53:ChangeResourceRecordSets, route53:ListHostedZones, etc.
   │
   └─ Get temporary AWS credentials:
      ├─ AccessKeyId: AKIA123456789ABCDEF
      ├─ SecretAccessKey: wJalrXUtnFEMI/K7M...
      ├─ SessionToken: FQoDYXdzEMj...
      └─ Expiration: 1 hour

STEP 7: EXTERNAL DNS DISCOVERS ROUTE53 HOSTED ZONE
└─ AWS Route53 API call: ListHostedZones (authenticated)
└─ Query: What hosted zones do I have permissions to modify?
   ├─ Policy check: external-dns-role allows route53:ListHostedZones ✅
   ├─ Response (example):
   │  ├─ HostedZone 1:
   │  │  ├─ Id: /hostedzone/Z1A2B3C4D5E6F7
   │  │  ├─ Name: retail.example.com.
   │  │  ├─ Private: false (public, internet-facing)
   │  │  └─ RecordCount: 5 (existing records)
   │  │
   │  └─ HostedZone 2:
   │     ├─ Id: /hostedzone/Z8A9B0C1D2E3F4
   │     ├─ Name: internal-cluster.example.com.
   │     ├─ Private: true (private, VPC-only)
   │     └─ RecordCount: 2
   │
   └─ Decision: Map Ingress hostname to HostedZone
      └─ Hostname: api.retail.example.com
      └─ HostedZone: retail.example.com (Z1A2B3C4D5E6F7)
      └─ Match: "api.retail.example.com" is subdomain of "retail.example.com" ✅

STEP 8: EXTERNAL DNS PREPARES DNS CHANGE BATCH
└─ AWS Route53 Change Batch API:
   ├─ Action: UPSERT (insert or update)
   │  └─ If record exists: update value
   │  └─ If record doesn't exist: create it
   │
   ├─ Record type: CNAME (Canonical Name)
   │  └─ Why CNAME? Points to ALB which is public AWS service
   │  └─ Not A record: ALB IP can change, CNAME follows DNS
   │
   ├─ ResourceRecordSet:
   │  ├─ Name: api.retail.example.com
   │  ├─ Type: CNAME
   │  ├─ TTL: 300 (5 minutes, allows fast updates)
   │  ├─ ResourceRecords:
   │  │  └─ Value: k8s-retailpr-shopapi-abc123def456-1234567890.us-east-1.elb.amazonaws.com
   │  │
   │  └─ SetIdentifier: (if using weighted routing, not used here)
   │
   └─ HostedZoneId: /hostedzone/Z1A2B3C4D5E6F7

STEP 9: EXTERNAL DNS CREATES ROUTE53 DNS RECORD
└─ AWS Route53 API call: ChangeResourceRecordSets
   ├─ Credentials: temporary, from Pod Identity (AKIA123456789ABCDEF)
   ├─ Request:
   │  └─ Changes[0]:
   │     ├─ Action: UPSERT
   │     ├─ ResourceRecordSet:
   │     │  ├─ Name: api.retail.example.com
   │     │  ├─ Type: CNAME
   │     │  ├─ TTL: 300
   │     │  └─ ResourceRecords: [{Value: ALB DNS}]
   │     │
   │     └─ SetIdentifier: (none)
   │
   └─ AWS Route53 processes:
      ├─ Validates: CNAME can't be apex (api. is subdomain, ✅ OK)
      ├─ Validates: TTL in range 60-86400 seconds (300 is valid ✅)
      ├─ Validates: ResourceRecords not empty (✅)
      └─ Creates: DNS record in Route53

STEP 10: ROUTE53 RETURNS CHANGE BATCH RESPONSE
└─ Response from AWS:
   ├─ Status: PENDING (DNS change queued)
   ├─ ChangeId: /change/C1A2B3C4D5E6F7G8H9
   ├─ SubmittedAt: 2024-01-15T10:30:45Z
   ├─ Propagation: typically 30-60 seconds to all DNS servers
   └─ Message: "Change has been submitted to all CloudFront edge locations"

STEP 11: EXTERNAL DNS UPDATES INGRESS STATUS (OPTIONAL)
└─ External DNS can annotate Ingress with creation confirmation:
   ├─ annotation: external-dns.alpha.kubernetes.io/created: "true"
   ├─ annotation: external-dns.alpha.kubernetes.io/route53-zone: "Z1A2B3C4D5E6F7"
   │
   └─ kubectl get ingress retail-ingress:
      ├─ NAME: retail-ingress
      ├─ CLASS: alb
      ├─ HOSTS: api.retail.example.com
      └─ ADDRESS: k8s-retailpr-shopapi-abc123def456-1234567890.us-east-1.elb.amazonaws.com

STEP 12: DNS PROPAGATES GLOBALLY
└─ Route53 updates all authoritative DNS servers:
   ├─ Primary: route53.amazonaws.com
   ├─ Secondary: backup Route53 servers (global distribution)
   ├─ CDN edge locations: CloudFront caches DNS responses
   └─ Propagation time: 30 seconds - 2 minutes (typical)

STEP 13: USER RESOLVES DOMAIN & ACCESSES APPLICATION
└─ User browser: https://api.retail.example.com/api/products
│
└─ DNS resolution:
   ├─ Browser query: "What is the IP for api.retail.example.com?"
   ├─ Query routed to: DNS resolver (ISP or 8.8.8.8)
   ├─ Resolver queries: Route53 authority servers
   ├─ Route53 response: CNAME → k8s-retailpr-shopapi-abc123def456-1234567890.us-east-1.elb.amazonaws.com
   │  └─ CNAME lookup chains to ALB public IP (e.g., 52.123.45.67)
   ├─ Browser receives: 52.123.45.67
   ├─ Resolver caches: TTL 300 seconds
   └─ Browser connects: 52.123.45.67:443 (HTTPS)

STEP 14: ALB ROUTES TO CORRECT SERVICE
└─ ALB receives: HTTPS request to api.retail.example.com/api/products
└─ Routing rules evaluate:
   ├─ Host header: api.retail.example.com ✅
   ├─ Path: /api/products (matches /api/* rule) ✅
   ├─ Target Group: catalog-service:8080
   └─ Forward to healthy pod

STEP 15: KUBERNETES SERVICE LOAD BALANCING
└─ Service: catalog-service (ClusterIP: 10.100.50.15)
│
└─ Endpoint selection:
   ├─ Query: kubectl get endpoints catalog-service
   ├─ Endpoints:
   │  ├─ 10.0.11.45:8080 (Pod 1, healthy)
   │  ├─ 10.0.12.46:8080 (Pod 2, healthy)
   │  └─ 10.0.13.47:8080 (Pod 3, healthy)
   │
   └─ Load balancing: kube-proxy selects one endpoint (round-robin)
      └─ Forward to: 10.0.12.46:8080 (Pod 2)

STEP 16: POD PROCESSES REQUEST & RETURNS RESPONSE
└─ Container receives: GET /api/products
└─ Application logic:
   ├─ Query database (using credentials from secrets)
   ├─ Retrieve products from MySQL
   └─ Return JSON response: {"products": [...]}

STEP 17: RESPONSE FLOWS BACK TO USER
└─ Pod response: 200 OK + JSON body
└─ Kubernetes network: pod → service → ALB
└─ ALB HTTPS: encrypt response
└─ User browser: displays products ✅

CONTINUOUS SYNCHRONIZATION:
└─ External DNS monitors Ingress for changes:
   ├─ If Ingress hostname changes:
   │  └─ Old DNS record deleted, new DNS record created
   │
   ├─ If Ingress deleted:
   │  └─ External DNS deletes associated DNS record
   │  └─ Users get: "DNS not found" error
   │
   ├─ If ALB replaced (due to update):
   │  └─ External DNS detects new ALB DNS name
   │  └─ Updates Route53 CNAME value
   │  └─ Users continue accessing (DNS updated automatically)
   │
   └─ Sync frequency: every 60 seconds (configurable)

COST & PERFORMANCE:
✅ Single Route53 hosted zone: $0.50/month + $0.40 per million queries
✅ CNAME traffic: first lookup takes 10-50ms (DNS recursion)
✅ Cached DNS: subsequent lookups <1ms (browser cache)
✅ ALB handles SSL/TLS: no extra cost
✅ Scale: supports unlimited subdomains in same hosted zone
✅ Failover: if ALB deleted, DNS immediately returns "not found"
   └─ Can point to backup ALB (weighted routing, requires manual setup)

DEBUGGING:
- Verify DNS record created: nslookup api.retail.example.com
- Check TTL: dig api.retail.example.com +nocmd +noall +answer
- Watch External DNS logs: kubectl logs -f -n kube-system deployment/external-dns
- Route53 console: see record in hosted zone
- External DNS event logs: kubectl describe ingress retail-ingress
```

### External DNS Terraform Implementation

```hcl
# c17-01-externaldns-iam-policy-and-role.tf
resource "aws_iam_role" "externaldns_role" {
  name = "external-dns-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "externaldns_policy" {
  name = "external-dns-policy"
  role = aws_iam_role.externaldns_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ]
      Resource = "arn:aws:route53:::hostedzone/*"
    },{
      Effect = "Allow"
      Action = [
        "route53:ListHostedZones"
      ]
      Resource = "*"
    }]
  })
}

# c17-02-externaldns-pod-identity-association.tf
resource "aws_eks_pod_identity_association" "externaldns" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns_role.arn
}

# c17-03-externaldns-eksaddon.tf
resource "aws_eks_addon" "external_dns" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "external-dns"
  addon_version            = "1.4.0-eksbuild.1"
  preserve                 = false
  resolve_conflicts        = "OVERWRITE"
}
```

---

## Interview Q&A - Part 1

### Q1: "Walk me through how you provisioned the EKS cluster with Terraform"

**Answer**:
> "I followed a 3-layer approach:
>
> **Layer 1 - VPC (Foundation)**:
> - Created VPC with CIDR 10.0.0.0/16
> - 2 public subnets (10.0.1.0/24, 10.0.2.0/24) across AZs
> - 2 private subnets (10.0.11.0/24, 10.0.12.0/24) across AZs
> - NAT Gateway in public subnet (for private nodes to reach internet)
> - Internet Gateway (for public subnet traffic)
> - Route tables (public routes to IGW, private routes to NAT)
>
> **Layer 2 - EKS Cluster**:
> - Created IAM role for EKS control plane (assumes eks.amazonaws.com service)
> - Attached AmazonEKSClusterPolicy (AWS managed policy)
> - Created EKS cluster in private subnets (high security)
> - Enabled audit logs (CloudWatch)
> - Created managed node group with 2 nodes (t3.medium)
> - Created IAM role for nodes (assumes ec2.amazonaws.com)
> - Attached required policies: AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly
>
> **Layer 3 - State Management**:
> - Used Terraform remote state (S3 backend)
> - DynamoDB for state locking (prevents concurrent changes)
> - Separate state files for VPC and EKS (for independent scaling)
> - Data sources to reference VPC state from EKS project
>
> **Result**: Production-ready cluster with private nodes, encrypted logs, and proper IAM."

---

### Q2: "How do you manage secrets securely in Kubernetes?"

**Answer**:
> "We use AWS Secrets Manager + CSI Driver integration instead of native K8s Secrets:
>
> **Problems with K8s Secrets**:
> - Stored in etcd (Base64, not encrypted by default)
> - Need to be rotated manually
> - Limited audit trail
> - Single point of failure if etcd is compromised
>
> **Our Solution**:
> 1. **Secret Storage**: AWS Secrets Manager (AES-256 encryption, KMS key)
> 2. **Pod Authentication**: Pod Identity Agent (validates pods, issues temporary AWS credentials)
> 3. **Secret Injection**: Secrets Store CSI Driver mounts secrets as files in /mnt/secrets
> 4. **Application**: Reads files at connection time (allows rotation without restart)
> 5. **Rotation**: Automatic every 30 days (AWS Secrets Manager handles it)
> 6. **Audit**: Complete CloudTrail logging (who accessed what, when)
>
> **Workflow**:
> - ServiceAccount with Pod Identity Association
> - Pod Identity links SA to IAM role
> - Container needs secret → CSI Driver fetches from Secrets Manager
> - Pod Identity Agent provides temporary AWS credentials
> - Secret mounted as file in pod
> - Application reads file
>
> **Security Benefits**: No hardcoded secrets, automatic rotation, fine-grained permissions, complete audit trail."

---

### Q3: "How do you handle persistent storage for stateful applications?"

**Answer**:
> "We use EBS CSI Driver for dynamic volume provisioning:
>
> **Architecture**:
> 1. **StorageClass** (gp3-ebs) - defines provisioning rules
>    - Provisioner: ebs.csi.aws.com
>    - Parameters: size, IOPS, throughput, encryption
> 
> 2. **PersistentVolumeClaim** (orders-storage) - storage request
>    - Size: 20Gi
>    - Access mode: ReadWriteOnce
>    - Triggers automatic volume creation
>
> 3. **EBS CSI Driver** (DaemonSet + Controller)
>    - Controller watches PVCs
>    - Calls AWS EC2 API to create EBS volumes
>    - Attaches volumes to nodes
>    - kubelet mounts to pod path
>
> 4. **Deployment** mounts PVC
>    - Application writes to /data/orders
>    - Data persists on EBS
>
> **Key Benefits**:
> - Dynamic provisioning (no manual volume creation)
> - Encrypted by default (KMS keys)
> - Auto-backups (EBS snapshots)
> - Expansion without downtime (allowVolumeExpansion: true)
> - Pod can restart, volume stays attached
> - If pod moves to different node (same AZ), volume follows
>
> **Limitations**:
> - ReadWriteOnce access (only 1 pod can write)
> - For multi-writer needs, we use RDS/databases or EFS"

---

### Q4: "How does the Ingress + ALB Controller work?"

**Answer**:
> "It's a two-step process:
>
> **Step 1: Deploy Ingress**
> - Developer writes Ingress manifest with routing rules
> - Specifies: hostnames, paths, service backends
> - Example: /api/catalog → catalog-service
>
> **Step 2: ALB Controller watches Ingress**
> - AWS Load Balancer Controller DaemonSet runs in kube-system
> - Controller has IAM role with EC2/ELB permissions
> - When Ingress is created, controller detects it
> - Controller calls AWS API:
>   ├─ CreateLoadBalancer (creates ALB)
>   ├─ CreateTargetGroup (for each service)
>   ├─ CreateListener (HTTP/HTTPS)
>   ├─ CreateRule (path-based routing)
>   └─ RegisterTargets (adds pod IPs)
>
> **Result**:
> - AWS ALB is provisioned automatically
> - ALB listens on port 80/443
> - Routes /api/catalog → Catalog pod IPs
> - Routes /api/orders → Orders pod IPs
> - Routes / → UI pod IPs
>
> **With External DNS**:
> - External DNS watches Ingress
> - Reads hostname annotation
> - Calls AWS Route53 API
> - Creates DNS record pointing to ALB
> - Users can now access via domain name
>
> **Zero-touch process**: Write Ingress → ALB created → DNS record created → Application accessible."

---

### Q5: "Why do you use Pod Identity instead of IRSA?"

**Answer**:
> "Pod Identity is AWS's newer, more secure approach to pod authentication:
>
> **Old approach - IRSA (IAM Roles for Service Accounts)**:
> - Uses OIDC provider (adds complexity)
> - ServiceAccount token must be mounted
> - Requires manually creating OIDC provider
> - Hard to debug when token issues occur
>
> **New approach - Pod Identity Agent**:
> - Simple: ServiceAccount → IAM role mapping
> - Automatic: Pod Identity Agent provides credentials
> - Secure: Credentials valid only 15 minutes
> - Scalable: Super simple for many microservices
> - Audit trail: Complete CloudTrail logging
>
> **How it works**:
> 1. Create IAM role (with trust policy for pods.eks.amazonaws.com)
> 2. Create Pod Identity Association:
>    - Service Account: catalog
>    - IAM Role: catalog-pod-iam-role
> 3. Pod starts:
>    - Kubelet injects service account token
>    - Pod Identity Agent validates token
>    - Agent assumes IAM role
>    - Returns temporary AWS credentials
> 4. Pod uses credentials for AWS API calls
>
> **Benefits**:
> - No OIDC setup needed
> - Simpler troubleshooting
> - Better security (shorter lived tokens)
> - AWS's recommended approach (newer)"

---

