#!/bin/bash

# Script to fix common Terraform issues in the kafka-eks-terraform project

set -e  # Exit on any error

echo "=== Fixing Terraform Issues ==="

# Check if we're in the right directory
if [[ ! -f "main.tf" ]]; then
  if [[ -f "terraform/environments/prod/main.tf" ]]; then
    cd terraform/environments/prod
  else
    echo "Error: Cannot find Terraform configuration files"
    exit 1
  fi
fi

echo "1. Checking for active state lock..."
LOCK_CHECK=$(aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}' || true)

if [[ "$LOCK_CHECK" != *"{}"* && -n "$LOCK_CHECK" ]]; then
  echo "Active lock found. Removing..."
  aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks-new/terraform.tfstate-md5"}}'
  echo "Lock removed."
else
  echo "No active lock found."
fi

echo "2. Cleaning local Terraform state..."
rm -rf .terraform
rm -f terraform.tfstate.backup

echo "3. Re-initializing Terraform..."
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET:-my-terraform-state-kafka-eks-12345}" \
  -backend-config="key=kafka-eks-new/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE:-terraform-locks}"

echo "4. Updating IAM permissions..."
terraform apply -target=module.oidc -auto-approve

echo "5. Running plan..."
terraform plan -out=tfplan

echo "Fix process completed. You can now run 'terraform apply tfplan' to deploy."

echo "=== Next Steps ==="
echo "1. Review the plan: terraform show tfplan"
echo "2. Apply the plan: terraform apply tfplan"
echo "3. Push changes to trigger workflows in the correct order"