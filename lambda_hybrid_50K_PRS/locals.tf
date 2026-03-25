locals {
  name_prefix                = lower("${var.project_name}-${var.environment}")
  edge_enabled               = var.enable_edge_layer
  edge_custom_domain_enabled = var.enable_edge_layer && var.edge_domain_name != null && var.route53_zone_name != null
  edge_origin_domain         = replace(aws_apigatewayv2_api.this.api_endpoint, "https://", "")
  edge_origin_path           = var.api_stage_name == "$default" ? null : "/${var.api_stage_name}"
  api_stage_segment          = var.api_stage_name == "$default" ? "" : "/${var.api_stage_name}"
  dashboard_name             = coalesce(var.dashboard_name_override, "${local.name_prefix}-dashboard")
  notification_topic_name    = coalesce(var.alarm_notification_topic_name_override, "${local.name_prefix}-alarms")

  artifact_bucket_name = coalesce(
    var.cicd_artifact_bucket_name_override,
    lower("${substr(var.project_name, 0, 16)}-${var.environment}-artifacts-${data.aws_caller_identity.current.account_id}-${random_string.bucket_suffix.result}")
  )

  cloudfront_log_bucket_name = coalesce(
    var.cloudfront_log_bucket_name_override,
    lower("${substr(var.project_name, 0, 16)}-${var.environment}-cf-logs-${data.aws_caller_identity.current.account_id}-${random_string.bucket_suffix.result}")
  )

  s3_bucket_name = coalesce(
    var.s3_bucket_name_override,
    lower("${substr(var.project_name, 0, 16)}-${var.environment}-${data.aws_caller_identity.current.account_id}-${random_string.bucket_suffix.result}")
  )

  dynamodb_table_name = coalesce(var.dynamodb_table_name_override, "${local.name_prefix}-requests")
  kms_alias_name      = "alias/${local.name_prefix}-platform"

  queue_names = {
    buffer   = "${local.name_prefix}-buffer"
    priority = "${local.name_prefix}-priority"
    bulk     = "${local.name_prefix}-bulk"
    dlq      = "${local.name_prefix}-dlq"
  }

  common_alarm_actions = var.enable_alarm_notifications ? [coalesce(var.alarm_notification_topic_arn, aws_sns_topic.alarm_notifications[0].arn)] : []

  default_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Architecture       = "Lambda-Hybrid-50K"
    CostCenter         = var.cost_center
    Owner              = var.owner
    DataClassification = var.data_classification
  }
}