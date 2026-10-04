# Offline tests against a mocked provider: `terraform test` from environments/dev (no AWS credentials needed).

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
  }

  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }

  mock_data "aws_vpc" {
    defaults = { cidr_block = "10.10.0.0/16" }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/mock"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:111111111111:log-group:mock"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:111111111111:key/mock"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:111111111111:mock"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/app/mock/abc"
      arn_suffix = "app/mock/abc"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:111111111111:listener/app/mock/abc/def"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111111111111:targetgroup/mock/abc"
      arn_suffix = "targetgroup/mock/abc"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:111111111111:cluster/acme-dev"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:111111111111:task-definition/mock:1"
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:us-east-1:111111111111:repository/acme-dev/api"
      repository_url = "111111111111.dkr.ecr.us-east-1.amazonaws.com/acme-dev/api"
    }
  }
}

variables {
  project            = "acme"
  environment        = "dev"
  aws_region         = "us-east-1"
  aws_account_id     = "111111111111"
  owner              = "platform"
  cost_center        = "eng"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 3
  single_nat_gateway = false
  certificate_arn    = "arn:aws:acm:us-east-1:111111111111:certificate/test"

  services = {
    api = {
      image_tag      = "v1.0.0"
      container_port = 8080
      priority       = 100
      path_patterns  = ["/api/*"]
      secrets = {
        DB_URL = "arn:aws:secretsmanager:us-east-1:111111111111:secret:dev/db-AbCdEf:url::"
      }
      enable_execute_command = true
    }
    worker = {
      image = "public.ecr.aws/docker/library/busybox:1.36"
    }
  }
}

run "network_layout" {
  command = apply

  assert {
    condition     = length(module.network.private_subnet_ids) == 3
    error_message = "Expected one private subnet per AZ."
  }

  assert {
    condition     = length(module.network.nat_public_ips) == 3
    error_message = "Expected one NAT gateway per AZ when single_nat_gateway is false."
  }
}

run "single_nat_for_cost_saving" {
  command = apply

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(module.network.nat_public_ips) == 1
    error_message = "Expected a single NAT gateway."
  }
}

run "services_wiring" {
  command = apply

  assert {
    condition     = length(module.ecr) == 1 && contains(keys(module.ecr), "api")
    error_message = "Only services without an explicit image should get an ECR repository."
  }

  assert {
    condition     = jsondecode(module.service["api"].task_definition_container_definitions)[0].image == "111111111111.dkr.ecr.us-east-1.amazonaws.com/acme-dev/api:v1.0.0"
    error_message = "api should deploy image_tag from its ECR repository."
  }

  assert {
    condition     = jsondecode(module.service["api"].task_definition_container_definitions)[0].readonlyRootFilesystem == true
    error_message = "Containers must default to a read-only root filesystem."
  }

  assert {
    condition     = jsondecode(module.service["worker"].task_definition_container_definitions)[0].portMappings == []
    error_message = "worker should expose no ports."
  }
}

run "rejects_duplicate_priorities" {
  command = plan

  variables {
    services = {
      a = { image = "x:1", container_port = 80, priority = 10, path_patterns = ["/a"] }
      b = { image = "x:1", container_port = 80, priority = 10, path_patterns = ["/b"] }
    }
  }

  expect_failures = [var.services]
}

run "rejects_service_without_image" {
  command = plan

  variables {
    services = {
      a = { container_port = 80 }
    }
  }

  expect_failures = [var.services]
}
