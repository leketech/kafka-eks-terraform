#!/bin/bash

# Script to fix EKS node group creation issues

echo "=== Fixing EKS Node Group Creation Issues ==="

# Check if required environment variables are set
if [ -z "$AWS_REGION" ]; then
  echo "❌ AWS_REGION environment variable is not set"
  echo "Please set it to your AWS region (e.g., us-east-1)"
  exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "❌ CLUSTER_NAME environment variable is not set"
  echo "Please set it to your EKS cluster name (e.g., kafka-eks-new-1)"
  exit 1
fi

echo "Using AWS region: $AWS_REGION"
echo "Using cluster name: $CLUSTER_NAME"

# Check if we're in the right directory
if [[ ! -f "main.tf" ]]; then
  if [[ -f "terraform/environments/prod/main.tf" ]]; then
    cd terraform/environments/prod
  else
    echo "Error: Cannot find Terraform configuration files"
    exit 1
  fi
fi

echo "1. Checking EKS cluster status..."
aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ EKS cluster $CLUSTER_NAME exists"
  aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION | jq '.cluster.status'
else
  echo "❌ EKS cluster $CLUSTER_NAME does not exist or is not accessible"
  exit 1
fi

echo "2. Checking node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --output json 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "Node groups found:"
  echo "$NODE_GROUPS" | jq -r '.nodegroups[]'
  
  # Check status of each node group
  for nodegroup in $(echo "$NODE_GROUPS" | jq -r '.nodegroups[]'); do
    echo "Checking node group: $nodegroup"
    STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION | jq -r '.nodegroup.status')
    echo "  Status: $STATUS"
    
    if [ "$STATUS" = "CREATE_FAILED" ]; then
      echo "  ❌ Node group $nodegroup has failed to create"
      HEALTH=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $AWS_REGION | jq -r '.nodegroup.health')
      echo "  Health: $HEALTH"
    fi
  done
else
  echo "❌ Failed to list node groups"
fi

echo "3. Checking EC2 instances..."
INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" --region $AWS_REGION --output json 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "EC2 instances found:"
  echo "$INSTANCES" | jq -r '.Reservations[].Instances[].InstanceId'
  
  # Check status of each instance
  for instance in $(echo "$INSTANCES" | jq -r '.Reservations[].Instances[].InstanceId'); do
    echo "Checking instance: $instance"
    STATUS=$(aws ec2 describe-instances --instance-ids $instance --region $AWS_REGION | jq -r '.Reservations[].Instances[].State.Name')
    echo "  Status: $STATUS"
    
    if [ "$STATUS" != "running" ]; then
      echo "  ⚠️ Instance $instance is not running (status: $STATUS)"
    fi
  done
else
  echo "❌ Failed to describe EC2 instances"
fi

echo "4. Checking security groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" --region $AWS_REGION --output json 2>/dev/null)
if [ $? -eq 0 ]; then
  echo "Security groups found:"
  echo "$SECURITY_GROUPS" | jq -r '.SecurityGroups[].GroupId'
else
  echo "No security groups found with EKS cluster tag, checking all security groups..."
  ALL_SGS=$(aws ec2 describe-security-groups --region $AWS_REGION --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "All security groups:"
    echo "$ALL_SGS" | jq -r '.SecurityGroups[].GroupId'
  else
    echo "❌ Failed to describe security groups"
  fi
fi

echo "5. Checking IAM role permissions..."
ROLE_NAME="GitHubActionsKafkaDeployRole"
aws iam get-role --role-name $ROLE_NAME > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ IAM role $ROLE_NAME exists"
  
  # Check attached policies
  echo "Attached policies:"
  ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE_NAME --output json)
  echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies[].PolicyName'
  
  # Check inline policies
  echo "Inline policies:"
  INLINE_POLICIES=$(aws iam list-role-policies --role-name $ROLE_NAME --output json)
  echo "$INLINE_POLICIES" | jq -r '.PolicyNames[]'
  
  # Check specific policy
  POLICY_DOC=$(aws iam get-role-policy --role-name $ROLE_NAME --policy-name terraform-kafka-permissions --output json 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "✅ terraform-kafka-permissions policy exists"
  else
    echo "❌ terraform-kafka-permissions policy does not exist"
  fi
else
  echo "❌ IAM role $ROLE_NAME does not exist"
fi

echo "6. Cleaning local Terraform state..."
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate.backup
rm -f terraform.tfstate

echo "7. Re-initializing Terraform..."
terraform init \
  -backend-config="bucket=my-terraform-state-kafka-eks-12345" \
  -backend-config="key=kafka-eks-new/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=terraform-locks"

if [ $? -eq 0 ]; then
  echo "✅ Terraform re-initialized successfully"
else
  echo "❌ Failed to re-initialize Terraform"
  exit 1
fi

echo ""
echo "=== Fix process completed ==="
echo "Next steps:"
echo "1. Review the information above to identify the specific issue"
echo "2. If IAM permissions are missing, run: terraform apply -target=module.oidc -auto-approve"
echo "3. If EKS configuration needs to be updated, run: terraform apply -target=module.eks -auto-approve"
echo "4. Monitor the deployment with: aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name <nodegroup-name>"