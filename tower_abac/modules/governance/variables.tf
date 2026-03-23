variable "organization_feature_set" {
  type = string
}

variable "organization_service_access_principals" {
  type = list(string)
}

variable "mandatory_resource_tags" {
  type = list(string)
}

variable "account_emails" {
  type = object({
    audit           = string
    log_archive     = string
    shared_services = string
    dev             = string
    staging         = string
    prod            = string
  })
}