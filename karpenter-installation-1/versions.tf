# =============================================================================
# versions.tf — Provider + Terraform version constraints
# =============================================================================
# WHY THIS FILE EXISTS:
#   Terraform providers are plugins that talk to external APIs (AWS, Helm, K8s).
#   Pinning versions prevents "works on my machine" drift.
#   Registry: https://registry.terraform.io/
#
# HOW TO READ provider blocks:
#   `source`  = registry path  (namespace/provider)
#   `version` = constraint      (~> 5.0 means >= 5.0, < 6.0)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # AWS provider — creates IAM roles, SQS queues, EventBridge rules, tags, etc.
    # Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Helm provider — installs the Karpenter controller as a Helm release
    # Docs: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    # Kubernetes provider — used for reading cluster metadata
    # Docs: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # TEAM ACTION: Update the bucket, key, and region to your shared S3 backend.
  # This stores terraform.tfstate remotely so the whole team shares state.
  # Docs: https://developer.hashicorp.com/terraform/language/backend/s3
  backend "s3" {
    bucket = "YOUR-TERRAFORM-STATE-BUCKET"       # <-- change this
    key    = "karpenter/terraform.tfstate"
    region = "us-east-1"                          # <-- change if needed
  }
}

# =============================================================================
# Provider configurations
# =============================================================================

provider "aws" {
  region = var.aws_region

  # All resources created by this config inherit these tags automatically.
  # This is a Terraform-level default_tags feature — saves you repeating tags everywhere.
  # Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags
  default_tags {
    tags = merge(var.tags, {
      ManagedBy   = "Terraform"
      Component   = "Karpenter"
      Environment = var.environment
    })
  }
}

# The Helm and Kubernetes providers need your cluster's API endpoint + CA cert.
# We pull these from data sources (see data.tf) rather than hard-coding.
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    # Use AWS CLI token generation for auth (no static kubeconfig needed)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}
