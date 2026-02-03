# Network Infrastructure Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.network_infrastructure.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.network_infrastructure.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network_infrastructure.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network_infrastructure.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.network_infrastructure.nat_gateway_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = module.network_infrastructure.nat_gateway_ips
}

#output "eks_cluster_name" {
#  description = "EKS cluster name"
#  value       = module.network_infrastructure.eks_cluster_name
#}
#
#output "eks_cluster_endpoint" {
#  description = "EKS cluster endpoint"
#  value       = module.network_infrastructure.eks_cluster_endpoint
#}
#
#output "eks_cluster_version" {
#  description = "EKS cluster version"
#  value       = module.network_infrastructure.eks_cluster_version
#}
#
#output "eks_cluster_arn" {
#  description = "EKS cluster ARN"
#  value       = module.network_infrastructure.eks_cluster_arn
#}
#
#output "eks_cluster_security_group_id" {
#  description = "EKS cluster security group ID"
#  value       = module.network_infrastructure.eks_cluster_security_group_id
#}
#
#output "eks_node_group_id" {
#  description = "EKS node group ID"
#  value       = module.network_infrastructure.eks_node_group_id
#}

# Analytics Outputs
output "vpc_flow_logs_bucket" {
  description = "S3 bucket for VPC Flow Logs"
  value       = module.vpc_flow_logs.vpc_flow_logs_bucket
}

output "vpc_flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs"
  value       = module.vpc_flow_logs.vpc_flow_logs_bucket_arn
}

output "nat_gateway_metadata_bucket" {
  description = "S3 bucket for NAT Gateway metadata"
  value       = module.vpc_flow_logs.nat_gateway_metadata_bucket
}

output "nat_gateway_metadata_bucket_arn" {
  description = "S3 bucket ARN for NAT Gateway metadata"
  value       = module.vpc_flow_logs.nat_gateway_metadata_bucket_arn
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = module.athena_analytics.athena_results_bucket
}

output "athena_results_bucket_arn" {
  description = "S3 bucket ARN for Athena query results"
  value       = module.athena_analytics.athena_results_bucket_arn
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = module.athena_analytics.athena_workgroup_name
}

output "athena_database_name" {
  description = "Athena database name"
  value       = module.athena_analytics.athena_database_name
}

#output "configure_kubectl" {
#  description = "Command to configure kubectl"
#  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.network_infrastructure.eks_cluster_name}"
#}

# Lambda Athena Query Outputs
output "lambda_function_name" {
  description = "Lambda function name for executing Athena queries"
  value       = module.lambda_athena_query.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda_athena_query.lambda_function_arn
}

output "lambda_cloudwatch_logs" {
  description = "CloudWatch log group for Lambda function"
  value       = module.lambda_athena_query.cloudwatch_log_group
}
