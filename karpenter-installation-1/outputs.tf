# =============================================================================
# outputs.tf — Values Terraform prints after `apply` and stores in state
# =============================================================================
# WHY OUTPUTS MATTER:
#   - `terraform output` lets teammates query values without reading code
#   - Other Terraform projects can consume these via `terraform_remote_state`
#   - CI/CD pipelines use outputs to wire systems together
#
# Docs: https://developer.hashicorp.com/terraform/language/values/outputs

output "karpenter_controller_role_arn" {
  description = "ARN of the IAM role assumed by the Karpenter controller pod (Step 1)"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_controller_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = aws_iam_role.karpenter_controller.name
}

output "karpenter_node_role_arn" {
  description = "ARN of the IAM role attached to Karpenter-provisioned EC2 nodes (Step 2)"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_role_name" {
  description = "Name of the Karpenter node IAM role — use this in EC2NodeClass Terraform/YAML"
  value       = aws_iam_role.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for spot interruption handling — used in Helm values and EC2NodeClass"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_interruption_queue_arn" {
  description = "SQS queue ARN for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}

output "karpenter_helm_metadata" {
  description = "Metadata from the Karpenter Helm release (name, version, namespace, status)"
  value = {
    name      = helm_release.karpenter.name
    namespace = helm_release.karpenter.namespace
    version   = helm_release.karpenter.version
    status    = helm_release.karpenter.status
  }
}

output "next_steps" {
  description = "Reminder: what to deploy AFTER this Terraform run"
  value       = <<-EOT
    Karpenter controller is running. Now deploy K8s manifests:
      1. kubectl apply -f k8s-manifests/ec2nodeclass.yaml
      2. kubectl apply -f k8s-manifests/nodepool-ondemand.yaml
      3. kubectl apply -f k8s-manifests/nodepool-spot.yaml

    Verify:
      kubectl get ec2nodeclass
      kubectl get nodepools
      kubectl logs -n ${var.karpenter_namespace} -l app.kubernetes.io/name=karpenter -f
  EOT
}
