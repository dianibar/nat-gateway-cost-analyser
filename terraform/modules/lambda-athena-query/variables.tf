variable "cluster_name" {
  description = "Cluster name for resource naming"
  type        = string
}

variable "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  type        = string
}

variable "athena_database" {
  description = "Athena database name"
  type        = string
}

variable "athena_workgroup" {
  description = "Athena workgroup name"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 256
}

variable "public_ip_query" {
  description = "Athena query for public IP traffic analysis"
  type        = string
}

variable "private_ip_query" {
  description = "Athena query for private IP traffic analysis"
  type        = string
}

variable "datahub_api_url" {
  description = "DataHub API URL"
  type        = string
  default     = "https://api.doit.com/datahub/v1/events"
}

variable "datahub_api_key" {
  description = "DataHub API key"
  type        = string
  sensitive   = true
}

variable "datahub_customer_context" {
  description = "DataHub customer context"
  type        = string
  sensitive   = true
}
