provider "aws" {
  region = var.aws_region

  # Guard against applying to the wrong account.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
      Repository  = "AWS_Infra"
    }
  }
}
