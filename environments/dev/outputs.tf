output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "api_security_group_id" {
  description = "Attach to the ECS service in TSL-18."
  value       = module.network.api_security_group_id
}

output "db_address" {
  value = module.database.address
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager secret holding the DB admin credentials (managed by RDS)."
  value       = module.database.master_user_secret_arn
}
