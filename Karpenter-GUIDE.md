# Karpenter on EKS — Terraform Script: Team Explanation Guide

## How to Read This Document
This guide explains:
1. The mental model behind the Terraform script structure
2. How to navigate Terraform documentation to explain each resource
3. The 4-step architecture and why each step exists
4. Common questions your team will ask

---

## The 4-Step Architecture: Why These Files Exist

Every Karpenter installation requires four layers. Each layer answers one question:

```
Step 1 (iam_controller.tf)   → WHO runs the Karpenter software? (controller pod permissions)
Step 2 (iam_node.tf)         → WHO are the workers Karpenter creates? (EC2 node permissions)
Step 3 (interruption.tf)     → HOW do we handle spot terminations? (SQS + EventBridge)
Step 4 (helm_karpenter.tf)   → HOW do we install the controller itself? (Helm release)
```

After those 4 Terraform steps, you apply 3 Kubernetes manifests:
```
ec2nodeclass.yaml       → HOW to build nodes (AMI, subnets, disk, security groups)
nodepool-ondemand.yaml  → WHAT on-demand nodes can exist (instance families, sizes, limits)
nodepool-spot.yaml      → WHAT spot nodes can exist (more families for availability)
```

---

## How to Navigate the Terraform Registry for Each Resource

When your team asks "where did this come from?", use this pattern:

### 1. Go to the Terraform Registry
**URL:** `https://registry.terraform.io/providers/hashicorp/aws/latest/docs`

### 2. Search for the resource name
Every `resource "aws_XYZ"` in the code maps directly to a page:

| Code Resource | Registry Search | Key Arguments to Explain |
|---|---|---|
| `aws_iam_role` | "aws_iam_role" | `assume_role_policy`, `name` |
| `aws_iam_policy` | "aws_iam_policy" | `policy` (JSON document) |
| `aws_iam_role_policy_attachment` | "aws_iam_role_policy_attachment" | `role`, `policy_arn` |
| `aws_eks_pod_identity_association` | "aws_eks_pod_identity_association" | `service_account`, `role_arn` |
| `aws_eks_access_entry` | "aws_eks_access_entry" | `type`, `principal_arn` |
| `aws_sqs_queue` | "aws_sqs_queue" | `message_retention_seconds`, `sqs_managed_sse_enabled` |
| `aws_cloudwatch_event_rule` | "aws_cloudwatch_event_rule" | `event_pattern` |
| `helm_release` | search in Helm provider | `repository`, `set` blocks |

### 3. The Registry page structure
Every resource page has the same layout:
```
Example Usage         → Copy-paste starter code
Argument Reference    → Every argument explained (required vs optional)
Attributes Reference  → Values you can read AFTER the resource is created
Import               → How to import existing resources
```

### 4. Key concept: data vs resource
```hcl
# data source = READ existing things
data "aws_eks_cluster" "cluster" { name = "my-cluster" }

# resource = CREATE/MANAGE new things
resource "aws_sqs_queue" "karpenter" { name = "my-queue" }
```

---

## Step-by-Step Thought Process: How This Script Was Written

### Step 1: Read the Official Karpenter Getting Started Guide
URL: `https://karpenter.sh/docs/getting-started/migrating-from-cas/`

The guide lists everything needed in bash/CLI commands. The Terraform script is just
those same steps written as `resource` blocks instead of `aws CLI` commands.

**Example mapping:**
```bash
# Karpenter docs (CLI):
aws iam create-role --role-name KarpenterControllerRole-${CLUSTER_NAME} ...

# This script (Terraform):
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"
  ...
}
```

### Step 2: Identify the IAM requirements (2 roles, not 1)
The key insight is that Karpenter needs TWO separate IAM roles:

```
Role 1: Controller Role
  - WHO assumes it: the Karpenter Pod (via EKS Pod Identity)
  - WHAT it does: calls EC2 API to create/terminate instances
  - Trust principal: pods.eks.amazonaws.com

Role 2: Node Role
  - WHO assumes it: EC2 instances that Karpenter launches
  - WHAT it does: joins EKS cluster, pulls ECR images, configures networking
  - Trust principal: ec2.amazonaws.com
```

This distinction is the #1 thing people get confused about.

### Step 3: Understand why SQS + EventBridge matters
Without the interruption queue, spot instances are risky in production.
With it, you get a 2-minute warning and Karpenter handles the replacement.

The EventBridge → SQS → Karpenter chain is what makes spot instances
viable for real workloads.

### Step 4: Helm deploys LAST with `depends_on`
The Helm chart is the final step. It must come after all IAM and SQS
resources exist, or the Karpenter pods will start without permissions and crash.

Terraform's `depends_on` meta-argument explicitly declares this ordering.

---

## Key Terraform Concepts to Explain to Your Team

### `for_each` (used in iam_node.tf)
```hcl
locals {
  node_policies = {
    eks_worker_node = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    ecr_pull        = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = local.node_policies   # Creates one resource per map entry
  role     = aws_iam_role.karpenter_node.name
  policy_arn = each.value          # each.value = the ARN, each.key = "eks_worker_node" etc.
}
```
**Explain:** Instead of copy-pasting the same block 4 times, `for_each` loops over a map.
If you add a 5th policy, you just add one line to the map.

### `locals` (used in data.tf)
```hcl
locals {
  cluster_name = var.cluster_name           # Alias for a variable
  sqs_queue_name = substr(var.cluster_name, 0, 80)  # Derived/computed value
}
```
**Explain:** Locals are like variables but derived from other values. They prevent
repeating the same expression in 10 different files.

### `data` sources (used in data.tf)
```hcl
data "aws_caller_identity" "current" {}
# Then use: data.aws_caller_identity.current.account_id
```
**Explain:** Data sources READ existing AWS state without creating anything.
Perfect for reading things that already exist (your EKS cluster, account ID, etc.)

### `depends_on` (used in helm_karpenter.tf)
```hcl
resource "helm_release" "karpenter" {
  depends_on = [
    aws_iam_role.karpenter_controller,
    aws_sqs_queue.karpenter_interruption,
  ]
}
```
**Explain:** Terraform normally figures out order from resource references.
But if the Helm chart doesn't directly reference an IAM role resource
(it takes the role name as a string value), Terraform won't know to wait.
`depends_on` forces explicit ordering.

---

## Deployment Order & Verification Commands

### Deploy
```bash
# 1. Infrastructure (this Terraform)
terraform init
terraform plan
terraform apply

# 2. Kubernetes configuration layer
kubectl apply -f k8s-manifests/ec2nodeclass.yaml
kubectl apply -f k8s-manifests/nodepool-ondemand.yaml
kubectl apply -f k8s-manifests/nodepool-spot.yaml
```

### Verify
```bash
# Controller is running?
kubectl get pods -n kube-system | grep karpenter

# NodeClass is ready?
kubectl get ec2nodeclass
# STATUS column should show: Ready=True

# NodePools are ready?
kubectl get nodepools

# Watch Karpenter logs in real time
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f | grep -E "INFO|ERROR|WARN"

# Watch node provisioning (after deploying a test workload)
kubectl get nodeclaims -w

# Test on-demand scaling
kubectl run test-ondemand --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"karpenter.sh/capacity-type":"on-demand"}}}'

# Test spot scaling
kubectl run test-spot --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"karpenter.sh/capacity-type":"spot"}}}'
```

---

## Required Subnet/Security Group Tags

**This is the most common setup mistake.** Karpenter discovers subnets and
security groups via tags — NOT hardcoded IDs.

```bash
# Tag your PRIVATE subnets (Karpenter will only launch nodes here):
aws ec2 create-tags \
  --resources subnet-XXXXXXXX subnet-YYYYYYYY subnet-ZZZZZZZZ \
  --tags \
    Key=kubernetes.io/role/internal-elb,Value=1 \
    Key=karpenter.sh/discovery,Value=YOUR_CLUSTER_NAME

# Tag your EKS cluster security group:
CLUSTER_SG=$(aws eks describe-cluster \
  --name YOUR_CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

aws ec2 create-tags \
  --resources $CLUSTER_SG \
  --tags Key=karpenter.sh/discovery,Value=YOUR_CLUSTER_NAME

# The "owned" vs "shared" tag issue from the transcript:
# Karpenter REQUIRES: kubernetes.io/cluster/CLUSTER_NAME=owned on subnets
# (not "shared" — that's for EKS managed node groups only)
aws ec2 create-tags \
  --resources subnet-XXXXXXXX subnet-YYYYYYYY subnet-ZZZZZZZZ \
  --tags Key=kubernetes.io/cluster/YOUR_CLUSTER_NAME,Value=owned
```

---

## Common Team Questions

**Q: Why don't we put node pools in Terraform?**
A: Node pools are Kubernetes CRDs (Custom Resources). Terraform can manage them
via the `kubernetes_manifest` resource, but keeping them as plain YAML gives teams
more flexibility to adjust scaling behavior without a full Terraform apply cycle.

**Q: Can we have multiple EC2NodeClasses?**
A: Yes. One NodeClass per environment, or per team with different storage/AMI needs.
Each NodePool references one NodeClass via `nodeClassRef`.

**Q: What happens if we hit the CPU limit in a NodePool?**
A: Karpenter stops provisioning new nodes. Pending pods stay pending until existing
nodes free up capacity. This is intentional — it prevents runaway bills.

**Q: How do we upgrade Karpenter?**
A: Change `karpenter_version` in `terraform.tfvars` and run `terraform apply`.
The Helm release resource handles the upgrade. Always check the Karpenter
changelog first: `https://github.com/aws-karpenter/karpenter/releases`

**Q: owned vs shared subnet tags — what's the difference?**
A: From the transcript: EKS managed node groups work with both. Karpenter REQUIRES
`owned`. Use `owned` for all node-facing subnets if using Karpenter.
