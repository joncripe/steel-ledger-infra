terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81" # 5.81+ makes the OIDC provider's thumbprint_list optional
    }
  }

  # This config creates the bucket below, so its state started out local
  # (chicken-and-egg). Now that the bucket exists, the state lives in it
  # too, under its own key, so it isn't a single copy on one laptop.
  #
  # If the bucket ever has to be rebuilt from scratch: comment this block
  # out, run `terraform init -migrate-state` to pull state back to local,
  # recreate the bucket, then restore this block and migrate again.
  # See ADR 0007.
  #
  # Backend blocks can't read variables, so `bucket` must be kept in sync
  # with var.state_bucket_name (variables.tf) by hand.
  backend "s3" {
    bucket       = "steel-ledger-tfstate"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
