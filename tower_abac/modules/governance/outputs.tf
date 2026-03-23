output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "management_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "organizational_unit_ids" {
  value = local.ou_ids
}

output "account_ids" {
  value = {
    for name, account in aws_organizations_account.accounts : name => account.id
  }
}