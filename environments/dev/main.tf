terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "steel-ledger-tfstate"
    key            = "dev/ec2-mac-dev.tfstate"
    region         = "us-east-1"
    dynamodb_table = "steel-ledger-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "ec2_mac_dev" {
  source = "../../modules/ec2-mac-dev"

  project_name      = "steel-ledger"
  environment       = "dev"
  availability_zone = var.availability_zone
  ssh_allowed_cidr  = var.ssh_allowed_cidr
  key_name          = var.key_name
}