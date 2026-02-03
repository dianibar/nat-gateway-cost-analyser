# EKS Cluster with NAT Gateway Monitoring

This Terraform configuration creates a complete AWS infrastructure for running an EKS cluster with NAT gateway monitoring capabilities.

## Architecture

- **VPC**: 10.0.0.0/16 with 3 availability zones
- **Public Subnets**: For NAT gateways and load balancers
- **Private Subnets**: For EKS worker nodes
- **NAT Gateways**: One per AZ for high availability
- **EKS Cluster**: Kubernetes 1.29 with managed node groups
- **VPC Flow Logs**: Captures all network traffic for analysis
- **CloudWatch Logs**: Centralized logging for VPC and EKS

## Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.0
3. AWS CLI configured with credentials
4. kubectl installed locally

## Deployment

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

This will take approximately 15-20 minutes to complete.

### 4. Configure kubectl

After deployment, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name nat-gateway-analysis
```

Or use the output from Terraform:

```bash
terraform output configure_kubectl
```

## Customization

Edit `terraform.tfvars` to customize:

- `aws_region`: AWS region for deployment
- `cluster_name`: Name of your EKS cluster
- `vpc_cidr`: VPC CIDR block
- `availability_zones`: AZs to use
- `kubernetes_version`: Kubernetes version
- `instance_types`: EC2 instance types for nodes
- `desired_size`: Number of worker nodes
- `log_retention_days`: CloudWatch log retention

## Monitoring NAT Gateway Logs

### VPC Flow Logs

VPC Flow Logs are automatically enabled and sent to CloudWatch. Access them at:

```
/aws/vpc/flowlogs/nat-gateway-analysis
```

### Query NAT Gateway Traffic

Use CloudWatch Insights to analyze NAT gateway traffic:

```
fields @timestamp, srcaddr, dstaddr, dstport, action, bytes
| filter dstaddr like /^10\./
| stats sum(bytes) as total_bytes by dstport
```

### EKS Cluster Logs

EKS cluster logs are available at:

```
/aws/eks/nat-gateway-analysis/cluster
```

## Outputs

After deployment, Terraform outputs:

- `vpc_id`: VPC identifier
- `nat_gateway_ids`: NAT gateway IDs
- `nat_gateway_ips`: Elastic IPs of NAT gateways
- `eks_cluster_name`: EKS cluster name
- `eks_cluster_endpoint`: Kubernetes API endpoint
- `vpc_flow_logs_group`: CloudWatch log group for VPC Flow Logs
- `eks_cluster_logs_group`: CloudWatch log group for EKS logs

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Cost Considerations

- NAT Gateways: ~$32/month per gateway + data processing charges
- EKS Control Plane: $0.10/hour
- EC2 Instances: Varies by instance type (t3.medium ~$0.04/hour)
- CloudWatch Logs: ~$0.50/GB ingested

## Troubleshooting

### Nodes not joining cluster

Check node security group allows communication with control plane security group.

### kubectl connection timeout

Verify the security group allows inbound traffic on port 443 from your IP.

### High NAT gateway costs

Monitor data processing charges in CloudWatch. Consider using VPC endpoints for AWS services to reduce NAT gateway traffic.

## Generating NAT Gateway Traffic

Once your EKS cluster is deployed, you can generate traffic through the NAT gateways for analysis.

### Deploy Traffic Generators

```bash
kubectl apply -f k8s-deployments.yaml
```

This deploys multiple traffic generators to your cluster:
- HTTP traffic generator (2 replicas)
- DNS traffic generator (2 replicas)
- TCP traffic generator (1 replica)
- High-volume traffic generator (1 replica)

### Verify Traffic Generators are Running

```bash
kubectl get pods -n nat-gateway-test
```

### Monitor Traffic Generation

View logs from the HTTP traffic generator:

```bash
kubectl logs -n nat-gateway-test deployment/http-traffic-generator -f
```

### Analyze NAT Gateway Traffic in CloudWatch

1. Go to CloudWatch Console
2. Navigate to Logs > Log Groups
3. Find `/aws/vpc/flowlogs/nat-gateway-analysis`
4. Use CloudWatch Insights to query traffic

**Example query to see all outbound traffic:**

```
fields @timestamp, srcaddr, dstaddr, dstport, action, bytes, protocol
| filter dstaddr not like /^10\./
| stats sum(bytes) as total_bytes, count() as packet_count by dstaddr, dstport
| sort total_bytes desc
```

**Example query to monitor NAT gateway performance:**

```
fields @timestamp, action, bytes
| filter action = "ACCEPT"
| stats sum(bytes) as total_bytes, count() as packet_count by bin(5m)
```

### Analyze NAT Gateway Traffic in S3

VPC Flow Logs are also stored in S3 for long-term storage and analysis.

**Access S3 Logs:**

```bash
aws s3 ls s3://nat-gateway-analysis-vpc-flow-logs-<account-id>/vpc-flow-logs/
```

**Download Logs from S3:**

```bash
aws s3 cp s3://nat-gateway-analysis-vpc-flow-logs-<account-id>/vpc-flow-logs/ ./logs --recursive
```

**Query S3 Logs with Athena:**

An Athena workgroup and database are automatically created by Terraform. The VPC Flow Logs table is partitioned by year, month, day, and hour for efficient querying.

**S3 Path Structure:**
```
s3://nat-gateway-analysis-vpc-flow-logs-<account-id>/vpc-flow-logs/
  AWSLogs/
    <account-id>/
      vpcflowlogs/
        <region>/
          <year>/
            <month>/
              <day>/
                <hour>/
                  *.log
```

**Add Partitions to Table:**

AWS VPC Flow Logs automatically organize files by date/time. To query them efficiently, add partitions:

```sql
ALTER TABLE vpc_flow_logs
ADD IF NOT EXISTS PARTITION (year='2026', month='01', day='22', hour='01')
LOCATION 's3://nat-gateway-analysis-vpc-flow-logs-<account-id>/vpc-flow-logs/AWSLogs/<account-id>/vpcflowlogs/<region>/2026/01/22/01/'
```

Or use the MSCK REPAIR TABLE command to automatically discover partitions:

```sql
MSCK REPAIR TABLE vpc_flow_logs
```

**Example Athena Queries:**

Top destination IPs by bytes transferred:

```sql
SELECT 
  dstaddr,
  SUM(bytes) as total_bytes,
  COUNT(*) as packet_count,
  COUNT(DISTINCT srcaddr) as unique_sources
FROM vpc_flow_logs
WHERE action = 'ACCEPT'
  AND year='2026' AND month='01' AND day='22'
GROUP BY dstaddr
ORDER BY total_bytes DESC
LIMIT 20
```

Traffic by port:

```sql
SELECT 
  dstport,
  protocol,
  SUM(bytes) as total_bytes,
  COUNT(*) as packet_count,
  COUNT(DISTINCT srcaddr) as unique_sources,
  COUNT(DISTINCT dstaddr) as unique_destinations
FROM vpc_flow_logs
WHERE action = 'ACCEPT'
  AND year='2026' AND month='01' AND day='22'
GROUP BY dstport, protocol
ORDER BY total_bytes DESC
```

Rejected connections:

```sql
SELECT 
  srcaddr,
  dstaddr,
  dstport,
  protocol,
  COUNT(*) as reject_count
FROM vpc_flow_logs
WHERE action = 'REJECT'
  AND year='2026' AND month='01' AND day='22'
GROUP BY srcaddr, dstaddr, dstport, protocol
ORDER BY reject_count DESC
```

NAT Gateway traffic summary:

```sql
SELECT 
  interface_id,
  action,
  COUNT(*) as packet_count,
  SUM(bytes) as total_bytes,
  COUNT(DISTINCT srcaddr) as unique_sources,
  COUNT(DISTINCT dstaddr) as unique_destinations,
  COUNT(DISTINCT dstport) as unique_ports
FROM vpc_flow_logs
WHERE year='2026' AND month='01' AND day='22'
GROUP BY interface_id, action
ORDER BY total_bytes DESC
```

### Scale Traffic Generation

Increase HTTP traffic replicas for more load:

```bash
kubectl scale deployment http-traffic-generator -n nat-gateway-test --replicas=5
```

Enable high-volume generator for stress testing:

```bash
kubectl scale deployment high-volume-traffic-generator -n nat-gateway-test --replicas=3
```

### Stop Traffic Generation

Remove all traffic generators:

```bash
kubectl delete namespace nat-gateway-test
```

For detailed traffic generation instructions, see `DEPLOYMENT_GUIDE.md`.

## Next Steps

1. Deploy monitoring tools (Prometheus, Grafana)
2. Set up log analysis dashboards
3. Configure alerts for NAT gateway metrics
4. Analyze traffic patterns and optimize NAT gateway configuration
