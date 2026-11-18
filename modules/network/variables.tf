variable "name" {
  description = "Name prefix for every resource, e.g. \"steel-ledger-dev\"."
  type        = string
}

variable "cidr_block" {
  description = "VPC address range. Each subnet gets a /24 slice of it."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across, one public + one private subnet each, e.g. [\"us-east-1a\", \"us-east-1b\"]. RDS needs at least 2 for its subnet group, even when single-AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "List at least 2 AZs: an RDS subnet group needs subnets in two AZs."
  }

  # Public subnets use /24 slices 0-9 and private ones 10-19, so more than
  # 10 AZs would overlap. No region has that many.
  validation {
    condition     = length(var.availability_zones) <= 10
    error_message = "At most 10 AZs: more would make public and private subnet ranges overlap."
  }
}
