variable "cluster_name" {
  description = "Cluster name for resource naming"
  type        = string
}

variable "vpc_flow_logs_bucket" {
  description = "S3 bucket name for VPC Flow Logs"
  type        = string
}

variable "nat_gateway_metadata_bucket" {
  description = "S3 bucket name for NAT Gateway metadata"
  type        = string
}

variable "nat_gateway_hourly_cost" {
  description = "NAT Gateway hourly provisioned fee in USD"
  type        = number
  default     = 0.045
}

variable "nat_gateway_data_processing_cost_per_gb" {
  description = "NAT Gateway data processing cost per GB in USD"
  type        = number
  default     = 0.045
}

variable "query_year" {
  description = "Year for filtering VPC Flow Logs (e.g., 2024)"
  type        = string
  default     = "2024"
}

variable "query_month" {
  description = "Month for filtering VPC Flow Logs (e.g., 01)"
  type        = string
  default     = "01"
}

variable "query_day" {
  description = "Day for filtering VPC Flow Logs (e.g., 15)"
  type        = string
  default     = "15"
}
