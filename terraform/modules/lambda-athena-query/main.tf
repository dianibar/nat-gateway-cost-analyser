# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# AWS Secrets Manager secret for DataHub API credentials
resource "aws_secretsmanager_secret" "datahub_api" {
  name                    = "${var.cluster_name}-datahub-api-credentials"
  description             = "DataHub API credentials for NAT Gateway cost analysis"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.cluster_name}-datahub-api-credentials"
  }
}

# Secret version with placeholder values (user should update these)
resource "aws_secretsmanager_secret_version" "datahub_api" {
  secret_id = aws_secretsmanager_secret.datahub_api.id
  secret_string = jsonencode({
    api_url    = var.datahub_api_url
    api_key    = var.datahub_api_key
    customer_context = var.datahub_customer_context
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.cluster_name}-athena-query-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-athena-query-lambda-role"
  }
}

# IAM Policy for Lambda to access Athena and S3
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.cluster_name}-athena-query-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaResultsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::${var.athena_results_bucket}",
          "arn:aws:s3:::${var.athena_results_bucket}/*",
          "arn:aws:s3:::nat-gateway-analysis-nat-gateway-metadata-381492072749",
          "arn:aws:s3:::nat-gateway-analysis-nat-gateway-metadata-381492072749/*",
          "arn:aws:s3:::nat-gateway-analysis-vpc-flow-logs-381492072749",
          "arn:aws:s3:::nat-gateway-analysis-vpc-flow-logs-381492072749/*"
        ]
      },
      {
        Sid    = "AthenaResultsBucketLocation"
        Effect = "Allow"
        Action = "s3:GetBucketLocation"
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:BatchCreatePartition",
          "glue:GetPartition"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.datahub_api.arn
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "athena_query" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.cluster_name}-athena-query"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ATHENA_DATABASE        = var.athena_database
      ATHENA_WORKGROUP       = var.athena_workgroup
      ATHENA_RESULTS_BUCKET  = var.athena_results_bucket
      PUBLIC_IP_QUERY        = var.public_ip_query
      PRIVATE_IP_QUERY       = var.private_ip_query
      DATAHUB_SECRET_NAME    = aws_secretsmanager_secret.datahub_api.name
    }
  }

  tags = {
    Name = "${var.cluster_name}-athena-query"
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# Archive the Lambda function code with dependencies
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_package"
  output_path = "${path.module}/lambda_function.zip"
  
  depends_on = [null_resource.lambda_build]
}

# Build Lambda package with dependencies
resource "null_resource" "lambda_build" {
  provisioner "local-exec" {
    command = "bash ${path.module}/build_lambda.sh"
  }
  
  triggers = {
    lambda_function = filemd5("${path.module}/lambda_function.py")
    requirements    = filemd5("${path.module}/requirements.txt")
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.athena_query.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.cluster_name}-athena-query-logs"
  }
}
