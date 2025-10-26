# Fix for IAM Role Deletion Issues

## Problem

The Terraform apply workflow is failing with the following error:

```
Error: deleting IAM Role (kafka-eks-new-cluster-20251025142556452100000001): reading IAM Instance Profiles for Role (kafka-eks-new-cluster-20251025142556452100000001): operation error IAM: ListInstanceProfilesForRole, https response error StatusCode: 403, RequestID: 2b4663ba-faab-47af-92a1-01ea2979dc79, api error AccessDenied: User: arn:aws:sts::907849381252:assumed-role/GitHubActionsKafkaDeployRole/github-actions-140243f7617ff19a576ec4e1595c327581457643 is not authorized to perform: iam:ListInstanceProfilesForRole on resource: role kafka-eks-new-cluster-20251025142556452100000001 because no identity-based policy allows the iam:ListInstanceProfilesForRole action
```

This error indicates that the GitHub Actions role is missing the `iam:ListInstanceProfilesForRole` permission required to delete IAM roles.

## Root Cause

When Terraform tries to delete an IAM role, it first needs to check if there are any instance profiles attached to that role. This requires the `iam:ListInstanceProfilesForRole` permission, which was missing from the GitHub Actions role policy.

## Solution

I've implemented a fix to resolve this issue:

### 1. Enhanced IAM Permissions

Updated the OIDC module ([terraform/modules/oidc/main.tf](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/terraform/modules/oidc/main.tf)) to include the missing permission:

- Added `iam:ListInstanceProfilesForRole` to the IAM permissions section

### 2. Updated Troubleshooting Guide

Enhanced the [TROUBLESHOOTING_GUIDE.md](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/TROUBLESHOOTING_GUIDE.md) with specific instructions for this issue:

- Added a new section for IAM role deletion issues
- Included detailed steps to diagnose and fix the permission issue

## How to Apply the Fix

### 1. Apply the Updated Configuration

```bash
# Navigate to the Terraform environment
cd terraform/environments/prod

# Apply the OIDC module to update IAM permissions
terraform apply -target=module.oidc -auto-approve
```

### 2. Verify the Permissions

```bash
# Check the role policy
aws iam get-role-policy --role-name GitHubActionsKafkaDeployRole --policy-name terraform-kafka-permissions

# Test the permission (replace with an actual role name from the error)
aws iam list-instance-profiles-for-role --role-name kafka-eks-new-cluster-20251025142556452100000001
```

### 3. Retry the Terraform Apply

```bash
# Continue with the Terraform apply
terraform apply
```

## Prevention

The updated configuration should prevent this issue from recurring:

1. **Comprehensive IAM permissions** - All required permissions for IAM role management are now included
2. **Enhanced troubleshooting** - Better documentation is available for future issues

## Additional Debugging

If the issue persists, you can use the following commands for additional debugging:

```bash
# Check the detailed role policy
aws iam get-role-policy --role-name GitHubActionsKafkaDeployRole --policy-name terraform-kafka-permissions --query 'PolicyDocument.Statement[?Resource!=null]' --output json

# List all roles to see which ones might be causing issues
aws iam list-roles --query 'Roles[?starts_with(RoleName, `kafka-eks`)].RoleName' --output table

# Check a specific role's instance profiles
aws iam list-instance-profiles-for-role --role-name ROLE_NAME_FROM_ERROR
```