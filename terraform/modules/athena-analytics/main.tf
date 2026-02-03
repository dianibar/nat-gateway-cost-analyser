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
    status = "Suspended"
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

# Lifecycle policy to clean up old query results
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-query-results"
    status = "Enabled"

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Bucket policy to allow Athena to write results
resource "aws_s3_bucket_policy" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryResults"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      }
    ]
  })
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Athena Workgroup for VPC Flow Logs Analysis
resource "aws_athena_workgroup" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs"

  configuration {
    enforce_workgroup_configuration    = false
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
  bucket = var.vpc_flow_logs_bucket

  properties = {
    classification = "parquet"
  }
}

# Athena Named Query - Create NAT Gateway Metadata Table
resource "aws_athena_named_query" "nat_gateway_metadata_table" {
  name            = "${var.cluster_name}-nat-gateway-metadata-table"
  description     = "Create table for NAT Gateway metadata"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    CREATE EXTERNAL TABLE `nat_gateway_metadata`(
      `nat_gateway_id` string COMMENT 'from deserializer', 
      `nat_gateway_name` string COMMENT 'from deserializer', 
      `interface_id` string COMMENT 'from deserializer', 
      `private_ip` string COMMENT 'from deserializer', 
      `subnet_id` string COMMENT 'from deserializer', 
      `availability_zone` string COMMENT 'from deserializer', 
      `state` string COMMENT 'from deserializer')
    ROW FORMAT SERDE 
      'org.apache.hadoop.hive.serde2.OpenCSVSerde' 
    WITH SERDEPROPERTIES ( 
      'escapeChar'='\\', 
      'quoteChar'='\"', 
      'separatorChar'=',') 
    STORED AS INPUTFORMAT 
      'org.apache.hadoop.mapred.TextInputFormat' 
    OUTPUTFORMAT 
      'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
    LOCATION
      's3://nat-gateway-analysis-nat-gateway-metadata-381492072749/'
    TBLPROPERTIES ('skip.header.line.count'='1')
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_database.vpc_flow_logs]
}

# Athena Named Query - Create VPC Flow Logs Table
resource "aws_athena_named_query" "vpc_flow_logs_table" {
  name            = "${var.cluster_name}-vpc_flow_logs-table"
  description     = "Create table for VPC flow logs"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    CREATE EXTERNAL TABLE `vpc_flow_logs`(
      `version` int, 
      `account_id` string, 
      `interface_id` string, 
      `srcaddr` string, 
      `dstaddr` string, 
      `srcport` int, 
      `dstport` int, 
      `protocol` int, 
      `packets` int, 
      `bytes` int, 
      `start` int, 
      `end` int, 
      `action` string, 
      `log_status` string,
      `flow_direction` string,
      `traffic-path` string, 
      `resource-id` string
  )
    PARTITIONED BY ( 
      `year` int, 
      `month` int, 
      `day` int, 
      `hour` int)
    ROW FORMAT SERDE 
      'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe' 
    STORED AS INPUTFORMAT 
      'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat' 
    OUTPUTFORMAT 
      'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat'
    LOCATION
      's3://nat-gateway-analysis-vpc-flow-logs-381492072749/vpc-flow-logs/AWSLogs/aws-account-id=381492072749/aws-service=vpcflowlogs/aws-region=us-east-1'
    TBLPROPERTIES (
      'transient_lastDdlTime'='1769561149')  
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name
  depends_on = [aws_athena_database.vpc_flow_logs]
}

# Athena Named Query - MSCK repair VPC Flow Logs 
resource "aws_athena_named_query" "msck_vpc_flow_logs_table" {
  name            = "${var.cluster_name}-msck_pc_flow_logs-table"
  description     = "MSCK repair for VPC flow logs"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    MSCK REPAIR TABLE `vpc_flow_logs`
  EOT  
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name
  depends_on = [aws_athena_named_query.vpc_flow_logs_table]
}



## Athena Named Query - Join NAT Gateway Metadata with VPC Flow Logs
#resource "aws_athena_named_query" "nat_gateway_flow_logs_join" {
#  name            = "${var.cluster_name}-nat-gateway-flow-logs-join"
#  description     = "Join NAT Gateway metadata with VPC Flow Logs"
#  database        = aws_athena_database.vpc_flow_logs.name
#  query           = <<-EOT
#    SELECT 
#      ng.nat_gateway_name,
#      ng.availability_zone,
#      vfl.dstaddr,
#      vfl.dstport,
#      SUM(vfl.bytes) as total_bytes,
#      COUNT(*) as packet_count,
#      COUNT(DISTINCT vfl.srcaddr) as unique_sources
#    FROM vpc_flow_logs vfl
#    JOIN nat_gateway_metadata ng ON vfl.interface_id = ng.interface_id
#    WHERE vfl.action = 'ACCEPT'
#    GROUP BY ng.nat_gateway_name, ng.availability_zone, vfl.dstaddr, vfl.dstport
#    ORDER BY total_bytes DESC
#  EOT
#  workgroup       = aws_athena_workgroup.vpc_flow_logs.name
#
#  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
#}
#
## Athena Named Query - NAT Gateway Traffic Summary by AZ
#resource "aws_athena_named_query" "nat_gateway_traffic_by_az" {
#  name            = "${var.cluster_name}-nat-gateway-traffic-by-az"
#  description     = "NAT Gateway traffic summary by availability zone"
#  database        = aws_athena_database.vpc_flow_logs.name
#  query           = <<-EOT
#    SELECT 
#      ng.nat_gateway_name,
#      ng.availability_zone,
#      ng.state,
#      COUNT(*) as packet_count,
#      SUM(vfl.bytes) as total_bytes,
#      COUNT(DISTINCT vfl.srcaddr) as unique_sources,
#      COUNT(DISTINCT vfl.dstaddr) as unique_destinations,
#      COUNT(DISTINCT vfl.dstport) as unique_ports
#    FROM vpc_flow_logs vfl
#    JOIN nat_gateway_metadata ng ON vfl.interface_id = ng.interface_id
#    GROUP BY ng.nat_gateway_name, ng.availability_zone, ng.state
#    ORDER BY total_bytes DESC
#  EOT
#  workgroup       = aws_athena_workgroup.vpc_flow_logs.name
#
#  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
#}
#
## Athena Named Query - NAT Gateway Cost Analysis
#resource "aws_athena_named_query" "nat_gateway_cost_analysis" {
#  name            = "${var.cluster_name}-nat-gateway-cost-analysis"
#  description     = "NAT Gateway hourly provisioned and data processing cost analysis"
#  database        = aws_athena_database.vpc_flow_logs.name
#  query           = <<-EOT
#    SELECT 
#      ng.nat_gateway_name,
#      ng.nat_gateway_id,
#      ng.availability_zone,
#      COUNT(DISTINCT CONCAT(DATE(from_unixtime(vfl.start)), ' ', HOUR(from_unixtime(vfl.start)))) as hours_with_traffic,
#      COUNT(*) as total_packets,
#      SUM(vfl.bytes) as total_bytes,
#      ROUND(SUM(vfl.bytes) / 1024.0 / 1024.0 / 1024.0, 2) as total_gb,
#      COUNT(DISTINCT vfl.srcaddr) as unique_sources,
#      COUNT(DISTINCT vfl.dstaddr) as unique_destinations,
#      ROUND(COUNT(DISTINCT CONCAT(DATE(from_unixtime(vfl.start)), ' ', HOUR(from_unixtime(vfl.start)))) * ${var.nat_gateway_hourly_cost}, 2) as hourly_provisioned_cost_usd,
#      ROUND((SUM(vfl.bytes) / 1024.0 / 1024.0 / 1024.0) * ${var.nat_gateway_data_processing_cost_per_gb}, 2) as data_processing_cost_usd,
#      ROUND((COUNT(DISTINCT CONCAT(DATE(from_unixtime(vfl.start)), ' ', HOUR(from_unixtime(vfl.start)))) * ${var.nat_gateway_hourly_cost}) + ((SUM(vfl.bytes) / 1024.0 / 1024.0 / 1024.0) * ${var.nat_gateway_data_processing_cost_per_gb}), 2) as total_cost_usd
#    FROM vpc_flow_logs vfl
#    JOIN nat_gateway_metadata ng ON vfl.interface_id = ng.interface_id
#    WHERE vfl.action = 'ACCEPT'
#    GROUP BY ng.nat_gateway_name, ng.nat_gateway_id, ng.availability_zone
#    ORDER BY total_cost_usd DESC
#  EOT
#  workgroup       = aws_athena_workgroup.vpc_flow_logs.name
#
#  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
#}

# Athena Named Query - Public IP Traffic Cost Analysis
resource "aws_athena_named_query" "public_ip_traffic_cost" {
  name            = "${var.cluster_name}-public-ip-traffic-cost"
  description     = "Traffic to public IPs with cost analysis by source address"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    SELECT 
      account_id, 
      srcaddr, 
      'egress' as flow_direction,
      nat_gateway_id,
      availability_zone,
      ROUND(SUM(bytes) / 1024.0 / 1024.0 / 1024.0, 4) as usage_gb,
      ROUND((SUM(bytes) / 1024.0 / 1024.0 / 1024.0) * ${var.nat_gateway_data_processing_cost_per_gb}, 4) as cost_usd
    FROM "nat_gateway_analysis_vpc_flow_logs"."vpc_flow_logs" vpc
    JOIN "nat_gateway_analysis_vpc_flow_logs"."nat_gateway_metadata" nat 
      ON vpc.interface_id = nat.interface_id
    WHERE flow_direction = 'egress'
      AND vpc.interface_id = nat.interface_id
      AND vpc.srcaddr = nat.private_ip
      AND NOT REGEXP_LIKE(vpc.dstaddr, '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)')
      AND year = ?
      AND month = ?
      AND day = ?
    GROUP BY account_id, srcaddr, nat_gateway_id, availability_zone, flow_direction
    ORDER BY usage_gb DESC
    LIMIT 30
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
}

# Athena Named Query - Private IP Traffic Cost Analysis
resource "aws_athena_named_query" "private_ip_traffic_cost" {
  name            = "${var.cluster_name}-private-ip-traffic-cost"
  description     = "Traffic to private IPs with cost analysis by source address"
  database        = aws_athena_database.vpc_flow_logs.name
  query           = <<-EOT
    SELECT 
      account_id, 
      srcaddr, 
      'ingress' as flow_direction,
      nat_gateway_id,
  availability_zone,
      ROUND(SUM(bytes) / 1024.0 / 1024.0 / 1024.0, 4) as usage_gb,
      ROUND((SUM(bytes) / 1024.0 / 1024.0 / 1024.0) * ${var.nat_gateway_data_processing_cost_per_gb}, 4) as cost_usd
    FROM "nat_gateway_analysis_vpc_flow_logs"."vpc_flow_logs" vpc
    JOIN "nat_gateway_analysis_vpc_flow_logs"."nat_gateway_metadata" nat 
      ON vpc.interface_id = nat.interface_id
    WHERE flow_direction = 'egress'
      AND vpc.interface_id = nat.interface_id
      AND vpc.srcaddr = nat.private_ip
      AND REGEXP_LIKE(vpc.dstaddr, '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.)')
      AND year = ?
      AND month = ?
      AND day = ?
    GROUP BY account_id, srcaddr, nat_gateway_id, availability_zone, flow_direction
    ORDER BY usage_gb DESC
    LIMIT 30
  EOT
  workgroup       = aws_athena_workgroup.vpc_flow_logs.name

  depends_on = [aws_athena_named_query.nat_gateway_metadata_table]
}
