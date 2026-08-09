variable "project_name" {
  description = "Project name, used in resource naming/tagging."
  type        = string
  default     = "steel-ledger"
}

variable "environment" {
  description = "Environment tag. This module is dev-tooling only, so this will almost always be \"dev\"."
  type        = string
  default     = "dev"
}

variable "availability_zone" {
  description = "AZ for the Dedicated Host and instance. EC2 Mac Dedicated Hosts are AZ-pinned and NOT available in every AZ."
  type        = string
}

variable "instance_type" {
  description = "Mac instance type. mac2.metal = Apple Silicon (M1)"
  type        = string
  default     = "mac2.metal"
}

variable "vpc_id" {
  description = "VPC to launch into. Leave null to use the account's default VPC."
  type        = string
  default     = null
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to reach port 22. Use your own IP as a /32, e.g. \"203.0.113.4/32\". Never 0.0.0.0/0."
  type        = string

  validation {
    condition     = var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "ssh_allowed_cidr must not be 0.0.0.0/0. Scope this to your own IP."
  }
}

variable "subnet_id" {
  description = "Subnet to launch into. Leave null to auto-select a default subnet in the given availability_zone."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH access."
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB. Xcode + simulator runtimes eat space fast; 150GB+ recommended."
  type        = number
  default     = 150
}

variable "macos_ami_name_filter" {
  description = "Name filter for the EC2 macOS AMI lookup. Defaults to the latest arm64 macOS 14 AMI."
  type        = string
  default     = "amzn-ec2-macos-14*-arm64"
}