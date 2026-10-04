output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix of the load balancer, for CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone ID of the load balancer, for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "Security group ID of the load balancer."
  value       = aws_security_group.this.id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener."
  value       = aws_lb_listener.https.arn
}

output "access_logs_bucket" {
  description = "Name of the access-log bucket."
  value       = aws_s3_bucket.logs.id
}
