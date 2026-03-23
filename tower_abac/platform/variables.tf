variable "aws_region" {
  description = "AWS region for the platform phase."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project or landing zone identifier used in names and tags."
  type        = string
  default     = "tower-abac"
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

variable "management_profile" {
  type        = string
  description = "AWS CLI profile for the management account."
  default     = "management"
}

variable "management_role_arn" {
  type        = string
  description = "Role ARN assumed in the management account."
}

variable "management_account_id" {
  type        = string
  description = "Management account ID from the bootstrap phase."
}

variable "audit_profile" {
  type        = string
  description = "AWS CLI profile for the audit account."
  default     = "audit"
}

variable "audit_role_arn" {
  type        = string
  description = "Role ARN assumed in the audit account."
}

variable "log_archive_profile" {
  type        = string
  description = "AWS CLI profile for the log archive account."
  default     = "log-archive"
}

variable "log_archive_role_arn" {
  type        = string
  description = "Role ARN assumed in the log archive account."
}

variable "shared_services_profile" {
  type        = string
  description = "AWS CLI profile for the shared services account."
  default     = "shared-services"
}

variable "shared_services_role_arn" {
  type        = string
  description = "Role ARN assumed in the shared services account."
}

variable "workload_dev_profile" {
  type        = string
  description = "AWS CLI profile for the dev workload account."
  default     = "workload-dev"
}

variable "workload_dev_role_arn" {
  type        = string
  description = "Role ARN assumed in the dev workload account."
}

variable "workload_staging_profile" {
  type        = string
  description = "AWS CLI profile for the staging workload account."
  default     = "workload-staging"
}

variable "workload_staging_role_arn" {
  type        = string
  description = "Role ARN assumed in the staging workload account."
}

variable "workload_prod_profile" {
  type        = string
  description = "AWS CLI profile for the prod workload account."
  default     = "workload-prod"
}

variable "workload_prod_role_arn" {
  type        = string
  description = "Role ARN assumed in the prod workload account."
}

variable "account_ids" {
  description = "Existing account IDs from the bootstrap phase."
  type = object({
    audit           = string
    log_archive     = string
    shared_services = string
    dev             = string
    staging         = string
    prod            = string
  })
}

variable "organization_id" {
  description = "AWS Organizations ID from the bootstrap phase."
  type        = string
}

variable "identity_center_groups" {
  description = "Principal groups to create in IAM Identity Center identity store."
  type = object({
    platform_admins = string
    developers      = string
    auditors        = string
  })
  default = {
    platform_admins = "PlatformAdmins"
    developers      = "Developers"
    auditors        = "Auditors"
  }
}

variable "create_identity_center_groups" {
  description = "Whether Terraform should create groups in the IAM Identity Center identity store."
  type        = bool
  default     = true
}

variable "permission_set_relay_state" {
  description = "Optional relay state for IAM Identity Center permission sets."
  type        = string
  default     = null
}