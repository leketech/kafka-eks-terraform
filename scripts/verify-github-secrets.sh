#!/bin/bash

# Script to verify GitHub secrets for Terraform workflows

echo "=== GitHub Secrets Verification ==="

# Check if running in GitHub Actions environment
if [ -n "$GITHUB_ACTIONS" ]; then
  echo "Running in GitHub Actions environment"
  
  # Check if required secrets are set
  if [ -z "$TF_STATE_BUCKET" ]; then
    echo "❌ ERROR: TF_STATE_BUCKET secret is not set!"
  else
    echo "✅ TF_STATE_BUCKET secret is set: $TF_STATE_BUCKET"
  fi
  
  if [ -z "$TF_STATE_LOCK_TABLE" ]; then
    echo "❌ ERROR: TF_STATE_LOCK_TABLE secret is not set!"
  else
    echo "✅ TF_STATE_LOCK_TABLE secret is set: $TF_STATE_LOCK_TABLE"
  fi
  
  # Test AWS credentials
  echo ""
  echo "=== AWS Credentials Test ==="
  if command -v aws &> /dev/null; then
    echo "Testing AWS credentials..."
    aws sts get-caller-identity > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ AWS credentials are valid"
      CALLER_IDENTITY=$(aws sts get-caller-identity)
      echo "Caller identity: $(echo $CALLER_IDENTITY | jq -r '.Arn')"
    else
      echo "❌ AWS credentials are invalid or not configured"
    fi
  else
    echo "❌ AWS CLI is not installed"
  fi
else
  echo "Not running in GitHub Actions environment"
  echo "This script is designed to verify GitHub secrets in GitHub Actions workflows"
  echo ""
  echo "For local testing, ensure you have:"
  echo "1. AWS credentials configured (aws configure)"
  echo "2. The following environment variables set:"
  echo "   - TF_STATE_BUCKET=my-terraform-state-kafka-eks-12345"
  echo "   - TF_STATE_LOCK_TABLE=terraform-locks"
fi

echo ""
echo "=== Backend Resources Verification ==="

# Test S3 bucket access
if [ -n "$TF_STATE_BUCKET" ]; then
  echo "Testing S3 bucket access..."
  aws s3 ls "$TF_STATE_BUCKET" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ S3 bucket $TF_STATE_BUCKET is accessible"
  else
    echo "❌ Cannot access S3 bucket $TF_STATE_BUCKET"
  fi
else
  echo "Skipping S3 bucket test (TF_STATE_BUCKET not set)"
fi

# Test DynamoDB table access
if [ -n "$TF_STATE_LOCK_TABLE" ]; then
  echo "Testing DynamoDB table access..."
  aws dynamodb describe-table --table-name "$TF_STATE_LOCK_TABLE" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ DynamoDB table $TF_STATE_LOCK_TABLE is accessible"
  else
    echo "❌ Cannot access DynamoDB table $TF_STATE_LOCK_TABLE"
  fi
else
  echo "Skipping DynamoDB table test (TF_STATE_LOCK_TABLE not set)"
fi

echo ""
echo "=== Verification Complete ==="