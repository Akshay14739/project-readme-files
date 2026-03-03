# =============================================================================
# variables.tf — All inputs your team needs to provide
# =============================================================================
# HOW TO READ THIS FILE:
#   Every `variable` block is an INPUT to the module.
#   Terraform Registry docs → https://registry.terraform.io/providers/hashicorp/aws/latest/docs
#   Run `terraform validate` to confirm types are correct before `plan`.

variable "aws_region" {
  description = "AWS region where your EKS cluster lives (e.g. us-east-1)"
  type        = string
}

variable "environment" {
  description = "Short environment name used in resource names (e.g. dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = <<-EOT
    Name of the EXISTING EKS cluster you want Karpenter installed on.
    This is the value you passed to `aws_eks_cluster.name` when you created the cluster.
    Karpenter uses this name in IAM policies, SQS queue names, and subnet/SG tag discovery.
  EOT
  type        = string
}

variable "cluster_endpoint" {
  description = <<-EOT
    API server endpoint of your EKS cluster.
    Find it: AWS Console → EKS → <cluster> → Overview → API server endpoint
    Or CLI:  aws eks describe-cluster --name <name> --query 'cluster.endpoint' --output text
    Passed directly to the Karpenter Helm chart so the controller can talk to Kubernetes.
  EOT
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = <<-EOT
    Base64-encoded CA certificate for your cluster (used by the Kubernetes/Helm Terraform providers).
    CLI: aws eks describe-cluster --name <name> --query 'cluster.certificateAuthority.data' --output text
  EOT
  type        = string
}

variable "existing_node_group_name" {
  description = <<-EOT
    Name of your EXISTING managed node group.
    Karpenter controller pods are pinned to this node group via nodeAffinity so that
    the Karpenter pods themselves never land on Karpenter-managed nodes (would cause a
    chicken-and-egg problem if those nodes get terminated).
    Find it: AWS Console → EKS → <cluster> → Compute → Node groups
  EOT
  type        = string
}

variable "karpenter_version" {
  description = <<-EOT
    Karpenter Helm chart version to install (always pin this in production!).
    Latest releases: https://github.com/aws-karpenter/karpenter/releases
    Example: "1.0.6"
  EOT
  type        = string
  default     = "1.0.6"
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace where Karpenter controller pods will run"
  type        = string
  default     = "kube-system"
}

# ---- Node pool sizing controls -----------------------------------------------

variable "on_demand_instance_families" {
  description = <<-EOT
    List of EC2 instance families allowed in the on-demand NodePool.
    More families = Karpenter has more choices = better bin-packing.
    For learning/dev keep this small to control AWS costs.
    Docs: https://instances.vantage.sh/  (compare families)
  EOT
  type        = list(string)
  default     = ["t3", "t3a", "m5"]
}

variable "on_demand_instance_sizes" {
  description = "Allowed instance sizes for the on-demand NodePool"
  type        = list(string)
  default     = ["small", "medium", "large"]
}

variable "spot_instance_families" {
  description = <<-EOT
    Spot NodePool should have MORE families than on-demand.
    If t3 spot capacity is unavailable, Karpenter falls back to t3a, m5, etc.
    Diversification is the key to reliable spot usage.
  EOT
  type        = list(string)
  default     = ["t3", "t3a", "m5", "m5a", "c5"]
}

variable "spot_instance_sizes" {
  description = "Allowed instance sizes for the spot NodePool (wider range than on-demand)"
  type        = list(string)
  default     = ["small", "medium", "large", "xlarge"]
}

variable "availability_zones" {
  description = <<-EOT
    AZs where Karpenter is allowed to launch nodes.
    MUST match your VPC subnet AZs, otherwise node launch will fail.
    Example: ["us-east-1a", "us-east-1b", "us-east-1c"]
  EOT
  type        = list(string)
}

variable "node_volume_size_gb" {
  description = "Root EBS volume size (GB) for Karpenter-managed nodes"
  type        = number
  default     = 20
}

variable "on_demand_cpu_limit" {
  description = <<-EOT
    Hard CPU ceiling for the on-demand NodePool across ALL nodes it manages.
    Acts as a cost safety net — Karpenter won't provision more than this total.
    E.g. 50 = max 50 vCPUs across all on-demand Karpenter nodes combined.
  EOT
  type        = number
  default     = 50
}

variable "spot_cpu_limit" {
  description = "Hard CPU ceiling for the spot NodePool"
  type        = number
  default     = 50
}

# ---- Tagging -----------------------------------------------------------------

variable "tags" {
  description = "Common tags applied to every resource (use for cost allocation, team tracking, etc.)"
  type        = map(string)
  default     = {}
}
