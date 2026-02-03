output "vpc_flow_logs_bucket" {
  description = "S3 bucket for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs.id
}

output "vpc_flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs.arn
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "nat_gateway_metadata_bucket" {
  description = "S3 bucket for NAT Gateway metadata"
  value       = aws_s3_bucket.nat_gateway_metadata.id
}

output "nat_gateway_metadata_bucket_arn" {
  description = "S3 bucket ARN for NAT Gateway metadata"
  value       = aws_s3_bucket.nat_gateway_metadata.arn
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.vpc_flow_logs.name
}

output "athena_database_name" {
  description = "Athena database name"
  value       = aws_athena_database.vpc_flow_logs.name
}
