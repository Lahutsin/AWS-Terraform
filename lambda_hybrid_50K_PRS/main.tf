data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host_header" {
  count = local.edge_enabled ? 1 : 0
  name  = "Managed-AllViewerExceptHostHeader"
}

data "aws_route53_zone" "edge" {
  count        = local.edge_custom_domain_enabled ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

resource "random_string" "bucket_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "aws_kms_key" "platform" {
  count = var.enable_customer_managed_kms ? 1 : 0

  description             = "Customer-managed key for ${local.name_prefix}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUse"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowServiceUseWithinAccount"
        Effect = "Allow"
        Principal = {
          Service = [
            "sqs.amazonaws.com",
            "sns.amazonaws.com",
            "events.amazonaws.com",
            "dynamodb.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "platform" {
  count = var.enable_customer_managed_kms ? 1 : 0

  name          = local.kms_alias_name
  target_key_id = aws_kms_key.platform[0].key_id
}

resource "aws_sns_topic" "alarm_notifications" {
  count = var.enable_alarm_notifications && var.alarm_notification_topic_arn == null ? 1 : 0

  name              = local.notification_topic_name
  kms_master_key_id = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_sns_topic_subscription" "alarm_email" {
  for_each = var.enable_alarm_notifications ? toset(var.alarm_notification_email_endpoints) : []

  topic_arn = coalesce(var.alarm_notification_topic_arn, aws_sns_topic.alarm_notifications[0].arn)
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic" "async_ingress" {
  count = var.enable_async_sns_topic ? 1 : 0

  name              = "${local.name_prefix}-async-ingress"
  kms_master_key_id = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_cloudwatch_event_bus" "async_ingress" {
  count = var.enable_eventbridge_ingress ? 1 : 0

  name = "${local.name_prefix}-async-bus"
}

resource "aws_s3_bucket" "cloudfront_logs" {
  count = local.edge_enabled && var.enable_cloudfront_logging ? 1 : 0

  bucket = local.cloudfront_log_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count  = local.edge_enabled && var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count      = local.edge_enabled && var.enable_cloudfront_logging ? 1 : 0
  bucket     = aws_s3_bucket.cloudfront_logs[0].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  count  = local.edge_enabled && var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count  = local.edge_enabled && var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "lambda_sources" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_sources.zip"
}

resource "aws_dynamodb_table" "requests" {
  name         = local.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  stream_enabled   = var.enable_dynamodb_stream
  stream_view_type = var.enable_dynamodb_stream ? var.dynamodb_stream_view_type : null

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
  }
}

resource "aws_s3_bucket" "payloads" {
  bucket        = local.s3_bucket_name
  force_destroy = var.s3_bucket_force_destroy
}

resource "aws_s3_bucket_server_side_encryption_configuration" "payloads" {
  bucket = aws_s3_bucket.payloads.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
      sse_algorithm     = var.enable_customer_managed_kms ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "payloads" {
  bucket = aws_s3_bucket.payloads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "payloads" {
  bucket = aws_s3_bucket.payloads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "async_dlq" {
  name                      = local.queue_names.dlq
  message_retention_seconds = var.dlq_message_retention_seconds
  kms_master_key_id         = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_sqs_queue" "buffer" {
  name                              = local.queue_names.buffer
  visibility_timeout_seconds        = var.queue_visibility_timeout_seconds
  message_retention_seconds         = var.queue_message_retention_seconds
  kms_master_key_id                 = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
  kms_data_key_reuse_period_seconds = var.enable_customer_managed_kms ? 300 : null

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.async_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

resource "aws_sqs_queue" "priority" {
  count = var.enable_priority_lane ? 1 : 0

  name                              = local.queue_names.priority
  visibility_timeout_seconds        = var.queue_visibility_timeout_seconds
  message_retention_seconds         = var.queue_message_retention_seconds
  kms_master_key_id                 = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
  kms_data_key_reuse_period_seconds = var.enable_customer_managed_kms ? 300 : null

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.async_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

resource "aws_sqs_queue" "bulk" {
  count = var.enable_bulk_lane ? 1 : 0

  name                              = local.queue_names.bulk
  visibility_timeout_seconds        = var.queue_visibility_timeout_seconds
  message_retention_seconds         = var.queue_message_retention_seconds
  kms_master_key_id                 = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
  kms_data_key_reuse_period_seconds = var.enable_customer_managed_kms ? 300 : null

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.async_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

data "aws_iam_policy_document" "buffer_queue_ingress" {
  count = var.enable_async_sns_topic || var.enable_eventbridge_ingress ? 1 : 0

  dynamic "statement" {
    for_each = var.enable_async_sns_topic ? [1] : []

    content {
      sid    = "AllowSNSSendMessage"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }

      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.buffer.arn]

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [aws_sns_topic.async_ingress[0].arn]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_eventbridge_ingress ? [1] : []

    content {
      sid    = "AllowEventBridgeSendMessage"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }

      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.buffer.arn]

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [aws_cloudwatch_event_rule.async_ingress[0].arn]
      }
    }
  }
}

resource "aws_sqs_queue_policy" "buffer_ingress" {
  count = var.enable_async_sns_topic || var.enable_eventbridge_ingress ? 1 : 0

  queue_url = aws_sqs_queue.buffer.id
  policy    = data.aws_iam_policy_document.buffer_queue_ingress[0].json
}

resource "aws_sns_topic_subscription" "buffer" {
  count = var.enable_async_sns_topic ? 1 : 0

  topic_arn            = aws_sns_topic.async_ingress[0].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.buffer.arn
  raw_message_delivery = true
}

resource "aws_cloudwatch_event_rule" "async_ingress" {
  count = var.enable_eventbridge_ingress ? 1 : 0

  name           = "${local.name_prefix}-async-ingress"
  description    = "Route async events into the SQS buffer queue"
  event_bus_name = aws_cloudwatch_event_bus.async_ingress[0].name
  event_pattern = jsonencode({
    source        = [var.async_eventbridge_source]
    "detail-type" = [var.async_eventbridge_detail_type]
  })
}

resource "aws_cloudwatch_event_target" "buffer" {
  count = var.enable_eventbridge_ingress ? 1 : 0

  rule           = aws_cloudwatch_event_rule.async_ingress[0].name
  event_bus_name = aws_cloudwatch_event_bus.async_ingress[0].name
  target_id      = "buffer-queue"
  arn            = aws_sqs_queue.buffer.arn
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "${local.name_prefix}-lambda-execution"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_execution" {
  statement {
    sid = "CloudWatchLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid = "DynamoDBAccess"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]

    resources = [aws_dynamodb_table.requests.arn]
  }

  statement {
    sid = "S3Access"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = ["${aws_s3_bucket.payloads.arn}/*"]
  }

  statement {
    sid = "SQSWorkerAccess"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]

    resources = concat(
      [aws_sqs_queue.buffer.arn],
      var.enable_priority_lane ? [aws_sqs_queue.priority[0].arn] : [],
      var.enable_bulk_lane ? [aws_sqs_queue.bulk[0].arn] : []
    )
  }

  statement {
    sid = "XRayWrite"

    actions = [
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments"
    ]

    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_customer_managed_kms ? [1] : []

    content {
      sid = "KMSAccess"

      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]

      resources = [aws_kms_key.platform[0].arn]
    }
  }
}

resource "aws_iam_policy" "lambda_execution" {
  name   = "${local.name_prefix}-lambda-execution"
  policy = data.aws_iam_policy_document.lambda_execution.json
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_execution.arn
}

resource "aws_cloudwatch_log_group" "sync" {
  name              = "/aws/lambda/${local.name_prefix}-sync"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${local.name_prefix}-worker"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name_prefix}-http-api"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_lambda_function" "sync" {
  function_name = "${local.name_prefix}-sync"
  role          = aws_iam_role.lambda_execution.arn
  runtime       = var.lambda_runtime
  handler       = "sync_handler.handler"
  architectures = var.lambda_architectures
  memory_size   = var.sync_lambda_memory_size
  timeout       = var.sync_lambda_timeout
  publish       = true

  reserved_concurrent_executions = var.sync_reserved_concurrency

  filename         = data.archive_file.lambda_sources.output_path
  source_code_hash = data.archive_file.lambda_sources.output_base64sha256

  environment {
    variables = {
      PAYLOAD_BUCKET = aws_s3_bucket.payloads.bucket
      REQUESTS_TABLE = aws_dynamodb_table.requests.name
      STACK_NAME     = local.name_prefix
    }
  }

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.sync,
    aws_iam_role_policy_attachment.lambda_execution
  ]
}

resource "aws_lambda_function" "worker" {
  function_name = "${local.name_prefix}-worker"
  role          = aws_iam_role.lambda_execution.arn
  runtime       = var.lambda_runtime
  handler       = "worker_handler.handler"
  architectures = var.lambda_architectures
  memory_size   = var.worker_lambda_memory_size
  timeout       = var.worker_lambda_timeout
  publish       = true

  reserved_concurrent_executions = var.worker_reserved_concurrency

  filename         = data.archive_file.lambda_sources.output_path
  source_code_hash = data.archive_file.lambda_sources.output_base64sha256

  environment {
    variables = {
      PAYLOAD_BUCKET = aws_s3_bucket.payloads.bucket
      REQUESTS_TABLE = aws_dynamodb_table.requests.name
      STACK_NAME     = local.name_prefix
    }
  }

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.worker,
    aws_iam_role_policy_attachment.lambda_execution
  ]
}

resource "aws_lambda_alias" "sync_live" {
  name             = "live"
  description      = "Live alias for the synchronous Lambda"
  function_name    = aws_lambda_function.sync.function_name
  function_version = aws_lambda_function.sync.version
}

resource "aws_lambda_alias" "worker_live" {
  name             = "live"
  description      = "Live alias for the asynchronous worker Lambda"
  function_name    = aws_lambda_function.worker.function_name
  function_version = aws_lambda_function.worker.version
}

resource "aws_lambda_provisioned_concurrency_config" "sync" {
  count = var.sync_provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.sync.function_name
  provisioned_concurrent_executions = var.sync_provisioned_concurrency
  qualifier                         = aws_lambda_alias.sync_live.name
}

resource "aws_lambda_provisioned_concurrency_config" "worker" {
  count = var.worker_provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.worker.function_name
  provisioned_concurrent_executions = var.worker_provisioned_concurrency
  qualifier                         = aws_lambda_alias.worker_live.name
}

resource "aws_lambda_event_source_mapping" "worker_buffer" {
  event_source_arn                   = aws_sqs_queue.buffer.arn
  function_name                      = aws_lambda_alias.worker_live.arn
  batch_size                         = var.worker_batch_size
  maximum_batching_window_in_seconds = var.worker_maximum_batching_window_in_seconds
  function_response_types            = ["ReportBatchItemFailures"]

  dynamic "scaling_config" {
    for_each = var.worker_maximum_concurrency != null ? [1] : []

    content {
      maximum_concurrency = var.worker_maximum_concurrency
    }
  }
}

resource "aws_lambda_event_source_mapping" "worker_priority" {
  count = var.enable_priority_lane ? 1 : 0

  event_source_arn                   = aws_sqs_queue.priority[0].arn
  function_name                      = aws_lambda_alias.worker_live.arn
  batch_size                         = var.worker_batch_size
  maximum_batching_window_in_seconds = var.worker_maximum_batching_window_in_seconds
  function_response_types            = ["ReportBatchItemFailures"]

  dynamic "scaling_config" {
    for_each = var.worker_maximum_concurrency != null ? [1] : []

    content {
      maximum_concurrency = var.worker_maximum_concurrency
    }
  }
}

resource "aws_lambda_event_source_mapping" "worker_bulk" {
  count = var.enable_bulk_lane ? 1 : 0

  event_source_arn                   = aws_sqs_queue.bulk[0].arn
  function_name                      = aws_lambda_alias.worker_live.arn
  batch_size                         = var.worker_batch_size
  maximum_batching_window_in_seconds = var.worker_maximum_batching_window_in_seconds
  function_response_types            = ["ReportBatchItemFailures"]

  dynamic "scaling_config" {
    for_each = var.worker_maximum_concurrency != null ? [1] : []

    content {
      maximum_concurrency = var.worker_maximum_concurrency
    }
  }
}

data "aws_iam_policy_document" "apigw_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_sqs" {
  name               = "${local.name_prefix}-apigw-sqs"
  assume_role_policy = data.aws_iam_policy_document.apigw_assume_role.json
}

data "aws_iam_policy_document" "apigw_sqs" {
  statement {
    actions = ["sqs:SendMessage"]
    resources = concat(
      [aws_sqs_queue.buffer.arn],
      var.enable_priority_lane ? [aws_sqs_queue.priority[0].arn] : [],
      var.enable_bulk_lane ? [aws_sqs_queue.bulk[0].arn] : []
    )
  }

  dynamic "statement" {
    for_each = var.enable_customer_managed_kms ? [1] : []

    content {
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:Encrypt", "kms:DescribeKey"]
      resources = [aws_kms_key.platform[0].arn]
    }
  }
}

resource "aws_iam_role_policy" "apigw_sqs" {
  name   = "${local.name_prefix}-apigw-sqs"
  role   = aws_iam_role.apigw_sqs.id
  policy = data.aws_iam_policy_document.apigw_sqs.json
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "sync_lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_alias.sync_live.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_integration" "buffer_sqs" {
  api_id                 = aws_apigatewayv2_api.this.id
  credentials_arn        = aws_iam_role.apigw_sqs.arn
  description            = "Push request body to the async buffer queue"
  integration_subtype    = "SQS-SendMessage"
  integration_type       = "AWS_PROXY"
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    MessageBody = "$request.body"
    QueueUrl    = aws_sqs_queue.buffer.id
  }
}

resource "aws_apigatewayv2_integration" "priority_sqs" {
  count = var.enable_priority_lane ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  credentials_arn        = aws_iam_role.apigw_sqs.arn
  description            = "Push request body to the priority async queue"
  integration_subtype    = "SQS-SendMessage"
  integration_type       = "AWS_PROXY"
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    MessageBody = "$request.body"
    QueueUrl    = aws_sqs_queue.priority[0].id
  }
}

resource "aws_apigatewayv2_integration" "bulk_sqs" {
  count = var.enable_bulk_lane ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  credentials_arn        = aws_iam_role.apigw_sqs.arn
  description            = "Push request body to the bulk async queue"
  integration_subtype    = "SQS-SendMessage"
  integration_type       = "AWS_PROXY"
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    MessageBody = "$request.body"
    QueueUrl    = aws_sqs_queue.bulk[0].id
  }
}

resource "aws_apigatewayv2_route" "sync" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST ${var.sync_route_path}"
  target    = "integrations/${aws_apigatewayv2_integration.sync_lambda.id}"
}

resource "aws_apigatewayv2_route" "buffer" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST ${var.buffer_route_path}"
  target    = "integrations/${aws_apigatewayv2_integration.buffer_sqs.id}"
}

resource "aws_apigatewayv2_route" "priority" {
  count = var.enable_priority_lane ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST ${var.priority_route_path}"
  target    = "integrations/${aws_apigatewayv2_integration.priority_sqs[0].id}"
}

resource "aws_apigatewayv2_route" "bulk" {
  count = var.enable_bulk_lane ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST ${var.bulk_route_path}"
  target    = "integrations/${aws_apigatewayv2_integration.bulk_sqs[0].id}"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.api_stage_name
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = var.api_detailed_metrics_enabled
    throttling_burst_limit   = var.api_throttling_burst_limit
    throttling_rate_limit    = var.api_throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      integration    = "$context.integrationStatus"
      errorMessage   = "$context.error.message"
      responseLength = "$context.responseLength"
      ip             = "$context.identity.sourceIp"
    })
  }
}

resource "aws_lambda_permission" "allow_apigw_sync" {
  statement_id  = "AllowHttpApiInvokeSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  qualifier     = aws_lambda_alias.sync_live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_wafv2_web_acl" "regional" {
  count = var.enable_waf && !local.edge_enabled ? 1 : 0

  name  = "${local.name_prefix}-regional"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(local.name_prefix, "-", "")}-regional"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(local.name_prefix, "-", "")}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RegionalRateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(local.name_prefix, "-", "")}-regional-rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "regional" {
  count = var.enable_waf && !local.edge_enabled ? 1 : 0

  resource_arn = aws_apigatewayv2_stage.this.arn
  web_acl_arn  = aws_wafv2_web_acl.regional[0].arn
}

resource "aws_acm_certificate" "edge" {
  provider = aws.us_east_1
  count    = local.edge_custom_domain_enabled ? 1 : 0

  domain_name       = var.edge_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "edge_certificate_validation" {
  for_each = local.edge_custom_domain_enabled ? {
    for option in aws_acm_certificate.edge[0].domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.edge[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "edge" {
  provider = aws.us_east_1
  count    = local.edge_custom_domain_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.edge[0].arn
  validation_record_fqdns = [for record in aws_route53_record.edge_certificate_validation : record.fqdn]
}

resource "aws_wafv2_web_acl" "edge" {
  provider = aws.us_east_1
  count    = var.enable_waf && local.edge_enabled ? 1 : 0

  name  = "${local.name_prefix}-edge"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(local.name_prefix, "-", "")}-edge"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(local.name_prefix, "-", "")}-edge-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(local.name_prefix, "-", "")}-edge-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "EdgeRateLimit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${replace(local.name_prefix, "-", "")}-edge-rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_cloudfront_cache_policy" "edge_api" {
  count = local.edge_enabled ? 1 : 0

  name        = "${local.name_prefix}-edge-api"
  default_ttl = var.cloudfront_default_ttl
  max_ttl     = var.cloudfront_max_ttl
  min_ttl     = var.cloudfront_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "edge" {
  count = local.edge_enabled ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Edge distribution for ${local.name_prefix}"
  price_class     = var.cloudfront_price_class
  aliases         = local.edge_custom_domain_enabled ? [var.edge_domain_name] : []
  web_acl_id      = var.enable_waf ? aws_wafv2_web_acl.edge[0].arn : null

  origin {
    domain_name = local.edge_origin_domain
    origin_id   = "api-gateway-origin"
    origin_path = local.edge_origin_path

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    dynamic "origin_shield" {
      for_each = var.enable_origin_shield ? [1] : []

      content {
        enabled              = true
        origin_shield_region = var.origin_shield_region
      }
    }
  }

  default_cache_behavior {
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id          = aws_cloudfront_cache_policy.edge_api[0].id
    compress                 = true
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host_header[0].id
    target_origin_id         = "api-gateway-origin"
    viewer_protocol_policy   = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = local.edge_custom_domain_enabled ? aws_acm_certificate_validation.edge[0].certificate_arn : null
    cloudfront_default_certificate = local.edge_custom_domain_enabled ? false : true
    minimum_protocol_version       = local.edge_custom_domain_enabled ? "TLSv1.2_2021" : null
    ssl_support_method             = local.edge_custom_domain_enabled ? "sni-only" : null
  }

  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging ? [1] : []

    content {
      bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
      include_cookies = false
      prefix          = var.cloudfront_log_prefix
    }
  }

  depends_on = [aws_apigatewayv2_stage.this]
}

resource "aws_cloudwatch_log_group" "waf_regional" {
  count = var.enable_waf && !local.edge_enabled && var.enable_waf_logging ? 1 : 0

  name              = "aws-waf-logs-${local.name_prefix}-regional"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
}

resource "aws_cloudwatch_log_group" "waf_edge" {
  provider = aws.us_east_1
  count    = var.enable_waf && local.edge_enabled && var.enable_waf_logging ? 1 : 0

  name              = "aws-waf-logs-${local.name_prefix}-edge"
  retention_in_days = var.log_retention_in_days
}

resource "aws_wafv2_web_acl_logging_configuration" "regional" {
  count = var.enable_waf && !local.edge_enabled && var.enable_waf_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf_regional[0].arn]
  resource_arn            = aws_wafv2_web_acl.regional[0].arn
}

resource "aws_wafv2_web_acl_logging_configuration" "edge" {
  provider = aws.us_east_1
  count    = var.enable_waf && local.edge_enabled && var.enable_waf_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf_edge[0].arn]
  resource_arn            = aws_wafv2_web_acl.edge[0].arn
}

resource "aws_route53_record" "edge_alias" {
  count = local.edge_custom_domain_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.edge[0].zone_id
  name    = var.edge_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = aws_cloudfront_distribution.edge[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb" "sync" {
  count = var.enable_alb_ingress ? 1 : 0

  name               = substr(replace("${local.name_prefix}-alb", "_", "-"), 0, 32)
  internal           = var.alb_internal
  load_balancer_type = "application"
  subnets            = var.alb_subnet_ids
  security_groups    = var.alb_security_group_ids
}

resource "aws_lb_target_group" "sync_lambda" {
  count = var.enable_alb_ingress ? 1 : 0

  name        = substr(replace("${local.name_prefix}-sync", "_", "-"), 0, 32)
  target_type = "lambda"
}

resource "aws_lambda_permission" "allow_alb_sync" {
  count = var.enable_alb_ingress ? 1 : 0

  statement_id  = "AllowAlbInvokeSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  qualifier     = aws_lambda_alias.sync_live.name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.sync_lambda[0].arn
}

resource "aws_lb_target_group_attachment" "sync_lambda" {
  count = var.enable_alb_ingress ? 1 : 0

  target_group_arn = aws_lb_target_group.sync_lambda[0].arn
  target_id        = aws_lambda_alias.sync_live.arn
  depends_on       = [aws_lambda_permission.allow_alb_sync]
}

resource "aws_lb_listener" "sync" {
  count = var.enable_alb_ingress ? 1 : 0

  load_balancer_arn = aws_lb.sync[0].arn
  port              = var.alb_listener_port
  protocol          = var.alb_certificate_arn != null ? "HTTPS" : "HTTP"
  certificate_arn   = var.alb_certificate_arn
  ssl_policy        = var.alb_certificate_arn != null ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sync_lambda[0].arn
  }
}

resource "aws_lb_listener_rule" "sync_path" {
  count = var.enable_alb_ingress ? 1 : 0

  listener_arn = aws_lb_listener.sync[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sync_lambda[0].arn
  }

  condition {
    path_pattern {
      values = [var.sync_route_path]
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "sync_errors" {
  alarm_name          = "${local.name_prefix}-sync-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_errors_alarm_threshold

  dimensions = {
    FunctionName = aws_lambda_function.sync.function_name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  alarm_name          = "${local.name_prefix}-worker-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_errors_alarm_threshold

  dimensions = {
    FunctionName = aws_lambda_function.worker.function_name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "worker_throttles" {
  alarm_name          = "${local.name_prefix}-worker-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_throttles_alarm_threshold

  dimensions = {
    FunctionName = aws_lambda_function.worker.function_name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.api_5xx_alarm_threshold

  dimensions = {
    ApiId = aws_apigatewayv2_api.this.id
    Stage = aws_apigatewayv2_stage.this.name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "buffer_visible_messages" {
  alarm_name          = "${local.name_prefix}-buffer-visible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.queue_visible_messages_alarm_threshold

  dimensions = {
    QueueName = aws_sqs_queue.buffer.name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "buffer_oldest_message" {
  alarm_name          = "${local.name_prefix}-buffer-oldest"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Maximum"
  threshold           = var.queue_oldest_message_alarm_threshold

  dimensions = {
    QueueName = aws_sqs_queue.buffer.name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "priority_visible_messages" {
  count = var.enable_priority_lane ? 1 : 0

  alarm_name          = "${local.name_prefix}-priority-visible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.queue_visible_messages_alarm_threshold

  dimensions = {
    QueueName = aws_sqs_queue.priority[0].name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "bulk_visible_messages" {
  count = var.enable_bulk_lane ? 1 : 0

  alarm_name          = "${local.name_prefix}-bulk-visible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.queue_visible_messages_alarm_threshold

  dimensions = {
    QueueName = aws_sqs_queue.bulk[0].name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible_messages" {
  alarm_name          = "${local.name_prefix}-dlq-visible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.dlq_visible_messages_alarm_threshold

  dimensions = {
    QueueName = aws_sqs_queue.async_dlq.name
  }

  alarm_actions             = local.common_alarm_actions
  ok_actions                = local.common_alarm_actions
  insufficient_data_actions = []
}

resource "aws_cloudwatch_dashboard" "this" {
  count = var.enable_cloudwatch_dashboard ? 1 : 0

  dashboard_name = local.dashboard_name
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "API Requests and 5XX"
          region  = var.aws_region
          stat    = "Sum"
          period  = var.alarm_period_seconds
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.this.id, "Stage", aws_apigatewayv2_stage.this.name],
            [".", "5xx", ".", ".", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Errors and Throttles"
          region  = var.aws_region
          stat    = "Sum"
          period  = var.alarm_period_seconds
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.sync.function_name],
            [".", "Errors", "FunctionName", aws_lambda_function.worker.function_name],
            [".", "Throttles", "FunctionName", aws_lambda_function.worker.function_name]
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "Async Queue Depth"
          region  = var.aws_region
          stat    = "Average"
          period  = var.alarm_period_seconds
          metrics = concat(
            [
              ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.buffer.name],
              [".", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.async_dlq.name]
            ],
            var.enable_priority_lane ? [[".", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.priority[0].name]] : [],
            var.enable_bulk_lane ? [[".", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.bulk[0].name]] : []
          )
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title   = "Async Queue Age"
          region  = var.aws_region
          stat    = "Maximum"
          period  = var.alarm_period_seconds
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", aws_sqs_queue.buffer.name],
            [".", "ApproximateAgeOfOldestMessage", "QueueName", aws_sqs_queue.async_dlq.name]
          ]
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "cicd_artifacts" {
  count = var.cicd_enabled ? 1 : 0

  bucket = local.artifact_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cicd_artifacts" {
  count  = var.cicd_enabled ? 1 : 0
  bucket = aws_s3_bucket.cicd_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_customer_managed_kms ? aws_kms_key.platform[0].arn : null
      sse_algorithm     = var.enable_customer_managed_kms ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cicd_artifacts" {
  count  = var.cicd_enabled ? 1 : 0
  bucket = aws_s3_bucket.cicd_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  count = var.cicd_enabled ? 1 : 0

  name               = "${local.name_prefix}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
}

resource "aws_iam_role" "codebuild" {
  count = var.cicd_enabled ? 1 : 0

  name               = "${local.name_prefix}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

data "aws_iam_policy_document" "codepipeline" {
  count = var.cicd_enabled ? 1 : 0

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.cicd_artifacts[0].arn,
      "${aws_s3_bucket.cicd_artifacts[0].arn}/*"
    ]
  }

  statement {
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.cicd_connection_arn]
  }

  statement {
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:ValidateTemplate"
    ]

    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "codebuild" {
  count = var.cicd_enabled ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.cicd_artifacts[0].arn,
      "${aws_s3_bucket.cicd_artifacts[0].arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  count = var.cicd_enabled ? 1 : 0

  name   = "${local.name_prefix}-codepipeline"
  role   = aws_iam_role.codepipeline[0].id
  policy = data.aws_iam_policy_document.codepipeline[0].json
}

resource "aws_iam_role_policy" "codebuild" {
  count = var.cicd_enabled ? 1 : 0

  name   = "${local.name_prefix}-codebuild"
  role   = aws_iam_role.codebuild[0].id
  policy = data.aws_iam_policy_document.codebuild[0].json
}

resource "aws_codebuild_project" "sam_package" {
  count = var.cicd_enabled ? 1 : 0

  name         = "${local.name_prefix}-sam-package"
  service_role = aws_iam_role.codebuild[0].arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = var.cicd_codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.cicd_artifacts[0].bucket
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "sam/buildspec.yml"
  }
}

resource "aws_codepipeline" "sam_deploy" {
  count = var.cicd_enabled ? 1 : 0

  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline[0].arn

  artifact_store {
    location = aws_s3_bucket.cicd_artifacts[0].bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn        = var.cicd_connection_arn
        FullRepositoryId     = var.cicd_repository_id
        BranchName           = var.cicd_branch_name
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "PackageSAM"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.sam_package[0].name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeploySAM"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ActionMode   = "CREATE_UPDATE"
        Capabilities = "CAPABILITY_IAM,CAPABILITY_NAMED_IAM,CAPABILITY_AUTO_EXPAND"
        StackName    = var.cicd_stack_name
        TemplatePath = "BuildOutput::packaged.yaml"
        RoleArn      = aws_iam_role.codepipeline[0].arn
      }
    }
  }
}