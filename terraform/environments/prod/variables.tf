variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"
    ], var.aws_region)
    error_message = "The aws_region value must be a valid AWS region identifier."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "kafka-eks-new-1"  // Changed to avoid conflict
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state (required for team use)"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format: username/repo-name (for OIDC authentication)"
  type        = string
  default     = "leketech/kafka-eks-terraform"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+/[a-zA-Z0-9-_]+$", var.github_repo))
    error_message = "github_repo must be in format 'username/repository' (e.g., 'leketech/kafka-eks-terraform')."
  }
}

variable "aws_account_id" {
  description = "AWS Account ID for IAM role configuration"
  type        = string
  default     = "907849381252"
}