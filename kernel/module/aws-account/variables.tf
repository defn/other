variable "state_account_id" {
  description = "AWS account ID for cross-account trust (state account)"
  type        = string
}

variable "namespace" {
  description = "Namespace prefix for resource naming (typically org name)"
  type        = string
}

variable "stage" {
  description = "Stage for resource naming"
  type        = string
  default     = "ops"
}

variable "org_account_id" {
  description = "AWS account ID of the org management account (for SSO assume)"
  type        = string
  default     = ""
}

variable "outbound_federation" {
  description = "Enable IAM outbound web identity federation for this account"
  type        = bool
  default     = false
}

variable "access_analyzer_org_admin" {
  description = "When true, create an organization-level IAM Access Analyzer in this account. Only ops accounts (delegated admins via _ops_delegated_services in catalog/aws.cue) can do this."
  type        = bool
  default     = false
}

# Opt-in regions to disable in this account. Default is empty -- no
# regions are disabled out of the box, because DisableRegion deletes
# any resources in the targeted region. Set this to the full opt-in
# region list once you've confirmed the account has nothing in those
# regions worth keeping. The full list of opt-in regions as of
# 2026-04 is:
#
#   af-south-1       (Cape Town)
#   ap-east-1        (Hong Kong)
#   ap-east-2        (Taipei)
#   ap-south-2       (Hyderabad)
#   ap-southeast-3   (Jakarta)
#   ap-southeast-4   (Melbourne)
#   ap-southeast-5   (Malaysia)
#   ap-southeast-7   (Thailand)
#   ca-west-1        (Calgary)
#   eu-central-2     (Zurich)
#   eu-south-1       (Milan)
#   eu-south-2       (Spain)
#   il-central-1     (Tel Aviv)
#   me-central-1     (UAE)
#   me-south-1       (Bahrain)
#   mx-central-1     (Mexico)
#
# Always-enabled regions (us-east-1, us-east-2, us-west-1, us-west-2,
# eu-west-1, eu-west-2, eu-west-3, eu-central-1, eu-north-1,
# ap-northeast-1/2/3, ap-southeast-1/2, ap-south-1, sa-east-1,
# ca-central-1) cannot be disabled via aws_account_region. To
# restrict access to those, layer an SCP via module/aws-org's
# allowed_regions variable instead.
variable "disabled_regions" {
  description = "Opt-in AWS regions to disable in this account. WARNING: disabling a region deletes any resources in it."
  type        = list(string)
  default     = []
}
