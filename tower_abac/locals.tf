locals {
  default_tags = {
    Project            = var.project_name
    ManagedBy          = "Terraform"
    Architecture       = "AWS-Control-Tower-ABAC"
    CostCenter         = var.cost_center
    Owner              = var.workload_owner
    DataClassification = "internal"
  }

  workload_accounts = {
    dev = {
      name        = "Workload-Dev"
      email       = var.account_emails.dev
      parent_name = "Workloads"
      environment = "dev"
    }
    staging = {
      name        = "Workload-Staging"
      email       = var.account_emails.staging
      parent_name = "Workloads"
      environment = "staging"
    }
    prod = {
      name        = "Workload-Prod"
      email       = var.account_emails.prod
      parent_name = "Workloads"
      environment = "prod"
    }
  }
}