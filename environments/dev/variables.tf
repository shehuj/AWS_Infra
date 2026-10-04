################################################################################
# Account and naming
################################################################################

variable "project" {
  description = "Project name, used as a prefix for all resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.project))
    error_message = "project must be 2-15 lowercase letters, numbers or hyphens."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID this environment is allowed to deploy into."
  type        = string
}

variable "owner" {
  description = "Owning team, applied as a tag."
  type        = string
}

variable "cost_center" {
  description = "Cost center, applied as a tag."
  type        = string
}

################################################################################
# Network
################################################################################

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving for non-prod)."
  type        = bool
  default     = false
}

################################################################################
# Load balancer
################################################################################

variable "certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener."
  type        = string
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN for the ALB."
  type        = string
  default     = null
}

################################################################################
# Cluster
################################################################################

variable "default_capacity_provider_strategy" {
  description = "Cluster default capacity provider strategy."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [{ capacity_provider = "FARGATE", weight = 1, base = 1 }]
}

variable "log_retention_days" {
  description = "Default CloudWatch log retention in days."
  type        = number
  default     = 365
}

variable "alarm_email" {
  description = "Optional email subscribed to the alarms SNS topic (requires confirmation)."
  type        = string
  default     = null
}

################################################################################
# Services
################################################################################

variable "services" {
  description = <<-EOT
    ECS services to run, keyed by service name. If `image` is omitted an ECR
    repository is created for the service and `image_tag` is deployed from it.
    Set `priority` (unique per ALB) plus host_headers and/or path_patterns to expose
    a service through the ALB; leave priority null for internal workers.
  EOT
  type = map(object({
    image                    = optional(string)
    image_tag                = optional(string)
    container_port           = optional(number)
    cpu                      = optional(number, 512)
    memory                   = optional(number, 1024)
    cpu_architecture         = optional(string, "ARM64")
    desired_count            = optional(number, 2)
    min_capacity             = optional(number, 2)
    max_capacity             = optional(number, 10)
    requests_per_target      = optional(number)
    command                  = optional(list(string))
    environment              = optional(map(string), {})
    secrets                  = optional(map(string), {})
    secrets_kms_key_arns     = optional(list(string), [])
    user                     = optional(string)
    readonly_root_filesystem = optional(bool, true)
    writable_paths           = optional(list(string), ["/tmp"])
    enable_execute_command   = optional(bool, false)
    task_role_policy_json    = optional(string)
    capacity_provider_strategy = optional(list(object({
      capacity_provider = string
      weight            = number
      base              = optional(number, 0)
    })), [])

    # Load balancer exposure
    priority             = optional(number)
    host_headers         = optional(list(string), [])
    path_patterns        = optional(list(string), [])
    health_check_path    = optional(string, "/health")
    health_check_matcher = optional(string, "200-399")
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.services) : s.image != null || s.image_tag != null])
    error_message = "Each service needs either an explicit image or an image_tag to deploy from its ECR repository."
  }

  validation {
    condition     = alltrue([for s in values(var.services) : s.priority == null || s.container_port != null])
    error_message = "Services exposed through the ALB (priority set) must set container_port."
  }

  validation {
    condition     = length(compact([for s in values(var.services) : s.priority == null ? "" : tostring(s.priority)])) == length(distinct(compact([for s in values(var.services) : s.priority == null ? "" : tostring(s.priority)])))
    error_message = "ALB listener rule priorities must be unique across services."
  }
}
