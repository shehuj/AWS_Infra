variable "name" {
  description = "Cluster name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt ECS Exec sessions and cluster log groups."
  type        = string
}

variable "container_insights" {
  description = "Container Insights level: enhanced, enabled or disabled."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights must be one of: enhanced, enabled, disabled."
  }
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy for services that don't set one. Base tasks run on FARGATE; the rest is split by weight."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
  ]

  validation {
    condition     = alltrue([for s in var.default_capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    error_message = "Only FARGATE and FARGATE_SPOT capacity providers are supported."
  }
}

variable "log_retention_days" {
  description = "Retention for the ECS Exec audit log group."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
