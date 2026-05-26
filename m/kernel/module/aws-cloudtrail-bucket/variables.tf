variable "namespace" {
  description = "Tag namespace, typically the org name"
  type        = string
}

variable "mgmt_account_id" {
  description = "Management account that owns the CloudTrail organization trail (used to build trail ARN in policies)"
  type        = string
}

variable "ops_account_id" {
  description = "Ops account allowed to read trail objects and decrypt with the KMS key"
  type        = string
}

variable "trail_name" {
  description = "Name of the organization trail in the management account"
  type        = string
}

variable "region" {
  description = "Region for the CloudTrail bucket and KMS key (use the org's SSO region)"
  type        = string
}

variable "alias_name" {
  description = "KMS alias short name (without the alias/ prefix)"
  type        = string
}

variable "object_lock_mode" {
  description = "S3 Object Lock retention mode"
  type        = string
  default     = "GOVERNANCE"
}

variable "object_lock_days" {
  description = "Default S3 Object Lock retention in days"
  type        = number
  default     = 365
}

variable "transition_deep_archive_days" {
  description = "Days after creation before objects transition directly to DEEP_ARCHIVE. (Skipping GLACIER_IR avoids its 90-day minimum-storage-duration billing penalty and AWS's 90-day minimum gap to DEEP_ARCHIVE.)"
  type        = number
  default     = 30
}

variable "noncurrent_expiration_days" {
  description = "Days after which noncurrent versions expire"
  type        = number
  default     = 30
}
