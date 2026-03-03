# ==============================================================================
# karpenter.tf — Install Karpenter on an existing EKS cluster
# ==============================================================================
#
# USAGE:
#   terraform init
#   terraform plan -var-file="karpenter.tfvars"
#   terraform apply -var-file="karpenter.tfvars"
#
# INPUTS: see the "variables" section below. Copy karpenter.tfvars.example and
#         fill in your real values before running.
#
# WHAT THIS SCRIPT CREATES (in dependency order):
#   Step 1 — IAM role + policy + Pod Identity for the Karpenter controller pod
#   Step 2 — IAM role + policies + EKS access entry for EC2 nodes Karpenter creates
#   Step 3 — SQS queue + 4 EventBridge rules for spot interruption handling
#   Step 4 — Helm release that deploys the Karpenter controller into kube-system
#
# AFTER THIS SCRIPT: apply the three YAML files in the k8s-manifests/ folder:
#   kubectl apply -f k8s-manifests/ec2nodeclass.yaml
#   kubectl apply -f k8s-manifests/nodepool-ondemand.yaml
#   kubectl apply -f k8s-manifests/nodepool-spot.yaml
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Update this backend block to match your team's shared S3 state bucket
  backend "s3" {
    bucket = "YOUR-TERRAFORM-STATE-BUCKET"   # <-- change this
    key    = "karpenter/terraform.tfstate"
    region = "us-east-1"                      # <-- change if needed
  }
}

# ==============================================================================
# INPUTS — fill these in via karpenter.tfvars (see bottom of this file)
# ==============================================================================

variable "aws_region" {
  description = "AWS region where your EKS cluster lives. Example: us-east-1"
  type        = string
}

variable "cluster_name" {
  description = <<-EOT
    Name of your EXISTING EKS cluster.
    Find it: AWS Console → EKS → Clusters
    CLI: aws eks list-clusters
  EOT
  type = string
}

variable "cluster_endpoint" {
  description = <<-EOT
    HTTPS endpoint of your EKS API server.
    CLI: aws eks describe-cluster --name <NAME> --query 'cluster.endpoint' --output text
  EOT
  type = string
}

variable "cluster_ca_data" {
  description = <<-EOT
    Base64-encoded certificate authority data for the cluster.
    CLI: aws eks describe-cluster --name <NAME> --query 'cluster.certificateAuthority.data' --output text
  EOT
  type      = string
  sensitive = true
}

variable "existing_node_group_name" {
  description = <<-EOT
    Name of your existing managed node group. Karpenter controller pods are
    pinned here via nodeAffinity so they never land on Karpenter-managed nodes
    (which would cause a chicken-and-egg crash if those nodes get terminated).
    Find it: AWS Console → EKS → <cluster> → Compute → Node groups
  EOT
  type = string
}

variable "karpenter_version" {
  description = <<-EOT
    Karpenter Helm chart version. Always pin this in production.
    Latest: https://github.com/aws-karpenter/karpenter/releases
  EOT
  type    = string
  default = "1.0.6"
}

variable "availability_zones" {
  description = <<-EOT
    List of AZs where Karpenter may launch nodes.
    MUST match the AZs of your private subnets — otherwise node launch will fail.
    Example: ["us-east-1a", "us-east-1b", "us-east-1c"]
  EOT
  type = list(string)
}

variable "on_demand_instance_types" {
  description = "EC2 instance types allowed in the on-demand node pool (stable workloads)"
  type        = list(string)
  default     = ["t3.small", "t3.medium", "t3.large", "t3a.small", "t3a.medium", "t3a.large"]
}

variable "spot_instance_types" {
  description = <<-EOT
    EC2 instance types allowed in the spot node pool.
    Use MORE types than on-demand — if t3 spot is unavailable, Karpenter falls
    back to t3a, m5, etc. Diversity = reliability for spot.
  EOT
  type    = list(string)
  default = ["t3.small", "t3.medium", "t3.large", "t3a.small", "t3a.medium", "t3a.large", "m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]
}

variable "on_demand_cpu_limit" {
  description = "Max total vCPUs Karpenter may provision across ALL on-demand nodes. Cost safety net."
  type        = number
  default     = 50
}

variable "spot_cpu_limit" {
  description = "Max total vCPUs Karpenter may provision across ALL spot nodes. Cost safety net."
  type        = number
  default     = 100
}

variable "node_volume_size_gb" {
  description = "Root EBS volume size in GB for every node Karpenter provisions"
  type        = number
  default     = 20
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where the Karpenter controller runs"
  type        = string
  default     = "kube-system"
}

variable "tags" {
  description = "Tags applied to every AWS resource this script creates"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# PROVIDERS
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy   = "Terraform"
      Component   = "Karpenter"
    })
  }
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

# ==============================================================================
# DATA SOURCES — read existing AWS state, create nothing
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================================
# LOCALS — computed values reused across the file
# ==============================================================================

locals {
  account_id     = data.aws_caller_identity.current.account_id
  region         = data.aws_region.current.name
  cluster_name   = var.cluster_name

  controller_role_name = "${var.cluster_name}-karpenter-controller"
  node_role_name       = "${var.cluster_name}-karpenter-node"
  sqs_queue_name       = substr(var.cluster_name, 0, 80)
  eb_prefix            = substr(var.cluster_name, 0, 20)  # EventBridge name limit
}

# ==============================================================================
# STEP 1 — IAM for the Karpenter CONTROLLER POD
# ==============================================================================
#
# The Karpenter controller runs as a Kubernetes Pod but needs to call AWS APIs
# (create EC2 instances, read SQS, etc.) without hard-coded credentials.
#
# Solution: EKS Pod Identity
#   Pod → ServiceAccount → IAM Role → AWS Permissions
#
# Three resources wire this together:
#   A. aws_iam_role              (the role + trust policy)
#   B. aws_iam_policy            (what the role can do)
#   C. aws_eks_pod_identity_association  (links K8s SA → IAM Role)

# 1A. Trust policy: only EKS Pod Identity service can assume this role
data "aws_iam_policy_document" "controller_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# 1B. The controller IAM role
resource "aws_iam_role" "controller" {
  name               = local.controller_role_name
  assume_role_policy = data.aws_iam_policy_document.controller_assume.json
  tags               = { Name = local.controller_role_name }
}

# 1C. Permissions policy — what the controller pod is allowed to do in AWS
data "aws_iam_policy_document" "controller_permissions" {

  # Create and manage EC2 instances
  statement {
    sid    = "EC2ProvisioningActions"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${local.region}::image/*",
      "arn:aws:ec2:${local.region}::snapshot/*",
      "arn:aws:ec2:${local.region}:*:security-group/*",
      "arn:aws:ec2:${local.region}:*:subnet/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
      "arn:aws:ec2:${local.region}:*:capacity-reservation/*",
    ]
  }

  # Terminate Karpenter-owned instances only (scoped by tag)
  statement {
    sid    = "EC2TerminateScoped"
    effect = "Allow"
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}"
      values   = ["owned"]
    }
  }

  # Tag new resources at creation time
  statement {
    sid    = "EC2Tagging"
    effect = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
    ]
  }

  # Read-only instance/subnet/SG discovery (Describe actions require *)
  statement {
    sid    = "EC2Discovery"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }

  # SQS: poll the interruption queue every ~10s
  statement {
    sid    = "SQSInterruptionQueue"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.interruption.arn]
  }

  # IAM: create instance profiles for new nodes
  statement {
    sid    = "IAMInstanceProfiles"
    effect = "Allow"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = ["*"]
  }

  # IAM: pass the node role to EC2 when launching instances
  statement {
    sid    = "IAMPassNodeRole"
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.node.arn]
  }

  # EKS: read cluster metadata for self-discovery
  statement {
    sid    = "EKSDiscovery"
    effect = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.cluster_name}"]
  }

  # SSM + Pricing: fetch latest AMI IDs and spot price history
  statement {
    sid    = "SSMAndPricing"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "pricing:GetProducts",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "controller" {
  name        = "${local.cluster_name}-karpenter-controller-policy"
  description = "Karpenter controller permissions for cluster ${local.cluster_name}"
  policy      = data.aws_iam_policy_document.controller_permissions.json
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

# 1D. EKS Pod Identity Association — bridges the K8s ServiceAccount to the IAM role
resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = local.cluster_name
  namespace       = var.karpenter_namespace
  service_account = "karpenter"    # Must match serviceAccount.name in Helm values
  role_arn        = aws_iam_role.controller.arn

  depends_on = [aws_iam_role_policy_attachment.controller]
}

# ==============================================================================
# STEP 2 — IAM for EC2 NODES that Karpenter creates
# ==============================================================================
#
# This is a DIFFERENT role from Step 1.
#   Step 1 role: assumed by the Karpenter Pod to call AWS APIs
#   Step 2 role: assumed by EC2 instances to join the cluster and pull images
#
# Trust principal here is ec2.amazonaws.com (not pods.eks.amazonaws.com)
# because this role is assumed by EC2 instances, not Kubernetes pods.

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = local.node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = { Name = local.node_role_name }
}

# Attach AWS-managed policies (one block per policy via for_each)
locals {
  node_policies = {
    worker_node = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"         # Register with cluster, get cluster config
    ecr_pull    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly" # Pull container images from ECR
    cni         = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"              # Assign pod IPs, manage ENIs
    ssm         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"       # Systems Manager (debug without SSH)
  }
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each   = local.node_policies
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# EKS Access Entry — tells the EKS control plane to trust nodes using this IAM role
# Replaces the older aws-auth ConfigMap approach
resource "aws_eks_access_entry" "node" {
  cluster_name      = local.cluster_name
  principal_arn     = aws_iam_role.node.arn
  type              = "EC2_LINUX"
  kubernetes_groups = ["system:nodes"]
  tags              = { Name = "${local.cluster_name}-karpenter-node-access" }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ==============================================================================
# STEP 3 — SQS + EventBridge for spot interruption handling
# ==============================================================================
#
# When AWS reclaims a spot instance it sends a 2-minute warning.
# This pipeline captures that warning and lets Karpenter act on it:
#
#   EventBridge (4 rules watch EC2 events)
#     → SQS Queue (buffers the message)
#       → Karpenter polls queue every ~10s
#         → Cordons + drains old node, launches replacement → zero downtime

resource "aws_sqs_queue" "interruption" {
  name                      = local.sqs_queue_name
  message_retention_seconds = 300      # 5 min; spot warnings are only valid for 2 min
  sqs_managed_sse_enabled   = true     # Encrypt messages at rest
  tags                      = { Name = local.sqs_queue_name }
}

# Queue policy: allow EventBridge to send messages; deny all plain HTTP
data "aws_iam_policy_document" "sqs_policy" {
  statement {
    sid     = "AllowEventBridge"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }
  statement {
    sid     = "DenyHTTP"
    effect  = "Deny"
    actions = ["sqs:*"]
    resources = [aws_sqs_queue.interruption.arn]
    principals { type = "AWS"; identifiers = ["*"] }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy    = data.aws_iam_policy_document.sqs_policy.json
}

# Rule 1: AWS Health Events (hardware failures, scheduled maintenance)
resource "aws_cloudwatch_event_rule" "health" {
  name          = "${local.eb_prefix}-karpenter-health"
  description   = "Karpenter: AWS Health events"
  event_pattern = jsonencode({ source = ["aws.health"], detail-type = ["AWS Health Event"] })
}
resource "aws_cloudwatch_event_target" "health" {
  rule = aws_cloudwatch_event_rule.health.name
  arn  = aws_sqs_queue.interruption.arn
}

# Rule 2: Spot Interruption Warning (THE critical 2-minute warning)
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name          = "${local.eb_prefix}-karpenter-spot"
  description   = "Karpenter: EC2 Spot interruption warning"
  event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Spot Instance Interruption Warning"] })
}
resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

# Rule 3: Rebalance Recommendation (early signal before the interruption warning)
resource "aws_cloudwatch_event_rule" "rebalance" {
  name          = "${local.eb_prefix}-karpenter-rebalance"
  description   = "Karpenter: EC2 rebalance recommendation"
  event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Instance Rebalance Recommendation"] })
}
resource "aws_cloudwatch_event_target" "rebalance" {
  rule = aws_cloudwatch_event_rule.rebalance.name
  arn  = aws_sqs_queue.interruption.arn
}

# Rule 4: Instance State Change (catches unexpected terminations)
resource "aws_cloudwatch_event_rule" "state_change" {
  name          = "${local.eb_prefix}-karpenter-state"
  description   = "Karpenter: EC2 instance state change"
  event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Instance State-change Notification"] })
}
resource "aws_cloudwatch_event_target" "state_change" {
  rule = aws_cloudwatch_event_rule.state_change.name
  arn  = aws_sqs_queue.interruption.arn
}

# ==============================================================================
# STEP 4 — Helm release: the Karpenter controller itself
# ==============================================================================
#
# The Helm chart pulls from AWS's public ECR registry (OCI format).
# Key settings passed via `set` blocks:
#   - clusterName / clusterEndpoint  → so Karpenter knows its own cluster
#   - interruptionQueue              → the SQS queue from Step 3
#   - serviceAccount.name            → must match the Pod Identity Association (Step 1)
#   - nodeAffinity                   → pins controller pods to EXISTING managed nodes
#                                      (not Karpenter-managed nodes — avoids bootstrap deadlock)

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  namespace        = var.karpenter_namespace
  create_namespace = false    # kube-system already exists

  set { name = "settings.clusterName";      value = local.cluster_name }
  set { name = "settings.clusterEndpoint";  value = var.cluster_endpoint }
  set { name = "settings.interruptionQueue"; value = aws_sqs_queue.interruption.name }

  set { name = "serviceAccount.create"; value = "true" }
  set { name = "serviceAccount.name";   value = "karpenter" }

  # Pin the controller pods to your existing managed node group
  set {
    name  = "controller.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "eks.amazonaws.com/nodegroup"
  }
  set {
    name  = "controller.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }
  set {
    name  = "controller.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = var.existing_node_group_name
  }

  set { name = "controller.resources.requests.cpu";    value = "1" }
  set { name = "controller.resources.requests.memory"; value = "1Gi" }
  set { name = "controller.resources.limits.cpu";      value = "1" }
  set { name = "controller.resources.limits.memory";   value = "1Gi" }

  # Explicit ordering: ALL IAM + SQS resources must exist before the Helm install
  depends_on = [
    aws_iam_role_policy_attachment.controller,
    aws_eks_pod_identity_association.controller,
    aws_iam_role_policy_attachment.node,
    aws_eks_access_entry.node,
    aws_sqs_queue_policy.interruption,
    aws_cloudwatch_event_target.spot_interruption,
  ]
}

# ==============================================================================
# OUTPUTS — values printed after apply; queryable with `terraform output`
# ==============================================================================

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller pod (Step 1)"
  value       = aws_iam_role.controller.arn
}

output "karpenter_node_role_name" {
  description = "IAM role name for Karpenter-provisioned EC2 nodes — paste into ec2nodeclass.yaml"
  value       = aws_iam_role.node.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for spot interruption handling"
  value       = aws_sqs_queue.interruption.name
}

output "karpenter_status" {
  description = "Helm release status"
  value       = helm_release.karpenter.status
}

output "next_steps" {
  description = "Commands to run after this apply"
  value = <<-EOT

    ✅ Karpenter controller is installed. Now apply the Kubernetes manifests:

    # 1. Update <YOUR_CLUSTER_NAME> and <KARPENTER_NODE_ROLE> in each YAML file, then:
    kubectl apply -f k8s-manifests/ec2nodeclass.yaml
    kubectl apply -f k8s-manifests/nodepool-ondemand.yaml
    kubectl apply -f k8s-manifests/nodepool-spot.yaml

    # 2. Verify:
    kubectl get ec2nodeclass
    kubectl get nodepools
    kubectl get pods -n kube-system | grep karpenter
    kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

    # Key value to paste into ec2nodeclass.yaml → nodeIAMRole:
    ${aws_iam_role.node.name}
  EOT
}

# ==============================================================================
# REQUIRED SUBNET & SECURITY GROUP TAGS (run these once before terraform apply)
# ==============================================================================
#
# Karpenter discovers subnets and security groups via TAGS, not hard-coded IDs.
# Run these AWS CLI commands against your existing VPC before applying this script.
#
# 1. Tag your PRIVATE subnets (replace SUBNET-IDs and CLUSTER_NAME):
#
#   aws ec2 create-tags \
#     --resources subnet-aaa subnet-bbb subnet-ccc \
#     --tags \
#       Key=kubernetes.io/role/internal-elb,Value=1 \
#       Key=karpenter.sh/discovery,Value=YOUR_CLUSTER_NAME \
#       Key=kubernetes.io/cluster/YOUR_CLUSTER_NAME,Value=owned
#
# 2. Tag your EKS cluster security group:
#
#   SG_ID=$(aws eks describe-cluster \
#     --name YOUR_CLUSTER_NAME \
#     --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
#
#   aws ec2 create-tags --resources $SG_ID \
#     --tags Key=karpenter.sh/discovery,Value=YOUR_CLUSTER_NAME
#
# NOTE: The subnet tag must be "owned" (not "shared").
#   "shared" is for EKS managed node groups. Karpenter requires "owned".
# ==============================================================================

# ==============================================================================
# EXAMPLE karpenter.tfvars — copy this block into a file called karpenter.tfvars
# and fill in your real values before running terraform apply.
# ==============================================================================
#
# aws_region               = "us-east-1"
# cluster_name             = "my-eks-cluster"
# cluster_endpoint         = "https://XXXXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com"
# cluster_ca_data          = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."   # base64 CA cert
# existing_node_group_name = "my-eks-cluster-node-group"
# karpenter_version        = "1.0.6"
# availability_zones       = ["us-east-1a", "us-east-1b", "us-east-1c"]
#
# on_demand_instance_types = ["t3.small", "t3.medium", "t3.large", "t3a.small", "t3a.medium"]
# spot_instance_types      = ["t3.small", "t3.medium", "t3.large", "t3a.small", "t3a.medium",
#                             "m5.large", "m5.xlarge", "c5.large", "c5.xlarge"]
# on_demand_cpu_limit      = 50
# spot_cpu_limit           = 100
# node_volume_size_gb      = 20
#
# tags = {
#   Team    = "platform"
#   Project = "karpenter"
# }
