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
  value       = coalesce(
    data.aws_iam_openid_connect_provider.existing_github.arn,
    aws_iam_openid_connect_provider.github[0].arn
  )
}

output "aws_account_id" {
  description = "AWS Account ID (needed for GitHub Actions secret)"
  value       = var.aws_account_id
}