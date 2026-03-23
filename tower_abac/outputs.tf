output "organization_id" {
  description = "AWS Organizations ID."
  value       = module.governance.organization_id
}

output "organizational_unit_ids" {
  description = "Organizational unit IDs keyed by OU name."
  value       = module.governance.organizational_unit_ids
}

output "account_ids" {
  description = "Created account IDs keyed by logical account name."
  value       = module.governance.account_ids
}