# Kubernetes Traffic Generation Deployment Guide

This guide explains how to deploy traffic generators to your EKS cluster to create NAT gateway traffic for analysis.

## Prerequisites

1. EKS cluster deployed (using the Terraform configuration)
2. kubectl configured to access your cluster
3. Cluster nodes must have internet access through NAT gateways

## Deployment Steps

### 1. Deploy Traffic Generators

```bash
kubectl apply -f k8s-deployments.yaml
```

This creates:
- `nat-gateway-test` namespace
- HTTP traffic generator (2 replicas)
- DNS traffic generator (2 replicas)
- TCP traffic generator (1 replica)
- High-volume traffic generator (1 replica - optional)

### 2. Verify Deployments

```bash
kubectl get deployments -n nat-gateway-test
kubectl get pods -n nat-gateway-test
```

### 3. Monitor Traffic Generation

Check logs from a traffic generator pod:

```bash
kubectl logs -n nat-gateway-test deployment/http-traffic-generator -f
```

## Traffic Generators Explained

### HTTP Traffic Generator
- Makes HTTPS requests to external websites
- 2 replicas for consistent traffic
- Targets: Google, Amazon, GitHub, Cloudflare, Wikipedia
- Interval: 1-5 seconds between requests

### DNS Traffic Generator
- Performs DNS lookups to external domains
- 2 replicas
- Targets: google.com, amazon.com, github.com, cloudflare.com, aws.amazon.com, kubernetes.io, docker.com
- Interval: 1 second between lookups

### TCP Traffic Generator
- Establishes TCP connections to external IPs
- 1 replica
- Targets: 8.8.8.8:53, 1.1.1.1:443, 208.67.222.222:443
- Interval: 3 seconds between connections

### High-Volume Traffic Generator
- Generates parallel HTTP requests
- 1 replica (optional - use for stress testing)
- Creates 10 concurrent request streams
- Resource intensive (500m CPU, 256Mi memory)

## Analyzing NAT Gateway Traffic

### View VPC Flow Logs in CloudWatch

1. Go to CloudWatch Console
2. Navigate to Logs > Log Groups
3. Find `/aws/vpc/flowlogs/nat-gateway-analysis`
4. Click on the log group

### Query NAT Gateway Traffic with CloudWatch Insights

```
fields @timestamp, srcaddr, dstaddr, dstport, action, bytes, protocol
| filter dstaddr not like /^10\./
| stats sum(bytes) as total_bytes, count() as packet_count by dstaddr, dstport
| sort total_bytes desc
```

### Find Traffic from Specific Pod

```
fields @timestamp, srcaddr, dstaddr, dstport, action, bytes
| filter srcaddr like /^10\.0\./
| stats sum(bytes) as total_bytes by srcaddr, dstaddr
```

### Monitor NAT Gateway Performance

```
fields @timestamp, action, bytes
| filter action = "ACCEPT"
| stats sum(bytes) as total_bytes, count() as packet_count by bin(5m)
```

### Identify Rejected Connections

```
fields @timestamp, srcaddr, dstaddr, dstport, action
| filter action = "REJECT"
| stats count() as reject_count by dstaddr, dstport
```

## Scaling Traffic Generation

### Increase HTTP Traffic Replicas

```bash
kubectl scale deployment http-traffic-generator -n nat-gateway-test --replicas=5
```

### Enable High-Volume Generator

The high-volume generator is included but set to 1 replica. Scale it up for stress testing:

```bash
kubectl scale deployment high-volume-traffic-generator -n nat-gateway-test --replicas=3
```

### Create Custom Traffic Generator

Create a new deployment with specific traffic patterns:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-traffic-generator
  namespace: nat-gateway-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-traffic-generator
  template:
    metadata:
      labels:
        app: custom-traffic-generator
    spec:
      containers:
      - name: generator
        image: curlimages/curl:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            while true; do
              curl -s -m 5 https://your-target-url.com > /dev/null 2>&1
              sleep 2
            done
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

## Monitoring Metrics

### Check Pod Resource Usage

```bash
kubectl top pods -n nat-gateway-test
```

### Monitor Node Resource Usage

```bash
kubectl top nodes
```

## Cleanup

### Remove Traffic Generators

```bash
kubectl delete namespace nat-gateway-test
```

### Remove Specific Deployment

```bash
kubectl delete deployment http-traffic-generator -n nat-gateway-test
```

## Troubleshooting

### Pods Not Running

```bash
kubectl describe pod <pod-name> -n nat-gateway-test
kubectl logs <pod-name> -n nat-gateway-test
```

### No Traffic Visible in VPC Flow Logs

1. Verify NAT gateway is active: `aws ec2 describe-nat-gateways`
2. Check security group rules allow outbound traffic
3. Verify pods have internet connectivity: `kubectl exec -it <pod-name> -n nat-gateway-test -- curl https://google.com`

### High CPU Usage

Reduce replicas or disable high-volume generator:

```bash
kubectl scale deployment high-volume-traffic-generator -n nat-gateway-test --replicas=0
```

## Cost Optimization

- Monitor NAT gateway data processing charges
- Use VPC endpoints for AWS services to reduce NAT gateway traffic
- Schedule traffic generation during specific times
- Use smaller replicas for continuous monitoring

## Next Steps

1. Set up CloudWatch dashboards for NAT gateway metrics
2. Create alarms for traffic anomalies
3. Integrate with Prometheus/Grafana for advanced analytics
4. Analyze traffic patterns and optimize NAT gateway configuration
