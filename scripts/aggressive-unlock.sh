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

# Scan all locks in the table
echo "Scanning all locks in table..."
LOCKS=$(aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --output json 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "❌ Failed to scan DynamoDB table"
  exit 1
fi

# Get lock count
LOCK_COUNT=$(echo "$LOCKS" | jq '.Count' 2>/dev/null || echo "0")

if [ "$LOCK_COUNT" -eq "0" ]; then
  echo "✅ No locks found in the table"
  exit 0
fi

echo "Found $LOCK_COUNT lock(s) in the table"

# Extract lock IDs
LOCK_IDS=$(echo "$LOCKS" | jq -r '.Items[].LockID.S' 2>/dev/null || echo "")

if [ -z "$LOCK_IDS" ]; then
  echo "⚠️ No lock IDs found in scan results"
  exit 0
fi

echo "Lock IDs found:"
echo "$LOCK_IDS"

# Remove each lock
echo "Removing all locks..."
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

# Final verification
echo "Verifying locks have been removed..."
FINAL_LOCKS=$(aws dynamodb scan --table-name "$TF_STATE_LOCK_TABLE" --output json 2>/dev/null)
FINAL_COUNT=$(echo "$FINAL_LOCKS" | jq '.Count' 2>/dev/null || echo "0")

if [ "$FINAL_COUNT" -eq "0" ]; then
  echo "✅ All locks have been successfully removed"
else
  echo "⚠️ $FINAL_COUNT lock(s) still remain in the table"
fi

echo "=== Unlock process completed ==="