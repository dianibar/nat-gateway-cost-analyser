terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Network Infrastructure Module
module "network_infrastructure" {
  source = "./modules/network-infrastructure"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  kubernetes_version = var.kubernetes_version
  instance_types     = var.instance_types
  desired_size       = var.desired_size
  min_size           = var.min_size
  max_size           = var.max_size
}

# VPC Flow Logs Module
module "vpc_flow_logs" {
  source = "./modules/vpc-flow-logs"

  cluster_name = var.cluster_name
  vpc_id       = module.network_infrastructure.vpc_id
}

# Athena Analytics Module
module "athena_analytics" {
  source = "./modules/athena-analytics"

  cluster_name                  = var.cluster_name
  vpc_flow_logs_bucket          = module.vpc_flow_logs.vpc_flow_logs_bucket
  nat_gateway_metadata_bucket   = module.vpc_flow_logs.nat_gateway_metadata_bucket
}

# Lambda Athena Query Module
module "lambda_athena_query" {
  source = "./modules/lambda-athena-query"

  cluster_name            = var.cluster_name
  athena_results_bucket   = module.athena_analytics.athena_results_bucket
  athena_database         = module.athena_analytics.athena_database_name
  athena_workgroup        = module.athena_analytics.athena_workgroup_name
  public_ip_query         = file("${path.module}/../queries/public_ip_traffic.sql")
  private_ip_query        = file("${path.module}/../queries/private_ip_traffic.sql")
  datahub_api_url         = var.datahub_api_url
  datahub_api_key         = var.datahub_api_key
  datahub_customer_context = var.datahub_customer_context
}
