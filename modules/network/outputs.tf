output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per AZ (load balancer and API tasks)."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per AZ (database)."
  value       = [for s in aws_subnet.private : s.id]
}

output "api_security_group_id" {
  description = "Security group the API service attaches to (TSL-18)."
  value       = aws_security_group.api.id
}
