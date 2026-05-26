output "bucket_name" {
  description = "Name of the public S3 bucket"
  value       = aws_s3_bucket.pub.bucket
}

output "bucket_arn" {
  description = "ARN of the public S3 bucket"
  value       = aws_s3_bucket.pub.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.pub.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.pub.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (e.g. d111111abcdef8.cloudfront.net)"
  value       = aws_cloudfront_distribution.pub.domain_name
}

output "oac_id" {
  description = "CloudFront Origin Access Control ID"
  value       = aws_cloudfront_origin_access_control.pub.id
}
