#!/bin/bash

# Script to clean up Kafka deployment

set -e

# Default values
NAMESPACE="kafka"
CONFIRM=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -y|--yes)
            CONFIRM=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --namespace NAME     Kubernetes namespace (default: kafka)"
            echo "  -y, --yes                Skip confirmation prompt"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Confirmation prompt
if [ "$CONFIRM" = false ]; then
    echo "This will delete all Kafka resources in namespace: $NAMESPACE"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo "Cleaning up Kafka deployment in namespace: $NAMESPACE"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Delete Kafka resources
echo "Deleting Kafka resources..."

# Delete monitoring
kubectl delete -f kubernetes/monitoring/ 2>/dev/null || echo "No monitoring resources to delete"

# Delete Kafka broker
kubectl delete -f kubernetes/kafka/broker/ 2>/dev/null || echo "No Kafka broker resources to delete"

# Delete Zookeeper
kubectl delete -f kubernetes/kafka/zookeeper/ 2>/dev/null || echo "No Zookeeper resources to delete"

# Delete storage
kubectl delete -f kubernetes/storage/ 2>/dev/null || echo "No storage resources to delete"

# Delete namespace
kubectl delete -f kubernetes/namespaces/ 2>/dev/null || echo "No namespace resources to delete"

echo "✅ Cleanup complete"