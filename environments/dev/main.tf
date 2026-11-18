# dev environment for The Steel Ledger (web/API stack).
#
# Auto-applied on every merge to main (ADR 0009). Each new resource type
# needs its write permissions in bootstrap/ci-policies.tf first (ADR 0008).
#
#   network  - VPC, public/private subnets, the API's security group (TSL-8)
#   database - Postgres in the private subnets (TSL-8)
#
# dev settings lean cheap and disposable: smallest instance, one day of
# backups, and no deletion protection (ADR 0010).
#
# The EC2 Mac lives separately in environments/dev-mac.

terraform {
  required_version = ">= 1.10.0" # use_lockfile needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Key must stay under "dev/": the dev CI roles can only touch that prefix.
  backend "s3" {
    bucket       = "steel-ledger-tfstate"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "steel-ledger"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "network" {
  source = "../../modules/network"

  name               = "steel-ledger-dev"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "database" {
  source = "../../modules/database"

  name                    = "steel-ledger-dev" # must match the CI log-group permission
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  allowed_security_groups = { api = module.network.api_security_group_id }

  # Throwaway dev data: cheap and easy to tear down.
  backup_retention_days = 1
  deletion_protection   = false
  skip_final_snapshot   = true
  apply_immediately     = true
}
