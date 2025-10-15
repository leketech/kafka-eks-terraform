# Deployment Guide

This guide explains how to deploy the Kafka EKS solution.

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Terraform** (>= 1.6) installed
4. **kubectl** installed
5. **Helm** (optional, for alternative deployments)
6. **GitHub Repository** for CI/CD

## Initial Setup

### 1. Configure AWS Credentials

```bash
aws configure
```

Or use environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2. Prepare Terraform State Backend

Create an S3 bucket for state storage and a DynamoDB table for state locking:

```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state-kafka-eks-12345

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-kafka-eks-12345 \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 3. Configure Variables

Update `terraform/environments/prod/terraform.tfvars` with your configuration:

```hcl
# AWS Configuration
aws_region = "us-east-1"

# EKS Cluster Configuration
cluster_name = "kafka-eks"

# Terraform State Configuration
terraform_state_bucket = "my-terraform-state-kafka-eks-12345"
dynamodb_table         = "terraform-locks"

# GitHub Repository for OIDC
github_repo    = "your-username/your-repo"
aws_account_id = "123456789012"
```

## Deployment Process

### 1. Deploy Infrastructure

Navigate to the production environment directory:

```bash
cd terraform/environments/prod
```

Initialize Terraform:

```bash
terraform init \
  -backend-config="bucket=my-terraform-state-kafka-eks-12345" \
  -backend-config="key=kafka-eks/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```

Review the execution plan:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

### 2. Configure kubectl

After infrastructure deployment, configure kubectl to access the cluster:

```bash
aws eks update-kubeconfig --name kafka-eks --region us-east-1
```

Or use the provided script:

```bash
./scripts/setup-kubectl.sh
```

### 3. Deploy Kafka Resources

Apply the Kubernetes manifests:

```bash
# Create namespace
kubectl apply -f kubernetes/namespaces/

# Apply storage class
kubectl apply -f kubernetes/storage/

# Apply Zookeeper manifests
kubectl apply -f kubernetes/kafka/zookeeper/

# Apply Kafka manifests
kubectl apply -f kubernetes/kafka/broker/

# Apply monitoring
kubectl apply -f kubernetes/monitoring/
```

### 4. Verify Deployment

Check the status of resources:

```bash
# Check nodes
kubectl get nodes

# Check Zookeeper pods
kubectl get pods -n kafka -l app=zookeeper

# Check Kafka pods
kubectl get pods -n kafka -l app=kafka

# Check services
kubectl get svc -n kafka
```

Or use the verification script:

```bash
./scripts/verify-kafka.sh
```

## CI/CD Setup

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `AWS_ACCOUNT_ID` - Your AWS account ID
- `TF_STATE_BUCKET` - S3 bucket name for Terraform state
- `TF_STATE_LOCK_TABLE` - DynamoDB table name for state locking

### 2. GitHub Actions Workflows

The repository includes three workflows:

1. **Terraform Plan** - Runs on pull requests to validate changes
2. **Terraform Apply** - Runs on push to main to deploy infrastructure
3. **Kafka Deploy** - Runs after successful Terraform Apply to deploy Kafka

## Monitoring and Operations

### Accessing Metrics

The Kafka Exporter exposes metrics on port 9308:

```bash
# Port forward to access metrics
kubectl port-forward svc/kafka-exporter -n kafka 9308:9308
```

Metrics will be available at `http://localhost:9308/metrics`

### Scaling Kafka

To scale the number of Kafka brokers:

1. Update the replica count in `kubernetes/kafka/broker/statefulset.yaml`
2. Apply the changes:

```bash
kubectl apply -f kubernetes/kafka/broker/statefulset.yaml
```

### Upgrading Kafka

To upgrade Kafka:

1. Update the image tag in `kubernetes/kafka/broker/statefulset.yaml`
2. Apply the changes:

```bash
kubectl apply -f kubernetes/kafka/broker/statefulset.yaml
```

## Troubleshooting

### Common Issues

1. **Terraform State Locking**
   - If state is locked, check for running operations
   - Release lock if needed: `terraform force-unlock LOCK_ID`

2. **Kubernetes Connection**
   - Verify AWS credentials: `aws sts get-caller-identity`
   - Update kubeconfig: `aws eks update-kubeconfig --name kafka-eks`

3. **Pods Not Starting**
   - Check pod status: `kubectl describe pod -n kafka POD_NAME`
   - Check logs: `kubectl logs -n kafka POD_NAME`

### Cleaning Up

To remove all resources:

1. Delete Kubernetes resources:

```bash
./scripts/cleanup.sh -y
```

2. Destroy Terraform infrastructure:

```bash
cd terraform/environments/prod
terraform destroy
```

3. Clean up S3 bucket and DynamoDB table:

```bash
# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks

# Delete S3 bucket (ensure it's empty first)
aws s3 rb s3://my-terraform-state-kafka-eks-12345 --force
```