locals {
  default_tags = {
    Project            = var.project_name
    ManagedBy          = "Terraform"
    Architecture       = "AWS-Control-Tower-ABAC"
    CostCenter         = var.cost_center
    Owner              = var.workload_owner
    DataClassification = "internal"
  }
}