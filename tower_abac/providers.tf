provider "aws" {
  alias   = "management"
  region  = var.aws_region
  profile = var.management_profile

  assume_role {
    role_arn     = var.management_role_arn
    session_name = "tower-abac-management"
  }

  default_tags {
    tags = local.default_tags
  }
}