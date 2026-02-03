output "vpc_flow_logs_bucket" {
  description = "S3 bucket for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs.id
}

output "vpc_flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs.arn
}

output "nat_gateway_metadata_bucket" {
  description = "S3 bucket for NAT Gateway metadata"
  value       = aws_s3_bucket.nat_gateway_metadata.id
}

output "nat_gateway_metadata_bucket_arn" {
  description = "S3 bucket ARN for NAT Gateway metadata"
  value       = aws_s3_bucket.nat_gateway_metadata.arn
}
