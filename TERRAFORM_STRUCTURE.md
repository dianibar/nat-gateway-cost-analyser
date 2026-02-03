# Terraform Modular Structure

This document describes the modular Terraform structure for the NAT Gateway Cost Analyzer project.

## Module Overview

The infrastructure is organized into three main modules:

### 1. Network Infrastructure Module (`modules/network-infrastructure/`)
**Purpose**: Creates the core networking and Kubernetes infrastructure

**Resources**:
- VPC with configurable CIDR block
- Public and private subnets across multiple availability zones
- NAT Gateways (one per AZ) with Elastic IPs
- Internet Gateway
- Route tables and routes
- EKS cluster with managed node groups
- Security groups for EKS control plane and worker nodes
- IAM roles and policies for EKS

**Inputs**:
- `cluster_name`: Name for the EKS cluster
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `availability_zones`: List of AZs for deployment
- `kubernetes_version`: EKS Kubernetes version
- `instance_types`: EC2 instance types for worker nodes
- `desired_size`, `min_size`, `max_size`: Node group scaling parameters

**Outputs**:
- VPC ID and CIDR
- Subnet IDs (public and private)
- NAT Gateway IDs and Elastic IPs
- EKS cluster details (name, endpoint, version, ARN, security group)
- Node group ID

### 2. VPC Flow Logs Module (`modules/vpc-flow-logs/`)
**Purpose**: Manages VPC Flow Logs collection and NAT Gateway metadata storage

**Resources**:
- S3 bucket for VPC Flow Logs with versioning and encryption
- S3 bucket for NAT Gateway metadata with versioning, encryption, and lifecycle policies
- VPC Flow Logs configuration (sends logs to S3)
- S3 bucket policies for VPC Flow Logs delivery
- Lifecycle policies to archive old metadata to Glacier after 90 days and delete after 365 days

**Inputs**:
- `cluster_name`: Name for resource naming
- `vpc_id`: VPC ID from network infrastructure module

**Outputs**:
- VPC Flow Logs bucket name and ARN
- NAT Gateway metadata bucket name and ARN

### 3. Athena Analytics Module (`modules/athena-analytics/`)
**Purpose**: Creates Athena infrastructure for analyzing VPC Flow Logs and NAT Gateway metadata

**Resources**:
- S3 bucket for Athena query results with versioning and encryption
- Athena workgroup for VPC Flow Logs analysis
- Athena database for storing table definitions
- Named queries for:
  - Creating NAT Gateway metadata table
  - Joining NAT Gateway metadata with VPC Flow Logs
  - Analyzing NAT Gateway traffic by availability zone

**Inputs**:
- `cluster_name`: Name for resource naming
- `vpc_flow_logs_bucket`: S3 bucket name for VPC Flow Logs (from vpc-flow-logs module)
- `nat_gateway_metadata_bucket`: S3 bucket name for NAT Gateway metadata (from vpc-flow-logs module)

**Outputs**:
- Athena results bucket name and ARN
- Athena workgroup name
- Athena database name
- Named query IDs for table creation and analysis queries

## Module Dependencies

```
network_infrastructure
    ↓
vpc_flow_logs (depends on network_infrastructure.vpc_id)
    ↓
athena_analytics (depends on vpc_flow_logs outputs)
```

## Root Module Configuration

The root `main.tf` orchestrates all three modules:

1. **Network Infrastructure**: Creates VPC and EKS cluster
2. **VPC Flow Logs**: Creates S3 buckets and enables VPC Flow Logs
3. **Athena Analytics**: Creates Athena infrastructure for analysis

All module outputs are exposed at the root level for easy access.

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Infrastructure
```bash
terraform plan
```

### Apply Infrastructure
```bash
terraform apply
```

### Destroy Infrastructure (preserving S3 buckets)
```bash
# Remove S3 buckets from state to preserve them
terraform state rm module.vpc_flow_logs.aws_s3_bucket.vpc_flow_logs
terraform state rm module.vpc_flow_logs.aws_s3_bucket.nat_gateway_metadata
terraform state rm module.athena_analytics.aws_s3_bucket.athena_results

# Then destroy remaining resources
terraform destroy
```

## Athena Named Queries

The athena-analytics module creates three named queries:

1. **nat-gateway-metadata-table**: Creates the external table for NAT Gateway metadata
2. **nat-gateway-flow-logs-join**: Joins NAT Gateway metadata with VPC Flow Logs
3. **nat-gateway-traffic-by-az**: Analyzes traffic by availability zone

These queries can be executed in the AWS Athena console using the workgroup created by this module.

## Next Steps

1. Run `terraform apply` to create all infrastructure
2. Upload NAT Gateway metadata CSV to the metadata bucket using `get_nat_gateways.py`
3. Execute the Athena named queries to create tables and analyze traffic
4. Use the Athena workgroup to run custom analysis queries
