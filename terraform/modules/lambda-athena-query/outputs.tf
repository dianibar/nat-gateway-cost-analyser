output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.athena_query.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.athena_query.arn
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda_role.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "datahub_secret_arn" {
  description = "ARN of the DataHub API credentials secret"
  value       = aws_secretsmanager_secret.datahub_api.arn
}

output "datahub_secret_name" {
  description = "Name of the DataHub API credentials secret"
  value       = aws_secretsmanager_secret.datahub_api.name
}
