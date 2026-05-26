variable "accounts" {
  description = "Map of account names to their configuration"
  type = map(object({
    email                      = string
    iam_user_access_to_billing = optional(string)
    role_name                  = optional(string)
    delegated_services         = optional(list(string), [])
    parent_ou                  = optional(string)
  }))
}

variable "cloudtrail_enabled" {
  description = "Whether to create the org CloudTrail. False until the bucket stack has been applied in the host account."
  type        = bool
  default     = false
}

variable "cloudtrail_trail_name" {
  description = "Name of the org CloudTrail (e.g. <org>-org-trail)"
  type        = string
  default     = ""
}

variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket the org trail writes to (in the log host account)"
  type        = string
  default     = ""
}

variable "cloudtrail_kms_alias_arn" {
  description = "ARN of the KMS alias used to encrypt CloudTrail objects (in the log host account)"
  type        = string
  default     = ""
}

variable "allowed_regions" {
  description = "Regions in which member accounts may use AWS APIs. Enforced via the RegionAllowlist SCP attached at the org root. Global-service APIs (IAM, Organizations, Route 53, CloudFront, etc.) are exempt regardless of region. Source of truth lives in catalog/aws.cue's aws_allowed_regions; the generator stamps the literal list into each org's main.tf."
  type        = list(string)
}
