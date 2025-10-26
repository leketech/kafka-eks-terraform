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

# Try multiple approaches to check for locks
LOCKS_FOUND=false

# Approach 1: Check using the specific key from the error message
echo "Checking for lock: kafka-eks-new/terraform.tfstate"
LOCK_INFO_1=$(aws dynamodb get-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate"}}' 2>/dev/null || echo "{}")
if [ "$LOCK_INFO_1" != "{}" ]; then
  echo "Active lock found (approach 1):"
  echo "$LOCK_INFO_1"
  LOCKS_FOUND=true
fi

# Approach 2: Check using the MD5 key from the error message
echo "Checking for lock: kafka-eks-new/terraform.tfstate-md5"
LOCK_INFO_2=$(aws dynamodb get-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}' 2>/dev/null || echo "{}")
if [ "$LOCK_INFO_2" != "{}" ]; then
  echo "Active lock found (approach 2):"
  echo "$LOCK_INFO_2"
  LOCKS_FOUND=true
fi

# Approach 3: Check using the path from the error message
echo "Checking for lock: ***/kafka-eks-new/terraform.tfstate"
LOCK_INFO_3=$(aws dynamodb get-item --table-name $TABLE_NAME --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}' 2>/dev/null || echo "{}")
if [ "$LOCK_INFO_3" != "{}" ]; then
  echo "Active lock found (approach 3):"
  echo "$LOCK_INFO_3"
  LOCKS_FOUND=true
fi

if [ "$LOCKS_FOUND" = true ]; then
  echo ""
  echo "2. Removing stale locks..."
  
  # Remove using the specific key from the error message
  aws dynamodb delete-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate"}}' && echo "✅ Lock 'kafka-eks-new/terraform.tfstate' removed" || echo "⚠️ Failed to remove lock 'kafka-eks-new/terraform.tfstate'"
  
  # Remove using the MD5 key from the error message
  aws dynamodb delete-item --table-name $TABLE_NAME --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}' && echo "✅ Lock 'kafka-eks-new/terraform.tfstate-md5' removed" || echo "⚠️ Failed to remove lock 'kafka-eks-new/terraform.tfstate-md5'"
  
  # Remove using the path from the error message
  aws dynamodb delete-item --table-name $TABLE_NAME --key '{"LockID": {"S": "***/kafka-eks-new/terraform.tfstate"}}' && echo "✅ Lock '***/kafka-eks-new/terraform.tfstate' removed" || echo "⚠️ Failed to remove lock '***/kafka-eks-new/terraform.tfstate'"
  
  echo "Locks removed successfully."
else
  echo "No active locks found."
fi

echo "3. Cleaning local Terraform state..."
rm -rf .terraform
rm -f terraform.tfstate.backup
rm -f terraform.tfstate

echo ""
echo "✅ Terraform state lock cleanup completed!"
echo "You can now run Terraform commands normally."