output "oidc_issuer_url" {
  description = "S3 HTTPS URL used as k3s --service-account-issuer"
  value       = local.issuer_url
}

output "oidc_provider_arn" {
  description = "IAM OIDC Identity Provider ARN"
  value       = aws_iam_openid_connect_provider.k3d.arn
}

output "bucket_name" {
  description = "S3 bucket name for OIDC discovery docs"
  value       = local.bucket
}

output "run_id" {
  description = "Generated timestamp identifying this run"
  value       = local.run_id
}

output "ack_iam_role_arn" {
  description = "IAM role ARN for ACK IAM controller (created in tofu, chicken-egg)"
  value       = aws_iam_role.ack_iam.arn
}
