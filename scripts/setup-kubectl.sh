#!/bin/bash

# Script to set up kubectl for EKS cluster access

set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Default values
CLUSTER_NAME="kafka-eks"
AWS_REGION="us-east-1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --cluster-name NAME  EKS cluster name (default: kafka-eks)"
            echo "  -r, --region REGION      AWS region (default: us-east-1)"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Setting up kubectl for EKS cluster: $CLUSTER_NAME in region: $AWS_REGION"

# Update kubeconfig
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# Verify connection
echo "Verifying connection to the cluster..."
kubectl cluster-info

echo "✅ kubectl is now configured for EKS cluster: $CLUSTER_NAME"