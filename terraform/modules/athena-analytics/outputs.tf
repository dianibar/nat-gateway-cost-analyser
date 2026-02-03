output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  description = "S3 bucket ARN for Athena query results"
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.vpc_flow_logs.name
}

output "athena_database_name" {
  description = "Athena database name"
  value       = aws_athena_database.vpc_flow_logs.name
}

output "nat_gateway_metadata_table_query_id" {
  description = "Named query ID for NAT Gateway metadata table creation"
  value       = aws_athena_named_query.nat_gateway_metadata_table.id
}

#output "nat_gateway_flow_logs_join_query_id" {
#  description = "Named query ID for NAT Gateway and VPC Flow Logs join"
#  value       = aws_athena_named_query.nat_gateway_flow_logs_join.id
#}
#
#output "nat_gateway_traffic_by_az_query_id" {
#  description = "Named query ID for NAT Gateway traffic by AZ"
#  value       = aws_athena_named_query.nat_gateway_traffic_by_az.id
#}
#
#output "nat_gateway_cost_analysis_query_id" {
#  description = "Named query ID for NAT Gateway cost analysis"
#  value       = aws_athena_named_query.nat_gateway_cost_analysis.id
#}

output "public_ip_traffic_cost_query_id" {
  description = "Named query ID for public IP traffic cost analysis"
  value       = aws_athena_named_query.public_ip_traffic_cost.id
}

output "private_ip_traffic_cost_query_id" {
  description = "Named query ID for private IP traffic cost analysis"
  value       = aws_athena_named_query.private_ip_traffic_cost.id
}
