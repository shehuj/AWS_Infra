data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "current" {}

################################################################################
# Access logs bucket
# ALB log delivery supports only SSE-S3, not SSE-KMS.
################################################################################

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_18:This is the log destination bucket; logging it to itself would recurse
  #checkov:skip=CKV_AWS_145:ALB log delivery supports only SSE-S3, not SSE-KMS
  #checkov:skip=CKV_AWS_144:Access logs do not require cross-region replication
  #checkov:skip=CKV2_AWS_62:No consumers for object events on access logs
  bucket_prefix = "${substr(var.name, 0, 24)}-alb-logs-"
  force_destroy = var.force_destroy_logs_bucket

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

locals {
  access_logs_prefix     = "access"
  connection_logs_prefix = "connection"

  # ELB writes to <prefix>/AWSLogs/<account-id>/ and validates with a test object there.
  log_delivery_resources = [
    for prefix in [local.access_logs_prefix, local.connection_logs_prefix] :
    "${aws_s3_bucket.logs.arn}/${prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
  ]
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "AllowELBLogDelivery"
    actions   = ["s3:PutObject"]
    resources = local.log_delivery_resources

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
  }

  # Regions launched before August 2022 deliver logs from a regional ELB account.
  statement {
    sid       = "AllowLegacyELBAccountLogDelivery"
    actions   = ["s3:PutObject"]
    resources = local.log_delivery_resources

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs.json

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

################################################################################
# Security group
################################################################################

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-alb-"
  description = "Load balancer ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.ingress_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "HTTPS"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  #checkov:skip=CKV_AWS_260:Port 80 only issues a 301 redirect to HTTPS
  for_each = toset(var.ingress_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "HTTP (redirected to HTTPS)"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Egress is restricted to the VPC: the ALB only talks to targets.
data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "vpc" {
  security_group_id = aws_security_group.this.id
  description       = "To targets within the VPC"
  cidr_ipv4         = data.aws_vpc.this.cidr_block
  ip_protocol       = "-1"
}

################################################################################
# Load balancer
################################################################################

resource "aws_lb" "this" {
  #checkov:skip=CKV2_AWS_76:WAF is optional and attached via var.web_acl_arn; rule sets are managed with the Web ACL
  name               = substr(var.name, 0, 32)
  load_balancer_type = "application"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.this.id]

  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "defensive"
  idle_timeout               = var.idle_timeout
  enable_http2               = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = local.access_logs_prefix
    enabled = true
  }

  connection_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = local.connection_logs_prefix
    enabled = true
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.logs]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Services attach listener rules; anything unmatched gets a 404.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_certificate" "additional" {
  for_each = toset(var.additional_certificate_arns)

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.web_acl_arn != null ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.web_acl_arn
}
