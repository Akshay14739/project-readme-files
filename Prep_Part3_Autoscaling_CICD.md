# Interview Preparation Guide: Part 3
## Advanced Autoscaling & Production CI/CD Pipeline
**Sections 17 & 21: Karpenter, GitHub Actions, ArgoCD**

**Date**: February 9, 2026  
**Status**: Complete Interview Preparation Guide

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Section 17: Karpenter - Advanced Node Autoscaling](#section-17-karpenter---advanced-node-autoscaling)
3. [Section 21: DevOps CI/CD with GitHub Actions & ArgoCD](#section-21-devops-cicd-pipeline)
4. [Complete Automation Workflow](#complete-automation-workflow)
5. [Interview Q&A - Part 3](#interview-qa---part-3)

---

## Executive Summary

You implemented **enterprise-grade automation** for:

✅ **Cluster Autoscaling** - Karpenter (seconds vs minutes, cost optimization with Spot)  
✅ **Continuous Integration** - GitHub Actions (build, test, push to ECR)  
✅ **Continuous Deployment** - ArgoCD (GitOps, automatic sync, Helm integration)  
✅ **OIDC Authentication** - Secure AWS access without hardcoded keys  
✅ **Zero-Downtime Deployments** - Rolling updates with automatic rollback  

---

## Section 17: Karpenter - Advanced Node Autoscaling

### Problem: Traditional Node Autoscaling is Slow

```
┌─────────────────────────────────────────────────────────────────┐
│ CLUSTER AUTOSCALER (Traditional Kubernetes)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                │
│ Time 0:00  Pod fails to schedule (no capacity)                │
│            ↓                                                   │
│ Time 0:30  Autoscaler detects unscheduled pods                │
│            ↓                                                   │
│ Time 0:45  Request EC2 instances from Auto Scaling Group (ASG)│
│            ↓                                                   │
│ Time 2:00  EC2 instances launched & booted                    │
│            ↓                                                   │
│ Time 2:30  Nodes registered with Kubernetes                   │
│            ↓                                                   │
│ Time 3:00  Pods scheduled and running                         │
│            ↓                                                   │
│ Result:    3 MINUTES from request to running pods ❌ SLOW     │
│            User timeout, customer impact                       │
│                                                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ KARPENTER (Modern Node Provisioning)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                │
│ Time 0:00  Pod fails to schedule (no capacity)                │
│            ↓                                                   │
│ Time 0:02  Karpenter detects unschedulable pods               │
│            ↓                                                   │
│ Time 0:04  Makes API call to EC2 (parallel provisioning)      │
│            ↓                                                   │
│ Time 0:15  EC2 instances launched & booted                    │
│            ↓                                                   │
│ Time 0:20  Nodes registered with Kubernetes                   │
│            ↓                                                   │
│ Time 0:25  Pods scheduled and running                         │
│            ↓                                                   │
│ Result:    25 SECONDS from request to running pods ✅ FAST!  │
│            Near zero interruption to user                      │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

### Karpenter Architecture

```
KARPENTER PROVISIONING FLOW
═════════════════════════════════════════════════════════════════

1. MONITORING PHASE
   ├─ Karpenter controller runs in kube-system namespace
   ├─ Watches for unschedulable pods in cluster
   ├─ Also watches for underutilized nodes
   └─ Continuously evaluates cluster utilization

2. DECISION MAKING
   When pod fails to schedule:
   ├─ Analyzes pod requirements:
   │  ├─ CPU: 500m
   │  ├─ Memory: 512Mi
   │  ├─ Instance type hints: t3, t4, m5 (optional)
   │  └─ Zone preference: any AZ
   │
   ├─ Checks NodePool configuration:
   │  ├─ On-Demand pool: cheap, reliable (primary)
   │  ├─ Spot pool: cheaper, risk of interruption (secondary)
   │  └─ Instance type recommendations: consolidate or split
   │
   └─ Selects best instance offering:
      └─ On-Demand: t3.medium (smallest that fits)
         Cost: $0.0416/hour
         Launch time: ~15 seconds

3. PROVISIONING PHASE
   ├─ Create EC2 instances (using EC2 FleetRequest API)
   ├─ Wait for boot (cloud-init runs, kubelet starts)
   ├─ Register with Kubernetes (CSR signed automatically)
   └─ Kubelet joins cluster

4. SCHEDULING PHASE
   ├─ New node joins cluster
   ├─ kube-scheduler places waiting pods on new node
   ├─ Pods transition: Pending → Running
   └─ Application starts

5. CONSOLIDATION PHASE
   Periodically (every 30 seconds):
   ├─ Identify underutilized nodes
   ├─ Drain pods gracefully
   ├─ Delete empty nodes
   ├─ Cost optimization ✅
   └─ Removes Spot instances before interruption

════════════════════════════════════════════════════════════════════
```

**Detailed Step-by-Step: Karpenter Node Provisioning (Pod to Running)**

```
STEP 1: POD CREATED, SCHEDULER EVALUATES
└─ Developer applies: kubectl apply -f deployment.yaml
└─ Deployment controller creates pods
└─ Scheduler receives: Pod.catalog-5dcb7bb4f-xyz pending
   ├─ Pod requirements: CPU 800m, Memory 1Gi, zone: any AZ
   ├─ Pod requests: should run on a node ✅
   └─ Current cluster nodes:
      ├─ Node 1: 2CPU, 2Gi memory → FULL (other pods hogging resources)
      ├─ Node 2: 1CPU, 0.5Gi memory → FULL (no room)
      └─ Result: No node fits this pod ❌ UNSCHEDULABLE

STEP 2: KARPENTER DETECTS UNSCHEDULABLE POD
└─ Karpenter controller watching: karpenter.sh/capacity-type = on-demand
└─ Event: Pod.catalog pending > 1 second in Pending state
└─ Query: Why is it pending?
   └─ API call: kubectl describe pod catalog-5dcb7bb4f-xyz
   └─ Response: "0/2 nodes are available: 2 Insufficient cpu"
└─ Decision trigger: YES, we need more capacity
└─ Consolidation check: Can we remove any underutilized nodes first?
   ├─ Node 1: 40% utilized → No (still busy)
   ├─ Node 2: 25% utilized → No (has capacity for small pods)
   └─ Result: Cannot consolidate, must provision new
└─ Karpenter status: **PROVISIONING MODE**

STEP 3: SELECT INSTANCE TYPE & OFFERING
└─ Karpenter evaluates: what machines can fit this pod?
   ├─ Pod needs: CPU 800m, Memory 1Gi
   ├─ NodePool configuration:
   │  ├─ Family: [t3, t4, m5, m6, c5, c6]
   │  ├─ Capacity type: on-demand (primary)
   │  ├─ Zone: us-east-1a, us-east-1b, us-east-1c
   │  └─ Instance sizes: t3.small to m5.2xlarge
   │
   └─ Instance fit analysis:
      ├─ t3.micro: 1 CPU, 1Gi RAM → fits, cheapest $0.0104/hr
      ├─ t3.small: 2 CPU, 2Gi RAM → fits, $0.0208/hr
      ├─ m5.large: 2 CPU, 8Gi RAM → fits, $0.096/hr
      │
      └─ Best choice: t3.small
         ├─ Reason: fits pod requests (800m < 2000m CPU available)
         ├─ Consolidation-friendly: other pods can fit on it
         ├─ Cost: $0.0208/hour vs $0.0416/hour for larger
         └─ AWS region: us-east-1b (default zone in config)

STEP 4: REQUEST EC2 INSTANCES (AWS API CALL)
└─ Karpenter initiates: EC2 Fleet Request API call
└─ Request parameters:
   ├─ Action: CreateFleet
   ├─ InstanceType: t3.small
   ├─ SubnetId: subnet-1a2b3c4d (us-east-1b)
   ├─ ImageId: ami-0a3c5c (Amazon EKS Optimized AMI)
   ├─ IamInstanceProfile: karpenter-node-role
   ├─ SecurityGroupIds: [sg-1a2b3c4d (EKS node security group)]
   ├─ TagSpecifications:
   │  ├─ karpenter.sh/provisioner: default
   │  ├─ karpenter.sh/capacity-type: on-demand
   │  ├─ kubernetes.io/cluster/kalyan-cluster: owned
   │  └─ Name: karpenter-node-1a2b3c4d
   │
   └─ Result: Fleet starts launching instance
      ├─ AWS state: pending (instance being allocated)
      └─ Karpenter state: WAITING_FOR_INSTANCE

STEP 5: EC2 INSTANCE BOOTS (AWS INFRASTRUCTURE) ⏱️ ~10-15 seconds
└─ EC2 hypervisor allocates vCPU & memory
└─ Instance starts booting
└─ Boot sequence:
   ├─ t3.small: 2 vCPU, 2Gi RAM allocated
   ├─ Network interface attached (eth0: private IP 10.0.2.100/24)
   ├─ Storage: 20Gi EBS gp3 volume (fast, optimized)
   ├─ Security group applied (allows kubelet port 10250, SSH 22)
   └─ Instance begins loading OS kernel
└─ AWS EC2 state: running ✅

STEP 6: CLOUD-INIT & KUBELET STARTUP ⏱️ ~5-10 seconds
└─ Linux kernel boots
└─ Cloud-init executes (user-data script from EKS AMI):
   ├─ Export environment variables:
   │  ├─ AWS_DEFAULT_REGION=us-east-1
   │  ├─ CLUSTER_NAME=kalyan-cluster
   │  ├─ KUBELET_CONFIG=/etc/kubernetes/kubelet/kubelet-config.json
   │  └─ NODE_ROLE=default (matches karpenter provisioner)
   │
   ├─ Bootstrap kubelet:
   │  ├─ Download kubeconfig from AWS API Server
   │  │  └─ endpoint: https://kalyan-cluster.eks.us-east-1.amazonaws.com
   │  ├─ Start kubelet service: systemctl start kubelet
   │  ├─ Register node with cluster: CSR (Certificate Signing Request) sent
   │  └─ CSR auto-signed by AWS (EC2 controller approves)
   │
   └─ Result: Node successfully joined cluster
      ├─ Node status: Ready (after health checks)
      └─ Kubelet state: running, listening on :10250

STEP 7: KARPENTER MONITORS EC2 → KUBERNETES TRANSITION
└─ Karpenter polls: kubectl get nodes
└─ Query EC2 API: DescribeInstances (instance-id from fleet)
└─ Correlation: EC2 instance i-1a2b3c4d → Kubernetes Node karpenter-node-1a2b3c4d
└─ Node status check:
   ├─ NodeReady condition: False → True (takes 10-30 seconds)
   ├─ Node resources: allocatable CPU 1950m, Memory 1876Mi
   ├─ Kubelet status: Ready ✅
   └─ Taints: karpenter.sh/capacity-type=on-demand:NoSchedule
      └─ This prevents OTHER schedulers from using this node
      └─ Only Karpenter scheduler removes taint after verification

STEP 8: KARPENTER PROVISIONING OBJECT REGISTERED
└─ Create Kubernetes resource: karpenter.sh/NodePool object
└─ Status: NodePool.status.nodes += 1
└─ Record: Karpenter.status.summary:
   ├─ capacity-type: on-demand
   ├─ providerName: default  
   ├─ instance-type: t3.small
   ├─ zone: us-east-1b
   ├─ available-capacity: CPU 1950m, Memory 1876Mi
   └─ nodes-created: 1
└─ Karpenter state: NODE_PROVISIONED ✅

STEP 9: KUBERNETES SCHEDULER PLACES POD ON NEW NODE
└─ Scheduler runs its evaluation again: kubectl get nodes
└─ New node available: karpenter-node-1a2b3c4d (Ready)
   ├─ Available CPU: 1950m (pod needs 800m) ✓
   ├─ Available Memory: 1876Mi (pod needs 1Gi) ✓
   └─ Taints: none (Karpenter removed NoSchedule taint)
│
└─ Scheduler decision: PLACE Pod.catalog on new node
   ├─ Pod.spec.nodeName = karpenter-node-1a2b3c4d
   ├─ Pod status: Pending → Running
   └─ kubelet on new node pulls image & starts container
      ├─ Docker image pull: catalog:sha-abc123 (5-10 sec)
      ├─ Container init: database connections established
      ├─ Readiness probe: GET /api/ready → 200 OK ✅
      └─ Pod fully running ✅

STEP 10: APPLICATION SERVING TRAFFIC
└─ Pod now running on karpenter-node-1a2b3c4d:
   ├─ Pod IP: 10.0.2.101
   ├─ Pod is ready for traffic
   ├─ Service endpoint updated: 10.0.2.101:8080
   └─ Users can access application ✅
│
└─ Metrics updated:
   ├─ Cluster CPU utilization: was 85% → now 45% (more capacity)
   ├─ Cluster Memory utilization: was 88% → now 62%
   ├─ New node memory reserved: 4% for system components
   ├─ Pod count increased: 12 → 13 pods
   └─ Node count increased: 2 → 3 nodes

STEP 11: ONGOING KARPENTER CONSOLIDATION (30-60 seconds later)
└─ Karpenter consolidation loop checks:
   ├─ Node 1: 45% utilized
   ├─ Node 2: 30% utilized
   ├─ Node 3 (new): 35% utilized
   └─ Analysis: Can we consolidate (remove underutilized nodes)?
│
└─ Consolidation simulation:
   ├─ If we remove Node 2, can its pods fit on other nodes?
   │  ├─ Node 2 pods: 5 pods requiring 300m CPU, 0.5Gi RAM each
   │  ├─ Available on Node 1: 1000m CPU, 1Gi RAM → YES, fits ✓
   │  ├─ Action: cordon Node 2 (no new pods scheduled)
   │  ├─ Drain Node 2: evictPod → pods rescheduled to Node 1
   │  ├─ Terminate EC2 instance: i-2a3b4c5d
   │  └─ Result: saved $0.096/hour (assuming m5.large)
   │
   └─ Cost optimization: Karpenter automatically saves money ✅
      ├─ Provisioning: responsive to demand
      ├─ Consolidation: aggressive cost optimization
      ├─ Spot instances: 70% cheaper than On-Demand (if enabled)
      ├─ Zero manual intervention: fully automated
      └─ Result: same reliability, lower costs

TOTAL TIME: Pod Pending → Pod Running: **25-35 seconds** ⚡
TRADITIONAL CLUSTER AUTOSCALER: **3-5 minutes** ❌
TIME SAVED PER SCALE-UP EVENT: **2.5-4.5 minutes** 🎯

KARPENTER ADVANTAGES:
✅ Fast: seconds instead of minutes
✅ Efficient: rightsizes instances to workload
✅ Cost-optimized: consolidation + Spot instances
✅ Seamless: no manual intervention needed
✅ Responsive: handles traffic spikes instantly
```

### Karpenter Setup: Terraform

**Karpenter Infrastructure Setup Workflow:**

```
┌────────────────────────────────────────────────────────────────┐
│ TERRAFORM KARPENTER SETUP FILES                               │
└────────────────────────────────────────────────────────────────┘

c6_01_karpenter_controller_iam_role.tf
├─ IAM role for Karpenter controller pod
├─ Trust relationship: pods.eks.amazonaws.com
├─ Permissions: EC2 provisioning, spot management
└─ Output: role ARN → used in c6_06

c6_02_karpenter_node_iam_role.tf
├─ IAM role for EC2 nodes created by Karpenter
├─ Attached policies:
│  ├─ AmazonEKSWorkerNodePolicy
│  ├─ AmazonEKS_CNI_Policy
│  └─ AmazonEC2ContainerRegistryReadOnly
└─ Output: role name → referenced in EC2NodeClass

c6_03_karpenter_sqs_queue.tf
├─ SQS queue for interruption notices
├─ Receives: Spot interruption warnings
├─ Retention: 5 minutes
└─ Output: queue name → Karpenter monitors

c6_04_karpenter_eventbridge_rules.tf
├─ EventBridge rule 1: Spot interruption notices
│  └─ Routes to: SQS queue
├─ EventBridge rule 2: Instance state changes
│  └─ Routes to: SQS queue
└─ Result: Karpenter gets AWS events→graceful draining

c6_05_karpenter_helm_chart.tf  
├─ Helm chart: Deploys karpenter controller pod
├─ Namespace: karpenter
├─ Config:
│  ├─ Service account with IAM role
│  ├─ SQS queue name
│  └─ Cluster name
└─ Result: Karpenter running & listening to events

         ↓

Config files cascade: Role → Node Role → Queue → Events → Helm
All connected: IAM roles → EC2 provisioning → Node creation
```

```hcl
# 03_KARPENTER_terraform-manifests/c6_01_karpenter_controller_iam_role.tf

resource "aws_iam_role" "karpenter_controller" {
  name = "karpenter-controller-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"  # Pod Identity
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Custom policy for EC2 provisioning
resource "aws_iam_role_policy" "karpenter_controller_policy" {
  name = "karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",           # Create instance groups
          "ec2:CreateLaunchTemplate",  # Template for instances
          "ec2:CreateSpotDatafeedSubscription",
          "ec2:DescribeFleetHistory",
          "ec2:DescribeFleets",
          "ec2:DescribeImages",        # Get AMI info
          "ec2:DescribeInstanceTypes", # Get instance type specs
          "ec2:DescribeInstances",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:GetSpotDatafeedHistory",
          "ec2:RunInstances",          # Launch instances
          "ec2:RunScheduledInstances",
          "ec2:TerminateInstances"     # Delete instances
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"               # Pass node IAM role
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/karpenter-node-role"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",          # Get AMI from SSM
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/eks/optimized-ami*"
      }
    ]
  })
}

---

# c6_04_karpenter_node_iam_role.tf

resource "aws_iam_role" "karpenter_node" {
  name = "karpenter-node-role"
  
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

# Node needs basic Kubernetes permissions
resource "aws_iam_role_policy_attachment" "karpenter_node_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_registry_policy" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

---

# c6_06_karpenter_helm_install.tf

resource "helm_release" "karpenter" {
  name            = "karpenter"
  repository      = "oci://public.ecr.aws/karpenter"
  chart           = "karpenter"
  namespace       = "karpenter"
  create_namespace = true
  version         = "v0.31.0"
  
  # Controller service account with IAM role
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }
  
  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter_interruption.name
  }
}

---

# c6_07_karpenter_sqs_queue.tf & c6_08_karpenter_eventbridge_rules.tf

# SQS Queue for Spot Interruption Notices
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "karpenter-interruption-queue"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

# EventBridge Rule: Spot Instance Interruption Notice
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "karpenter-spot-interruption"
  description = "Karpenter spot interruption warning"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_to_sqs" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterSpotInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# EventBridge Rule: Instance State Changes
resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  name        = "karpenter-instance-state"
  description = "Karpenter instance state changes"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_state_to_sqs" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state.name
  target_id = "KarpenterStateChangeQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}
```

### Karpenter Configuration: NodePool & EC2NodeClass

**Karpenter Decision Tree: NodePool → EC2NodeClass → Instance Selection:**

```
Pod Fails to Schedule (insufficient capacity)
                 │
                 ↓
   Karpenter Controller Analyzes:
   ├─ Pod CPU: 500m
   ├─ Pod Memory: 512Mi
   └─ Pod requirements (affinity, node selectors)
                 │
                 ↓
   ┌────────────────────────────────────────────┐
   │ Check Which NodePool to Use:               │
   │                                            │
   │ NodePool: on-demand (weight 50)            │
   │  └─ Preferred for production               │
   │                                            │
   │ NodePool: spot (weight 10)                 │
   │  └─ Lower weight (fallback option)         │
   └────────────────┬───────────────────────────┘
                    │ (pod doesn't specify nodePool)
                    └─ Use on-demand (higher weight)
                    │
                    ↓
   ┌────────────────────────────────────────────┐
   │ EC2NodeClass: default                      │
   │  ├─ AMI: Amazon Linux 2 (EKS optimized)   │
   │  ├─ Role: karpenter-node-role             │
   │  ├─ Subnets: auto-discover                │
   │  ├─ Security Groups: auto-discover        │
   │  ├─ EBS: 100GB gp3 encrypted             │
   │  └─ Monitoring: detailed CloudWatch       │
   └────────────────┬───────────────────────────┘
                    │
                    ↓
   ┌────────────────────────────────────────────┐
   │ NodePool Requirements: Evaluate            │
   │                                            │
   │ ├─ Architecture: amd64 ✓                  │
   │ ├─ Instance types: t3.* or t4g.* ✓        │
   │ ├─ Capacity type: on-demand ✓             │
   │ ├─ EBS optimized: true ✓                 │
   │ └─ CPU limit: 1000m (have 0m) ✓          │
   └────────────────┬───────────────────────────┘
                    │
                    ↓
    Karpenter selects best instance:
    ├─ Cost: cheapest first
    ├─ Fit: smallest that fits
    │  └─ 500m CPU → t3.medium (2vCPU, $0.0416/h)
    ├─ Region: same AZs as existing nodes
    └─ Launch via EC2 API → 15-30 seconds ⚡
```

```yaml
---
# EC2NodeClass: Template for EC2 instances
apiVersion: ec2.karpenter.sh/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AMI selection
  amiFamily: AL2          # Amazon Linux 2 (EKS Optimized)
  role: "karpenter-node-role"
  
  # Networking
  subnetSelector:
    karpenter.sh/discovery: "true"  # Uses subnet tagged with this
  
  securityGroupSelector:
    karpenter.sh/discovery: "true"  # Uses SG tagged with this
  
  # Tagging
  tags:
    ManagedBy: karpenter
    Environment: production
  
  # User data (scripts to run on instance boot)
  userData: |
    #!/bin/bash
    echo "Karpenter provisioned node"
  
  # EBS volume configuration
  blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      volumeSize: 100Gi
      volumeType: gp3
      iops: 3000
      throughput: 125
      encrypted: true
      deleteOnTermination: true
  
  # MetadataOptions (IMDS)
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
  
  # Monitoring
  detailedMonitoring: true

---
# NodePool: On-Demand instances (primary)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: on-demand
spec:
  template:
    spec:
      # Link to EC2NodeClass
      nodeClassRef:
        name: default
      
      requirements:
      # Instance families (prefer newer generations)
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["t3.medium", "t3.large", "t4g.medium", "t4g.large"]
      
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand"]  # Only on-demand, not Spot
      
      - key: karpenter.sh/ebs-optimized
        operator: In
        values: ["true"]       # Use EBS-optimized instances
      
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
  
  # Limits
  limits:
    resources:
      cpu: 1000m            # Total CPU allowed for this pool
      memory: 1000Gi        # Total memory allowed
  
  # Pricing behavior
  providerRef:
    name: default
  
  # Consolidation (scale down)
  consolidationPolicy:
    nodes: "false"          # Disable consolidation for on-demand
  
  # TTL: prevent permanently running nodes
  ttlSecondsAfterEmpty: 30  # 30 seconds without pods = delete node
  ttlSecondsUntilExpired: 604800  # 7 days max node age

---
# NodePool: Spot instances (secondary, optimized for cost)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: spot
spec:
  weight: 50  # Lower weight (on-demand preferred)
  
  template:
    spec:
      nodeClassRef:
        name: default
      
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["t3.medium", "t3.large", "t4g.medium", "t4g.large"]
      
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]      # Only Spot instances
      
      - key: karpenter.sh/ebs-optimized
        operator: In
        values: ["true"]
  
  limits:
    resources:
      cpu: 2000m            # More CPU allowed (cheaper)
      memory: 2000Gi
  
  # Disruption budget for Spot
  disruption:
    consolidateAfter: 30s
    expireAfter: 604800s    # 7 days
    budgets:
    - duration: 5m
      nodes: 10%            # Max 10% of nodes disrupted per 5 min
      reasons:
      - "Underutilized"
      - "Empty"
  
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 604800

---
# Pod Scheduling: Prefer cheaper Spot instances for flexible workloads
apiVersion: v1
kind: Pod
metadata:
  name: catalog-spot
spec:
  # Require Spot nodes
  nodeSelector:
    karpenter.sh/capacity-type: "spot"
  
  # Or use affinity for softer constraint
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["spot"]
```

### Karpenter Benefits Summary

```
COMPARISON: Cluster Autoscaler vs Karpenter
═════════════════════════════════════════════════════════════════

Feature                  │ Cluster Autoscaler │ Karpenter
─────────────────────────┼────────────────────┼─────────────────
Scaling Time            │ 2-3 minutes        │ 15-30 seconds ✅
Bin Packing             │ Limited            │ Excellent ✅
Spot Instance Support   │ Complex            │ Built-in ✅
Interruption Handling   │ Manual             │ Automatic ✅
Instance Type Selection │ Manual ASG config  │ Auto-optimized ✅
Consolidation           │ Slow               │ Fast ✅
Configuration           │ AWS ASG (complex)  │ K8s CRDs (simple) ✅
Downtime                │ Yes                │ Zero-downtime ✅
Cost Savings            │ Moderate           │ High (Spot) ✅

COST SAVINGS EXAMPLE (100 pods, 2 vCPU each)
─────────────────────────────────────────────────────────────────

Cluster Autoscaler:
├─ 20 on-demand t3.xlarge (4 vCPU each)
├─ Cost: $0.1664/hour × 20 = $3.328/hour
├─ Monthly: $3.328 × 730 = $2,429.44

Karpenter (optimized):
├─ 15 on-demand t3.large (2 vCPU each) = 30 vCPU
├─ 5 spot t3.xlarge (4 vCPU each) = 20 vCPU
├─ Spot is 70% cheaper
├─ Cost: ($0.0832 × 15 + $0.0249 × 5) × 730
├─ Cost: ($1.248 + $0.1245) × 730
├─ Cost: $1.3725 × 730 = $1,001.93/month
├─ **SAVINGS: $1,427.51/month (59% reduction!) ✅**

With hundreds of pods, savings multiply significantly
```

---

## Section 21: DevOps CI/CD Pipeline

### Problem: Manual Deployment is Error-Prone

```
❌ MANUAL DEPLOYMENT (Before CI/CD):
1. Developer writes code, commits to GitHub
2. Team member manually:
   ├─ Pulls code from GitHub
   ├─ Runs tests locally
   ├─ Builds Docker image manually
   ├─ Tags image with version
   ├─ Pushes to ECR (manually, easy to forget)
   ├─ Manually updates Kubernetes manifests
   ├─ Applies kubectl apply (hoping nothing breaks)
   ├─ Watches logs to see if it works
   └─ Rolls back if broken (manually)
3. Risk: Human error at every step
4. Time: 30 minutes per deployment
5. Consistency: Different every time

✅ AUTOMATED CI/CD PIPELINE (After GitHub Actions + ArgoCD):
1. Developer commits code to GitHub
2. GitHub Actions automatically:
   ├─ Builds Docker image
   ├─ Tags with commit SHA
   ├─ Pushes to ECR
   ├─ Updates values.yaml with new tag
   ├─ Commits to Git (automatic)
3. ArgoCD automatically:
   ├─ Detects Git change
   ├─ Pulls updated values.yaml
   ├─ Deploys via Helm
   ├─ Monitors health
   ├─ Rolls back if unhealthy (auto-remediation)
4. Result: Deployment in 2 minutes, zero human error
5. Complete audit trail: who changed what, when
```

### CI/CD Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                    COMPLETE CI/CD FLOW                            │
└────────────────────────────────────────────────────────────────────┘

STEP 1: DEVELOPER PUSHES CODE
═════════════════════════════════════════════════════════════════════
┌──────────────┐
│   Developer  │
│   git push   │ (to feature branch)
│   (new code) │
└──────┬───────┘
       │ (to GitHub)
       ↓
   ┌───────────────────────────────────────────────┐
   │  GitHub Repository                            │
   │  ├─ main branch (source of truth)             │
   │  └─ .github/workflows/build-push-ui.yaml      │
   │     (CI pipeline definition)                  │
   └───────────────────────────────────────────────┘

STEP 2: GITHUB ACTIONS (Continuous Integration)
═════════════════════════════════════════════════════════════════════
GitHub Actions Workflow Triggered:

1. CHECKOUT (Clone repository)
   ├─ Action: actions/checkout
   └─ Result: Code in runner

2. AUTHENTICATE TO AWS (OIDC - NO SECRETS!)
   ├─ Action: aws-actions/configure-aws-credentials
   ├─ Flow:
   │  ├─ GitHub generates OIDC token (tied to this action)
   │  ├─ Calls AWS STS: ExchangeWebIdentityForToken
   │  ├─ AWS verifies token (GitHub is trusted)
   │  ├─ Returns temporary AWS credentials (valid 1 hour)
   ├─ Result: Secure AWS access
   └─ NO HARDCODED AWS_ACCESS_KEY_ID! ✅

3. LOGIN TO ECR (Amazon Elastic Container Registry)
   ├─ Action: aws-actions/amazon-ecr-login
   ├─ Retrieves ECR credentials
   └─ Result: Can push images to ECR

4. BUILD DOCKER IMAGE
   ├─ Action: docker/build-push-action
   ├─ Dockerfile: backend/ui/Dockerfile
   ├─ Build context: ./ (entire repo)
   ├─ Base image: node:18-alpine
   ├─ Compiles TypeScript/React
   ├─ Bundles assets
   └─ Result: Docker image layer built

5. TAG IMAGE
   ├─ Tag 1: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/ui:latest
   ├─ Tag 2: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/ui:sha-abc1234
   │         (short git commit SHA for traceability)
   └─ Result: Image tagged with version

6. PUSH TO ECR
   ├─ Action: docker/build-push-action (with push: true)
   ├─ Target: Amazon ECR repository
   ├─ Encryption: KMS-encrypted images
   └─ Result: Image available in ECR

7. UPDATE HELM VALUES
   ├─ File: 03_RetailStore_Helm_with_Data_Plane/values-ui.yaml
   ├─ Change: image.tag from "v1.0.0" to "sha-abc1234"
   ├─ Commit: auto-commit to main branch (via GitHub Actions)
   └─ Result: Git updated with new image tag

8. WORKFLOW COMPLETE
   └─ Status: CI pipeline success ✅

STEP 3: GIT CHANGE DETECTED
═════════════════════════════════════════════════════════════════════
values-ui.yaml updated:
├─ Old: image.tag: "v1.0.0"
└─ New: image.tag: "sha-abc1234"

ArgoCD continuously watches this file (every 30 seconds)

STEP 4: ARGOCD (Continuous Deployment - GitOps)
═════════════════════════════════════════════════════════════════════
ArgoCD detects change:

1. SYNC DETECTION
   ├─ ArgoCD compares: Git state vs Cluster state
   ├─ Finds difference: values-ui.yaml changed
   └─ Status: OUT OF SYNC

2. AUTOMATIC SYNC (if configured)
   ├─ Trigger: Auto-sync enabled in Application CRD
   ├─ Action: Deploy latest changes
   └─ Policy: Automatic, Prune, Self-heal

3. HELM UPGRADE
   ├─ Action: helm upgrade ui ./charts/ui -f values-ui.yaml
   ├─ Reads: values-ui.yaml (with new image.tag)
   ├─ Generates: Complete K8s manifests from Helm
   └─ Result: Kubernetes manifests ready

4. DEPLOYMENT STRATEGY
   ├─ Type: RollingUpdate
   ├─ Current: 3 pods running old version (v1.0.0)
   │
   └─ Steps:
      ├─ Create new pod with sha-abc1234
      ├─ Wait for readiness probe (healthy)
      ├─ Route traffic to new pod (via service)
      ├─ Terminate old pod
      ├─ Repeat for pod 2
      ├─ Repeat for pod 3
      └─ ZERO-DOWNTIME! ✅ (always 2-3 pods running)

5. MONITORING & VERIFICATION
   ├─ ArgoCD monitors rollout progress
   ├─ Checks pod health
   ├─ Verifies readiness probes pass
   └─ Status: SYNCED (successful)

STEP 5: APPLICATION RUNNING (NEW VERSION)
═════════════════════════════════════════════════════════════════════
├─ UI pod 1: running new version sha-abc1234
├─ UI pod 2: running new version sha-abc1234
├─ UI pod 3: running new version sha-abc1234
├─ Users accessing: New feature deployed!
└─ Deployment time: ~2 minutes ✅

═════════════════════════════════════════════════════════════════════
COMPLETE FLOW: Code → Pushed → GitHub Actions → ECR → ArgoCD → EKS
Time: Code push to live: ~2-3 minutes ✅ Fully automated ✅
═════════════════════════════════════════════════════════════════════
```

### GitHub Actions Workflow

**CI Pipeline: Build, Test, Push → ECR:**

```
Developer: git push origin main
            │
            ↓
        ┌─────────────────────────────────┐
        │ GitHub Repository Webhook       │
        │ (push detected)                  │
        └────────────┬────────────────────┘
                     │
                     ↓
    ┌────────────────────────────────────┐
    │ GitHub Actions Runner              │
    │ (ubuntu-latest machine)            │
    └────────────┬───────────────────────┘
                 │
          ┌──────┴──────┬──────────┬──────────┬───────────────┐
          ↓             ↓          ↓          ↓               ↓
    ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
    │ Checkout │ │ Configure│ │ Login to │ │ Build &  │ │ Push to ECR  │
    │ Code     │ │ AWS      │ │ ECR      │ │ Tag      │ │              │
    │ from Git │ │ (OIDC)   │ │ (Temp    │ │ Docker   │ │ New image   │
    │          │ │          │ │ creds)   │ │ image    │ │ versions up  │
    └──────────┘ └──────────┘ └──────────┘ └──────────┘ │              │
                      │            │            │         │              │
                      ↓            │            │         │              │
            ┌─────────────────┐    │            │         └──────────────┘
            │ OIDC Token + STS│    │            │                  │
            │ No hardcoded    │    │            │                  ↓
            │ credentials! ✅ │    │            └────────────────────────┐
            └─────────────────┘    │                       │             │
                                   │        ┌──────────────┼─────────────┴─┐
                                   │        ↓              ↓              ↓
                                   │      Image:latest  Image:sha-abc123  Image tags
                                   │      Image updated in ECR repository
                                   │
                     ┌─────────────┴──────────────────────────────┐
                     │ Step: Update Helm Values                  │
                     └──────────┬───────────────────────────────┘
                                │
                                ↓
                     ┌──────────────────────────────┐
                     │ values-ui.yaml updated:      │
                     │ image.tag: sha-abc123        │
                     └──────────┬───────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ↓                       ↓
        ┌─────────────────────┐  ┌─────────────────────┐
        │ Git Commit          │  │ Push to GitHub      │
        │ "chore: Update UI   │  │ (automatic)         │
        │  image tag to       │  │                     │
        │  sha-abc123"        │  │ values-ui.yaml      │
        │                     │  │ committed to main   │
        └─────────────────────┘  └─────────────────────┘
                                        │
                                        ↓
                                 ArgoCD watches Git...
```

```yaml
# .github/workflows/build-push-ui.yaml

name: Build and Push UI to ECR

on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'ui/**'              # Only trigger on UI changes
      - '.github/workflows/build-push-ui.yaml'

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: retail-store/ui
  IMAGE_TAG: ${{ github.sha }}  # Git commit SHA

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    permissions:
      id-token: write        # OIDC token permission
      contents: read
    
    steps:
    # Step 1: Checkout code
    - name: Checkout Code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0       # Full history for version detection
    
    # Step 2: Configure AWS credentials using OIDC
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::123456789:role/github-actions-role
        aws-region: ${{ env.AWS_REGION }}
        role-skip-session-tagging: true
      # Behind the scenes:
      # 1. GitHub generates OIDC token (tied to repo, branch, action)
      # 2. Calls AWS STS: AssumeRoleWithWebIdentity
      # 3. AWS verifies GitHub's OIDC provider signature
      # 4. Returns temporary credentials (1 hour)
      # 5. Sets as environment variables
      # NO HARDCODED AWS KEYS! ✅
    
    # Step 3: Login to Amazon ECR
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2
      with:
        mask-password: true  # Don't expose password in logs
    
    - name: Get ECR Registry
      id: ecr-uri
      run: echo "registry=${{ steps.login-ecr.outputs.registry }}" >> $GITHUB_OUTPUT
    
    # Step 4: Build and Push to ECR
    - name: Build and Push Docker Image
      uses: docker/build-push-action@v5
      with:
        context: ./ui              # Dockerfile location
        push: true                 # Push to ECR
        
        # Image tagging
        tags: |
          ${{ steps.ecr-uri.outputs.registry }}/${{ env.ECR_REPOSITORY }}:latest
          ${{ steps.ecr-uri.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }}
        
        # Build arguments
        build-args: |
          REACT_APP_API_ENDPOINT=https://api.example.com
          BUILD_DATE=${{ github.event.head_commit.timestamp }}
          VCS_REF=${{ github.sha }}
        
        # Caching for faster builds
        cache-from: type=gha
        cache-to: type=gha,mode=max
    
    # Step 5: Update values.yaml in Git
    - name: Update Helm Values
      run: |
        # Update image tag in values-ui.yaml
        sed -i "s|tag: .*|tag: ${{ env.IMAGE_TAG }}|" \
            03_RetailStore_Helm_with_Data_Plane/02_retailstore_values_HELM_aws_dataplane/values-ui.yaml
        
        # Show what changed
        cat 03_RetailStore_Helm_with_Data_Plane/02_retailstore_values_HELM_aws_dataplane/values-ui.yaml
    
    # Step 6: Commit and push changes
    - name: Commit and Push Changes
      run: |
        git config --global user.email "github-actions@github.com"
        git config --global user.name "GitHub Actions"
        
        # Stage changes
        git add 03_RetailStore_Helm_with_Data_Plane/02_retailstore_values_HELM_aws_dataplane/values-ui.yaml
        
        # Check if there are changes
        if git diff --cached --quiet; then
          echo "No changes to commit"
        else
          git commit -m "chore: Update UI image tag to ${{ env.IMAGE_TAG }}"
          git push origin main
        fi
    
    # Step 7: Notify Slack (optional)
    - name: Notify Slack
      if: always()
      uses: slackapi/slack-github-action@v1
      with:
        payload: |
          {
            "text": "UI Deployment: ${{ job.status }}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "UI Docker Image Build\nStatus: ${{ job.status }}\nCommit: ${{ github.sha }}\nImage: retail-store/ui:${{ env.IMAGE_TAG }}"
                }
              }
            ]
          }
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### OIDC Authentication: Zero-Secrets Workflow

**How GitHub Actions Gets AWS Credentials Without Storing Secrets:**

```
Step 1: GITHUB ACTIONS WORKFLOW STARTS
├─ Job: build-and-push (on: push to main branch)
├─ Runner: ubuntu-latest
├─ Environment: Workflow execution context
│  ├─ Repository: myorg/retail-store
│  ├─ Branch: main
│  ├─ Actor: developer-name
│  ├─ Commit SHA: abc1234567890def
│  └─ Timestamp: 2024-02-09T10:15:32Z
│
└─ No AWS credentials in environment ✅

Step 2: REQUEST OIDC TOKEN
├─ Action: actions/configure-aws-credentials
├─ Step: "id-token: write"
│  └─ Permission to request OIDC token from GitHub
│
├─ GitHub generates token:
│  ├─ Type: JWT (JSON Web Token)
│  ├─ Signed with: GitHub's private key (kept secure)
│  └─ Content:
│     ├─ github_repository: myorg/retail-store
│     ├─ github_ref: main
│     ├─ github_actor: developer-name
│     ├─ github_job: build-and-push
│     ├─ github_sha: abc1234567890def
│     ├─ iss: https://token.actions.githubusercontent.com
│     ├─ aud: sts.amazonaws.com
│     ├─ iat: 1707467732 (issued at)
│     └─ exp: 1707467792 (expires in 1 hour)
│
└─ Token ready ✅

Step 3: EXCHANGE TOKEN FOR AWS CREDENTIALS
├─ Action calls: aws sts assume-role-with-web-identity
│  ├─ WebIdentityToken: JWT from step 2
│  ├─ RoleArn: arn:aws:iam::123456789:role/github-actions-role
│  └─ RoleSessionName: myorg-retail-store-abc1234
│
├─ AWS processes request:
│  ├─ Find: github-actions-role (in IAM)
│  ├─ Check: Trust relationship
│  │  └─ "Allowed principals: OIDC provider, GitHub"
│  │
│  ├─ Verify: OIDC token signature
│  │  ├─ Get GitHub's public key (cached)
│  │  ├─ Verify: JWT signature is valid ✓
│  │  ├─ Verify: Token not expired ✓
│  │  └─ Verified: Truly from GitHub ✅
│  │
│  ├─ Check: Token claim conditions
│  │  ├─ Condition: aud == "sts.amazonaws.com" ✓
│  │  ├─ Condition: sub (subject) matches policy pattern
│  │  │  └─ Pattern: repo:myorg/retail-store:*
│  │  │  └─ Token subject: repo:myorg/retail-store:ref:refs/heads/main
│  │  │  └─ MATCHES ✓
│  │  │
│  │  └─ All conditions met ✅
│  │
│  └─ APPROVED: This GitHub action is trusted

Step 4: GENERATE TEMPORARY STS CREDENTIALS
├─ AWS STS creates temporary credentials:
│  ├─ AccessKeyId: ASIAB5EXAMPLE2024
│  │  └─ Temporary (only for this session)
│  │
│  ├─ SecretAccessKey: wJalrXU...exampleKey/EXAMPLE
│  │  └─ Temporary (only for this session)
│  │
│  ├─ SessionToken: AQoDXw...exampleToken
│  │  └─ Unique for this exchange
│  │
│  ├─ Expiration: 3600 seconds (1 hour)
│  │  └─ Credentials auto-expire
│  │  └─ Can't be reused after expiration
│  │
│  └─ Policy: github-actions-role permissions
│     ├─ ecr:GetAuthorizationToken
│     ├─ ecr:BatchGetImage
│     ├─ ecr:InitiateLayerUpload
│     ├─ ecr:CompleteLayerUpload
│     ├─ ecr:PutImage
│     └─ (limited scope, not full AWS access)

└─ Credentials returned to GitHub Actions ✅

Step 5: SET ENVIRONMENT VARIABLES
├─ GitHub Actions saves credentials as env vars:
│  ├─ AWS_ACCESS_KEY_ID=ASIAB5EXAMPLE2024
│  ├─ AWS_SECRET_ACCESS_KEY=wJalrXU...exampleKey/EXAMPLE
│  └─ AWS_SESSION_TOKEN=AQoDXw...exampleToken
│
├─ Available to: Job steps only
├─ NOT visible in: Logs (masked by GitHub Actions)
├─ NOT persisted: Deleted after workflow completion
└─ Security: Temporary credentials ✅

Step 6: AUTHENTICATE TO ECR
├─ Step: "aws-actions/amazon-ecr-login"
├─ Uses: AWS credentials from above
├─ Call: aws ecr get-authorization-token
│  ├─ Authenticates with temporary credentials
│  ├─ Validates: credentials are valid ✓
│  └─ Role has: ecr:GetAuthorizationToken ✓
│
├─ Response: ECR login token
│  ├─ Type: Docker authentication token
│  ├─ Expires: 12 hours
│  └─ Allows: Push to ECR
│
└─ Logged in to ECR ✅

Step 7: DOCKER BUILD & PUSH
├─ Step: "docker/build-push-action"
├─ Uses: ECR login token from above
├─ Build Docker image
├─ Tag image with ECR URI
├─ Push to Amazon ECR
│  ├─ Each layer encrypted in transit
│  ├─ Each layer encrypted at rest (KMS)
│  └─ Audit logged in CloudTrail
│
└─ Image pushed ✅

Step 8: CREDENTIALS EXPIRE
├─ Time elapsed: 59 minutes
├─ Temporary credentials: 1 minute remaining
├─ Workflow status: COMPLETE
│  └─ Temporary credentials: Revoked automatically
│
├─ What happens to stolen creds?
│  ├─ If leaked after job: Expired (can't use)
│  ├─ Validity: 1 hour only
│  ├─ Scope: Limited (ECR only, not full AWS)
│  └─ Audit trail: CloudTrail logs who accessed what
│
└─ Security: Minimal blast radius ✅

SECURITY ADVANTAGES
├─ ❌ Before (Leaked AWS Access Key):
│  ├─ Permanent key stored as GitHub Secret
│  ├─ Valid forever (until manual rotation)
│  ├─ Full AWS permissions (attacker gets everything)
│  ├─ Manual rotation required (tedious)
│  └─ Blast radius: Unlimited
│
└─ ✅ After (OIDC Token):
   ├─ Token valid 5 minutes only
   ├─ Temporary credentials valid 1 hour only
   ├─ Limited permissions (least privilege)
   ├─ Auto-expiration (no manual rotation needed)
   ├─ Fine-grained audit trail (repo, branch, workflow, commit)
   └─ Blast radius: Minimal
```

### OIDC Trust Policy: GitHub → AWS

```hcl
# Trust policy allowing GitHub Actions to assume role

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "AllowGitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    
    # Only allow tokens from specific repository
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:myorg/retail-store:*"]  # Your GitHub repo
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Minimal permissions: only what GitHub Actions needs
data "aws_iam_policy_document" "github_actions" {
  statement {
    sid    = "ECRAccess"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",          # Login to ECR
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"                        # Push to ECR
    ]
    resources = [
      "arn:aws:ecr:us-east-1:123456789:repository/retail-store/*"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
```

### ArgoCD Setup & Configuration

**Step-by-Step: GitOps Sync Cycle (Complete Deployment Automation)**

```
STEP 1: DEVELOPER PUSHES CODE & TAGS IMAGE
└─ Feature complete: feature/ui-redesign → main branch
└─ GitHub Actions CI completes: Docker build, image scan, ECR push
└─ Image tag: 123456789.dkr.ecr.us-east-1.amazonaws.com/ui:sha-abc123def
└─ Helm values repository updated: infrastructure-as-code/retail-ui/values-prod.yaml
   └─ Change: image.tag: "sha-1.0.0" → "sha-abc123def"
   └─ Commit message: "chore: bump UI image to sha-abc123def"
   └─ Push to GitOps repo (separate from app code)

STEP 2: DEVELOPERS SLEEP 😴, GITOPS AUTOMATION WAKES UP
└─ ArgoCD Application resource watches: "argocd.example.com/argocd-server"
└─ Application manifest points to:
   └─ Git repository: git@github.com:company/retail-infrastructure.git
   └─ Path: /12_Helm/retail-ui/
   └─ Values file: values-prod.yaml
   └─ Sync policy: automatic (enabled)
   └─ Sync interval: every 180 seconds (3 min) OR webhook-triggered
└─ Previous state cached in ArgoCD database (etcd)
   └─ Last known Git commit: sha-xyz789
   └─ Last known K8s deployment state: 3 pods with v1.0.0

STEP 3: ARGOCD CONTROLLER DETECTS CHANGE
└─ Push event webhook OR polling interval reached
└─ API call to GitHub: GET /repos/company/retail-infrastructure/contents/12_Helm/retail-ui/values-prod.yaml
└─ Response includes new commit: sha-abc123def
└─ Comparison: SHA-ABC123DEF (Git) vs SHA-XYZ789 (cached) → DIFFERENT ❌
└─ Result: Application marked "OutOfSync"
   └─ Reason: Git state ≠ Cluster state
   └─ ArgoCD UI dashboard shows 🔴 SYNCING indicator

STEP 4: ARGOCD FETCHES GIT MANIFESTS & RENDERS TEMPLATES
└─ Git clone: release-notes/retail-infrastructure to /tmp/argocd-cache-12345
└─ Checkout commit: sha-abc123def
└─ Helm template rendering:
   ├─ Input: chart path = /12_Helm/retail-ui/
   ├─ Input: values file = /12_Helm/retail-ui/values-prod.yaml
      │  └─ image.tag: "sha-abc123def"
      │  └─ image.repository: "123456789.dkr.ecr.us-east-1.amazonaws.com/ui"
      │  └─ replicas: 3
      │  └─ resources.requests.memory: "256Mi"
      │  └─ hpa.minReplicas: 2, hpa.maxReplicas: 10
   ├─ Helm engine processes template files:
      │  ├─ deployment.yaml: manifest → {{ include "ui.deployment" . }} rendered
      │  ├─ service.yaml: ClusterIP service → cluster.local:8080
      │  ├─ hpa.yaml: metrics-based scaling configured
      │  ├─ servicemonitor.yaml: Prometheus monitoring setup
      │  └─ ingress.yaml: ALB routing rules → http://ui.retail.aws.company.com
   ├─ Output: rendered YAML manifests (no templating syntax left)
   └─ Git diff calculated: what changed since last sync?
      └─ Changed: Deployment.spec.template.spec.containers[0].image
         └─ FROM: 123456789.dkr.ecr.us-east-1.amazonaws.com/ui:sha-1.0.0
         └─ TO:   123456789.dkr.ecr.us-east-1.amazonaws.com/ui:sha-abc123def
      └─ Unchanged: replicas, resources, service, HPA, ingress

STEP 5: ARGOCD COMPARES GIT STATE (DESIRED) vs CLUSTER STATE (CURRENT)
└─ Query Kubernetes API: kubectl get all -n retail-products
└─ Existing state:
   ├─ Deployment.ui: 3 pods running
   │  ├─ Pod 1 (ui-5c9f7b2d1-xyz): image sha-1.0.0, running 47 minutes
   │  ├─ Pod 2 (ui-5c9f7b2d1-abc): image sha-1.0.0, running 43 minutes
   │  └─ Pod 3 (ui-5c9f7b2d1-def): image sha-1.0.0, running 39 minutes
   ├─ Service.ui: ClusterIP 10.100.50.42 with endpoints [10.0.11.45, 10.0.12.46, 10.0.13.47]
   ├─ HPA: currently 3 replicas (metrics: CPU 42%, Memory 51%)
   └─ Ingress: active, routing traffic to Service.ui
└─ Desired state (from Git/Helm templates):
   ├─ Deployment.ui: 3 pods running
   │  └─ Image: sha-abc123def (THE CHANGE)
   ├─ Service.ui: same ClusterIP, same endpoints after rollout
   ├─ HPA: same configuration
   └─ Ingress: same routing
└─ Comparison result: DIFFERENT ❌
   └─ Required action: RollingUpdate deployment with new image
   └─ Safety check: RollingUpdateStrategy confirmed (maxSurge: 1, maxUnavailable: 0)
      └─ Ensures zero downtime: never go below 3 pods, never exceed 4 pods

STEP 6: ARGOCD EXECUTES SYNC (CREATE/UPDATE/DELETE OPERATIONS)
└─ Sync mode: automatic + self-healing enabled
└─ Operations ordered by ArgoCD:
   ├─ Operation 1: PATCH Deployment.spec.template.spec.containers[0].image
      │  └─ Kubernetes API call: kubectl patch deployment ui ...
      │  └─ Effect: triggers RollingUpdate deployment controller
      │  └─ Duration: 1-3 seconds for API response
      │
      ├─ Kubernetes RollingUpdate Orchestration (automatic, initiated by patch):
      │  ├─ Step A: Create pod 1 (new) - image sha-abc123def
      │  │  └─ Kubelet on node-1 pulls image: sha-abc123def
      │  │  └─ Container starts, application initializes (5-15 seconds)
      │  │  └─ Readiness probe: GET /ready → connected to DB → 200 OK ✅
      │  │
      │  ├─ Step B: Update Service.ui endpoints
      │  │  └─ Service controller adds new pod to endpoints: 10.0.11.48
      │  │  └─ Load balancer (kube-proxy) starts routing some traffic to new pod
      │  │  └─ New pod receives traffic (gradually, depends on readiness)
      │  │
      │  ├─ Step C: Terminate pod 1 (old) - graceful shutdown
      │  │  └─ Kubelet sends SIGTERM to container (preStop hook: 30 sec to drain connections)
      │  │  └─ Load balancer stops routing traffic (endpoint removed)
      │  │  └─ Pod terminates after 30 seconds, freeing resources
      │  │
      │  ├─ Step D: Repeat for pod 2 (old)
      │  │  └─ Create pod 2 (new) → verify readiness → update endpoints → terminate old
      │  │
      │  └─ Step E: Repeat for pod 3 (old)
      │     └─ Create pod 3 (new) → verify readiness → update endpoints → terminate old
      │
      └─ Operation Complete: All 3 pods running with sha-abc123def
         └─ New pods: 10.0.11.48, 10.0.12.47, 10.0.13.48
         └─ Endpoints updated in Service: [10.0.11.48, 10.0.12.47, 10.0.13.48]
         └─ HTTP traffic: Users still connected to ui.retail.aws.company.com ✅
         └─ Zero downtime: never dropped active connections
         └─ Complete time: 2-5 minutes (depending on image size, startup time)

STEP 7: ARGOCD HEALTH CHECKS & MONITORING
└─ After sync complete, ArgoCD monitors application health:
   ├─ Kubernetes resource status:
   │  ├─ Deployment.ui healthy?
   │  │  └─ Desired: 3, Current: 3, Ready: 3, Updated: 3 ✅
   │  ├─ Service.ui healthy?
   │  │  └─ Endpoints: 3 active, all passing readiness probe ✅
   │  └─ HPA healthy?
   │     └─ Metrics collection working, scale decisions ready ✅
   │
   ├─ Pod-level health:
   │  └─ Readiness probes: all green ✅
   │  └─ Liveness probes: all responding ✅
   │  └─ Resource limits: memory 256Mi/pod × 3 = 768Mi total ✅
   │
   └─ Application health (custom):
      └─ HTTP endpoint: GET /health → 200 OK ✅
      └─ Database connectivity: connection pool → MySQL ✅
      └─ Service mesh injection: Istio sidecar running (if enabled) ✅

STEP 8: ARGOCD STATUS UPDATE & AUDIT LOG
└─ Application status updated:
   ├─ Status.conditions[0].type: Synced
   ├─ Status.health.status: Healthy
   ├─ Status.operationState.finishedAt: 2024-01-15T10:34:22Z
   ├─ Status.operationState.syncResult.resources: [Deployment, Service, HPA, Ingress] updated
   └─ Message: "successfully synced (all resources: 4 synced, 0 failed)"
└─ Git audit trail (automatic):
   ├─ Pushed by: developer-name
   ├─ Commit message: "chore: bump UI image to sha-abc123def"
   ├─ Deployment time: 2024-01-15 10:34:22 UTC
   ├─ ArgoCD sync timestamp: logged with Git commit SHA
   └─ Rollback-safe: can instant revert to sha-1.0.0 by reverting Git commit
└─ Dashboard shows:
   ├─ Application.ui: 🟢 SYNCED, 🟢 HEALTHY
   ├─ Last sync: 2 seconds ago
   ├─ Sync log: 4 resources updated successfully
   └─ Git commit: sha-abc123def by developer-name
└─ Notifications (if configured):
   ├─ Slack: "@dev-team UI deployment complete (sha-abc123def)"
   ├─ Email: "ui application synced in 3 minutes"
   └─ PagerDuty: no alert (all healthy)

STEP 9: CONTINUOUS SELF-HEALING (ONGOING)
└─ ArgoCD continues monitoring every 180 seconds:
   ├─ If pod crashes → new pod auto-created (Deployment controller)
   ├─ If developer manually deletes pod → Deployment controller recreates
   ├─ If someone manually edits Deployment in cluster (kubectl edit) → ArgoCD reverts
   │  └─ Reason: Git is source of truth, not cluster state
   │  └─ Message: "OutOfSync" → auto-revert to Git state
   └─ Result: Application always matches Git state (GitOps guarantee)

TOTAL DEPLOYMENT TIME: ~2-5 minutes (from Git push to all pods running)
ZERO DOWNTIME: ✅ RollingUpdate keeps service active
ROLLBACK TIME: ~1 minute (git revert + ArgoCD auto-sync)
AUDIT TRAIL: ✅ Complete Git history (who, what, when, why)
```

**CD Pipeline: GitOps Synchronization → Kubernetes:**

```
Git Change Detected (values-ui.yaml updated with new tag)
       │
       ↓
┌──────────────────────────────────────────────────────┐
│ Git Repository (Source of Truth)                     │
│ ├─ values-ui.yaml: image.tag = sha-abc123          │
│ ├─ deployment.yaml: template with {{ values }}     │
│ ├─ service.yaml, hpa.yaml, etc.                    │
│ └─ Helm charts: /03_RetailStore_Helm_...           │
└────────────────┬─────────────────────────────────────┘
                 │
        Every 30 seconds (or webhook)
                 │
                 ↓
  ┌─────────────────────────────────────┐
  │ ArgoCD Controller                   │
  │ (argocd-application-controller)     │
  └────────────────┬────────────────────┘
                   │
             Poll Git Repo
                   │
         ┌─────────┴─────────┐
         ↓                   ↓
    ┌─────────┐        ┌──────────────┐
    │Git State│        │Cluster State │
    │(in Git) │        │(in K8s)      │
    └─────────┘        └──────────────┘
         │                   │
         └─────────┬─────────┘
                   │
         Are they the same?
                   │
        ┌──────────┴──────────┐
        ↓                     ↓
      YES                     NO
      (Synced)           (Out of Sync)
        │                     │
        └─        ┌───────────┴────────┐
                  │                    │
                  ↓                    ↓
            Auto-Sync ON          Auto-Sync OFF
            (configured)          (manual only)
                  │                    │
                  └─ Helm upgrade ─────┴─ Alert developer
                        │
                        ↓
        ┌─────────────────────────────────┐
        │ helm upgrade ui ./charts/ui   │
        │   -f values-ui.yaml             │
        └────────────┬────────────────────┘
                     │
                     ↓
        ┌─────────────────────────────────┐
        │ Kubernetes Deployment Rollout   │
        │                                 │
        │ Current: 3 pods (v1.0.0)       │
        │ Target:  3 pods (sha-abc123)   │
        │                                 │
        │ ├─ Create pod 1 (new)          │
        │ ├─ Wait for readiness          │
        │ ├─ Route traffic → pod 1       │
        │ ├─ Terminate pod (old)         │
        │ ├─ Repeat for pod 2, 3        │
        │ └─ ZERO DOWNTIME ✅            │
        └────────────┬────────────────────┘
                     │
                     ↓
        ┌─────────────────────────────────┐
        │ ArgoCD Monitoring               │
        │                                 │
        │ ├─ All pods healthy?            │
        │ ├─ Service endpoints ready?     │
        │ ├─ HPA configured correctly?    │
        │ └─ Status: SYNCED ✅            │
        └─────────────────────────────────┘
                     │
              Application Running
              New version deployed
              Complete audit trail in Git
```

```yaml
---
# ArgoCD Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: argocd

---
# Install ArgoCD via Helm (or AWS EKS Add-on)
# helm repo add argocd https://argoproj.github.io/argo-helm
# helm install argocd -n argocd --create-namespace argocd/argo-cd

---
# ArgoCD Application: UI Microservice
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ui
  namespace: argocd
spec:
  # Project (RBAC grouping)
  project: default
  
  # Source: Where to deploy FROM (Git)
  source:
    repoURL: https://github.com/myorg/retail-store.git
    targetRevision: main                    # Branch to sync from
    
    # Using Helm as templating engine
    path: 03_RetailStore_Helm_with_Data_Plane/02_retailstore_values_HELM_aws_dataplane
    
    helm:
      releaseName: ui
      
      # Override default values
      values: |
        image:
          repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/retail-store/ui
          tag: latest
      
      # Use custom values file
      valueFiles:
        - values-ui.yaml              # Primary values
  
  # Destination: Where to deploy TO (Kubernetes cluster)
  destination:
    server: https://kubernetes.default.svc  # Current cluster
    namespace: default                      # Target namespace
  
  # Sync Policy: How to keep cluster in sync
  syncPolicy:
    # Automatic sync: changes detected in Git → auto-deploy
    automated:
      prune: true          # Delete resources not in Git
      selfHeal: true       # If pod crashes, redeploy
      allowEmpty: false    # Don't delete all pods
    
    # Progressive syncing
    syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true
    
    # Retry on failure
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    
    # Health assessment
    progressDeadlineSeconds: 600
  
  # Revision History (keep last 10)
  revisionHistoryLimit: 10

---
# ArgoCD Application: Catalog Service
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: catalog
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/myorg/retail-store.git
    targetRevision: main
    path: 03_RetailStore_Helm_with_Data_Plane/02_retailstore_values_HELM_aws_dataplane
    
    helm:
      releaseName: catalog
      valueFiles:
        - values-catalog.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# Similar for other services (cart, checkout, orders)
# Each has its own Application CRD
```

### ArgoCD Management Commands

```bash
# Install ArgoCD
helm repo add argocd https://argoproj.github.io/argo-helm
helm install argocd argocd/argo-cd -n argocd --create-namespace

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access: https://localhost:8080
# Username: admin
# Password: (from above)

# CLI commands
# Login
argocd login localhost:8080

# Create application from CLI
argocd app create ui \
  --repo https://github.com/myorg/retail-store.git \
  --path 03_RetailStore_Helm_with_Data_Plane \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# View applications
argocd app list

# View specific app
argocd app get ui

# Sync (manual deployment)
argocd app sync ui

# Rollback to previous version
argocd app rollback ui 1

# Watch deployment
argocd app wait ui --sync

# Delete application
argocd app delete ui
```

---

## Complete Automation Workflow

```
COMPLETE END-TO-END AUTOMATION
═════════════════════════════════════════════════════════════════

Developer Flow:
┌─────────────────────────────────────────────────────────────────┐
│ 1. Developer makes code change (e.g., UI logo update)            │
│ 2. git commit && git push (to GitHub)                            │
│ 3. GitHub Actions triggered automatically:                      │
│    ├─ Build Docker image from code                              │
│    ├─ Tag with commit SHA                                       │
│    ├─ Push to Amazon ECR                                        │
│    └─ Update Helm values.yaml with new image tag               │
│ 4. Git commit pushed (automatic)                                │
│    └─ values-ui.yaml: image.tag = abc1234                      │
│ 5. ArgoCD detects change in Git:                               │
│    ├─ Reads updated values.yaml                                │
│    ├─ Helm charts generate K8s manifests                       │
│    ├─ Deploys to EKS via helm upgrade                          │
│    └─ Rolling update (zero-downtime)                           │
│ 6. Application running with new changes                         │
│    └─ End-to-end time: ~2-3 minutes                           │
│ 7. If something breaks:                                         │
│    ├─ ArgoCD detects unhealthy pods                           │
│    ├─ Auto-rollback to previous version                        │
│    └─ Alerts developer (Slack, email)                         │
└─────────────────────────────────────────────────────────────────┘

SYSTEM COMPONENTS WORKING TOGETHER:
═════════════════════════════════════════════════════════════════

┌─────────────────┐
│  GitHub Repo    │ ← Source of truth for application code
│  + Helm Charts  │   + configuration
└────────┬────────┘
         │
    (webhook)
         │
         ↓
┌─────────────────────────────┐
│   GitHub Actions CI         │ Builds & tests automatically
│   (Build, Test, Push)       │ on every push
└────────┬────────────────────┘
         │
    (push image)
         │
         ↓
┌──────────────────────────────┐
│   Amazon ECR                 │ Centralized container registry
│   (Container Images)         │ with encryption & scanning
└────────────────────────────────┘
         ↑
         │  (pull image)
         │
┌────────┴─────────────────┐
│   ArgoCD                  │ Continuous Deployment (GitOps)
│   (GitOps Controller)     │ watches Git for changes
└────────┬─────────────────┘
         │
    (helm upgrade)
         │
         ↓
┌──────────────────────────────┐
│   EKS Cluster                │ Production environment
│   (Running Pods)             │ with Karpenter scaling
└──────────────────────────────┘
```

---

## Interview Q&A - Part 3

### Q1: "How does Karpenter improve upon traditional cluster autoscaling?"

**Answer**:
> "Karpenter is fundamentally different from Cluster Autoscaler:
>
> **Cluster Autoscaler (Traditional)**:
> - Watches Kubernetes Pending pods
> - Calls AWS Auto Scaling Groups API
> - ASG launches instances slowly (2-3 minutes)
> - Doesn't optimize instance selection
> - Struggles with Spot instances
> - Uses fixed node pools
>
> **Karpenter (Modern)**:
> - Watches Pending pods immediately
> - Calls EC2 FleetRequest API (parallel provisioning)
> - Launches instances in 15-30 seconds ✅
> - Bin-packing: automatically selects right instance type
> - Native Spot support with interruption handling
> - Dynamic NodePools with consolidation
>
> **Key Improvements**:
>
> 1. **Speed**
>    - CA: 2-3 minutes (user timeout risk)
>    - Karpenter: 15-30 seconds (imperceptible delay)
>
> 2. **Cost Optimization**
>    - CA: Can't use Spot effectively
>    - Karpenter: 70% cheaper Spot instances with graceful handling
>    - Consolidation: Removes underutilized nodes
>    - Savings: 40-50% with mixed on-demand/Spot
>
> 3. **Instance Selection**
>    - CA: You specify instance types manually
>    - Karpenter: Analyzes pod requirements (CPU, memory), auto-selects optimal instance
>    - Example: 500m CPU request → picks t3.medium (not t3.xlarge)
>
> 4. **Spot Interruption Handling**
>    - CA: No built-in support
>    - Karpenter: Monitors EventBridge for interruption notices
>    - Gracefully drains pods 2 minutes before interruption
>    - Consolidation replaces Spot nodes before expiration
>
> 5. **Zero-Downtime**
>    - Pods evicted gracefully with preStop hooks
>    - PDBs honored (keep minimum replicas)
>    - New pods scheduled before old pods terminate
>
> **Example Cost Savings**:
> - 100 pods needing 2vCPU each = 200vCPU total
> - Cluster Autoscaler: 20 on-demand t3.xlarge = \$2,429/month
> - Karpenter mixed: 15 on-demand + 5 Spot = \$1,001/month
> - **Savings: \$1,428/month (59%) ✅**
>"

---

### Q2: "Walk me through a complete CI/CD deployment from code push to running app"

**Answer**:
> "It's a 5-step automated process:
>
> **Step 1: Developer Pushes Code (T=0)**
> - Developer: git push origin main
> - GitHub receives push
> - Webhook triggers GitHub Actions workflow
>
> **Step 2: GitHub Actions CI (T=0-1min)**
> - Checkout: Clone repo from GitHub
> - OIDC Auth: No hardcoded keys!
>   ├─ GitHub generates OIDC token
>   ├─ Token exchange with AWS STS
>   └─ Get temporary credentials (1 hour validity)
> - Docker Build: Compile app, bundle assets
> - Tag Image: 
>   ├─ retail-store/ui:latest
>   ├─ retail-store/ui:abc1234 (commit SHA)
> - Push to ECR: Upload to Amazon ECR (encrypted)
> - Update Git: Modify values-ui.yaml with new image tag
> - Auto-commit: Push changes back to GitHub
>
> **Step 3: ArgoCD Detects Change (T=1-2min)**
> - ArgoCD continuously polls Git (every 30 seconds by default)
> - Detects: values-ui.yaml changed (image.tag updated)
> - Decision: Cluster state ≠ Git state → OUT OF SYNC
> - Trigger: Auto-sync enabled → DEPLOY
>
> **Step 4: ArgoCD Deploys via Helm (T=2-2.5min)**
> - Helm chart: 03_RetailStore_Helm_with_Data_Plane
> - Command: helm upgrade ui ./charts/ui -f values-ui.yaml
> - Process:
>   ├─ Render templates with new image tag
>   ├─ Generate Kubernetes manifest
>   └─ Apply to cluster
>
> **Step 5: Kubernetes Executes Rolling Update (T=2.5-3min)**
> - Current state: 3 pods running old version (v1.0.0)
> - Rolling Update Strategy:
>   ├─ Create pod 1 with new version (abc1234)
>   ├─ Wait for readiness probe (HTTP /ready)
>   ├─ Service routes traffic to pod 1
>   ├─ Terminate old pod 1
>   ├─ Repeat for pod 2
>   ├─ Repeat for pod 3
>   └─ Result: 3 pods new version, zero downtime ✅
>
> **Step 6: Application Running (T=3min)**
> - All 3 UI pods running new version
> - ALB already routing traffic to them
> - Users see new feature immediately
> - Complete flow: code push → live = **3 minutes**
>
> **Failure Handling**:
> - If pod fails readiness, Kubernetes doesn't proceed
> - ArgoCD detects unhealthy pods
> - Auto-rollback triggers (if configured)
> - Previous version restored
> - Alert sent (Slack)
>
> **Repeatability**:
> - No manual steps
> - Same process every time
> - Complete audit trail in Git
> - Can trace code change → image tag → deployment
>"

---

### Q3: "Why use OIDC instead of hardcoded AWS credentials for GitHub Actions?"

**Answer**:
> "It's a fundamental security improvement:
>
> **❌ OLD WAY (Hardcoded Credentials)**:
> ```
> AWS_ACCESS_KEY_ID=AKIAI234567890ABC
> AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY  
> ```
> - Stored as GitHub Secret (good first step)
> - But secrets are permanent (never expire)
> - If leaked: attacker has full AWS access
> - Difficult to rotate (must update everywhere)
> - Audit trail: Can't tell which action used credentials
>
> **✅ NEW WAY (OIDC Web Identity)**:
> 1. GitHub generates OIDC token (signed by GitHub's private key)
> 2. Token contains metadata:
>    ├─ Repository: myorg/retail-store
>    ├─ Workflow: build-push-ui.yaml
>    ├─ Branch: main
>    ├─ Actor: developer-name
>    ├─ Issued at: 2024-02-09T10:15:32Z
>    └─ Expires in: 5 minutes (ONE-TIME USE)
> 3. GitHub Actions sends token to AWS STS
> 4. AWS validates:
>    ├─ Is this really from GitHub? (verify signature)
>    ├─ Is this repository trusted? (check condition)
>    └─ Does role allow this workflow? (verify principal)
> 5. AWS issues temporary credentials:
>    ├─ AccessKeyId: temporary
>    ├─ SecretAccessKey: temporary
>    ├─ SessionToken: temporary
>    └─ Expires in: 1 hour
>
> **Benefits of OIDC**:
>
> ✅ **No Stored Credentials**
>    - Nothing to leak (token is ephemeral)
>    - Each workflow gets unique token
>    - Can't reuse across workflows
>
> ✅ **Automatic Expiration**
>    - GitHub token: 5 minutes (one-time)
>    - AWS credentials: 1 hour (can't be reused)
>    - Credentials don't persist
>
> ✅ **Fine-Grained Audit Trail**
>    - CloudTrail logs show:
>       ├─ Which GitHub repo made call
>       ├─ Which workflow triggered it
>       ├─ Which branch it ran on
>       ├─ Exact timestamp
>       └─ Can't do this with stored keys
>
> ✅ **Easy Rotation**
>    - No secrets to rotate
>    - Just trust GitHub if it's still secure
>    - (GitHub maintains OIDC keys, not you)
>
> ✅ **Least Privilege**
>    - Can restrict to specific repos
>    - Can restrict to specific branches
>    - Can restrict to specific workflows
>    - Example: Only allow main branch to deploy to prod
>
> **Security Comparison**:
> ```
> Stored Key:
> ├─ Lifetime: Unlimited (until rotated)
> ├─ Scope: Any action that can access secrets
> ├─ Leak impact: Full AWS access forever
> └─ Audit: Action name, but not definitive
>
> OIDC Token:
> ├─ Lifetime: 5 minutes (GitHub) → 1 hour (AWS)
> ├─ Scope: Only this specific workflow execution
> ├─ Leak impact: Can't reuse (already expired)
> └─ Audit: Complete lineage from GitHub
> ```
>
> **AWS Best Practice**: OIDC is now the recommended approach. It's how enterprise customers do it.
>"

---

### Q4: "How does ArgoCD handle failed deployments?"

**Answer**:
> "ArgoCD has sophisticated failure detection and remediation:
>
> **Scenario**: New image pushed, deployment happens, but app crashes
>
> **Detection Phase**:
> 1. ArgoCD deploys new version via helm upgrade
> 2. Kubernetes creates new pods with new image
> 3. New pod starts but readiness probe fails (app error)
> 4. Pod remains in NotReady state
>
> **Health Assessment**:
> ArgoCD checks application health:
> ```
> Pod 1: Running, but NotReady (readiness probe failed)
>        Status: Progressing/Degraded
> Pod 2: Running, but NotReady (same issue)
>        Status: Progressing/Degraded
> Pod 3: Still Running (old version, still healthy)
>        Status: Healthy
> ```
> *(Note: depends on surge strategy)*
>
> **Automatic Remediation Options**:
>
> **Option 1: Auto-Rollback (if configured)**
> ```
> Application sync policy:
>   syncPolicy:
>     automated:
>       prune: true
>       selfHeal: true
>       allowEmpty: false
> ```
> - ArgoCD detects degradation
> - Rolls back to previous stable version
> - Updates Helm to previous version
> - Pods recover to last known good state
> - Alert sent to team (manual review needed)
>
> **Option 2: Manual Intervention (safer)**
> ```
> Application status: OUT OF SYNC / DEGRADED
> UI shows: Health issues detected
> Team receives alert: \"UI deployment failed\"
> ```
> - Developer checks logs:
>   ├─ kubectl logs <pod>
>   ├─ kubectl describe pod <pod>
>   └─ Debugging shows: TypeError in JavaScript (bad build)
> - Fix applied to source code
> - New commit pushed
> - GitHub Actions rebuilds
> - ArgoCD detects new image tag
> - Deployment retries
>
> **Option 3: Progressive Deployment (Canary/Blue-Green)**
> ```yaml
> apiVersion: argoproj.io/v1alpha1
> kind: Application
> metadata:
>   name: ui
>   annotations:
>     argocd.argoproj.io/deployment-strategy: progressive
> spec:
>   syncPolicy:
>     syncStrategy:
>       canary:
>         steps:
>         - weight: 10        # Route 10% to new version
>         - pause: {}         # Wait for metrics
>         - weight: 50        # Route 50% to new version
>         - pause: {}
>         - weight: 100       # Route 100%
> ```
> - Only 10% of traffic gets new version initially
> - Monitor error rates, latency
> - If metrics look good: proceed to 50%
> - If problems detected: auto-revert to 0%
> - Zero customer impact!
>
> **Failure Notification**:
> ArgoCD sends alerts:
> - Slack: 'UI deployment failed, rolling back'
> - Email: detailed failure report
> - Jira: auto-create incident ticket
> - Datadog: integration with monitoring
>
> **Prevention Mechanisms**:
> 1. **Pre-deployment Checks**
>    - GitHub Actions tests before push
>    - Helm chart validation
>    - Security scanning
> 2. **Readiness Probes** (in pod spec)
>    - HTTP GET /health (every 5 seconds)
>    - If fail 2x → not ready
>    - Prevents traffic routing to bad pods
> 3. **Pod Disruption Budgets**
>    - Minimum availability guaranteed
>    - Prevents all pods from being replaced at once
> 4. **Resource Limits**
>    - Prevents OOM crashes
>    - CPU throttling prevents slowdowns
>
> **Philosophy**: Failures are expected in production. Design for graceful degradation, not failure prevention.
>"

---

### Q5: "How do all these systems work together in production?"

**Answer**:
> "It's an integrated ecosystem:
>
> **Development to Production Journey**:
>
> **DAY 1: Setup**
> ├─ Terraform creates EKS cluster + all add-ons
> ├─ Karpenter installed for auto-scaling nodes
> ├─ Helm charts created for each microservice
> ├─ GitHub Actions workflow defined
> ├─ ArgoCD deployed and configured
> └─ All pieces in place
>
> **DAY 30: Production Release**
> ├─ Daily deployments automated
> ├─ Traffic scales with demand (HPA)
> ├─ Nodes auto-scale (Karpenter)
> ├─ Costs optimized (Spot + On-Demand mix)
> ├─ All observable (OpenTelemetry)
> └─ Zero manual intervention
>
> **REAL TIME FLOW**:
>
> **T+0min**: Traffic surge detected
> │
> ├─ HPA: CPU usage increases 85% → scale pods 3→5
> ├─ Karpenter: Not enough node capacity
> └─ Karpenter provisions new t3.large (30s)
>
> **T+0:30**: New pods running, traffic stabilized
> │
> ├─ HPA: CPU now 78% (stable)
> ├─ Karpenter: Nodes ready, consolidation evaluated
> └─ App responsive, all users happy
>
> **DEPLOYMENT DURING PEAK TRAFFIC**:
>
> **T=peak traffic**: Traffic 100 req/s
> │
> ├─ Developer pushes UI fix
> ├─ GitHub Actions: Build new image (1 min)
> ├─ ArgoCD: Detect new version (30 sec)
> ├─ Deployment: Rolling update starts
> │  ├─ Create 1 new pod (surge=1)
> │  ├─ Wait for readiness (healthy)
> │  ├─ Old pod terminates gracefully
> │  └─ Repeat for remaining pods
> │
> ├─ During update: Always 4-5 pods handling traffic
> ├─ Zero downtime: Requests never drop
> └─ Users don't notice (completely transparent)
>
> **SYSTEM RESILIENCE**:
>
> Failure Scenario: Database connection timeout
> │
> ├─ Application logs: 'DB connection timeout'
> ├─ OpenTelemetry: Trace shows latency spike (X-Ray)
> ├─ CloudWatch: Error rate alert triggered
> ├─ Metrics: Slow queries detected
> ├─ Developer: Looks at traces → finds bad query
> ├─ Quick fix: Deploy new version
> │  ├─ Code change committed
> │  ├─ GitHub Actions rebuilds
> │  ├─ ArgoCD deploys
> │  └─ Fixed in production (2 min)
> ├─ Monitoring: Error rate returns to normal
> └─ All automated!
>
> **COST OPTIMIZATION**:
>
> ├─ Off-peak hours (2am-6am): 3 pods (1 on-demand)
> │  └─ Cost: ~\$0.10/hour (minimal)
> │
> ├─ Business hours (9am-5pm): 20 pods (15 on-demand + 5 Spot)
> │  └─ Cost: ~\$1.50/hour (pay for what you use)
> │
> ├─ Peak hours: 40 pods (30 on-demand + 10 Spot)
> │  └─ Cost: ~\$3.00/hour (necessary for traffic)
> │
> └─ Monthly: ~\$1,200 (fully managed, auto-scaling)
>
> **COMPLETE AUTOMATION BENEFITS**:
> ├─ ✅ Time: From code change to production in 2-3 minutes
> ├─ ✅ Reliability: No human errors in deployment
> ├─ ✅ Visibility: Complete audit trail in Git
> ├─ ✅ Safety: Automatic rollback on failures
> ├─ ✅ Cost: Pay exactly for what you use
> ├─ ✅ Scalability: From 100 to 10,000 pods transparently
> └─ ✅ Operations: DevOps, not 'DevOps on-call'
>"

---

## Final Summary

You have implemented a **world-class, production-ready Kubernetes infrastructure** demonstrating:

**Infrastructure & Operations**:
- Terraform IaC for reproducible deployments
- EKS cluster with enterprise networking
- All critical add-ons (Pod Identity, Storage, Networking, DNS)

**Application Scaling**:
- Horizontal Pod Autoscaling (HPA) for demand-driven scaling
- Karpenter for intelligent node provisioning
- Cost optimization via Spot instances
- Zero-downtime deployments

**Microservices Architecture**:
- 5 independent, scalable microservices
- AWS data plane integration (RDS, DynamoDB, ElastiCache, SQS)
- Secure secret management
- Persistent storage with EBS

**CI/CD Automation**:
- GitHub Actions for Continuous Integration
- OIDC-based secure AWS access (no hardcoded credentials)
- Docker image building and ECR deployment
- ArgoCD for GitOps-style Continuous Deployment
- Helm for standardized, reproducible deployments

**Observability**:
- OpenTelemetry for distributed tracing
- Complete audit trail of every deployment
- Real-time monitoring and alerting
- Root cause analysis capabilities

This is **enterprise-grade infrastructure** with all the hallmarks of production systems at scale.

