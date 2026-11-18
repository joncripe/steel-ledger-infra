variable "name" {
  description = "DB instance identifier and name prefix, e.g. \"steel-ledger-dev\". The CI log-group permission (bootstrap/ci-policies.tf) expects steel-ledger-<env>."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database lives in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group (at least two AZs)."
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Security groups whose members may connect on the Postgres port, keyed by a fixed label (e.g. { api = sg-... }). Nothing else can. A map, not a list: the IDs aren't known until apply, but the keys must be known at plan."
  type        = map(string)
}

variable "engine_version" {
  description = "Postgres major version. RDS picks the latest minor and upgrades it automatically."
  type        = string
  default     = "18"
}

variable "instance_class" {
  description = "Instance size. db.t4g.micro is the smallest (2 burstable vCPUs, 1 GB RAM)."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  description = "Disk size in GB (gp3). 20 is the minimum."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the database created inside the instance."
  type        = string
  default     = "steelledger"
}

variable "master_username" {
  description = "Admin username. The password is generated and stored by RDS in Secrets Manager, never by Terraform."
  type        = string
  default     = "steelledger_admin"
}

variable "multi_az" {
  description = "Keep a standby copy in a second AZ that takes over on failure. Doubles the instance cost."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days of automatic backups to keep (the point-in-time restore window)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Block deleting the instance until this is turned off. Keep true outside dev."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Delete without taking a last backup. Only for throwaway data (dev)."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes now instead of in the next maintenance window. Some changes restart the DB."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Days to keep Postgres logs in CloudWatch."
  type        = number
  default     = 7
}
