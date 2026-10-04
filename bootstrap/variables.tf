variable "aws_region" {
  description = "Region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used in resource names."
  type        = string
}
