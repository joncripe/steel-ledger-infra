variable "aws_region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state. Must match the backend bucket in versions.tf."
  type        = string
  default     = "steel-ledger-tfstate"
}