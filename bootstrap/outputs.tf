output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.id
}

output "api_ecr_repository_url" {
  description = "Push/pull URL for the Vapor API image."
  value       = aws_ecr_repository.api.repository_url
}

output "ci_role_arns" {
  description = "CI role ARNs keyed by <env>-<plan|apply>, for aws-actions/configure-aws-credentials."
  value       = { for k, role in aws_iam_role.ci : k => role.arn }
}