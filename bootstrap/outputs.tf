output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.id
}

output "api_ecr_repository_url" {
  description = "Push/pull URL for the Vapor API image."
  value       = aws_ecr_repository.api.repository_url
}

output "gha_role_arns" {
  description = "CI role ARN per environment, for aws-actions/configure-aws-credentials."
  value       = { for env, role in aws_iam_role.gha : env => role.arn }
}