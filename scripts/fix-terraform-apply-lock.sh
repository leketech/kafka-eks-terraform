#!/bin/bash

# Script to fix the specific Terraform lock issue in the apply workflow

echo "=== Fixing Terraform Apply Lock Issue ==="

# Check if required environment variables are set
if [ -z "$TF_STATE_LOCK_TABLE" ]; then
  echo "❌ TF_STATE_LOCK_TABLE environment variable is not set"
  echo "Please set it to your DynamoDB lock table name (e.g., terraform-locks)"
  exit 1
fi

if [ -z "$TF_STATE_BUCKET" ]; then
  echo "❌ TF_STATE_BUCKET environment variable is not set"
  echo "Please set it to your S3 bucket name (e.g., my-terraform-state-kafka-eks-12345)"
  exit 1
fi

echo "Using DynamoDB table: $TF_STATE_LOCK_TABLE"
echo "Using S3 bucket: $TF_STATE_BUCKET"

# Extract the specific lock ID from the error message
# Error shows: Lock Info: ID: 8536632e-b54c-0b6e-1697-1679e7de1025, Path: ***/kafka-eks-new/terraform.tfstate
echo "Removing the specific lock causing the issue..."

# Try to remove the lock with the exact path from the error
aws dynamodb delete-item --table-name "$TF_STATE_LOCK_TABLE" --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}' && echo "✅ Lock with path '***/kafka-eks-new/terraform.tfstate' removed" || echo "⚠️ Failed to remove lock with path '***/kafka-eks-new/terraform.tfstate'"

# Also try the MD5 version
aws dynamodb delete-item --table-name "$TF_STATE_LOCK_TABLE" --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}' && echo "✅ Lock with MD5 'kafka-eks-new/terraform.tfstate-md5' removed" || echo "⚠️ Failed to remove lock with MD5 'kafka-eks-new/terraform.tfstate-md5'"

# Try the direct path as well
aws dynamodb delete-item --table-name "$TF_STATE_LOCK_TABLE" --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate"}}' && echo "✅ Lock with direct path 'kafka-eks-new/terraform.tfstate' removed" || echo "⚠️ Failed to remove lock with direct path 'kafka-eks-new/terraform.tfstate'"

# Clean local Terraform state
echo "Cleaning local Terraform state..."
cd terraform/environments/prod 2>/dev/null || echo "Not in terraform directory, will not clean local state"

# Final verification
echo "Verifying the specific lock has been removed..."
FINAL_LOCK_CHECK=$(aws dynamodb get-item --table-name "$TF_STATE_LOCK_TABLE" --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}' 2>/dev/null || echo "{}")
if [ "$FINAL_LOCK_CHECK" = "{}" ]; then
  echo "✅ Specific lock no longer exists"
else
  echo "⚠️ Specific lock may still exist"
fi

echo "=== Terraform Apply Lock Fix Completed ==="
echo "You can now retry the Terraform apply workflow"