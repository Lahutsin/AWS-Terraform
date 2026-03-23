data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "workload_access" {
  name = "${var.project_name}-${var.environment}-workload-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Environment" = var.environment
            "aws:PrincipalTag/CostCenter"  = var.cost_center
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "workload_access" {
  name = "${var.project_name}-${var.environment}-workload-access-policy"
  role = aws_iam_role.workload_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ABACAccessToTaggedResources"
        Effect = "Allow"
        Action = [
          "s3:*",
          "ec2:*",
          "eks:*",
          "rds:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = "$${aws:PrincipalTag/Environment}"
            "aws:ResourceTag/CostCenter"  = "$${aws:PrincipalTag/CostCenter}"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "example_workload" {
  bucket = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-example"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example_workload" {
  bucket = aws_s3_bucket.example_workload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "example_workload" {
  bucket = aws_s3_bucket.example_workload.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "example_workload" {
  bucket = aws_s3_bucket.example_workload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_tagging" "example_workload" {
  bucket = aws_s3_bucket.example_workload.id

  tag_set = {
    Environment        = var.environment
    CostCenter         = var.cost_center
    Owner              = var.owner
    DataClassification = "internal"
  }
}