# Kafka EKS Terraform - Troubleshooting Guide

## Current Issues

1. **Node Group Creation Failure**: "Instances failed to join the kubernetes cluster"
2. **State Lock Issue**: "Error acquiring the state lock"
3. **Workflow Triggering Problems**: Plan workflow not triggering, deploy workflow not running
4. **IAM Permission Issues**: Missing permissions for OIDC provider operations

## Root Causes

### Node Group Creation Failure
This error typically occurs when EKS node group instances cannot join the Kubernetes cluster due to:
- Insufficient IAM permissions
- Networking issues (security groups, VPC configuration)
- Bootstrap configuration problems

### State Lock Issue
This happens when a Terraform operation is interrupted, leaving a lock entry in the DynamoDB table.

### Workflow Triggering Problems
GitHub Actions workflows have dependencies:
- `terraform-plan.yml` triggers on PRs and pushes to main
- `terraform-apply.yml` triggers on successful plan completion
- `kafka-deploy.yml` triggers on successful apply completion

### IAM Permission Issues
Missing IAM permissions can prevent Terraform from managing AWS resources properly, particularly:
- OIDC provider operations (create, delete, get)
- DynamoDB operations (scan, get, put, delete)
- S3 operations (list, get, put, delete)

## Solutions

### 1. Fix Node Group Creation Failure

First, ensure your GitHub Actions role has all required permissions:

```bash
# Check if the role exists
aws iam get-role --role-name GitHubActionsKafkaDeployRole

# Check attached policies
aws iam list-attached-role-policies --role-name GitHubActionsKafkaDeployRole

# Check inline policies
aws iam list-role-policies --role-name GitHubActionsKafkaDeployRole
aws iam get-role-policy --role-name GitHubActionsKafkaDeployRole --policy-name terraform-kafka-permissions
```

The role should have permissions for:
- `iam:TagOpenIDConnectProvider`
- `ec2:ModifyLaunchTemplate`
- And all other permissions required for EKS cluster and node group management

### 2. Resolve State Lock Issue

```bash
# Check for active locks
aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'

# If a lock exists and you're certain no operations are running, remove it
aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'

# Clean local state
cd terraform/environments/prod
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate.backup

# Re-initialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=kafka-eks-new/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```

### 3. Fix Workflow Triggering

Ensure GitHub repository secrets are properly configured:
- `TF_STATE_BUCKET`: S3 bucket for Terraform state
- `TF_STATE_LOCK_TABLE`: DynamoDB table for state locking

### 4. Fix IAM Permission Issues

If you encounter permission errors like:
```
User: arn:aws:sts::ACCOUNT_ID:assumed-role/GitHubActionsKafkaDeployRole/SESSION is not authorized to perform: iam:DeleteOpenIDConnectProvider
```

Update the IAM policy attached to the GitHub Actions role to include the missing permissions. The updated policy should include:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:PassRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRoles",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:ListOpenIDConnectProviders",
        "iam:GetOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider"
      ],
      "Resource": "*"
    }
  ]
}
```

After updating the policy, wait a few minutes for the changes to propagate, then try the operation again.

## Step-by-Step Fix Process

1. **Clear any existing state locks**
   ```bash
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

2. **Clean local Terraform state**
   ```bash
   cd terraform/environments/prod
   rm -rf .terraform
   rm -f .terraform.lock.hcl
   rm -f terraform.tfstate.backup
   ```

3. **Re-initialize Terraform**
   ```bash
   terraform init \
     -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
     -backend-config="key=kafka-eks-new/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=terraform-locks"
   ```

4. **Update IAM permissions**
   ```bash
   terraform apply -target=module.oidc -auto-approve
   ```

5. **Run a new plan**
   ```bash
   terraform plan -out=tfplan
   ```

6. **Apply the plan**
   ```bash
   terraform apply tfplan
   ```

## Prevention

1. Always let Terraform operations complete naturally
2. Regularly verify IAM role permissions
3. Ensure GitHub secrets are properly configured
4. Monitor CloudWatch logs for node group issues

## Additional Debugging

If node group issues persist:

1. Check CloudWatch logs:
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/aws/eks"
   ```

2. Check EC2 instances:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=kafka-eks-new-1"
   ```

3. Check security groups:
   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:eks:cluster-name,Values=kafka-eks-new-1"
   ```

## GitHub Actions Specific Solutions

### Automatic Lock Cleanup

The updated workflows now include automatic lock cleanup steps that will attempt to remove stale locks before running Terraform commands. This prevents the "Error acquiring the state lock" issue from blocking your deployments.

### Manual Lock Removal

If you need to manually remove a lock:

1. Go to the AWS DynamoDB console
2. Find your lock table (typically named `terraform-locks`)
3. Look for the item with LockID: `kafka-eks-new/terraform.tfstate-md5`
4. Delete this item if it exists and no operations are currently running

### Local Development

When working locally, if you encounter lock issues:

1. Run the fix script: `./scripts/unlock-terraform.sh`
2. Or manually remove the lock: `aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'`

## Common Error Patterns and Solutions

### "ConditionalCheckFailedException" Error

This error occurs when Terraform tries to acquire a lock but the lock already exists. The solution is to remove the stale lock:

```bash
aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
```

### "Required plugins are not installed" Error

This happens when the Terraform providers are corrupted or missing. Clean the local state and re-initialize:

```bash
cd terraform/environments/prod
rm -rf .terraform
rm -f .terraform.lock.hcl
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=kafka-eks-new/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```

### GitHub Secrets Issues

Ensure your GitHub repository has the required secrets:
- `TF_STATE_BUCKET`: Should be set to `my-terraform-state-kafka-eks-12345`
- `TF_STATE_LOCK_TABLE`: Should be set to `terraform-locks`

You can verify these in your GitHub repository settings under "Settings" → "Secrets and variables" → "Actions".

## Persistent Lock Issues Resolution

If the lock issue persists even after manual removal, try these additional steps:

1. **Check for multiple lock entries**:
   ```bash
   aws dynamodb scan --table-name terraform-locks
   ```

2. **Delete all lock entries**:
   ```bash
   aws dynamodb scan --table-name terraform-locks --query 'Items[].LockID.S' --output text | xargs -I {} aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "{}"}}'
   ```

3. **Verify backend configuration consistency**:
   - Ensure all workflows use the same backend configuration
   - Check that the S3 bucket and DynamoDB table names match across all environments

4. **Check for concurrent operations**:
   - Ensure no other Terraform processes are running
   - Check if any team members are running Terraform operations simultaneously

5. **Increase DynamoDB table capacity** (if using provisioned throughput):
   ```bash
   aws dynamodb update-table --table-name terraform-locks --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
   ```

## Network and Module Download Issues

If Terraform is having trouble downloading modules:

1. **Check network connectivity**:
   ```bash
   curl -I https://registry.terraform.io/
   ```

2. **Clear module cache**:
   ```bash
   rm -rf ~/.terraform.d/plugin-cache/
   ```

3. **Use alternative registry mirrors** (if needed):
   Add to your Terraform configuration:
   ```hcl
   provider_meta "aws" {
     module_source = "terraform-aws-modules"
   }
   ```

4. **Manually download modules**:
   ```bash
   cd terraform/modules
   git clone https://github.com/terraform-aws-modules/terraform-aws-vpc.git vpc
   git clone https://github.com/terraform-aws-modules/terraform-aws-eks.git eks
   ```

## Aggressive Lock Removal

If standard lock removal methods don't work, use the aggressive approach:

1. **Scan all locks in the table**:
   ```bash
   aws dynamodb scan --table-name terraform-locks
   ```

2. **Remove all locks using the aggressive script**:
   ```bash
   ./scripts/aggressive-unlock.sh
   ```

3. **Verify locks have been removed**:
   ```bash
   aws dynamodb scan --table-name terraform-locks
   ```

This approach removes all locks from the DynamoDB table, which should resolve even the most persistent lock issues.

## IAM Permissions Issues

If you encounter permission errors when trying to scan or remove locks, it's likely that the GitHub Actions role is missing required permissions. The role needs the following DynamoDB permissions:

- `dynamodb:Scan` - To list all locks in the table
- `dynamodb:GetItem` - To check if a specific lock exists
- `dynamodb:DeleteItem` - To remove locks

To fix this, update the IAM policy attached to the GitHub Actions role to include these permissions. The updated policy should be:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    }
  ]
}
```

After updating the policy, wait a few minutes for the changes to propagate, then try the lock removal again.

## Specific Fix for Terraform Apply Workflow Lock Issue

The Terraform apply workflow is failing with a specific error:
```
Error: Error acquiring the state lock
Error message: operation error DynamoDB: PutItem, https response error
StatusCode: 400, RequestID: RNKF233JH00TDC4PDNMQ15FNRFVV4KQNSO5AEMVJF66Q9ASUAAJG,
ConditionalCheckFailedException: The conditional request failed
```

This error shows that there's a lock with ID `8536632e-b54c-0b6e-1697-1679e7de1025` and path `***/kafka-eks-new/terraform.tfstate` that's preventing the workflow from running.

To fix this specific issue:

1. **Run the specific fix script**:
   ```bash
   ./scripts/fix-terraform-apply-lock.sh
   ```

2. **Or manually remove the specific lock**:
   ```bash
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}'
   ```

3. **Also remove the MD5 version of the lock**:
   ```bash
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

4. **Verify the locks have been removed**:
   ```bash
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}'
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

The updated GitHub Actions workflows now include enhanced lock cleanup steps that should automatically handle this issue in the future.