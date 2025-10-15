# ============================================================================
# Providers Configuration
# ============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# VPC Module
# ============================================================================

module "vpc" {
  source = "../../modules/vpc"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  cluster_name       = var.cluster_name
}

# ============================================================================
# OIDC Module
# ============================================================================

module "oidc" {
  source = "../../modules/oidc"

  github_repo            = var.github_repo
  aws_account_id         = var.aws_account_id
  terraform_state_bucket = var.terraform_state_bucket
  dynamodb_table         = var.dynamodb_table
}

# ============================================================================
# EKS Module
# ============================================================================

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_group_min_size     = 2
  node_group_max_size     = 4
  node_group_desired_size = 3

  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
}

# ============================================================================
# Data Sources for Cluster Access
# ============================================================================

data "aws_eks_cluster" "kafka" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "kafka" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

// Add a small delay to ensure the cluster is fully ready
resource "time_sleep" "wait_for_cluster_data" {
  create_duration = "60s"

  depends_on = [module.eks]
}

// Kubernetes provider configuration that works both locally and in GitHub Actions
provider "kubernetes" {
  host                   = data.aws_eks_cluster.kafka.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.kafka.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.kafka.token
  
  // For GitHub Actions, we'll override this with exec-based auth
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.kafka.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.kafka.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.kafka.token
    
    // For GitHub Actions, we'll override this with exec-based auth
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}

// Add a data source to verify the Kubernetes provider is working
data "kubernetes_service" "test" {
  depends_on = [time_sleep.wait_for_cluster_data]

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

// Outputs for GitHub Actions
output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions OIDC authentication"
  value       = module.oidc.github_actions_role_name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication"
  value       = module.oidc.github_actions_role_arn
}
