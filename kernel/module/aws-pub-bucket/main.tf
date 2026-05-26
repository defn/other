terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  bucket_name = "pub-${data.aws_caller_identity.current.account_id}-${var.region}-an"

  tags = {
    Namespace = var.namespace
    Name      = local.bucket_name
    ManagedBy = "Terraform"
  }
}

# =============================================================================
# Pub bucket -- account-regional namespace, fully private, fronted by CloudFront
# =============================================================================

resource "aws_s3_bucket" "pub" {
  bucket           = local.bucket_name
  bucket_namespace = "account-regional"
  force_destroy    = false
  tags             = local.tags
}

resource "aws_s3_bucket_ownership_controls" "pub" {
  bucket = aws_s3_bucket.pub.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "pub" {
  bucket                  = aws_s3_bucket.pub.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "pub" {
  bucket = aws_s3_bucket.pub.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pub" {
  bucket = aws_s3_bucket.pub.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# NOTE: CloudFront access logging dropped from v1.
#
# The original design here created a sibling pub-logs bucket
# (account-regional namespace, BucketOwnerPreferred, log-delivery-write
# ACL) and pointed `logging_config` on the distribution at it. AWS
# CloudFront's legacy log delivery rejected that bucket on most regions
# with "The S3 bucket that you specified for CloudFront logs does not
# enable ACL access" -- the account-regional namespace does not satisfy
# CloudFront's bucket-validation check. Two pub accounts (imma in
# us-east-1, whoa in us-east-1) succeeded; four others
# (spiral/helix/fogg/jianghu in us-east-2 / us-west-2) failed.
#
# Tracked in ~/TODO.md: re-add CloudFront access logging using v2
# (CloudWatch Logs Delivery via aws_cloudwatch_log_delivery_destination
# + aws_cloudwatch_log_delivery), which accepts standard S3 buckets and
# does not require ACL adoption.

# =============================================================================
# CloudFront origin access control (OAC) -- modern replacement for OAI
# =============================================================================

resource "aws_cloudfront_origin_access_control" "pub" {
  name                              = "${local.bucket_name}-oac"
  description                       = "OAC for ${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# =============================================================================
# CloudFront distribution
# =============================================================================

resource "aws_cloudfront_distribution" "pub" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  comment             = "pub-${var.namespace}"
  default_root_object = var.default_root_object
  aliases             = var.aliases

  origin {
    origin_id                = "s3-${local.bucket_name}"
    domain_name              = aws_s3_bucket.pub.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.pub.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-${local.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  dynamic "custom_error_response" {
    for_each = var.enable_404_page ? toset([403, 404]) : toset([])
    content {
      error_code            = custom_error_response.value
      response_code         = 404
      response_page_path    = var.error_404_path
      error_caching_min_ttl = 300
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = length(var.aliases) == 0
    acm_certificate_arn            = length(var.aliases) == 0 ? null : var.acm_certificate_arn
    ssl_support_method             = length(var.aliases) == 0 ? null : "sni-only"
    minimum_protocol_version       = length(var.aliases) == 0 ? "TLSv1" : "TLSv1.2_2021"
  }

  # logging_config dropped -- see comment block above the OAC for the
  # CloudFront ACL incompatibility with account-regional buckets.

  tags = local.tags
}

# =============================================================================
# Pub bucket policy -- CloudFront OAC via aws:SourceArn + DenyInsecureTransport
# =============================================================================

data "aws_iam_policy_document" "pub_bucket" {
  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.pub.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.pub.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.pub.arn,
      "${aws_s3_bucket.pub.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "pub" {
  bucket     = aws_s3_bucket.pub.id
  policy     = data.aws_iam_policy_document.pub_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.pub]
}
