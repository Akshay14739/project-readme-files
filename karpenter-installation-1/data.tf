# =============================================================================
# data.tf — Read existing infrastructure without managing it
# =============================================================================
# WHY DATA SOURCES?
#   A `data` block reads existing AWS resources.
#   A `resource` block creates/manages resources.
#   We use data sources to reference the existing EKS cluster, IAM, account, etc.
#   This avoids re-creating things that already exist.
#
# Docs: https://developer.hashicorp.com/terraform/language/data-sources

# --------------------------------------------------------------------------
# Current AWS account & region metadata
# --------------------------------------------------------------------------

# aws_caller_identity → who is running terraform (account ID, ARN, user ID)
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

# aws_region → the region set in your AWS provider block
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region
data "aws_region" "current" {}

# --------------------------------------------------------------------------
# Existing EKS cluster — reads cluster metadata Karpenter needs
# --------------------------------------------------------------------------
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# --------------------------------------------------------------------------
# Locals — computed values reused across multiple files
# --------------------------------------------------------------------------
# `locals` are like variables but derived from other values (not user inputs).
# Think of them as "calculated constants".
# Docs: https://developer.hashicorp.com/terraform/language/values/locals

locals {
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
  cluster_name = var.cluster_name

  # SQS queue name must match the cluster name (Karpenter convention).
  # AWS SQS name limit is 80 chars, so we truncate safely.
  sqs_queue_name = substr(var.cluster_name, 0, 80)

  # Karpenter controller IAM role name — unique per cluster.
  karpenter_controller_role_name = "${var.cluster_name}-karpenter-controller"

  # Karpenter node IAM role name — attached to EC2 instances Karpenter creates.
  karpenter_node_role_name = "${var.cluster_name}-karpenter-node"

  # The OIDC issuer URL is needed to build the trust relationship for Pod Identity.
  # This tells AWS "I trust tokens issued by THIS EKS cluster's OIDC provider".
  oidc_issuer_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  # Strip "https://" from the OIDC URL — IAM policies need the bare URL.
  oidc_provider = replace(local.oidc_issuer_url, "https://", "")
}
