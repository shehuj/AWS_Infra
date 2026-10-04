output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "nat_public_ips" {
  description = "NAT gateway egress IPs."
  value       = module.network.nat_public_ips
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_cluster.cluster_name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = module.ecs_cluster.cluster_arn
}

output "alb_dns_name" {
  description = "ALB DNS name. Point a Route 53 alias record at it."
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID, for Route 53 alias records."
  value       = module.alb.zone_id
}

output "ecr_repository_urls" {
  description = "ECR repository URL per service."
  value       = { for k, m in module.ecr : k => m.repository_url }
}

output "services" {
  description = "Service details for CI/CD pipelines."
  value = { for k, m in module.service : k => {
    service_name       = m.service_name
    task_role_arn      = m.task_role_arn
    execution_role_arn = m.execution_role_arn
    security_group_id  = m.security_group_id
    log_group_name     = m.log_group_name
  } }
}

output "alarms_topic_arn" {
  description = "SNS topic receiving CloudWatch alarms."
  value       = aws_sns_topic.alarms.arn
}
