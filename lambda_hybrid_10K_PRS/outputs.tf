output "api_endpoint" {
  description = "Base URL of the deployed HTTP API stage."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "sync_invoke_url" {
  description = "Invoke URL for the synchronous route."
  value       = "${aws_apigatewayv2_stage.this.invoke_url}${var.sync_route_path}"
}

output "async_invoke_url" {
  description = "Invoke URL for the asynchronous route."
  value       = "${aws_apigatewayv2_stage.this.invoke_url}${var.async_route_path}"
}

output "dynamodb_table_name" {
  description = "DynamoDB table used to store request metadata."
  value       = aws_dynamodb_table.requests.name
}

output "payload_bucket_name" {
  description = "S3 bucket that stores full request payloads."
  value       = aws_s3_bucket.payloads.bucket
}

output "async_queue_url" {
  description = "Primary SQS queue URL for asynchronous requests."
  value       = aws_sqs_queue.async.id
}

output "async_dlq_url" {
  description = "Dead-letter queue URL for failed asynchronous requests."
  value       = aws_sqs_queue.async_dlq.id
}

output "sync_lambda_name" {
  description = "Name of the synchronous Lambda function."
  value       = aws_lambda_function.sync.function_name
}

output "worker_lambda_name" {
  description = "Name of the asynchronous worker Lambda function."
  value       = aws_lambda_function.worker.function_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name when the edge layer is enabled."
  value       = var.enable_edge_layer ? aws_cloudfront_distribution.edge[0].domain_name : null
}

output "edge_url" {
  description = "Preferred public edge URL when CloudFront is enabled."
  value       = var.enable_edge_layer ? "https://${coalesce(var.edge_domain_name, aws_cloudfront_distribution.edge[0].domain_name)}" : null
}

output "waf_arn" {
  description = "WAF ARN attached either to CloudFront or the API stage."
  value       = var.enable_waf ? (var.enable_edge_layer ? aws_wafv2_web_acl.edge[0].arn : aws_wafv2_web_acl.regional[0].arn) : null
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for the stack."
  value       = var.enable_cloudwatch_dashboard ? aws_cloudwatch_dashboard.this[0].dashboard_name : null
}

output "codepipeline_name" {
  description = "Optional CodePipeline name for the SAM or CloudFormation deployment layer."
  value       = var.cicd_enabled ? aws_codepipeline.sam_deploy[0].name : null
}

output "alarm_notification_topic_arn" {
  description = "SNS topic ARN used for CloudWatch alarm notifications."
  value       = var.enable_alarm_notifications ? coalesce(var.alarm_notification_topic_arn, aws_sns_topic.alarm_notifications[0].arn) : null
}

output "cloudfront_log_bucket_name" {
  description = "S3 bucket used for CloudFront access logs when enabled."
  value       = var.enable_edge_layer && var.enable_cloudfront_logging ? aws_s3_bucket.cloudfront_logs[0].bucket : null
}

output "waf_log_group_name" {
  description = "CloudWatch Logs destination used for WAF logging."
  value       = var.enable_waf && var.enable_waf_logging ? (var.enable_edge_layer ? aws_cloudwatch_log_group.waf_edge[0].name : aws_cloudwatch_log_group.waf_regional[0].name) : null
}

output "codebuild_project_name" {
  description = "Optional CodeBuild project that packages the SAM template for deployment."
  value       = var.cicd_enabled ? aws_codebuild_project.sam_package[0].name : null
}