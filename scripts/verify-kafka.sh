#!/bin/bash

# Script to verify Kafka deployment status

set -e

# Default values
NAMESPACE="kafka"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --namespace NAME     Kubernetes namespace (default: kafka)"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Verifying Kafka deployment in namespace: $NAMESPACE"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Check nodes
echo "=== Kubernetes Nodes ==="
kubectl get nodes

# Check Zookeeper pods
echo "=== Zookeeper Pods ==="
kubectl get pods -n "$NAMESPACE" -l app=zookeeper

# Check Kafka pods
echo "=== Kafka Pods ==="
kubectl get pods -n "$NAMESPACE" -l app=kafka

# Check services
echo "=== Services ==="
kubectl get svc -n "$NAMESPACE"

# Check if all pods are running
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE"

# Check Zookeeper status
echo "=== Zookeeper Status ==="
for i in {0..2}; do
    echo "Zookeeper-$i status:"
    kubectl exec -n "$NAMESPACE" "zookeeper-$i" -- echo "ruok" | kubectl exec -n "$NAMESPACE" "zookeeper-$i" -- nc localhost 2181 || echo "Zookeeper-$i not responding"
    echo ""
done

# Check Kafka broker status
echo "=== Kafka Broker Status ==="
for i in {0..2}; do
    echo "Kafka-$i status:"
    kubectl exec -n "$NAMESPACE" "kafka-$i" -- kafka-broker-api-versions --bootstrap-server localhost:9092 || echo "Kafka-$i not responding"
    echo ""
done

echo "✅ Verification complete"