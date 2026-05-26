output "bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "kms_key_arn" {
  description = "ARN of the CloudTrail KMS key"
  value       = aws_kms_key.cloudtrail.arn
}

output "kms_alias_arn" {
  description = "ARN of the CloudTrail KMS alias"
  value       = aws_kms_alias.cloudtrail.arn
}
