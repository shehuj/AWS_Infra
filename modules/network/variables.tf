variable "name" {
  description = "Name prefix for all network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. A /16 is recommended."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4 for high availability."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, not AZ-fault-tolerant). Set false in production."
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints for ECR, CloudWatch Logs, Secrets Manager, SSM, STS and S3 so tasks reach AWS APIs privately."
  type        = bool
  default     = true
}

variable "interface_endpoint_services" {
  description = "Interface endpoint service short names to create when enable_vpc_endpoints is true."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "ssm", "ssmmessages", "sts", "kms"]
}

variable "flow_logs_retention_days" {
  description = "Retention for VPC flow logs in CloudWatch."
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the flow logs log group."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
