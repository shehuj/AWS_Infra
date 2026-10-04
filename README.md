# AWS_Infra

Production-grade Amazon ECS on Fargate, built from Terraform modules you can compose.

## Architecture

```
                        Internet
                           │  443 (80 → 301 redirect)
                ┌──────────▼──────────┐   WAFv2 (optional)
                │  ALB  (public subnets, TLS 1.3, access + connection logs → S3)
                └──────────┬──────────┘
                           │ listener rules (host / path)
   ┌───────────────────────▼────────────────────────────┐
   │ ECS cluster (Fargate / Fargate Spot, Container Insights enhanced)
   │   service A ── tasks in private subnets, 1 SG per service
   │   service B ── autoscaling: CPU / memory / requests per target
   └───────────────────────┬────────────────────────────┘
                           │
      VPC endpoints (ECR, Logs, Secrets Manager, SSM, STS, KMS, S3)
      NAT gateway per AZ (prod) for everything else
```

All logs, ECR images, ECS Exec sessions and SNS alarm notifications are encrypted
with a customer managed KMS key per environment that rotates automatically.

## Layout

| Path | Purpose |
|---|---|
| `bootstrap/` | One-time-per-account stack: KMS-encrypted, versioned S3 state bucket (native S3 locking, so no DynamoDB) |
| `modules/kms` | CMK with rotation and scoped grants for CloudWatch Logs and service principals |
| `modules/network` | VPC over 2–4 AZs, public and private subnets, a NAT gateway per AZ or one shared, flow logs, VPC endpoints, locked-down default SG |
| `modules/alb` | Internet-facing or internal ALB, HTTPS-only, hardened settings, access-log bucket, WAF association |
| `modules/ecr` | Repository with immutable tags, scan on push, KMS encryption and lifecycle policy |
| `modules/ecs-cluster` | Cluster, capacity providers, Container Insights, audited and encrypted ECS Exec |
| `modules/ecs-service` | Task definition, least-privilege IAM, security group, target group and listener rule, autoscaling, circuit breaker, alarms |
| `environments/<env>` | Thin root modules that wire the modules together. Config is in `terraform.tfvars` and remote state settings in `backend.hcl` |

## Security and reliability defaults

- **Network**: tasks run in private subnets with no public IPs. Only the ALB security group can reach a service port. The default SG has no rules (CIS 5.4). VPC flow logs are on.
- **IAM**: separate execution and task roles. Trust policies are pinned to the account with `aws:SourceAccount` and `aws:SourceArn` to stop confused-deputy access. Secrets access is limited to the exact ARNs referenced, and there are no wildcard admin policies.
- **Containers**: read-only root filesystem with explicit writable paths, `initProcessEnabled`, non-blocking logging, Graviton (ARM64) by default.
- **Secrets**: injected from Secrets Manager or SSM by ARN. Secret values never pass through Terraform or tfvars.
- **Deployments**: rolling at 100/200%, a circuit breaker with automatic rollback, AZ rebalancing, and `desired_count` handed to autoscaling.
- **TLS**: `ELBSecurityPolicy-TLS13-1-2-Res-2021-06`, HTTP→HTTPS redirect, invalid headers dropped, desync mitigation set to defensive.
- **Guardrails**: `allowed_account_ids` on the provider, mandatory default tags (Project, Environment, Owner, CostCenter), deletion protection and no force-destroy in prod.
- **Observability**: Container Insights (enhanced), and per-service alarms for CPU, memory, unhealthy targets and 5XX, all sent to a KMS-encrypted SNS topic.

## Getting started

Prerequisites: Terraform >= 1.10, AWS credentials for the target account, and an ACM certificate in the region.

```bash
# 1. Create the state bucket (once per account)
cd bootstrap
terraform init
terraform apply -var project=acme
terraform output          # copy state_bucket and state_kms_key_arn

# 2. Configure the environment
cd ../environments/dev
$EDITOR backend.hcl       # bucket + kms_key_id from step 1
$EDITOR terraform.tfvars  # account id, certificate ARN, services

# 3. Deploy
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

For a service without an explicit `image`, an ECR repository is created. Push your
image to it (`ecr_repository_urls` output) with the tag set in `image_tag`. Tags are
immutable, so every release gets a new tag.

## Adding a service

Add an entry to `services` in the environment's `terraform.tfvars`:

```hcl
services = {
  web = {
    image_tag         = "2026.10.03-abc123"
    container_port    = 3000
    cpu               = 512
    memory            = 1024
    priority          = 200               # unique per ALB
    host_headers      = ["app.example.com"]
    health_check_path = "/healthz"
    secrets = {
      DATABASE_URL = "arn:aws:secretsmanager:us-east-1:111111111111:secret:prod/web/db-AbCdEf"
    }
  }

  # Background worker: no priority means no ALB exposure
  queue-worker = {
    image_tag = "v3.2.1"
    task_role_policy_json = <<-JSON
      {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sqs:ReceiveMessage","sqs:DeleteMessage"],"Resource":"arn:aws:sqs:us-east-1:111111111111:jobs"}]}
    JSON
  }
}
```

See `environments/dev/variables.tf` for every option.

## Environments

`dev` and `prod` use identical `.tf` files and differ only in `terraform.tfvars`:

| | dev | prod |
|---|---|---|
| AZs / NAT | 2 / single NAT | 3 / NAT per AZ |
| Capacity | 1 on-demand base task, the rest Fargate Spot (1:4) | On-demand Fargate, base 2 |
| Deletion protection | off, buckets and repos force-destroyable | on |
| App log retention | 30 days | 365 days |

Put production in its own AWS account. `allowed_account_ids` stops a mis-pointed apply.
To add `staging`, copy `environments/prod`, then change `terraform.tfvars` and `backend.hcl`.

## Quality checks

All of these run in CI (`.github/workflows/terraform.yml`) and locally:

```bash
terraform fmt -recursive -check
terraform -chdir=environments/dev test        # mocked provider, no AWS credentials needed
tflint --init && tflint --chdir=modules/ecs-service --config=$PWD/.tflint.hcl
checkov -d . --framework terraform            # suppressions are inline with a reason
pre-commit install                            # optional git hooks
```

The workflow includes a commented-out `plan` job that uses GitHub OIDC (no long-lived keys).
To enable it, create a plan role per account.

## Versioning modules

Environments reference modules by relative path. When other repos start consuming
these modules, tag releases (`modules/ecs-service/v1.2.0`) and pin with
`source = "git::https://github.com/<org>/AWS_Infra.git//modules/ecs-service?ref=modules/ecs-service/v1.2.0"`.
