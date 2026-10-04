################################################################################
# Placement
################################################################################

variable "name" {
  description = "Service name. Also used as the container name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,32}$", var.name))
    error_message = "name must be 1-32 characters of letters, numbers, hyphens or underscores."
  }
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster (used for autoscaling and alarms)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs to run tasks in."
  type        = list(string)
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy. Pass the cluster default explicitly rather than leaving it empty: ECS copies the default onto the service, which otherwise shows as drift."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = []
}

################################################################################
# Container
################################################################################

variable "image" {
  description = "Container image URI. Pin by immutable tag or digest."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Null for workers with no inbound traffic."
  type        = number
  default     = null
}

variable "cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096, 8192, 16384)."
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task memory in MiB. Must be a valid Fargate combination with cpu."
  type        = number
  default     = 1024
}

variable "cpu_architecture" {
  description = "CPU architecture: ARM64 (Graviton, cheaper) or X86_64."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be ARM64 or X86_64."
  }
}

variable "command" {
  description = "Override the container command."
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "Plain-text environment variables. Never put secrets here."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets injected as environment variables: map of VAR_NAME to Secrets Manager or SSM Parameter Store ARN."
  type        = map(string)
  default     = {}
}

variable "secrets_kms_key_arns" {
  description = "KMS key ARNs that encrypt the referenced secrets (when using customer managed keys)."
  type        = list(string)
  default     = []
}

variable "readonly_root_filesystem" {
  description = "Mount the container root filesystem read-only."
  type        = bool
  default     = true
}

variable "writable_paths" {
  description = "Paths mounted as writable ephemeral volumes (e.g. /tmp) when the root filesystem is read-only."
  type        = list(string)
  default     = ["/tmp"]

  validation {
    condition     = alltrue([for p in var.writable_paths : startswith(p, "/") && p != "/"])
    error_message = "writable_paths must be absolute paths other than /."
  }
}

variable "user" {
  description = "User (UID[:GID]) to run the container as. Prefer a non-root user."
  type        = string
  default     = null
}

variable "container_health_check" {
  description = "Optional container-level health check."
  type = object({
    command      = list(string)
    interval     = optional(number, 30)
    timeout      = optional(number, 5)
    retries      = optional(number, 3)
    start_period = optional(number, 60)
  })
  default = null
}

variable "stop_timeout" {
  description = "Seconds to wait for graceful shutdown before SIGKILL (max 120 on Fargate)."
  type        = number
  default     = 30
}

variable "ephemeral_storage_gib" {
  description = "Ephemeral storage size in GiB (21-200). Null uses the 20 GiB default."
  type        = number
  default     = null
}

variable "log_retention_days" {
  description = "Retention for the application log group."
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the application log group and ECS Exec sessions."
  type        = string
}

################################################################################
# IAM
################################################################################

variable "task_role_policy_json" {
  description = "Optional inline IAM policy (JSON) granting the application its AWS permissions."
  type        = string
  default     = null
}

variable "task_role_managed_policy_arns" {
  description = "Managed policy ARNs to attach to the task role."
  type        = list(string)
  default     = []
}

################################################################################
# Networking and load balancing
################################################################################

variable "allowed_security_group_ids" {
  description = "Extra security groups allowed to reach container_port (e.g. other services)."
  type        = list(string)
  default     = []
}

variable "load_balancer" {
  description = "Attach the service to an existing ALB HTTPS listener. Null for internal workers."
  type = object({
    listener_arn         = string
    security_group_id    = string
    arn_suffix           = string
    priority             = number
    host_headers         = optional(list(string), [])
    path_patterns        = optional(list(string), [])
    health_check_path    = optional(string, "/health")
    health_check_matcher = optional(string, "200-399")
    deregistration_delay = optional(number, 30)
    health_check_grace_s = optional(number, 60)
    slow_start_seconds   = optional(number, 0)
    stickiness_enabled   = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.load_balancer == null || length(try(var.load_balancer.host_headers, [])) + length(try(var.load_balancer.path_patterns, [])) > 0
    error_message = "load_balancer requires at least one host_headers or path_patterns entry."
  }
}

################################################################################
# Deployment and scaling
################################################################################

variable "desired_count" {
  description = "Initial number of tasks. Autoscaling manages it after creation."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling."
  type        = number
  default     = 10
}

variable "cpu_target_percent" {
  description = "Target average CPU utilisation for autoscaling."
  type        = number
  default     = 60
}

variable "memory_target_percent" {
  description = "Target average memory utilisation for autoscaling."
  type        = number
  default     = 75
}

variable "requests_per_target" {
  description = "Optional ALB requests-per-target scaling target. Null disables it."
  type        = number
  default     = null
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for break-glass debugging (audited to the cluster exec log group)."
  type        = bool
  default     = false
}

variable "exec_log_group_arn" {
  description = "ARN of the cluster ECS Exec log group (required when enable_execute_command is true)."
  type        = string
  default     = null
}

variable "wait_for_steady_state" {
  description = "Wait for the deployment to reach steady state during apply."
  type        = bool
  default     = false
}

################################################################################
# Observability
################################################################################

variable "alarm_actions" {
  description = "SNS topic ARNs notified when alarms fire or recover."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
