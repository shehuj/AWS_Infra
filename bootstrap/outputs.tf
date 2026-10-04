output "state_bucket" {
  description = "Name of the Terraform state bucket. Put this in each environment's backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "KMS key ARN encrypting the state bucket. Put this in each environment's backend.hcl."
  value       = module.kms.key_arn
}
