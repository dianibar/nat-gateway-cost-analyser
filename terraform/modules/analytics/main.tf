# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# S3 Bucket for VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "${var.cluster_name}-vpc-flow-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.cluster_name}-vpc-flow-logs"
  }
}

# Block public access to VPC Flow Logs bucket
resource "aws_s3_bucket_public_access_block" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on VPC Flow Logs bucket
resource "aws_s3_bucket_versioning" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on VPC Flow Logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket policy to allow VPC Flow Logs
resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.vpc_flow_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.vpc_flow_logs.arn
      }
    ]
  })
}

# VPC Flow Logs to S3
resource "aws_flow_log" "s3" {
  log_destination      = "${aws_s3_bucket.vpc_flow_logs.arn}/vpc-flow-logs/"
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id
  log_format           = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

  tags = {
    Name = "${var.cluster_name}-vpc-flow-logs-s3"
  }

  depends_on = [aws_s3_bucket_policy.vpc_flow_logs]
}

# S3 Bucket for Athena Query Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.cluster_name}-athena-results-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.cluster_name}-athena-results"
  }
}

# Block public access to Athena results bucket
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on Athena results bucket
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on Athena results bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket for NAT Gateway Metadata
resource "aws_s3_bucket" "nat_gateway_metadata" {
  bucket = "${var.cluster_name}-nat-gateway-metadata-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.cluster_name}-nat-gateway-metadata"
  }
}

# Block public access to metadata bucket
resource "aws_s3_bucket_public_access_block" "nat_gateway_metadata" {
  bucket = aws_s3_bucket.nat_gateway_metadata.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on metadata bucket
resource "aws_s3_bucket_versioning" "nat_gateway_metadata" {
  bucket = aws_s3_bucket.nat_gateway_metadata.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on metadata bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "nat_gateway_metadata" {
  bucket = aws_s3_bucket.nat_gateway_metadata.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy to transition old files to Glacier
resource "aws_s3_bucket_lifecycle_configuration" "nat_gateway_metadata" {
  bucket = aws_s3_bucket.nat_gateway_metadata.id

  rule {
    id     = "archive-old-metadata"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Athena Workgroup for VPC Flow Logs Analysis
resource "aws_athena_workgroup" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/vpc-flow-logs/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Name = "${var.cluster_name}-vpc-flow-logs-workgroup"
  }

  depends_on = [aws_s3_bucket.athena_results]
}

# Athena Database for VPC Flow Logs
resource "aws_athena_database" "vpc_flow_logs" {
  name   = replace("${var.cluster_name}_vpc_flow_logs", "-", "_")
  bucket = aws_s3_bucket.vpc_flow_logs.id

  properties = {
    classification = "parquet"
  }

  depends_on = [aws_s3_bucket.vpc_flow_logs]
}

# Athena Named Query - Create NAT Gateway Metadata Table
resource "aws_athena_named_query" "nat_gateway_metadata_table" {
  name            = "${var.cluster_name}-nat-gateway-metadata-table"
  description     = "Create table for NAT Gateway metadata"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    CREATE EXTERNAL TABLE IF NOT EXISTS nat_gateway_metadata (
      nat_gateway_id STRING,
      nat_gateway_name STRING,
      interface_id STRING,
      private_ip STRING,
      subnet_id STRING,
      availability_zone STRING,
      state STRING
    )
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
    WITH SERDEPROPERTIES (
      'field.delim' = ','
    )
    STORED AS TEXTFILE
    LOCATION 's3://${aws_s3_bucket.nat_gateway_metadata.bucket}/nat-gateways/'
    TBLPROPERTIES (
      'skip.header.line.count' = '1'
    )
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_database.vpc_flow_logs]
}

# Athena Named Query - Join NAT Gateway Metadata with VPC Flow Logs
resource "aws_athena_named_query" "nat_gateway_flow_logs_join" {
  name            = "${var.cluster_name}-nat-gateway-flow-logs-join"
  description     = "Join NAT Gateway metadata with VPC Flow Logs"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    SELECT 
      ng.nat_gateway_name,
      ng.availability_zone,
      vfl.dstaddr,
      vfl.dstport,
      SUM(vfl.bytes) as total_bytes,
      COUNT(*) as packet_count,
      COUNT(DISTINCT vfl.srcaddr) as unique_sources
    FROM vpc_flow_logs vfl
    JOIN nat_gateway_metadata ng ON vfl.interface_id = ng.interface_id
    WHERE vfl.action = 'ACCEPT'
    GROUP BY ng.nat_gateway_name, ng.availability_zone, vfl.dstaddr, vfl.dstport
    ORDER BY total_bytes DESC
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
}

# Athena Named Query - NAT Gateway Traffic Summary by AZ
resource "aws_athena_named_query" "nat_gateway_traffic_by_az" {
  name            = "${var.cluster_name}-nat-gateway-traffic-by-az"
  description     = "NAT Gateway traffic summary by availability zone"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    SELECT 
      ng.nat_gateway_name,
      ng.availability_zone,
      ng.state,
      COUNT(*) as packet_count,
      SUM(vfl.bytes) as total_bytes,
      COUNT(DISTINCT vfl.srcaddr) as unique_sources,
      COUNT(DISTINCT vfl.dstaddr) as unique_destinations,
      COUNT(DISTINCT vfl.dstport) as unique_ports
    FROM vpc_flow_logs vfl
    JOIN nat_gateway_metadata ng ON vfl.interface_id = ng.interface_id
    GROUP BY ng.nat_gateway_name, ng.availability_zone, ng.state
    ORDER BY total_bytes DESC
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
}
