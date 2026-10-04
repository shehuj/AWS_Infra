locals {
  name = "${var.project}-${var.environment}"

  is_prod = var.environment == "prod"

  # Services without an explicit image get an ECR repository.
  ecr_services = { for k, s in var.services : k => s if s.image == null }
}

################################################################################
# Encryption
################################################################################

module "kms" {
  source = "../../modules/kms"

  name               = local.name
  description        = "Encrypts logs, ECR images, ECS Exec sessions and alarm notifications for ${local.name}"
  service_principals = ["cloudwatch.amazonaws.com"]
}

################################################################################
# Network
################################################################################

module "network" {
  source = "../../modules/network"

  name                     = local.name
  vpc_cidr                 = var.vpc_cidr
  az_count                 = var.az_count
  single_nat_gateway       = var.single_nat_gateway
  kms_key_arn              = module.kms.key_arn
  flow_logs_retention_days = var.log_retention_days
}

################################################################################
# Load balancer
################################################################################

module "alb" {
  source = "../../modules/alb"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.public_subnet_ids
  certificate_arn            = var.certificate_arn
  ingress_cidr_blocks        = var.alb_ingress_cidr_blocks
  web_acl_arn                = var.web_acl_arn
  enable_deletion_protection = local.is_prod
  force_destroy_logs_bucket  = !local.is_prod
  access_logs_retention_days = var.log_retention_days
}

################################################################################
# Alarm notifications
################################################################################

resource "aws_sns_topic" "alarms" {
  name              = "${local.name}-alarms"
  kms_master_key_id = module.kms.key_arn
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

################################################################################
# ECS cluster
################################################################################

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name                               = local.name
  kms_key_arn                        = module.kms.key_arn
  default_capacity_provider_strategy = var.default_capacity_provider_strategy
  log_retention_days                 = var.log_retention_days
}

################################################################################
# Services
################################################################################

module "ecr" {
  source   = "../../modules/ecr"
  for_each = local.ecr_services

  name         = "${local.name}/${each.key}"
  kms_key_arn  = module.kms.key_arn
  force_delete = !local.is_prod
}

module "service" {
  source   = "../../modules/ecs-service"
  for_each = var.services

  name         = each.key
  cluster_arn  = module.ecs_cluster.cluster_arn
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids
  kms_key_arn  = module.kms.key_arn

  image            = coalesce(each.value.image, try("${module.ecr[each.key].repository_url}:${each.value.image_tag}", null))
  container_port   = each.value.container_port
  cpu              = each.value.cpu
  memory           = each.value.memory
  cpu_architecture = each.value.cpu_architecture
  command          = each.value.command

  environment          = each.value.environment
  secrets              = each.value.secrets
  secrets_kms_key_arns = each.value.secrets_kms_key_arns

  user                     = each.value.user
  readonly_root_filesystem = each.value.readonly_root_filesystem
  writable_paths           = each.value.writable_paths
  task_role_policy_json    = each.value.task_role_policy_json

  desired_count       = each.value.desired_count
  min_capacity        = each.value.min_capacity
  max_capacity        = each.value.max_capacity
  requests_per_target = each.value.requests_per_target
  # ECS copies the cluster default onto services that omit a strategy, so pass it
  # explicitly to keep config and live state in agreement.
  capacity_provider_strategy = length(each.value.capacity_provider_strategy) > 0 ? each.value.capacity_provider_strategy : var.default_capacity_provider_strategy

  enable_execute_command = each.value.enable_execute_command
  exec_log_group_arn     = module.ecs_cluster.exec_log_group_arn

  load_balancer = each.value.priority == null ? null : {
    listener_arn         = module.alb.https_listener_arn
    security_group_id    = module.alb.security_group_id
    arn_suffix           = module.alb.arn_suffix
    priority             = each.value.priority
    host_headers         = each.value.host_headers
    path_patterns        = each.value.path_patterns
    health_check_path    = each.value.health_check_path
    health_check_matcher = each.value.health_check_matcher
  }

  log_retention_days = local.is_prod ? var.log_retention_days : 30
  alarm_actions      = [aws_sns_topic.alarms.arn]
}
