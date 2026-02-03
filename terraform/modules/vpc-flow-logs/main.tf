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
  log_format           = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${flow-direction} $${traffic-path} $${resource-id}"
  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
    hive_compatible_partitions = true
  }
  tags = {
    Name = "${var.cluster_name}-vpc-flow-logs-s3"
  }

  depends_on = [aws_s3_bucket_policy.vpc_flow_logs]
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
