# Trigger Workflow

This file is used to trigger the GitHub Actions workflow.

## Last Updated

Updated on: 2025-10-25

Fixed S3 access issues for Terraform state.

Applied bucket policy updates to resolve HeadObject permission issues.

Testing with enhanced debugging to check secret configuration.

Triggering workflow to verify all fixes:
- KMS DeleteAlias permission added
- KMS UpdateKeyDescription permission added
- KMS CreateAlias permission added
- IAM CreateOpenIDConnectProvider permission added
- IAM TagOpenIDConnectProvider permission added
- EC2 ModifyLaunchTemplate permission added
- CloudWatch Log Group conflicts resolved
- All state locks removed from DynamoDB
- Failed node group deleted
- All workflows should now pass