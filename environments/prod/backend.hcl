# Values come from `terraform output` in bootstrap/. Use a separate account
# (and therefore a separate state bucket) for production.
bucket       = "REPLACE_ME-tfstate-222222222222-us-east-1"
key          = "prod/ecs/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
kms_key_id   = "arn:aws:kms:us-east-1:222222222222:key/REPLACE_ME"
use_lockfile = true
