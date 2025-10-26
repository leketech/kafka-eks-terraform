# Fix for EKS Node Group Creation Failure

## Problem

The Terraform apply workflow is failing with the following error:

```
Error: waiting for EKS Node Group (kafka-eks-new-1:eks_nodes-20251026064335904800000001) create: unexpected state 'CREATE_FAILED', wanted target 'ACTIVE'. last error: i-001a4bf09d16744e0, i-0f4f94a7229ce04d4, i-0fb59e2cde2feaf88: NodeCreationFailure: Instances failed to join the kubernetes cluster
```

This error indicates that the EKS node group instances are unable to join the Kubernetes cluster.

## Root Causes

The issue can be caused by several factors:

1. **Insufficient IAM permissions** - The GitHub Actions role may be missing required permissions
2. **Networking issues** - Security groups or VPC configuration may prevent instances from joining the cluster
3. **Bootstrap configuration problems** - Instances may not be properly configured to join the cluster
4. **Instance profile or role attachment issues** - The instances may not have the correct IAM roles attached

## Solution

I've implemented several fixes to resolve this issue:

### 1. Enhanced IAM Permissions

Updated the OIDC module ([terraform/modules/oidc/main.tf](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/terraform/modules/oidc/main.tf)) with comprehensive IAM permissions:

- Added missing EC2 permissions including `ec2:ModifyLaunchTemplate`
- Added missing IAM permissions including `iam:GetOpenIDConnectProvider`, `iam:CreateOpenIDConnectProvider`, `iam:DeleteOpenIDConnectProvider`, and `iam:TagOpenIDConnectProvider`
- Added comprehensive KMS permissions
- Added CloudWatch Logs permissions
- Attached the EBS CSI driver policy

### 2. Improved EKS Configuration

Updated the EKS module ([terraform/modules/eks/main.tf](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/terraform/modules/eks/main.tf)) with better configuration:

- Added bootstrap configuration to ensure nodes can join the cluster
- Added proper tagging for node security groups
- Ensured the EBS CSI driver addon is properly configured

### 3. Updated Troubleshooting Guide

Enhanced the [TROUBLESHOOTING_GUIDE.md](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/TROUBLESHOOTING_GUIDE.md) with specific instructions for this issue:

- Added detailed steps to diagnose node group creation failures
- Included commands to check EC2 instances, security groups, and IAM permissions
- Provided a step-by-step fix process

### 4. Created Fix Script

Created a new script [scripts/fix-node-group-issues.sh](file:///c%3A/Users/Leke/ket/kafka-eks-terraform/scripts/fix-node-group-issues.sh) to help diagnose and fix node group issues:

- Checks EKS cluster status
- Lists and checks node groups
- Verifies EC2 instances
- Validates security groups
- Confirms IAM role permissions
- Cleans and re-initializes Terraform state

## How to Apply the Fix

### 1. Run the Fix Script

```bash
# Set required environment variables
export AWS_REGION=us-east-1
export CLUSTER_NAME=kafka-eks-new-1

# Run the fix script
./scripts/fix-node-group-issues.sh
```

### 2. Apply the Updated Configuration

```bash
# Navigate to the Terraform environment
cd terraform/environments/prod

# Apply the OIDC module to update IAM permissions
terraform apply -target=module.oidc -auto-approve

# Apply the EKS module to update node group configuration
terraform apply -target=module.eks -auto-approve
```

### 3. Monitor the Deployment

```bash
# Check the status of the node group
aws eks describe-nodegroup --cluster-name kafka-eks-new-1 --nodegroup-name eks_nodes-20251026064335904800000001

# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=kafka-eks-new-1"

# Check CloudWatch logs for any errors
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"
```

## Prevention

The updated configuration should prevent this issue from recurring:

1. **Comprehensive IAM permissions** - All required permissions are now included
2. **Proper bootstrap configuration** - Nodes are properly configured to join the cluster
3. **Correct tagging** - Resources are properly tagged for identification
4. **Enhanced troubleshooting** - Better documentation and tools are available

## Additional Debugging

If the issue persists, you can use the following commands for additional debugging:

```bash
# Check the detailed status of the node group
aws eks describe-nodegroup --cluster-name kafka-eks-new-1 --nodegroup-name eks_nodes-20251026064335904800000001 --query 'nodegroup.health'

# Check CloudWatch logs for the cluster
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/kafka-eks-new-1"

# Check the launch template used by the node group
aws ec2 describe-launch-templates --filters "Name=tag:eks:cluster-name,Values=kafka-eks-new-1"
```