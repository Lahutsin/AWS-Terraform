module "governance" {
  source = "./modules/governance"

  providers = {
    aws = aws.management
  }

  organization_feature_set                = var.organization_feature_set
  organization_service_access_principals  = var.organization_service_access_principals
  mandatory_resource_tags                 = var.mandatory_resource_tags
  account_emails                          = var.account_emails
}