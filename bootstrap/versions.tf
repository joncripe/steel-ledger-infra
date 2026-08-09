terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Deliberately no backend block -- this config's state stays local.
  # It creates the S3 bucket + DynamoDB table that every OTHER config's
  # remote backend depends on, so it can't depend on them itself.
}