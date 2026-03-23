variable "aws_region" {
  description = "AWS region for global baseline resources."
  type        = string
  default     = "eu-central-1"
}

variable "organization_feature_set" {
  description = "AWS Organizations feature set."
  type        = string
  default     = "ALL"
}

variable "organization_service_access_principals" {
  description = "Trusted access integrations enabled at the organization level."
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com"
  ]
}

variable "management_profile" {
  type        = string
  description = "AWS CLI profile for the management account."
  default     = "management"
}

variable "management_role_arn" {
  type        = string
  description = "Role ARN assumed in the management account."
}

variable "account_emails" {
  description = "Email addresses used when creating organization accounts."
  type = object({
    audit           = string
    log_archive     = string
    shared_services = string
    dev             = string
    staging         = string
    prod            = string
  })
}

variable "project_name" {
  description = "Project or landing zone identifier used in names and tags."
  type        = string
  default     = "tower-abac"
}

variable "mandatory_resource_tags" {
  description = "Tags that workloads must carry for ABAC and governance."
  type        = list(string)
  default     = ["Environment", "CostCenter", "Owner", "DataClassification"]
}

variable "cost_center" {
  description = "Default cost center tag value."
  type        = string
  default     = "shared-platform"
}

variable "workload_owner" {
  description = "Default workload owner tag value."
  type        = string
  default     = "platform-team"
}