module "identity_center_abac" {
  source = "../modules/identity-center-abac"

  providers = {
    aws = aws.management
  }

  create_identity_center_groups = var.create_identity_center_groups
  identity_center_groups        = var.identity_center_groups
  permission_set_relay_state    = var.permission_set_relay_state
  audit_account_id              = var.account_ids.audit
  shared_services_account_id    = var.account_ids.shared_services
  workload_account_ids          = {
    dev     = var.account_ids.dev
    staging = var.account_ids.staging
    prod    = var.account_ids.prod
  }
}

module "logging_baseline" {
  source = "../modules/logging-baseline"

  providers = {
    aws.management  = aws.management
    aws.audit       = aws.audit
    aws.log_archive = aws.log_archive
  }

  aws_region             = var.aws_region
  project_name           = var.project_name
  organization_id        = var.organization_id
  management_account_id  = var.management_account_id
  audit_account_id       = var.account_ids.audit
  log_archive_account_id = var.account_ids.log_archive
}

module "workload_dev" {
  source = "../modules/workload-baseline"

  providers = {
    aws = aws.workload_dev
  }

  environment  = "dev"
  project_name = var.project_name
  cost_center  = var.cost_center
  owner        = var.workload_owner
}

module "workload_staging" {
  source = "../modules/workload-baseline"

  providers = {
    aws = aws.workload_staging
  }

  environment  = "staging"
  project_name = var.project_name
  cost_center  = var.cost_center
  owner        = var.workload_owner
}

module "workload_prod" {
  source = "../modules/workload-baseline"

  providers = {
    aws = aws.workload_prod
  }

  environment  = "prod"
  project_name = var.project_name
  cost_center  = var.cost_center
  owner        = var.workload_owner
}