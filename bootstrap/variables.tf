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

variable "monthly_budget_usd" {
  description = "Monthly AWS spend (whole account) that triggers the budget emails."
  type        = number
  default     = 25
}

variable "budget_alert_email_parameter" {
  description = "SSM Parameter Store name holding the budget alert email. Created by hand so the address stays out of this public repo."
  type        = string
  default     = "/steel-ledger/budget-alert-email"
}
