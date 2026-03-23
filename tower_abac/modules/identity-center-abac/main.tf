data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id  = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  platform_admins    = var.identity_center_groups.platform_admins
  developers         = var.identity_center_groups.developers
  auditors           = var.identity_center_groups.auditors
}

resource "aws_identitystore_group" "platform_admins" {
  count = var.create_identity_center_groups ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = local.platform_admins
  description       = "Platform administrators with elevated access."
}

resource "aws_identitystore_group" "developers" {
  count = var.create_identity_center_groups ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = local.developers
  description       = "Developers constrained by ABAC tags."
}

resource "aws_identitystore_group" "auditors" {
  count = var.create_identity_center_groups ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = local.auditors
  description       = "Read-only auditors for security and compliance."
}

resource "aws_ssoadmin_permission_set" "platform_admin" {
  instance_arn     = local.instance_arn
  name             = "PlatformAdmin"
  description      = "Administrative access for platform operators."
  relay_state      = var.permission_set_relay_state
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "platform_admin_access" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
}

resource "aws_ssoadmin_permission_set" "workload_operator" {
  instance_arn     = local.instance_arn
  name             = "WorkloadOperatorABAC"
  description      = "ABAC-constrained operator access for workload teams."
  relay_state      = var.permission_set_relay_state
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "workload_operator_poweruser" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.workload_operator.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "workload_operator_abac" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.workload_operator.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowABACOnTaggedResources"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "rds:*",
          "logs:*",
          "cloudwatch:*",
          "ssm:*",
          "s3:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = "$${aws:PrincipalTag/Environment}"
            "aws:ResourceTag/CostCenter"  = "$${aws:PrincipalTag/CostCenter}"
          }
        }
      },
      {
        Sid    = "AllowCreateWhenTagsMatchPrincipal"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "eks:CreateCluster",
          "rds:CreateDBInstance",
          "s3:CreateBucket"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = "$${aws:PrincipalTag/Environment}"
            "aws:RequestTag/CostCenter"  = "$${aws:PrincipalTag/CostCenter}"
          }
        }
      },
      {
        Sid    = "DenyIfPrincipalTagsMissing"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          Null = {
            "aws:PrincipalTag/Environment" = "true"
            "aws:PrincipalTag/CostCenter"  = "true"
          }
        }
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "audit_readonly" {
  instance_arn     = local.instance_arn
  name             = "AuditReadOnly"
  description      = "Read-only access for auditors."
  relay_state      = var.permission_set_relay_state
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "audit_readonly_access" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
  permission_set_arn = aws_ssoadmin_permission_set.audit_readonly.arn
}

resource "aws_ssoadmin_account_assignment" "platform_admin_to_audit" {
  count = var.create_identity_center_groups ? 1 : 0

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = aws_identitystore_group.platform_admins[0].group_id
  principal_type     = "GROUP"
  target_id          = var.audit_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_admin_to_shared_services" {
  count = var.create_identity_center_groups ? 1 : 0

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_admin.arn
  principal_id       = aws_identitystore_group.platform_admins[0].group_id
  principal_type     = "GROUP"
  target_id          = var.shared_services_account_id
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "developers_to_workloads" {
  for_each = var.create_identity_center_groups ? var.workload_account_ids : {}

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.workload_operator.arn
  principal_id       = aws_identitystore_group.developers[0].group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "auditors_to_audit" {
  count = var.create_identity_center_groups ? 1 : 0

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.audit_readonly.arn
  principal_id       = aws_identitystore_group.auditors[0].group_id
  principal_type     = "GROUP"
  target_id          = var.audit_account_id
  target_type        = "AWS_ACCOUNT"
}