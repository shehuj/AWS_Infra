variable "name" {
  description = "Name prefix for the load balancer and related resources (max 32 chars for the ALB name)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for an internet-facing ALB, or private subnet IDs for an internal one."
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener."
  type        = string
}

variable "additional_certificate_arns" {
  description = "Extra ACM certificate ARNs to attach to the HTTPS listener (served by SNI)."
  type        = list(string)
  default     = []
}

variable "ssl_policy" {
  description = "TLS policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
}

variable "ingress_cidr_blocks" {
  description = "IPv4 CIDR blocks allowed to reach the ALB on 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Protect the ALB from accidental deletion."
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Connection idle timeout in seconds."
  type        = number
  default     = 60
}

variable "web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN to associate with the ALB."
  type        = string
  default     = null
}

variable "access_logs_retention_days" {
  description = "Days to keep ALB access logs in S3."
  type        = number
  default     = 365
}

variable "force_destroy_logs_bucket" {
  description = "Allow the access-log bucket to be destroyed while it still holds objects (non-prod only)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
