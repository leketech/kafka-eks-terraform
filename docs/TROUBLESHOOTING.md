# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the Kafka EKS deployment.

## Terraform Issues

### State Locking Problems

**Symptom**: Terraform fails with a state lock error.

**Solution**:
1. Check for running Terraform operations:
   ```bash
   aws dynamodb get-item --table-name terraform-locks --key '{"LockID": {"S": "kafka-eks/terraform.tfstate-md5"}}'
   ```

2. If no operation is running, release the lock:
   ```bash
   terraform force-unlock LOCK_ID
   ```

### Provider Initialization Errors

**Symptom**: Terraform fails during init with provider errors.

**Solution**:
1. Clear Terraform cache:
   ```bash
   rm -rf .terraform
   ```

2. Reinitialize:
   ```bash
   terraform init
   ```

### AWS Authentication Issues

**Symptom**: Terraform cannot authenticate with AWS.

**Solution**:
1. Verify AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Check environment variables:
   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   echo $AWS_DEFAULT_REGION
   ```

## Kubernetes Issues

### Cluster Connection Problems

**Symptom**: kubectl commands fail with connection errors.

**Solution**:
1. Verify kubeconfig:
   ```bash
   kubectl config current-context
   ```

2. Update kubeconfig:
   ```bash
   aws eks update-kubeconfig --name kafka-eks --region us-east-1
   ```

3. Test connection:
   ```bash
   kubectl cluster-info
   ```

### Pod Scheduling Issues

**Symptom**: Pods remain in Pending state.

**Solution**:
1. Check pod details:
   ```bash
   kubectl describe pod -n kafka POD_NAME
   ```

2. Check node resources:
   ```bash
   kubectl describe nodes
   ```

3. Check for taints/tolerations:
   ```bash
   kubectl get nodes -o json | jq '.items[].spec.taints'
   ```

### Persistent Volume Issues

**Symptom**: Pods fail to mount persistent volumes.

**Solution**:
1. Check PVC status:
   ```bash
   kubectl get pvc -n kafka
   ```

2. Check PV status:
   ```bash
   kubectl get pv
   ```

3. Check storage class:
   ```bash
   kubectl get storageclass
   ```

## Zookeeper Issues

### Ensemble Not Forming

**Symptom**: Zookeeper pods are running but ensemble is not formed.

**Solution**:
1. Check Zookeeper logs:
   ```bash
   kubectl logs -n kafka zookeeper-0
   ```

2. Verify myid files:
   ```bash
   kubectl exec -n kafka zookeeper-0 -- cat /data/myid
   ```

3. Test connectivity between pods:
   ```bash
   kubectl exec -n kafka zookeeper-0 -- nc -zv zookeeper-1.zookeeper-headless.kafka.svc.cluster.local 2888
   ```

### Zookeeper Not Responding

**Symptom**: Zookeeper health checks fail.

**Solution**:
1. Test Zookeeper status:
   ```bash
   kubectl exec -n kafka zookeeper-0 -- echo "ruok" | kubectl exec -n kafka zookeeper-0 -- nc localhost 2181
   ```

2. Check configuration:
   ```bash
   kubectl exec -n kafka zookeeper-0 -- cat /conf/zoo.cfg
   ```

## Kafka Issues

### Brokers Not Joining Cluster

**Symptom**: Kafka pods are running but not forming a cluster.

**Solution**:
1. Check Kafka logs:
   ```bash
   kubectl logs -n kafka kafka-0
   ```

2. Verify Zookeeper connectivity:
   ```bash
   kubectl exec -n kafka kafka-0 -- nc -zv zookeeper:2181
   ```

3. Check broker configuration:
   ```bash
   kubectl exec -n kafka kafka-0 -- env | grep KAFKA
   ```

### Topics Not Creating

**Symptom**: Unable to create or access Kafka topics.

**Solution**:
1. Test broker connectivity:
   ```bash
   kubectl exec -n kafka kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092
   ```

2. Check controller status:
   ```bash
   kubectl exec -n kafka kafka-0 -- kafka-topics --bootstrap-server localhost:9092 --list
   ```

## Network Issues

### Service Connectivity

**Symptom**: Services not accessible between pods.

**Solution**:
1. Check service endpoints:
   ```bash
   kubectl get endpoints -n kafka
   ```

2. Test DNS resolution:
   ```bash
   kubectl exec -n kafka kafka-0 -- nslookup zookeeper
   ```

3. Test connectivity:
   ```bash
   kubectl exec -n kafka kafka-0 -- nc -zv zookeeper 2181
   ```

### External Access

**Symptom**: Unable to access Kafka from outside the cluster.

**Solution**:
1. Check if LoadBalancer service is created:
   ```bash
   kubectl get svc -n kafka
   ```

2. Verify LoadBalancer status:
   ```bash
   kubectl describe svc kafka-external -n kafka
   ```

3. Check security groups:
   ```bash
   aws ec2 describe-security-groups --filters "Name=tag:Name,Values=kafka-eks*"
   ```

## Monitoring Issues

### Metrics Not Available

**Symptom**: Kafka Exporter metrics not accessible.

**Solution**:
1. Check exporter pod status:
   ```bash
   kubectl get pods -n kafka -l app=kafka-exporter
   ```

2. Check exporter logs:
   ```bash
   kubectl logs -n kafka deployment/kafka-exporter
   ```

3. Test connectivity to Kafka:
   ```bash
   kubectl exec -n kafka deployment/kafka-exporter -- nc -zv kafka:9092
   ```

## CI/CD Issues

### GitHub Actions Failures

**Symptom**: GitHub Actions workflows fail during deployment.

**Solution**:
1. Check GitHub secrets:
   - AWS_ACCOUNT_ID
   - TF_STATE_BUCKET
   - TF_STATE_LOCK_TABLE

2. Verify IAM role permissions:
   ```bash
   aws iam list-attached-role-policies --role-name GitHubActionsKafkaDeployRole
   ```

3. Test OIDC configuration:
   ```bash
   aws sts assume-role-with-web-identity --role-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsKafkaDeployRole --role-session-name test --web-identity-token TOKEN
   ```

## Performance Issues

### High Resource Usage

**Symptom**: Pods consuming excessive CPU or memory.

**Solution**:
1. Check resource usage:
   ```bash
   kubectl top pods -n kafka
   ```

2. Adjust resource limits in manifests:
   ```yaml
   resources:
     requests:
       memory: "512Mi"
       cpu: "250m"
     limits:
       memory: "1Gi"
       cpu: "500m"
   ```

### Slow Message Processing

**Symptom**: Kafka message processing is slow.

**Solution**:
1. Check disk I/O performance:
   ```bash
   kubectl exec -n kafka kafka-0 -- iostat
   ```

2. Verify network throughput:
   ```bash
   kubectl exec -n kafka kafka-0 -- iperf3 -c TARGET
   ```

3. Adjust Kafka configuration:
   - Increase heap size
   - Tune garbage collection
   - Optimize topic configuration

## Security Issues

### Authentication Failures

**Symptom**: Unauthorized access attempts or authentication failures.

**Solution**:
1. Check RBAC configuration:
   ```bash
   kubectl get roles,rolebindings -n kafka
   ```

2. Verify service accounts:
   ```bash
   kubectl get serviceaccounts -n kafka
   ```

3. Review IAM policies:
   ```bash
   aws iam list-role-policies --role-name GitHubActionsKafkaDeployRole
   ```

## Cleanup Issues

### Resource Deletion Failures

**Symptom**: Unable to delete Kubernetes resources.

**Solution**:
1. Check for finalizers:
   ```bash
   kubectl get pod -n kafka POD_NAME -o jsonpath='{.metadata.finalizers}'
   ```

2. Remove finalizers if stuck:
   ```bash
   kubectl patch pod -n kafka POD_NAME -p '{"metadata":{"finalizers":[]}}' --type=merge
   ```

3. Force delete if necessary:
   ```bash
   kubectl delete pod -n kafka POD_NAME --force --grace-period=0
   ```

## General Debugging Tips

### Enable Debug Logging

1. For Terraform:
   ```bash
   TF_LOG=DEBUG terraform apply
   ```

2. For Kubernetes:
   ```bash
   kubectl get events -n kafka
   ```

3. For AWS:
   ```bash
   aws --debug eks update-kubeconfig --name kafka-eks
   ```

### Collect Diagnostic Information

1. System information:
   ```bash
   kubectl version
   terraform version
   aws --version
   ```

2. Cluster information:
   ```bash
   kubectl cluster-info dump > cluster-dump.log
   ```

3. Resource descriptions:
   ```bash
   kubectl describe all -n kafka > resource-descriptions.log
   ```

Remember to sanitize any sensitive information before sharing logs or diagnostic data.