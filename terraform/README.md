# Terraform Infrastructure

This directory contains all Terraform configurations for deploying the Kafka EKS infrastructure.

## Structure

- `modules/` - Reusable Terraform modules
- `environments/` - Environment-specific configurations

## Modules

1. **VPC** - Creates the VPC, subnets, and networking components
2. **EKS** - Deploys the EKS cluster and managed node groups
3. **OIDC** - Configures GitHub Actions OIDC authentication

## Usage

Navigate to an environment directory and run Terraform commands:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```