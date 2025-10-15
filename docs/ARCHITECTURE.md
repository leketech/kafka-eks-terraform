# Architecture

This document describes the architecture of the Kafka EKS deployment.

## Overview

The solution deploys Apache Kafka on Amazon EKS using a modular Terraform approach. The architecture is separated into distinct components:

1. **Infrastructure as Code (Terraform)**
2. **Kubernetes Resources**
3. **CI/CD Pipelines**

## Terraform Architecture

### Modules

#### VPC Module
- Creates a Virtual Private Cloud with public and private subnets
- Configures NAT gateways for internet access from private subnets
- Sets up proper tagging for EKS integration

#### EKS Module
- Deploys an EKS cluster with managed node groups
- Configures necessary IAM roles and policies
- Enables required EKS add-ons (EBS CSI driver)

#### OIDC Module
- Sets up GitHub Actions OIDC authentication
- Creates IAM roles and policies for secure deployment
- Configures trust relationships between GitHub and AWS

### Environment Structure
- Separates configuration by environment (prod, staging, dev)
- Uses remote state management with S3 and DynamoDB
- Implements state locking to prevent concurrent modifications

## Kubernetes Architecture

### Namespaces
- Dedicated `kafka` namespace for all Kafka-related resources

### Zookeeper
- Deployed as a StatefulSet with 3 replicas
- Uses persistent volumes for data storage
- Configured with proper health checks

### Kafka Brokers
- Deployed as a StatefulSet with 3 replicas
- Uses persistent volumes for log storage
- Configured with appropriate resource limits and health checks

### Storage
- Uses AWS EBS volumes via the EBS CSI driver
- Configured with GP2 storage class
- Implements proper volume binding modes

### Monitoring
- Kafka Exporter for metrics collection
- Configured to expose Prometheus metrics

## CI/CD Architecture

### GitHub Actions Workflows
1. **Terraform Plan** - Validates infrastructure changes
2. **Terraform Apply** - Deploys infrastructure changes
3. **Kafka Deploy** - Deploys Kafka resources to the cluster

### Security
- Uses OIDC for secure authentication
- No long-lived credentials stored in repositories
- Role-based access control for different operations

## Network Architecture

### VPC Design
- Multi-AZ deployment for high availability
- Public subnets for internet-facing resources
- Private subnets for internal resources
- NAT gateways for outbound internet access

### Security Groups
- EKS control plane security groups
- Node group security groups
- Service-specific security groups

## Data Flow

1. GitHub Actions triggers Terraform deployment
2. Terraform creates/modifies AWS resources
3. EKS cluster is provisioned with node groups
4. GitHub Actions deploys Kafka resources to EKS
5. Kafka brokers register with Zookeeper
6. Applications connect to Kafka brokers
7. Metrics are exported via Kafka Exporter

## Scalability

### Horizontal Scaling
- Kafka brokers can be scaled by modifying replica count
- Node groups can be scaled based on resource requirements

### Vertical Scaling
- Resource requests/limits can be adjusted for Kafka and Zookeeper
- Node instance types can be changed

## High Availability

### Multi-AZ Deployment
- VPC spans multiple availability zones
- EKS control plane is highly available
- Kafka brokers distributed across AZs
- Zookeeper ensemble spans multiple AZs

### Auto Healing
- Kubernetes health checks for automatic restarts
- Node group auto scaling groups for node replacement
- EBS volumes automatically attached to replacement nodes