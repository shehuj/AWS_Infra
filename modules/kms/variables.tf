variable "name" {
  description = "Name used for the KMS key alias (alias/<name>)."
  type        = string
}

variable "description" {
  description = "Description of the KMS key."
  type        = string
  default     = "Customer managed key"
}

variable "deletion_window_in_days" {
  description = "Waiting period before the key is deleted after destruction."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "allow_cloudwatch_logs" {
  description = "Allow CloudWatch Logs in this account/region to use the key for log group encryption."
  type        = bool
  default     = true
}

variable "service_principals" {
  description = "AWS service principals (e.g. cloudwatch.amazonaws.com) allowed to use the key for encrypt/decrypt."
  type        = list(string)
  default     = []
}

variable "key_administrator_arns" {
  description = "Additional IAM principal ARNs allowed to administer (but not use) the key."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
