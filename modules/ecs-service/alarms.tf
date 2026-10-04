resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.cluster_name}-${var.name}-cpu-high"
  alarm_description   = "Service CPU is pinned above 85% despite autoscaling."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 8
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.this.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.cluster_name}-${var.name}-memory-high"
  alarm_description   = "Service memory is above 90%; tasks risk OOM kills."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 90
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 8
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.this.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = local.load_balanced ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.name}-unhealthy-targets"
  alarm_description   = "One or more targets are failing load balancer health checks."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    LoadBalancer = var.load_balancer.arn_suffix
    TargetGroup  = aws_lb_target_group.this[0].arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  count = local.load_balanced ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.name}-5xx"
  alarm_description   = "Targets are returning elevated 5XX responses."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    LoadBalancer = var.load_balancer.arn_suffix
    TargetGroup  = aws_lb_target_group.this[0].arn_suffix
  }

  tags = var.tags
}
