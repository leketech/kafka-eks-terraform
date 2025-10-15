variable "github_repo" {
  description = "GitHub repository in format: username/repo-name (for OIDC authentication)"
  type        = string
  default     = "leketech/kafka-k8s-aws"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+/[a-zA-Z0-9-_]+$", var.github_repo))
    error_message = "github_repo must be in format 'username/repository' (e.g., 'leketech/kafka-k8s-aws')."
  }
}

variable "aws_account_id" {
  description = "AWS Account ID for IAM role configuration"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state (required for team use)"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}