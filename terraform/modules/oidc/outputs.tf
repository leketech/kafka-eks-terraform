output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = data.aws_iam_openid_connect_provider.existing_github.arn
}

output "aws_account_id" {
  description = "AWS Account ID (needed for GitHub Actions secret)"
  value       = var.aws_account_id
}