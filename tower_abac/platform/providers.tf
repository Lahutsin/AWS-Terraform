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

provider "aws" {
  alias   = "audit"
  region  = var.aws_region
  profile = var.audit_profile

  assume_role {
    role_arn     = var.audit_role_arn
    session_name = "tower-abac-audit"
  }

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias   = "log_archive"
  region  = var.aws_region
  profile = var.log_archive_profile

  assume_role {
    role_arn     = var.log_archive_role_arn
    session_name = "tower-abac-log-archive"
  }

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias   = "shared_services"
  region  = var.aws_region
  profile = var.shared_services_profile

  assume_role {
    role_arn     = var.shared_services_role_arn
    session_name = "tower-abac-shared-services"
  }

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias   = "workload_dev"
  region  = var.aws_region
  profile = var.workload_dev_profile

  assume_role {
    role_arn     = var.workload_dev_role_arn
    session_name = "tower-abac-dev"
  }

  default_tags {
    tags = merge(local.default_tags, { Environment = "dev" })
  }
}

provider "aws" {
  alias   = "workload_staging"
  region  = var.aws_region
  profile = var.workload_staging_profile

  assume_role {
    role_arn     = var.workload_staging_role_arn
    session_name = "tower-abac-staging"
  }

  default_tags {
    tags = merge(local.default_tags, { Environment = "staging" })
  }
}

provider "aws" {
  alias   = "workload_prod"
  region  = var.aws_region
  profile = var.workload_prod_profile

  assume_role {
    role_arn     = var.workload_prod_role_arn
    session_name = "tower-abac-prod"
  }

  default_tags {
    tags = merge(local.default_tags, { Environment = "prod" })
  }
}