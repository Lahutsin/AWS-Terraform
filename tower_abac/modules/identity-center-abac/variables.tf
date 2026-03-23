variable "create_identity_center_groups" {
  type = bool
}

variable "identity_center_groups" {
  type = object({
    platform_admins = string
    developers      = string
    auditors        = string
  })
}

variable "permission_set_relay_state" {
  type = string
}

variable "audit_account_id" {
  type = string
}

variable "shared_services_account_id" {
  type = string
}

variable "workload_account_ids" {
  type = map(string)
}