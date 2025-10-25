# Fixing Terraform Workflow Issues

## Problem Summary

1. **Node Group Creation Failure**: "Instances failed to join the kubernetes cluster"
2. **State Lock Issue**: "Error releasing the state lock"
3. **Workflow Triggering Problems**: Plan workflow not triggering, deploy workflow not running

## Root Causes and Solutions

### 1. Node Group Creation Failure

**Root Cause**: Missing IAM permissions for EKS node group creation.

**Solution**: The OIDC module already includes the required permissions:
- `iam:TagOpenIDConnectProvider`
- `ec2:ModifyLaunchTemplate`

However, the role might not have been properly updated. Run the following to ensure the role has all required permissions:

```bash
# Re-apply the OIDC module to update the role permissions
cd terraform/environments/prod
terraform apply -target=module.oidc
```

### 2. State Lock Issue

**Root Cause**: Previous Terraform operation was interrupted, leaving a lock in the DynamoDB table.

**Solution**: 
1. First, check if there's an active lock:
   ```bash
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

2. If a lock exists and you're certain no other operations are running, remove it:
   ```bash
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

3. Clean up local state:
   ```bash
   rm -rf .terraform
   ```

### 3. Workflow Triggering Problems

**Root Cause**: Apply workflow failures prevent downstream workflows from triggering.

**Solution**:
1. Fix the node group permissions issue
2. Clear the state lock
3. Re-run the workflows in order:
   - terraform-plan.yml (trigger manually or with a PR)
   - terraform-apply.yml (will trigger automatically on main branch push after successful plan)
   - kafka-deploy.yml (will trigger automatically after successful apply)

## Step-by-Step Fix Process

1. **Clear the state lock**:
   ```bash
   # Check for active lock
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   
   # If lock exists, remove it (only if you're sure no other operations are running)
   aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
   ```

2. **Clean local state**:
   ```bash
   cd terraform/environments/prod
   rm -rf .terraform
   ```

3. **Re-initialize Terraform**:
   ```bash
   terraform init \
     -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
     -backend-config="key=kafka-eks-new/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=terraform-locks"
   ```

4. **Update IAM permissions**:
   ```bash
   terraform apply -target=module.oidc
   ```

5. **Run a new plan and apply**:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Prevention for Future

1. Always let workflows complete naturally - avoid cancelling them manually
2. Ensure GitHub secrets are properly configured:
   - `TF_STATE_BUCKET`
   - `TF_STATE_LOCK_TABLE`
3. Verify IAM role permissions regularly
4. Monitor CloudWatch logs for troubleshooting node group issues