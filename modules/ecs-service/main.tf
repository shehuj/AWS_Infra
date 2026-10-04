locals {
  load_balanced = var.load_balancer != null

  writable_volumes = { for p in var.writable_paths : replace(trim(p, "/"), "/", "-") => p }

  container_definition = { for k, v in {
    name      = var.name
    image     = var.image
    essential = true
    command   = var.command

    portMappings = var.container_port == null ? [] : [{
      name          = "http"
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [for name, value in var.environment : { name = name, value = value }]
    secrets     = [for name, arn in var.secrets : { name = name, valueFrom = arn }]

    readonlyRootFilesystem = var.readonly_root_filesystem
    user                   = var.user
    stopTimeout            = var.stop_timeout

    # Reap zombie processes and enable a clean ECS Exec experience.
    linuxParameters = { initProcessEnabled = true }

    mountPoints = [for vol, path in local.writable_volumes : {
      sourceVolume  = vol
      containerPath = path
      readOnly      = false
    }]

    healthCheck = var.container_health_check == null ? null : {
      command     = var.container_health_check.command
      interval    = var.container_health_check.interval
      timeout     = var.container_health_check.timeout
      retries     = var.container_health_check.retries
      startPeriod = var.container_health_check.start_period
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = local.region
        awslogs-stream-prefix = "ecs"
        # Never block the app on log back-pressure.
        mode            = "non-blocking"
        max-buffer-size = "25m"
      }
    }
  } : k => v if v != null }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.cluster_name}/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

################################################################################
# Task definition
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.cluster_name}-${var.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_gib != null ? [1] : []

    content {
      size_in_gib = var.ephemeral_storage_gib
    }
  }

  dynamic "volume" {
    for_each = local.writable_volumes

    content {
      name = volume.key
    }
  }

  container_definitions = jsonencode([local.container_definition])

  tags = var.tags
}

################################################################################
# Security group
################################################################################

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-svc-"
  description = "ECS service ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-${var.name}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  count = local.load_balanced && var.container_port != null ? 1 : 0

  security_group_id            = aws_security_group.this.id
  description                  = "From load balancer"
  referenced_security_group_id = var.load_balancer.security_group_id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allowed" {
  for_each = var.container_port != null ? toset(var.allowed_security_group_ids) : toset([])

  security_group_id            = aws_security_group.this.id
  description                  = "From ${each.value}"
  referenced_security_group_id = each.value
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound to AWS APIs, dependencies and the internet via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################################################################################
# Load balancer target
################################################################################

resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the ALB; target traffic stays inside private subnets
  count = local.load_balanced ? 1 : 0

  # Name omitted so AWS generates one; allows create_before_destroy on port changes.
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = var.load_balancer.deregistration_delay
  slow_start           = var.load_balancer.slow_start_seconds

  health_check {
    enabled             = true
    path                = var.load_balancer.health_check_path
    matcher             = var.load_balancer.health_check_matcher
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  stickiness {
    type    = "lb_cookie"
    enabled = var.load_balancer.stickiness_enabled
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-${var.name}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "this" {
  count = local.load_balanced ? 1 : 0

  listener_arn = var.load_balancer.listener_arn
  priority     = var.load_balancer.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  dynamic "condition" {
    for_each = length(var.load_balancer.host_headers) > 0 ? [1] : []

    content {
      host_header {
        values = var.load_balancer.host_headers
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.load_balancer.path_patterns) > 0 ? [1] : []

    content {
      path_pattern {
        values = var.load_balancer.path_patterns
      }
    }
  }

  tags = var.tags
}

################################################################################
# Service
################################################################################

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_execute_command  = var.enable_execute_command
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  wait_for_steady_state   = var.wait_for_steady_state

  availability_zone_rebalancing      = "ENABLED"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = local.load_balanced ? var.load_balancer.health_check_grace_s : null

  # Automatically roll back deployments that fail to stabilise.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = local.load_balanced ? [1] : []

    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  tags = var.tags

  lifecycle {
    # Autoscaling owns desired_count after the initial deploy.
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener_rule.this,
    aws_iam_role_policy.execution,
  ]
}
