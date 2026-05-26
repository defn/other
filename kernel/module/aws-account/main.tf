# State migration: count → non-count after module refactor.
moved {
  from = aws_iam_role.terraform[0]
  to   = aws_iam_role.terraform
}

moved {
  from = aws_iam_policy.terraform[0]
  to   = aws_iam_policy.terraform
}

moved {
  from = aws_iam_role_policy_attachment.terraform[0]
  to   = aws_iam_role_policy_attachment.terraform
}

locals {
  terraform_role_name = "${var.namespace}-${var.stage}-terraform"
  tags = {
    Namespace = var.namespace
    Stage     = var.stage
  }

  # Terraform assume role: state account + optional org management account
  terraform_principals = distinct(compact(concat(
    ["arn:aws:iam::${var.state_account_id}:root"],
    var.org_account_id != "" ? ["arn:aws:iam::${var.org_account_id}:root"] : [],
  )))
}

# =============================================================================
# Terraform role -- full access for IaC
# =============================================================================

data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:TagSession", "sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.terraform_principals
    }
  }
}

data "aws_iam_policy_document" "full_access" {
  statement {
    sid       = "FullAccess"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "terraform" {
  name                  = local.terraform_role_name
  description           = "Account Terraform Role"
  assume_role_policy    = data.aws_iam_policy_document.terraform_assume_role.json
  force_detach_policies = false
  max_session_duration  = 3600

  tags = merge(local.tags, {
    Name = local.terraform_role_name
  })
}

resource "aws_iam_policy" "terraform" {
  name        = local.terraform_role_name
  description = "Allow Full Access"
  policy      = data.aws_iam_policy_document.full_access.json

  tags = merge(local.tags, {
    Name = local.terraform_role_name
  })
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

# =============================================================================
# Region opt-out -- optional
# =============================================================================
# Disables specific opt-in regions in this account. Default
# disabled_regions is empty (nothing happens). Setting it to a
# non-empty list will DELETE any resources in those regions when
# DisableRegion runs -- treat as destructive.
resource "aws_account_region" "disabled" {
  for_each = toset(var.disabled_regions)

  region_name = each.value
  enabled     = false
}

# =============================================================================
# Outbound web identity federation -- optional
# =============================================================================

resource "aws_iam_outbound_web_identity_federation" "this" {
  count = var.outbound_federation ? 1 : 0
}

# =============================================================================
# IAM password policy -- defense-in-depth for the SSO-only account
# =============================================================================
# We use AWS Identity Center exclusively, so no human IAM users exist.
# This policy fires only if someone ever creates an IAM user (which
# DenyIAMUserCreation also forbids). The 30-character minimum and
# 30-day rotation match the user's preference and are well above
# AWS defaults.
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 30
  max_password_age               = 30
  password_reuse_prevention      = 24
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  hard_expiry                    = false
}

# =============================================================================
# Account-level S3 Block Public Access -- always on
# =============================================================================
# Belt-and-braces with the bucket-level public access block. Even if a
# future bucket policy or ACL would otherwise grant public access, the
# account-level block overrides it. The DenyS3PublicAccess SCP locks
# this in place by denying any attempt to disable the four flags.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# IAM Access Analyzer -- organization-level analyzer in delegated admin
# =============================================================================
# When access_analyzer_org_admin = true, this would create an
# ORGANIZATION-type IAM Access Analyzer in the delegated admin
# account. BLOCKED today: AWS requires the
# AWSServiceRoleForAccessAnalyzer service-linked role to exist in the
# organizational management account before a delegated admin can
# create the analyzer ("Access Analyzer Service Linked Role is not in
# the organizational management account" -- ConflictException). The
# fix is to add an aws_iam_service_linked_role resource in
# module/aws-org (which runs in the management account) and re-enable
# this. Tracked in ~/TODO.md.
#
# count = 0 hardcoded for now so per-account terraform stays clean.
# The variable plumbing below + tag in interface/aws/templates.cue is
# preserved so re-enabling is a one-line change once the SLR lands.
resource "aws_accessanalyzer_analyzer" "org" {
  # Temporarily disabled: the && false short-circuits the variable so
  # the resource has count = 0 while keeping the var.access_analyzer_org_admin
  # reference live (avoids the unused-variable warning).
  count = var.access_analyzer_org_admin && false ? 1 : 0

  analyzer_name = "${var.namespace}-org-analyzer"
  type          = "ORGANIZATION"

  tags = local.tags
}
