variable "aws_region" {
  description = "AWS region for the stack."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags."
  type        = string
  default     = "lambda-hybrid-50k"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "cost_center" {
  description = "Default cost center tag value."
  type        = string
  default     = "application"
}

variable "owner" {
  description = "Default owner tag value."
  type        = string
  default     = "platform-team"
}

variable "data_classification" {
  description = "Default data classification tag value."
  type        = string
  default     = "internal"
}

variable "api_name" {
  description = "Name of the HTTP API."
  type        = string
  default     = "lambda-hybrid-50k-api"
}

variable "api_stage_name" {
  description = "HTTP API stage name. Use $default to avoid a stage suffix in the URL."
  type        = string
  default     = "v1"
}

variable "api_throttling_burst_limit" {
  description = "Burst throttling limit for the HTTP API stage default route settings."
  type        = number
  default     = 10000
}

variable "api_throttling_rate_limit" {
  description = "Steady-state throttling rate limit for the HTTP API stage default route settings."
  type        = number
  default     = 5000
}

variable "api_detailed_metrics_enabled" {
  description = "Enable detailed CloudWatch metrics for API Gateway routes."
  type        = bool
  default     = true
}

variable "sync_route_path" {
  description = "Route path for synchronous requests."
  type        = string
  default     = "/sync"
}

variable "buffer_route_path" {
  description = "Route path for default buffered asynchronous requests."
  type        = string
  default     = "/async"
}

variable "async_route_path" {
  description = "Deprecated alias for buffer_route_path kept for compatibility with the 10K stack naming."
  type        = string
  default     = null
}

variable "priority_route_path" {
  description = "Route path for priority asynchronous requests."
  type        = string
  default     = "/async/priority"
}

variable "bulk_route_path" {
  description = "Route path for bulk asynchronous requests."
  type        = string
  default     = "/async/bulk"
}

variable "lambda_runtime" {
  description = "Runtime for both Lambda functions."
  type        = string
  default     = "python3.12"
}

variable "lambda_architectures" {
  description = "Instruction set architecture for Lambda functions."
  type        = list(string)
  default     = ["arm64"]
}

variable "sync_lambda_memory_size" {
  description = "Memory size for the synchronous Lambda in MB."
  type        = number
  default     = 1024
}

variable "sync_reserved_concurrency" {
  description = "Reserved concurrency for the synchronous Lambda. Set to null to leave it unreserved."
  type        = number
  default     = 150
}

variable "sync_provisioned_concurrency" {
  description = "Provisioned concurrency for the synchronous Lambda alias. Set to 0 to disable."
  type        = number
  default     = 40
}

variable "sync_lambda_timeout" {
  description = "Timeout for the synchronous Lambda in seconds."
  type        = number
  default     = 10
}

variable "worker_lambda_memory_size" {
  description = "Memory size for the worker Lambda in MB."
  type        = number
  default     = 1024
}

variable "worker_lambda_timeout" {
  description = "Timeout for the worker Lambda in seconds."
  type        = number
  default     = 60
}

variable "worker_reserved_concurrency" {
  description = "Reserved concurrency for the worker Lambda. Set to null to leave it unreserved."
  type        = number
  default     = 250
}

variable "worker_provisioned_concurrency" {
  description = "Provisioned concurrency for the worker Lambda alias. Set to 0 to disable."
  type        = number
  default     = 40
}

variable "worker_batch_size" {
  description = "Number of SQS messages processed per Lambda batch."
  type        = number
  default     = 10
}

variable "worker_maximum_batching_window_in_seconds" {
  description = "Maximum batching window for SQS event source mapping."
  type        = number
  default     = 5
}

variable "worker_maximum_concurrency" {
  description = "Optional cap for SQS event source mapping concurrency per queue. Set to null to let Lambda scale freely within reserved concurrency."
  type        = number
  default     = 150
}

variable "queue_message_retention_seconds" {
  description = "Retention period for the main queue in seconds."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Retention period for the dead-letter queue in seconds."
  type        = number
  default     = 1209600
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout for the main SQS queue in seconds."
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "How many times a message can be received before going to DLQ."
  type        = number
  default     = 5
}

variable "enable_priority_lane" {
  description = "Whether to create the dedicated priority SQS lane."
  type        = bool
  default     = true
}

variable "enable_bulk_lane" {
  description = "Whether to create the dedicated bulk SQS lane."
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for Lambda log groups."
  type        = number
  default     = 14
}

variable "enable_xray" {
  description = "Enable active X-Ray tracing for Lambda functions."
  type        = bool
  default     = true
}

variable "enable_customer_managed_kms" {
  description = "Whether to create a customer-managed KMS key and use it for supported data services."
  type        = bool
  default     = false
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the optional customer-managed KMS key."
  type        = number
  default     = 30
}

variable "enable_cloudwatch_dashboard" {
  description = "Whether to create a CloudWatch dashboard for the stack."
  type        = bool
  default     = true
}

variable "dashboard_name_override" {
  description = "Optional explicit CloudWatch dashboard name."
  type        = string
  default     = null
}

variable "lambda_errors_alarm_threshold" {
  description = "Threshold for Lambda error alarms within one period."
  type        = number
  default     = 1
}

variable "lambda_throttles_alarm_threshold" {
  description = "Threshold for Lambda throttle alarms within one period."
  type        = number
  default     = 1
}

variable "api_5xx_alarm_threshold" {
  description = "Threshold for API Gateway 5XX alarms within one period."
  type        = number
  default     = 1
}

variable "dlq_visible_messages_alarm_threshold" {
  description = "Threshold for visible messages in the DLQ alarm."
  type        = number
  default     = 1
}

variable "queue_visible_messages_alarm_threshold" {
  description = "Threshold for visible messages in the async queues alarm."
  type        = number
  default     = 100
}

variable "queue_oldest_message_alarm_threshold" {
  description = "Threshold in seconds for the oldest visible message in async queues."
  type        = number
  default     = 60
}

variable "waf_rate_limit" {
  description = "Request rate per five minutes allowed before the WAF rate-based rule blocks traffic."
  type        = number
  default     = 20000
}

variable "alarm_period_seconds" {
  description = "Period used by CloudWatch alarms."
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Number of periods evaluated by CloudWatch alarms."
  type        = number
  default     = 1
}

variable "enable_alarm_notifications" {
  description = "Whether to publish CloudWatch alarm state changes to SNS."
  type        = bool
  default     = true
}

variable "alarm_notification_topic_arn" {
  description = "Existing SNS topic ARN for alarm notifications. If null, Terraform can create one."
  type        = string
  default     = null
}

variable "alarm_notification_topic_name_override" {
  description = "Optional explicit name for the SNS topic created for alarm notifications."
  type        = string
  default     = null
}

variable "alarm_notification_email_endpoints" {
  description = "Email endpoints subscribed to the created or provided SNS topic for alarm notifications."
  type        = list(string)
  default     = []
}

variable "enable_edge_layer" {
  description = "Whether to create the CloudFront and optional Route 53 edge layer in front of the API."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Whether to create and associate WAF with the edge layer or the API stage."
  type        = bool
  default     = true
}

variable "route53_zone_name" {
  description = "Route 53 public zone name used for the edge alias record, for example example.com."
  type        = string
  default     = null
}

variable "edge_domain_name" {
  description = "Optional custom domain name for CloudFront, for example api.example.com."
  type        = string
  default     = null
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for the edge distribution."
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_default_ttl" {
  description = "Default TTL used by the custom CloudFront cache policy for cacheable methods."
  type        = number
  default     = 60
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL used by the custom CloudFront cache policy for cacheable methods."
  type        = number
  default     = 300
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL used by the custom CloudFront cache policy for cacheable methods."
  type        = number
  default     = 0
}

variable "enable_origin_shield" {
  description = "Whether to enable CloudFront Origin Shield in front of API Gateway."
  type        = bool
  default     = true
}

variable "origin_shield_region" {
  description = "Region used by CloudFront Origin Shield."
  type        = string
  default     = "eu-central-1"
}

variable "enable_cloudfront_logging" {
  description = "Whether to enable CloudFront standard access logging to S3 when the edge layer is enabled."
  type        = bool
  default     = true
}

variable "cloudfront_log_bucket_name_override" {
  description = "Optional explicit S3 bucket name for CloudFront access logs."
  type        = string
  default     = null
}

variable "cloudfront_log_prefix" {
  description = "Prefix used for CloudFront access logs."
  type        = string
  default     = "cloudfront/"
}

variable "enable_waf_logging" {
  description = "Whether to enable WAF logging to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "enable_alb_ingress" {
  description = "Whether to create an Application Load Balancer as an alternative ingress to the sync Lambda."
  type        = bool
  default     = false
}

variable "alb_internal" {
  description = "Whether the optional ALB should be internal."
  type        = bool
  default     = false
}

variable "alb_subnet_ids" {
  description = "Subnet IDs used by the optional ALB. Required when enable_alb_ingress is true."
  type        = list(string)
  default     = []
}

variable "alb_security_group_ids" {
  description = "Security groups attached to the optional ALB."
  type        = list(string)
  default     = []
}

variable "alb_listener_port" {
  description = "Listener port for the optional ALB."
  type        = number
  default     = 80
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS on the ALB. When null, the ALB uses HTTP."
  type        = string
  default     = null
}

variable "cicd_enabled" {
  description = "Whether to create the optional CI/CD scaffold with CodePipeline and CloudFormation deployment."
  type        = bool
  default     = false
}

variable "cicd_connection_arn" {
  description = "CodeStar connection ARN used by the optional CodePipeline source stage."
  type        = string
  default     = null
}

variable "cicd_repository_id" {
  description = "Repository identifier in owner/name format for the optional CodePipeline source stage."
  type        = string
  default     = null
}

variable "cicd_branch_name" {
  description = "Repository branch used by the optional CodePipeline source stage."
  type        = string
  default     = "main"
}

variable "cicd_codebuild_image" {
  description = "Container image used by the CodeBuild packaging stage."
  type        = string
  default     = "public.ecr.aws/sam/build-python3.12:latest"
}

variable "cicd_artifact_bucket_name_override" {
  description = "Optional explicit artifact bucket name for the optional CI/CD pipeline."
  type        = string
  default     = null
}

variable "cicd_stack_name" {
  description = "CloudFormation stack name used by the optional pipeline deploy action."
  type        = string
  default     = "lambda-hybrid-sam"
}

variable "dynamodb_table_name_override" {
  description = "Optional explicit DynamoDB table name."
  type        = string
  default     = null
}

variable "enable_dynamodb_stream" {
  description = "Whether to enable DynamoDB Streams on the request table."
  type        = bool
  default     = true
}

variable "dynamodb_stream_view_type" {
  description = "View type used when DynamoDB Streams are enabled."
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "enable_point_in_time_recovery" {
  description = "Whether to enable PITR for the DynamoDB table."
  type        = bool
  default     = true
}

variable "s3_bucket_name_override" {
  description = "Optional explicit S3 bucket name. Must be globally unique if provided."
  type        = string
  default     = null
}

variable "s3_bucket_force_destroy" {
  description = "Whether Terraform may delete non-empty S3 bucket objects on destroy."
  type        = bool
  default     = false
}

variable "enable_async_sns_topic" {
  description = "Whether to create an SNS topic that fans messages into the buffer queue."
  type        = bool
  default     = true
}

variable "enable_eventbridge_ingress" {
  description = "Whether to create a custom EventBridge bus and route matching events into the buffer queue."
  type        = bool
  default     = true
}

variable "async_eventbridge_source" {
  description = "EventBridge source matched by the async ingress rule."
  type        = string
  default     = "custom.lambda-hybrid"
}

variable "async_eventbridge_detail_type" {
  description = "EventBridge detail-type matched by the async ingress rule."
  type        = string
  default     = "async-request"
}