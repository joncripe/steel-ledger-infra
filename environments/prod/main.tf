# prod environment for The Steel Ledger (web/API stack).
#
# Starts empty on purpose: it proves the CI pipeline end to end (plan on PR,
# apply on merge, GitHub Environment gate, prod-apply role, state + lock)
# before any real resources exist. RDS, App Runner, etc. get added here by
# later tickets, along with the write permissions they need in
# bootstrap/ci-policies.tf (ADR 0008).
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

  # Key must stay under "prod/": the prod CI roles can only touch that prefix.
  backend "s3" {
    bucket       = "steel-ledger-tfstate"
    key          = "prod/terraform.tfstate"
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
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
