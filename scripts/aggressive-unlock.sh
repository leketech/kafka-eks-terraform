#!/bin/bash

# Aggressive Terraform unlock script - removes all locks from the DynamoDB table

echo "=== Aggressive Terraform Unlock Script ==="

# Check if required environment variables are set
if [ -z "$TF_STATE_LOCK_TABLE" ]; then
  echo "❌ TF_STATE_LOCK_TABLE environment variable is not set"
  echo "Please set it to your DynamoDB lock table name (e.g., terraform-locks)"
  exit 1
fi

echo "Using DynamoDB table: $TF_STATE_LOCK_TABLE"

# Check if we have scan permissions
echo "Checking DynamoDB scan permissions..."
aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --max-items 1 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ DynamoDB scan permission confirmed"
  # Scan all locks in the table
  echo "Scanning all locks in table..."
  LOCKS=$(aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --output json 2>/dev/null)
else
  echo "⚠️ No scan permission or table inaccessible, trying alternative approaches..."
  LOCKS="{}"
fi

if [ $? -ne 0 ] && [ "$LOCKS" != "{}" ]; then
  echo "❌ Failed to scan DynamoDB table"
  exit 1
fi

# Get lock count
if [ "$LOCKS" != "{}" ]; then
  LOCK_COUNT=$(echo "$LOCKS" | jq '.Count' 2>/dev/null || echo "0")
else
  LOCK_COUNT="0"
fi

if [ "$LOCK_COUNT" -eq "0" ]; then
  echo "✅ No locks found in the table"
  exit 0
fi

echo "Found $LOCK_COUNT lock(s) in the table"

# Extract lock IDs (only if we have scan permissions)
if [ "$LOCKS" != "{}" ]; then
  LOCK_IDS=$(echo "$LOCKS" | jq -r '.Items[].LockID.S' 2>/dev/null || echo "")
else
  echo "Skipping lock ID extraction due to permission limitations"
  LOCK_IDS=""
fi

if [ -z "$LOCK_IDS" ] && [ "$LOCKS" != "{}" ]; then
  echo "⚠️ No lock IDs found in scan results"
  exit 0
fi

# Remove each lock
echo "Removing locks..."
if [ -n "$LOCK_IDS" ]; then
  # We have lock IDs from scan
  for lock_id in $LOCK_IDS; do
    echo "Removing lock: $lock_id"
    
    # Create JSON key for this lock ID
    KEY_JSON=$(printf '{"LockID": {"S": "%s"}}' "$lock_id")
    
    # Try to delete the lock
    aws dynamodb delete-item --table-name "$TF_STATE_LOCK_TABLE" --key "$KEY_JSON" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
      echo "✅ Lock '$lock_id' removed successfully"
    else
      echo "❌ Failed to remove lock '$lock_id'"
    fi
  done
else
  # Try known lock IDs
  echo "Trying known lock IDs..."
  
  KNOWN_LOCKS=(
    "my-terraform-state-kafka-eks-12345/kafka-eks-new/terraform.tfstate"
    "kafka-eks-new/terraform.tfstate-md5"
  )
  
  for lock_id in "${KNOWN_LOCKS[@]}"; do
    echo "Trying to remove lock: $lock_id"
    KEY_JSON=$(printf '{"LockID": {"S": "%s"}}' "$lock_id")
    aws dynamodb delete-item --table-name "$TF_STATE_LOCK_TABLE" --key "$KEY_JSON" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ Lock '$lock_id' removed successfully"
    else
      echo "⚠️ Failed to remove lock '$lock_id' (may not exist)"
    fi
  done
fi

# Final verification
echo "Verifying locks have been removed..."
FINAL_LOCK_CHECK=$(aws dynamodb get-item --table-name "$TF_STATE_LOCK_TABLE" --key '{"LockID": {"S": "my-terraform-state-kafka-eks-12345/kafka-eks-new/terraform.tfstate"}}' 2>/dev/null || echo "{}")
if [ "$FINAL_LOCK_CHECK" = "{}" ]; then
  echo "✅ Specific lock no longer exists"
else
  echo "⚠️ Specific lock may still exist"
fi

# Try scan if we have permissions
aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --max-items 1 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  FINAL_LOCKS=$(aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --output json 2>/dev/null)
  FINAL_COUNT=$(echo "$FINAL_LOCKS" | jq '.Count' 2>/dev/null || echo "0")
  
  if [ "$FINAL_COUNT" -eq "0" ]; then
    echo "✅ All locks have been successfully removed"
  else
    echo "⚠️ $FINAL_COUNT lock(s) still remain in the table"
  fi
else
  echo "⚠️ Cannot verify remaining locks due to permission limitations"
fi

echo "=== Unlock process completed ==="