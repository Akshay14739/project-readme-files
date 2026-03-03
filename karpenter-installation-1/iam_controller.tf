# =============================================================================
# iam_controller.tf — Step 1: IAM role for the Karpenter CONTROLLER POD
# =============================================================================
#
# MENTAL MODEL FOR YOUR TEAM:
#   The Karpenter controller runs as a Kubernetes Pod.
#   That Pod needs to call AWS APIs (create EC2 instances, read SQS, etc.)
#   WITHOUT storing AWS credentials inside the container.
#
#   The modern solution is EKS Pod Identity (or IRSA).
#   Pod Identity = "this Kubernetes Service Account may assume this IAM Role"
#   The chain is:  Pod → Service Account → IAM Role → AWS Permissions
#
#   3 resources make this work:
#     1. aws_iam_role            (the role itself + trust policy)
#     2. aws_iam_policy          (what the role is ALLOWED to do)
#     3. aws_iam_role_policy_attachment  (glue the two together)
#   + 1 EKS resource:
#     4. aws_eks_pod_identity_association  (links SA → IAM Role)
#
# Terraform Registry references:
#   aws_iam_role:                   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
#   aws_iam_policy:                 https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
#   aws_iam_role_policy_attachment: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
#   aws_eks_pod_identity_association: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association

# --------------------------------------------------------------------------
# 1A. Trust policy document (who can ASSUME this role)
# --------------------------------------------------------------------------
# aws_iam_policy_document is a DATA source — it generates JSON without creating anything.
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "karpenter_controller_assume" {
  statement {
    sid     = "AllowEKSPodIdentity"
    actions = [
      "sts:AssumeRole",       # Core action: allows someone to get temporary credentials
      "sts:TagSession",       # Adds session tags for fine-grained audit logging
    ]
    effect = "Allow"

    principals {
      type = "Service"
      # This is the AWS service principal for EKS Pod Identity.
      # It tells AWS: "only the EKS Pod Identity service can assume this role".
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------
# 1B. The IAM Role itself
# --------------------------------------------------------------------------
resource "aws_iam_role" "karpenter_controller" {
  name               = local.karpenter_controller_role_name
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume.json

  tags = {
    Name = local.karpenter_controller_role_name
  }
}

# --------------------------------------------------------------------------
# 1C. The permissions policy (~500 lines of EC2/SQS/IAM permissions)
# --------------------------------------------------------------------------
# These permissions come directly from the official Karpenter CloudFormation template.
# Source: https://github.com/aws/karpenter-provider-aws/blob/main/website/content/en/docs/getting-started/getting-started-with-karpenter/cloudformation.yaml
#
# Categories of permissions:
#   - EC2 provisioning:     RunInstances, CreateFleet, CreateLaunchTemplate
#   - EC2 lifecycle:        TerminateInstances, DeleteLaunchTemplate
#   - Instance discovery:   DescribeInstanceTypes, DescribeAvailabilityZones
#   - SQS polling:          ReceiveMessage, DeleteMessage (interruption handling)
#   - IAM management:       CreateInstanceProfile, AddRoleToInstanceProfile
#   - SSM/Pricing:          GetParameter (for AMI IDs and pricing data)
#   - EKS discovery:        DescribeCluster (so Karpenter knows its own cluster)

data "aws_iam_policy_document" "karpenter_controller" {

  # --- EC2: Launch instances (scoped to cluster-tagged resources) -----------
  statement {
    sid    = "AllowScopedEC2InstanceActions"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
    ]
    resources = [
      "arn:aws:ec2:${local.region}::image/*",
      "arn:aws:ec2:${local.region}::snapshot/*",
      "arn:aws:ec2:${local.region}:*:security-group/*",
      "arn:aws:ec2:${local.region}:*:subnet/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:capacity-reservation/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
    ]
  }

  # --- EC2: Launch templates ------------------------------------------------
  statement {
    sid    = "AllowScopedEC2LaunchTemplateActions"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${local.region}:*:launch-template/*",
    ]
  }

  # --- EC2: Tagging new resources at creation time -------------------------
  statement {
    sid    = "AllowScopedEC2InstanceActionsWithTags"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
    ]
    resources = [
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # --- EC2: Tag existing Karpenter-owned resources --------------------------
  statement {
    sid    = "AllowScopedResourceCreationTagging"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
    ]
    resources = [
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}"
      values   = ["owned"]
    }
  }

  # --- EC2: Terminate/delete Karpenter-owned resources ----------------------
  statement {
    sid    = "AllowScopedDeletion"
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
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  # --- EC2: Read-only discovery (instance types, AZs, subnets, etc.) -------
  statement {
    sid    = "AllowInstanceDiscovery"
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
    resources = ["*"]   # Describe actions don't support resource-level restrictions
  }

  # --- SQS: Poll the interruption queue ------------------------------------
  # Karpenter polls this queue every ~10s to detect spot interruptions.
  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }

  # --- IAM: Manage instance profiles for nodes -----------------------------
  # Karpenter creates EC2 instance profiles to attach the node IAM role.
  statement {
    sid    = "AllowPassNodeIAMRole"
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

  statement {
    sid    = "AllowPassNodeIAMRoleToEC2"
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
  }

  # --- EKS: Read cluster config for Karpenter self-discovery ---------------
  statement {
    sid    = "AllowEKSClusterDiscovery"
    effect = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.cluster_name}"]
  }

  # --- SSM + Pricing: Fetch AMI IDs and spot pricing -----------------------
  statement {
    sid    = "AllowSSMReadForAMI"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "pricing:GetProducts",
    ]
    resources = ["*"]
  }
}

# Create the actual managed IAM policy from the document above
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.cluster_name}-karpenter-controller-policy"
  description = "Permissions for Karpenter controller to provision EC2 nodes in cluster ${local.cluster_name}"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# --------------------------------------------------------------------------
# 1D. EKS Pod Identity Association
# --------------------------------------------------------------------------
# This is the bridge between Kubernetes and IAM.
# It says: "The Kubernetes Service Account named 'karpenter' in namespace
#           'kube-system' may assume the IAM role we created above."
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association
resource "aws_eks_pod_identity_association" "karpenter_controller" {
  cluster_name    = local.cluster_name
  namespace       = var.karpenter_namespace
  service_account = "karpenter"              # Must match serviceAccount.name in Helm values
  role_arn        = aws_iam_role.karpenter_controller.arn

  # The Helm chart must be deployed after this association exists
  depends_on = [aws_iam_role_policy_attachment.karpenter_controller]
}
