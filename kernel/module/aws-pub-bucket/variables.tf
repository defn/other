variable "namespace" {
  description = "Tag namespace, typically the org name"
  type        = string
}

variable "region" {
  description = "Region for the pub bucket and CloudFront origin (use the org's SSO region)"
  type        = string
}

variable "aliases" {
  description = "CNAME aliases for the CloudFront distribution. Empty list (default) means use the default *.cloudfront.net hostname."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the aliases. Must live in us-east-1. Ignored when aliases is empty."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class: PriceClass_100 (US/CA/EU), PriceClass_200 (+ Asia/ME/Africa), or PriceClass_All (global)."
  type        = string
  default     = "PriceClass_100"
}

variable "default_root_object" {
  description = "Object served when the request URI is /."
  type        = string
  default     = "index.html"
}

variable "log_retention_days" {
  description = "Days after creation before CloudFront access log objects expire from the logs bucket."
  type        = number
  default     = 90
}

variable "enable_404_page" {
  description = "When true, 403/404 responses from the origin are rewritten to error_404_path with response code 404."
  type        = bool
  default     = true
}

variable "error_404_path" {
  description = "Path served (with response code 404) when enable_404_page is true and the origin returns 403 or 404."
  type        = string
  default     = "/404.html"
}

variable "geo_restriction_type" {
  description = "CloudFront geo-restriction type: none, whitelist, or blacklist."
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "Two-letter country codes used by geo_restriction_type. Must be empty when type is none."
  type        = list(string)
  default     = []
}
