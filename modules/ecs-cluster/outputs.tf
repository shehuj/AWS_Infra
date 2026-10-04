output "cluster_id" {
  description = "ID of the cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the cluster."
  value       = aws_ecs_cluster.this.name
}

output "exec_log_group_name" {
  description = "Name of the ECS Exec audit log group."
  value       = aws_cloudwatch_log_group.exec.name
}

output "exec_log_group_arn" {
  description = "ARN of the ECS Exec audit log group."
  value       = aws_cloudwatch_log_group.exec.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used by the cluster."
  value       = var.kms_key_arn
}
