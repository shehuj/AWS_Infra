# Non-sensitive environment configuration. Never put secret values here:
# reference Secrets Manager / SSM ARNs via `secrets` instead.

project        = "acme"
environment    = "dev"
aws_region     = "us-east-1"
aws_account_id = "694992586025"
owner          = "platform-team"
cost_center    = "engineering"

vpc_cidr           = "10.10.0.0/16"
az_count           = 2
single_nat_gateway = true

certificate_arn = "arn:aws:acm:us-east-1:694992586025:certificate/658f6e98-b168-42b3-8070-673965fc20e7"

# Dev favours cost: one on-demand task for a baseline, the rest on Spot.
default_capacity_provider_strategy = [
  { capacity_provider = "FARGATE", weight = 1, base = 1 },
  { capacity_provider = "FARGATE_SPOT", weight = 4 },
]

log_retention_days = 90

services = {
  api = {
    image_tag      = "v1.0.0"
    container_port = 8080
    cpu            = 256
    memory         = 512
    desired_count  = 1
    min_capacity   = 1
    max_capacity   = 3

    priority          = 100
    path_patterns     = ["/api/*"]
    health_check_path = "/api/health"

    enable_execute_command = true

    environment = {
      LOG_LEVEL = "debug"
    }

    # secrets = {
    #   DATABASE_URL = "arn:aws:secretsmanager:us-east-1:111111111111:secret:dev/api/db-AbCdEf"
    # }
  }
}
