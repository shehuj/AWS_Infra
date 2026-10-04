data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region
}

data "aws_iam_policy_document" "this" {
  #checkov:skip=CKV_AWS_109:Standard key policy root statement; access is delegated to IAM
  #checkov:skip=CKV_AWS_111:Standard key policy root statement; access is delegated to IAM
  #checkov:skip=CKV_AWS_356:In a key policy "*" refers only to this key
  # Delegate access control to IAM within the owning account.
  statement {
    sid       = "EnableIAMUserPermissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.key_administrator_arns) > 0 ? [1] : []

    content {
      sid = "KeyAdministration"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
        "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
        "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_administrator_arns
      }
    }
  }

  dynamic "statement" {
    for_each = var.allow_cloudwatch_logs ? [1] : []

    content {
      sid       = "AllowCloudWatchLogs"
      actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["logs.${local.region}.amazonaws.com"]
      }

      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:*"]
      }
    }
  }
}

data "aws_iam_policy_document" "services" {
  source_policy_documents = [data.aws_iam_policy_document.this.json]

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []

    content {
      sid       = "AllowServicePrincipals"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.service_principals
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.services.json

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
