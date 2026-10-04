# Non-sensitive environment configuration. Never put secret values here:
# reference Secrets Manager / SSM ARNs via `secrets` instead.

project        = "acme"
environment    = "prod"
aws_region     = "us-east-1"
aws_account_id = "222222222222"
owner          = "platform-team"
cost_center    = "engineering"

vpc_cidr           = "10.20.0.0/16"
az_count           = 3
single_nat_gateway = false

certificate_arn = "arn:aws:acm:us-east-1:222222222222:certificate/REPLACE_ME"
# web_acl_arn   = "arn:aws:wafv2:us-east-1:222222222222:regional/webacl/REPLACE_ME"

# Prod: on-demand Fargate only.
default_capacity_provider_strategy = [
  { capacity_provider = "FARGATE", weight = 1, base = 2 },
]

log_retention_days = 365
alarm_email        = "platform-oncall@example.com"

services = {
  api = {
    image_tag           = "v1.0.0"
    container_port      = 8080
    cpu                 = 1024
    memory              = 2048
    desired_count       = 3
    min_capacity        = 3
    max_capacity        = 20
    requests_per_target = 1000

    priority          = 100
    path_patterns     = ["/api/*"]
    health_check_path = "/api/health"

    environment = {
      LOG_LEVEL = "info"
    }
  }
}
