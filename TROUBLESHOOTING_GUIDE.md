# Kafka EKS Terraform - Troubleshooting Guide

## Current Issues

1. **Node Group Creation Failure**: "Instances failed to join the kubernetes cluster"
2. **State Lock Issue**: "Error releasing the state lock"
3. **Workflow Triggering Problems**: Plan workflow not triggering, deploy workflow not running

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

## Step-by-Step Fix Process

1. **Clear any existing state locks**
   ```bash
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

2. **Clean local Terraform state**
   ```bash
   cd terraform/environments/prod
   rm -rf .terraform
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