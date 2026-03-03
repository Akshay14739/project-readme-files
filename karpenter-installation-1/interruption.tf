# =============================================================================
# interruption.tf — Step 3: SQS + EventBridge for spot interruption handling
# =============================================================================
#
# MENTAL MODEL FOR YOUR TEAM:
#   AWS gives you a 2-minute warning before terminating a spot instance.
#   This 2-minute window is what makes spot instances safe for production
#   IF you handle the warning correctly.
#
#   The flow:
#     AWS EventBridge (detects EC2 events)
#       → SQS Queue (buffers the warning message)
#         → Karpenter controller (polls queue every ~10s, cordons + drains node)
#           → New replacement node launched
#             → Pods rescheduled → Zero downtime
#
#   There are 4 EventBridge rules watching for:
#     1. AWS Health Events       (scheduled maintenance, hardware failure)
#     2. Spot Interruption       (AWS reclaiming spot capacity — the classic case)
#     3. Rebalance Recommendation (early signal BEFORE interruption warning)
#     4. Instance State Change   (unexpected terminations, stopped instances)
#
# Terraform Registry references:
#   aws_sqs_queue:                    https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue
#   aws_cloudwatch_event_rule:        https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule
#   aws_cloudwatch_event_target:      https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target
#   Note: "cloudwatch_event" is the legacy Terraform resource name for EventBridge.

# --------------------------------------------------------------------------
# 3A. SQS Queue
# --------------------------------------------------------------------------
resource "aws_sqs_queue" "karpenter_interruption" {
  name = local.sqs_queue_name

  # 5 minutes (300s) message retention.
  # Rationale: spot warnings are only valid for 2 minutes. Messages older than
  # 5 minutes are stale — no point keeping them. Karpenter polls frequently enough.
  message_retention_seconds = 300

  # Encrypt messages at rest (security best practice).
  # SQS_MANAGED = AWS manages the key (simpler than custom KMS).
  sqs_managed_sse_enabled = true

  tags = {
    Name = local.sqs_queue_name
  }
}

# --------------------------------------------------------------------------
# 3B. SQS Queue Policy — who can SEND messages to this queue
# --------------------------------------------------------------------------
# This is a resource-based policy (attached to the queue, like an S3 bucket policy).
# It allows: EventBridge to send event notifications to the queue.
# It denies:  Any HTTP (non-HTTPS) requests for security hardening.

data "aws_iam_policy_document" "karpenter_sqs_policy" {
  # ALLOW: EventBridge and SQS service to send messages
  statement {
    sid    = "AllowEventBridgeAndSQSToSend"
    effect = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter_interruption.arn]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",   # EventBridge
        "sqs.amazonaws.com",      # SQS (for cross-account/testing scenarios)
      ]
    }
  }

  # DENY: Any request NOT using HTTPS (TLS enforcement)
  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    actions = ["sqs:*"]
    resources = [aws_sqs_queue.karpenter_interruption.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy    = data.aws_iam_policy_document.karpenter_sqs_policy.json
}

# --------------------------------------------------------------------------
# Helper local: short cluster name for EventBridge rule names (80 char limit)
# --------------------------------------------------------------------------
locals {
  short_cluster_name = substr(local.cluster_name, 0, 20)
}

# --------------------------------------------------------------------------
# 3C. EventBridge Rule 1: AWS Health Events
# --------------------------------------------------------------------------
# Catches: scheduled maintenance, hardware failures, network degradation.
# These give you MORE than 2 minutes of warning — sometimes hours/days.
# Perfect for gracefully draining before planned maintenance.

resource "aws_cloudwatch_event_rule" "karpenter_health" {
  name        = "${local.short_cluster_name}-karpenter-health"
  description = "Karpenter: AWS Health events for EC2 instances"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_health" {
  rule = aws_cloudwatch_event_rule.karpenter_health.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# --------------------------------------------------------------------------
# 3D. EventBridge Rule 2: EC2 Spot Interruption Warning (THE CRITICAL ONE)
# --------------------------------------------------------------------------
# This fires exactly 2 minutes before AWS terminates your spot instance.
# Karpenter detects this message → cordons the node → moves pods → launches replacement.
# "Two minutes is all you need IF Karpenter is listening." — transcript

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${local.short_cluster_name}-karpenter-spot"
  description = "Karpenter: EC2 Spot instance interruption warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# --------------------------------------------------------------------------
# 3E. EventBridge Rule 3: EC2 Instance Rebalance Recommendation
# --------------------------------------------------------------------------
# AWS sends this BEFORE the interruption warning.
# It's a proactive signal: "this instance has elevated risk of interruption soon."
# Karpenter can optionally start pre-provisioning a replacement immediately.

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${local.short_cluster_name}-karpenter-rebalance"
  description = "Karpenter: EC2 rebalance recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# --------------------------------------------------------------------------
# 3F. EventBridge Rule 4: EC2 Instance State Change Notification
# --------------------------------------------------------------------------
# Catches unexpected state changes: pending→running, running→stopping, running→terminated.
# Helps Karpenter update its internal node state accurately.
# Also catches manual terminations someone ran outside of Karpenter.

resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  name        = "${local.short_cluster_name}-karpenter-state"
  description = "Karpenter: EC2 instance state change notifications"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}
