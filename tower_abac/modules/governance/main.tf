data "aws_caller_identity" "current" {}

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = var.organization_service_access_principals
  feature_set                   = var.organization_feature_set
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

locals {
  ou_ids = {
    Security       = aws_organizations_organizational_unit.security.id
    Infrastructure = aws_organizations_organizational_unit.infrastructure.id
    Workloads      = aws_organizations_organizational_unit.workloads.id
  }

  accounts = {
    audit = {
      name      = "Audit"
      email     = var.account_emails.audit
      parent_id = local.ou_ids.Security
    }
    log_archive = {
      name      = "Log-Archive"
      email     = var.account_emails.log_archive
      parent_id = local.ou_ids.Security
    }
    shared_services = {
      name      = "Shared-Services"
      email     = var.account_emails.shared_services
      parent_id = local.ou_ids.Infrastructure
    }
    dev = {
      name      = "Workload-Dev"
      email     = var.account_emails.dev
      parent_id = local.ou_ids.Workloads
    }
    staging = {
      name      = "Workload-Staging"
      email     = var.account_emails.staging
      parent_id = local.ou_ids.Workloads
    }
    prod = {
      name      = "Workload-Prod"
      email     = var.account_emails.prod
      parent_id = local.ou_ids.Workloads
    }
  }

  tag_enforcement_services = [
    "ec2:RunInstances",
    "rds:CreateDBInstance",
    "eks:CreateCluster",
    "s3:CreateBucket"
  ]
}

resource "aws_organizations_account" "accounts" {
  for_each = local.accounts

  name      = each.value.name
  email     = each.value.email
  parent_id = each.value.parent_id

  close_on_deletion = false
}

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevent member accounts from leaving the organization."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeavingOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy" "protect_security_services" {
  name        = "ProtectSecurityServices"
  description = "Prevent disabling centralized logging and security services."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisablingSecurityServices"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromAdministratorAccount",
          "securityhub:DisableSecurityHub"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy" "require_workload_tags" {
  name        = "RequireWorkloadTags"
  description = "Require baseline tags on workload resource creation."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for tag_name in var.mandatory_resource_tags : {
        Sid      = "DenyCreateWithout${replace(tag_name, "-", "")}" 
        Effect   = "Deny"
        Action   = local.tag_enforcement_services
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/${tag_name}" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_leave_root" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "protect_security_on_security_ou" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.security.id
}

resource "aws_organizations_policy_attachment" "protect_security_on_workloads_ou" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "require_tags_workloads_ou" {
  policy_id = aws_organizations_policy.require_workload_tags.id
  target_id = aws_organizations_organizational_unit.workloads.id
}