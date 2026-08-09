variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "AZ for the Dedicated Host + Mac instance. Must support mac2.metal -- verify capacity before applying."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Your IP as a /32, e.g. \"203.0.113.4/32\". Find it with `curl -s ifconfig.me`."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access."
  type        = string
}