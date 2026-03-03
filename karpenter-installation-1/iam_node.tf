# =============================================================================
# iam_node.tf — Step 2: IAM role for EC2 NODES that Karpenter creates
# =============================================================================
#
# MENTAL MODEL FOR YOUR TEAM:
#   The CONTROLLER role (iam_controller.tf) gives the Karpenter Pod permission
#   to CALL AWS APIs.
#
#   The NODE role (this file) is a different role attached to the EC2 INSTANCES
#   that Karpenter launches. Those instances need permission to:
#     - Join the EKS cluster
#     - Pull container images from ECR
#     - Configure pod networking (VPC CNI)
#     - Be managed via AWS Systems Manager (SSM)
#
#   Trust policy here uses "ec2.amazonaws.com" (not "pods.eks.amazonaws.com")
#   because this role is assumed by EC2 instances, not Kubernetes pods.
#
# Terraform Registry references:
#   aws_iam_role:                     https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
#   aws_iam_role_policy_attachment:   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
#   aws_eks_access_entry:             https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry

# --------------------------------------------------------------------------
# 2A. Trust policy — EC2 instances can assume this role
# --------------------------------------------------------------------------
data "aws_iam_policy_document" "karpenter_node_assume" {
  statement {
    sid     = "AllowEC2ToAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type = "Service"
      # ec2.amazonaws.com = the EC2 service itself assumes this role when
      # launching an instance with an instance profile.
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------
# 2B. The IAM Role for nodes
# --------------------------------------------------------------------------
resource "aws_iam_role" "karpenter_node" {
  name               = local.karpenter_node_role_name
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume.json

  tags = {
    Name = local.karpenter_node_role_name
  }
}

# --------------------------------------------------------------------------
# 2C. Attach AWS-managed policies (no custom policy needed here)
# --------------------------------------------------------------------------
# These are pre-built AWS policies — we just attach them, not define them.
# "for_each" lets us attach multiple policies without copy-pasting blocks.
# Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/for_each

locals {
  # Map of label → policy ARN for each required node policy
  node_policies = {
    # Allows the kubelet to: register with EKS, update node status, get cluster config
    eks_worker_node = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

    # Allows kubelet to pull container images from ECR (your app Docker images)
    ecr_pull = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"

    # Allows the AWS VPC CNI plugin to: assign pod IP addresses, manage ENIs
    # This is critical — without it, pods can't get network addresses
    cni = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

    # Allows AWS Systems Manager to: run commands, collect logs, patch nodes
    # Useful for debugging without SSH access
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = local.node_policies

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

# --------------------------------------------------------------------------
# 2D. EKS Access Entry — allows Karpenter-created nodes to JOIN the cluster
# --------------------------------------------------------------------------
# This is the modern replacement for the aws-auth ConfigMap approach.
# It tells the EKS control plane: "nodes using this IAM role are trusted nodes".
#
# Type EC2_LINUX = this access entry is for Linux EC2 worker nodes.
# Other types: EC2_WINDOWS, FARGATE_LINUX, STANDARD (for kubectl users).
#
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  # system:nodes group is what grants worker node permissions in Kubernetes RBAC
  kubernetes_groups = ["system:nodes"]

  tags = {
    Name = "${local.cluster_name}-karpenter-node-access"
  }

  depends_on = [aws_iam_role_policy_attachment.karpenter_node]
}
