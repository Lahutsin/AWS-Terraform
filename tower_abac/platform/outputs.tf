output "identity_center_permission_sets" {
  description = "Permission set ARNs."
  value       = module.identity_center_abac.permission_sets
}

output "log_archive_bucket_name" {
  description = "Centralized log archive bucket."
  value       = module.logging_baseline.log_archive_bucket_name
}

output "workload_access_role_arns" {
  description = "ABAC-friendly workload role ARNs by environment."
  value = {
    dev     = module.workload_dev.workload_access_role_arn
    staging = module.workload_staging.workload_access_role_arn
    prod    = module.workload_prod.workload_access_role_arn
  }
}