variable "name" {
  description = "Repository name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for image encryption."
  type        = string
}

variable "max_tagged_images" {
  description = "Number of tagged images to retain."
  type        = number
  default     = 50
}

variable "untagged_expiry_days" {
  description = "Days after which untagged images are expired."
  type        = number
  default     = 7
}

variable "force_delete" {
  description = "Delete the repository even if it contains images (non-prod only)."
  type        = bool
  default     = false
}

variable "pull_principal_arns" {
  description = "Extra IAM principal ARNs (e.g. other accounts) allowed to pull images."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
