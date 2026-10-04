data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  # Strip JSON-key/version suffixes so IAM matches the base secret ARN.
  secret_resource_arns = distinct([
    for arn in values(var.secrets) :
    split(":", arn)[2] == "secretsmanager" ? join(":", slice(split(":", arn), 0, 7)) : arn
  ])
  secretsmanager_arns = [for arn in local.secret_resource_arns : arn if split(":", arn)[2] == "secretsmanager"]
  ssm_arns            = [for arn in local.secret_resource_arns : arn if split(":", arn)[2] == "ssm"]
}

# Trust ECS tasks from this account only (prevents confused-deputy).
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    }
  }
}

################################################################################
# Execution role: used by the ECS agent to pull images, write logs, fetch secrets
################################################################################

resource "aws_iam_role" "execution" {
  name_prefix        = "${substr(var.name, 0, 24)}-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/*"]
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  dynamic "statement" {
    for_each = length(local.secretsmanager_arns) > 0 ? [1] : []

    content {
      sid       = "SecretsManager"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.secretsmanager_arns
    }
  }

  dynamic "statement" {
    for_each = length(local.ssm_arns) > 0 ? [1] : []

    content {
      sid       = "SSMParameters"
      actions   = ["ssm:GetParameters"]
      resources = local.ssm_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.secrets_kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "DecryptSecrets"
      actions   = ["kms:Decrypt"]
      resources = var.secrets_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

################################################################################
# Task role: assumed by the application itself
################################################################################

resource "aws_iam_role" "task" {
  name_prefix        = "${substr(var.name, 0, 24)}-task-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "exec" {
  count = var.enable_execute_command ? 1 : 0

  statement {
    sid = "SSMMessages"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ExecLogsDescribe"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ExecLogsWrite"
    actions   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
    resources = ["${var.exec_log_group_arn}:*"]
  }

  statement {
    sid       = "ExecSessionDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "exec" {
  count = var.enable_execute_command ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.exec[0].json
}

resource "aws_iam_role_policy" "task" {
  count = var.task_role_policy_json != null ? 1 : 0

  name   = "application"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}

resource "aws_iam_role_policy_attachment" "task" {
  for_each = toset(var.task_role_managed_policy_arns)

  role       = aws_iam_role.task.name
  policy_arn = each.value
}
