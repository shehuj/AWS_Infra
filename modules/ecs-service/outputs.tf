output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ARN of the ECS service."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN of the current task definition revision."
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  description = "ARN of the task (application) role."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the task role, for attaching further policies."
  value       = aws_iam_role.task.name
}

output "execution_role_arn" {
  description = "ARN of the task execution role."
  value       = aws_iam_role.execution.arn
}

output "security_group_id" {
  description = "Security group ID of the service tasks."
  value       = aws_security_group.this.id
}

output "log_group_name" {
  description = "CloudWatch log group for the application."
  value       = aws_cloudwatch_log_group.this.name
}

output "target_group_arn" {
  description = "ARN of the target group, if load balanced."
  value       = try(aws_lb_target_group.this[0].arn, null)
}

output "task_definition_container_definitions" {
  description = "Rendered container definitions JSON."
  value       = aws_ecs_task_definition.this.container_definitions
}
