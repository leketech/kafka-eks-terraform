# Kafka EKS Terraform

This project deploys Apache Kafka on Amazon EKS (Elastic Kubernetes Service) using Terraform.

## Project Structure

```
kafka-eks-terraform/
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── eks/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── oidc/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── environments/
│   │   └── prod/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf
│   └── README.md
├── kubernetes/
│   ├── namespaces/
│   │   └── kafka.yaml
│   ├── kafka/
│   │   └── strimzi/
│   │       └── kafka-cluster.yaml
│   ├── monitoring/
│   │   └── kafka-exporter.yaml
│   └── storage/
│       └── storage-class.yaml
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       └── kafka-deploy.yml
├── scripts/
│   ├── setup-kubectl.sh
│   ├── verify-kafka.sh
│   └── cleanup.sh
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── TROUBLESHOOTING.md
├── .gitignore
└── README.md
```

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured
- kubectl

## GitHub Actions Setup

To use the GitHub Actions workflows, you need to set up the following repository secrets:

1. `AWS_ACCOUNT_ID` - Your AWS Account ID
2. `TF_STATE_BUCKET` - S3 bucket name for Terraform state
3. `TF_STATE_LOCK_TABLE` - DynamoDB table name for state locking
4. `GITHUB_ACTIONS_ROLE_NAME` - The name of the IAM role created by Terraform (output from `terraform apply`)

After running `terraform apply`, get the role name from the output:
```bash
terraform output github_actions_role_name
```

## Quick Start

1. **Configure AWS credentials**
   ```bash
   aws configure
   ```

2. **Prepare Terraform backend**
   Create an S3 bucket and DynamoDB table for state management:
   ```bash
   aws s3 mb s3://my-terraform-state-kafka-eks-12345
   aws s3api put-bucket-versioning --bucket my-terraform-state-kafka-eks-12345 --versioning-configuration Status=Enabled
   aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST
   ```

3. **Update configuration**
   Modify `terraform/environments/prod/terraform.tfvars` with your settings.

4. **Deploy infrastructure**
   ```bash
   cd terraform/environments/prod
   terraform init -backend-config="bucket=my-terraform-state-kafka-eks-12345" -backend-config="key=kafka-eks/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="dynamodb_table=terraform-locks"
   terraform plan
   terraform apply
   ```

5. **Get the GitHub Actions role name**
   ```bash
   terraform output github_actions_role_name
   ```
   Set this as the `GITHUB_ACTIONS_ROLE_NAME` secret in your GitHub repository.

6. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --name kafka-eks --region us-east-1
   ```

7. **Deploy Kafka**
   ```bash
   kubectl apply -f kubernetes/namespaces/
   kubectl apply -f kubernetes/storage/
   kubectl apply -f kubernetes/kafka/strimzi/
   kubectl apply -f kubernetes/monitoring/
   ```

## Project Components

### Terraform Modules

- **VPC Module**: Creates the network infrastructure including subnets, NAT gateways, and routing
- **EKS Module**: Deploys the EKS cluster with managed node groups
- **OIDC Module**: Sets up GitHub Actions OIDC authentication for secure deployments

### Kubernetes Resources

- **Strimzi Kafka Operator**: Manages Kafka cluster deployment and operations
- **Kafka Cluster**: Message brokers managed by Strimzi with persistent storage
- **Monitoring**: Kafka Exporter for exposing metrics to Prometheus
- **Storage**: Custom storage class for persistent volumes

### CI/CD Pipelines

- **Terraform Plan**: Validates infrastructure changes on pull requests
- **Terraform Apply**: Deploys infrastructure changes on push to main
- **Kafka Deploy**: Deploys Kafka resources after infrastructure is ready

## Documentation

- [Architecture](docs/ARCHITECTURE.md): Detailed architecture overview
- [Deployment Guide](docs/DEPLOYMENT.md): Step-by-step deployment instructions
- [Troubleshooting](docs/TROUBLESHOOTING.md): Common issues and solutions

## Security

- Uses GitHub Actions OIDC for secure authentication
- No long-lived credentials stored in repositories
- Role-based access control for different operations

## Monitoring

Metrics are exposed via Kafka Exporter on port 9308. Access them with:
```bash
kubectl port-forward svc/kafka-exporter -n kafka 9308:9308
```
Then visit `http://localhost:9308/metrics`