# =============================================================================
# helm_karpenter.tf — Step 4: Deploy Karpenter controller via Helm
# =============================================================================
#
# MENTAL MODEL FOR YOUR TEAM:
#   Helm is a package manager for Kubernetes (like apt/brew but for K8s).
#   A "Helm release" = an installation of a Helm chart into your cluster.
#   The chart is hosted on AWS's public ECR registry (OCI format).
#
#   Key Helm values we pass:
#     settings.clusterName         = tells Karpenter which cluster it belongs to
#     settings.interruptionQueue   = the SQS queue from interruption.tf
#     serviceAccount.name          = must match the name in Pod Identity Association
#     controller.nodeAffinity      = pins Karpenter pods to EXISTING managed nodes
#                                    (not Karpenter nodes — avoids chicken-and-egg)
#
# Terraform Registry:
#   helm_release: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  namespace  = var.karpenter_namespace

  # kube-system already exists in every EKS cluster, so don't try to create it
  create_namespace = false

  # ---- Core settings -------------------------------------------------------
  # These `set` blocks pass values to the Helm chart.
  # Equivalent to: helm install karpenter ... --set key=value

  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  # The SQS queue name Karpenter polls for spot interruption messages
  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter_interruption.name
  }

  # ---- Service Account settings -------------------------------------------
  # Karpenter's Helm chart creates a ServiceAccount for the controller pods.
  # The name here must EXACTLY match `service_account` in the Pod Identity Association.

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "karpenter"
  }

  # ---- Node Affinity: pin Karpenter to EXISTING managed nodes -------------
  # This is CRITICAL. Karpenter pods must NOT run on nodes that Karpenter manages.
  # If a Karpenter-managed node gets terminated, the Karpenter pod would die too —
  # and then nothing could bring up the replacement node.
  #
  # Solution: use nodeAffinity to force Karpenter pods onto the MANAGED node group
  # (the one created by your EKS cluster, not by Karpenter).

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

  # ---- Resource requests for the controller pod ---------------------------
  # Prevents Karpenter from consuming too much CPU/Memory on your management nodes.

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # ---- Dependency ordering -------------------------------------------------
  # Terraform's depends_on ensures all IAM, SQS, and Pod Identity resources
  # are created BEFORE the Helm chart is deployed. Without this, the controller
  # would start without permissions and crash.
  #
  # `depends_on` is a meta-argument, not a provider feature.
  # Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on

  depends_on = [
    aws_iam_role.karpenter_controller,
    aws_iam_policy.karpenter_controller,
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_eks_pod_identity_association.karpenter_controller,
    aws_iam_role.karpenter_node,
    aws_iam_role_policy_attachment.karpenter_node,
    aws_eks_access_entry.karpenter_node,
    aws_sqs_queue.karpenter_interruption,
    aws_sqs_queue_policy.karpenter_interruption,
    aws_cloudwatch_event_rule.karpenter_spot_interruption,
  ]
}
