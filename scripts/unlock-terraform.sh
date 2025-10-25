#!/bin/bash

# Script to unlock Terraform state lock

set -e  # Exit on any error

echo "=== Terraform State Lock Cleanup ==="

# Check if we're in the right directory
if [[ ! -f "main.tf" ]]; then
  if [[ -f "terraform/environments/prod/main.tf" ]]; then
    cd terraform/environments/prod
  else
    echo "Error: Cannot find Terraform configuration files"
    exit 1
  fi
fi

# Get table name from backend configuration or environment variable
TABLE_NAME=${TF_STATE_LOCK_TABLE:-terraform-locks}

echo "1. Checking for active state lock in table: $TABLE_NAME..."
LOCK_INFO=$(aws dynamodb get-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}' 2>/dev/null || echo "{}")

if [ "$LOCK_INFO" != "{}" ]; then
  echo "Active lock found:"
  echo "$LOCK_INFO"
  echo ""
  echo "2. Removing stale lock..."
  aws dynamodb delete-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
  echo "Lock removed successfully."
else
  echo "No active lock found."
fi

echo "3. Cleaning local Terraform state..."
rm -rf .terraform
rm -f terraform.tfstate.backup

echo ""
echo "✅ Terraform state lock cleanup completed!"
echo "You can now run Terraform commands normally."