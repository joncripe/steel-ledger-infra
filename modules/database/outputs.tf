output "address" {
  description = "Hostname the API connects to (resolves only inside the VPC)."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Postgres port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name inside the instance."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret with the admin username and password. The ARN isn't secret; the value is."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "The database's security group."
  value       = aws_security_group.db.id
}
