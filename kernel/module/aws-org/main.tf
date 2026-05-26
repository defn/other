data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "sso_instance" {}

locals {
  sso_instance_arn  = data.aws_ssoadmin_instances.sso_instance.arns
  sso_instance_isid = data.aws_ssoadmin_instances.sso_instance.identity_store_ids
}

resource "aws_organizations_organization" "organization" {
  aws_service_access_principals = [
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "ec2.amazonaws.com",
    "iam.amazonaws.com",
    "ram.amazonaws.com",
    "resource-explorer-2.amazonaws.com",
    "ssm.amazonaws.com",
    "sso.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
  ]
  # When each policy type is enabled, AWS Organizations auto-creates
  # and attaches an AWS-managed default policy at the root:
  #   SERVICE_CONTROL_POLICY   -> FullAWSAccess       (Allow *:*:*)
  #   RESOURCE_CONTROL_POLICY  -> RCPFullAWSAccess    (Allow *:*:*:* for Principal *)
  #   AISERVICES_OPT_OUT_POLICY -> FullAWSOptOutPolicy (optOut=false)
  # These defaults are AWS-managed, cannot be modified or deleted,
  # and cannot be imported as aws_organizations_policy resources.
  # Customer-managed policies are layered on top -- see the
  # aws_organizations_policy resources below.
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
    "AISERVICES_OPT_OUT_POLICY",
    "RESOURCE_CONTROL_POLICY",
    "DECLARATIVE_POLICY_EC2",
    "BEDROCK_POLICY",
  ]
  feature_set = "ALL"
}

# Opt out of all AWS AI services using customer content for model
# training. Applied at the org root so every account (current and
# future) inherits the policy. @@operators_allowed_for_child_policies
# = @@none prevents child policies from overriding the opt-out.
resource "aws_organizations_policy" "ai_opt_out" {
  name        = "OptOutFromAllAIServices"
  description = "Opt outs from all AI services."
  type        = "AISERVICES_OPT_OUT_POLICY"

  content = jsonencode({
    services = {
      "@@operators_allowed_for_child_policies" = ["@@none"]
      default = {
        "@@operators_allowed_for_child_policies" = ["@@none"]
        opt_out_policy = {
          "@@operators_allowed_for_child_policies" = ["@@none"]
          "@@assign"                               = "optOut"
        }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "ai_opt_out_root" {
  policy_id = aws_organizations_policy.ai_opt_out.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

resource "aws_iam_organizations_features" "organization" {
  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions"
  ]
}

locals {
  ou_top = toset([
    "Ops",
    "Shared",
    "Platform",
    "Workloads",
    "Edge",
    "Sandbox",
    "Exceptions",
    "Suspended",
  ])

  ou_nested = {
    "Shared/Network"       = "Shared"
    "Shared/Artifacts"     = "Shared"
    "Shared/Observability" = "Shared"
    "Workloads/NonProd"    = "Workloads"
    "Workloads/Prod"       = "Workloads"
  }

  ou_ids = merge(
    { for k, v in aws_organizations_organizational_unit.ou_top : k => v.id },
    { for k, v in aws_organizations_organizational_unit.ou_nested : k => v.id },
  )
}

resource "aws_organizations_organizational_unit" "ou_top" {
  for_each = local.ou_top

  name      = each.key
  parent_id = aws_organizations_organization.organization.roots[0].id

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_organizations_organizational_unit" "ou_nested" {
  for_each = local.ou_nested

  name      = reverse(split("/", each.key))[0]
  parent_id = aws_organizations_organizational_unit.ou_top[each.value].id

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_ssoadmin_permission_set" "admin_sso_permission_set" {
  instance_arn     = element(local.sso_instance_arn, 0)
  name             = "Administrator"
  session_duration = "PT2H"
  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "admin_sso_managed_policy_attachment" {
  instance_arn       = aws_ssoadmin_permission_set.admin_sso_permission_set.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin_sso_permission_set.arn
}

resource "aws_identitystore_group" "administrators_sso_group" {
  display_name      = "Administrators"
  identity_store_id = element(local.sso_instance_isid, 0)
}

resource "aws_organizations_account" "account" {
  for_each = var.accounts

  email                      = each.value.email
  name                       = each.key
  iam_user_access_to_billing = each.value.iam_user_access_to_billing
  role_name                  = each.value.role_name
  parent_id = (
    each.value.parent_ou == null
    ? null
    : local.ou_ids[each.value.parent_ou]
  )

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_ssoadmin_account_assignment" "admin_sso_account_assignment" {
  for_each = var.accounts

  instance_arn       = aws_ssoadmin_managed_policy_attachment.admin_sso_managed_policy_attachment.instance_arn
  permission_set_arn = aws_ssoadmin_managed_policy_attachment.admin_sso_managed_policy_attachment.permission_set_arn
  principal_id       = aws_identitystore_group.administrators_sso_group.group_id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.account[each.key].id
  target_type        = "AWS_ACCOUNT"
}

locals {
  delegated_pairs = merge([
    for k, v in var.accounts : {
      for svc in v.delegated_services : "${k}/${svc}" => {
        account_key = k
        service     = svc
      }
    }
  ]...)
}

resource "aws_organizations_delegated_administrator" "delegated" {
  for_each = local.delegated_pairs

  account_id        = aws_organizations_account.account[each.value.account_key].id
  service_principal = each.value.service
}

# Delegate AWS Organizations read + tag management to the ops
# account. This is separate from register-delegated-administrator
# (which covers specific services like sso.amazonaws.com and
# iam.amazonaws.com): it is a resource-based policy on the
# organization itself that grants the ops account the Organizations
# APIs it needs to describe the org tree, list accounts, and read
# policies without assuming back into the management account.
#
# The "ops" account is identified as the delegated-admin account in
# var.accounts -- i.e., the one with a non-empty delegated_services
# list. Orgs with zero or multiple delegated-admin accounts get no
# resource policy (the for_each below produces an empty set).
locals {
  delegated_admin_account_keys = [
    for k, v in var.accounts : k if length(v.delegated_services) > 0
  ]
  delegated_admin_account_id = (
    length(local.delegated_admin_account_keys) == 1
    ? aws_organizations_account.account[local.delegated_admin_account_keys[0]].id
    : ""
  )
}

data "aws_iam_policy_document" "org_delegation" {
  count = local.delegated_admin_account_id != "" ? 1 : 0

  statement {
    sid    = "DelegateOrganizationsReadAndTag"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.delegated_admin_account_id}:root"]
    }

    actions = [
      "organizations:DescribeOrganization",
      "organizations:DescribeOrganizationalUnit",
      "organizations:DescribeAccount",
      "organizations:DescribePolicy",
      "organizations:DescribeEffectivePolicy",
      "organizations:ListRoots",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListParents",
      "organizations:ListChildren",
      "organizations:ListAccounts",
      "organizations:ListAccountsForParent",
      "organizations:ListPolicies",
      "organizations:ListPoliciesForTarget",
      "organizations:ListTargetsForPolicy",
      "organizations:ListTagsForResource",
      "organizations:TagResource",
      "organizations:UntagResource",
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_resource_policy" "delegation" {
  count = local.delegated_admin_account_id != "" ? 1 : 0

  content = data.aws_iam_policy_document.org_delegation[0].json
}

# Organization-wide CloudTrail. Captures management events from every
# member account into the bucket created by module/aws-cloudtrail-bucket
# in the org's designated log host account. Bucket name and KMS alias
# ARN are deterministic (encoded in the per-org tfvars) so we don't need
# any cross-stack data sources.
resource "aws_cloudtrail" "org" {
  count = var.cloudtrail_enabled ? 1 : 0

  name                          = var.cloudtrail_trail_name
  s3_bucket_name                = var.cloudtrail_bucket_name
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = var.cloudtrail_kms_alias_arn

  depends_on = [aws_organizations_organization.organization]
}

# RegionAllowlist SCP. Denies any API call where aws:RequestedRegion
# is not in var.allowed_regions, with a NotAction list that exempts
# AWS global-service APIs (IAM, Organizations, Route 53, CloudFront,
# IAM Identity Center, billing, support, etc.). Global-service control
# planes route through us-east-1 regardless of where the caller sits;
# denying them by region would break IAM, billing, and SSO for every
# account in the org.
#
# To change the allowlist for a specific org, set `allowed_regions`
# in the org's `module "org" { ... }` block. To restrict an account
# further than the org-level list (e.g. a sandbox that should only
# reach us-east-1), layer a stricter SCP on the account's OU.
data "aws_iam_policy_document" "region_allowlist" {
  statement {
    sid    = "DenyAllOutsideAllowedRegions"
    effect = "Deny"

    not_actions = [
      "a4b:*",
      "access-analyzer:*",
      "account:*",
      "acm:*",
      "activate:*",
      "artifact:*",
      "aws-marketplace-management:*",
      "aws-marketplace:*",
      "aws-portal:*",
      "billing:*",
      "billingconductor:*",
      "budgets:*",
      "ce:*",
      "chatbot:*",
      "chime:*",
      "cloudfront:*",
      "cloudtrail:LookupEvents",
      "compute-optimizer:*",
      "config:*",
      "consoleapp:*",
      "consolidatedbilling:*",
      "cur:*",
      "datapipeline:GetAccountLimits",
      "devicefarm:*",
      "directconnect:*",
      "discovery-marketplace:*",
      "ec2:DescribeRegions",
      "ec2:DescribeTransitGateways",
      "ec2:DescribeVpnGateways",
      "ecr-public:*",
      "fms:*",
      "freetier:*",
      "globalaccelerator:*",
      "health:*",
      "iam:*",
      "importexport:*",
      "invoicing:*",
      "iq:*",
      "kms:*",
      "license-manager:ListReceivedLicenses",
      "lightsail:Get*",
      "mobileanalytics:*",
      "networkmanager:*",
      "notifications-contacts:*",
      "notifications:*",
      "organizations:*",
      "payments:*",
      "pricing:*",
      "purchase-orders:*",
      "ram:*",
      "resource-explorer-2:*",
      "route53-recovery-cluster:*",
      "route53-recovery-control-config:*",
      "route53-recovery-readiness:*",
      "route53:*",
      "route53domains:*",
      "s3:CreateMultiRegionAccessPoint",
      "s3:DeleteMultiRegionAccessPoint",
      "s3:DescribeMultiRegionAccessPointOperation",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetMultiRegionAccessPoint",
      "s3:GetMultiRegionAccessPointPolicy",
      "s3:GetMultiRegionAccessPointPolicyStatus",
      "s3:GetStorageLensConfiguration",
      "s3:GetStorageLensDashboard",
      "s3:ListAllMyBuckets",
      "s3:ListMultiRegionAccessPoints",
      "s3:ListStorageLensConfigurations",
      "s3:PutAccountPublicAccessBlock",
      "s3:PutMultiRegionAccessPointPolicy",
      "savingsplans:*",
      "shield:*",
      "signin:*",
      "sso:*",
      "sso-directory:*",
      # sts:* intentionally NOT exempted. STS has real regional
      # endpoints with per-region enforcement; leaving sts out of
      # NotAction means the SCP denies sts:AssumeRole (and every
      # other STS call) in any region outside allowed_regions.
      # sts.amazonaws.com global endpoint resolves to us-east-1
      # which is in the allow list, so SDK defaults + SSO flows +
      # the chained <org>-via-defn profile all still work.
      "support:*",
      "supportapp:*",
      "supportplans:*",
      "sustainability:*",
      "tag:*",
      "tax:*",
      "trustedadvisor:*",
      "user-subscriptions:*",
      "vendor-insights:*",
      "wellarchitected:*",
    ]

    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_organizations_policy" "region_allowlist" {
  name        = "RegionAllowlist"
  description = "Deny API calls outside the allowed-regions set"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.region_allowlist.json
}

resource "aws_organizations_policy_attachment" "region_allowlist_root" {
  policy_id = aws_organizations_policy.region_allowlist.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

# =============================================================================
# DenyS3PublicAccess SCP -- belt-and-braces with the per-account
# aws_s3_account_public_access_block resource. Forbids any path to a
# public S3 bucket: deleting the BPA, putting a BPA with any flag
# false, or attaching a public-grant canned ACL.
#
# The new module/aws-pub-bucket distribution is not a public bucket --
# the bucket is private with PAB on, and CloudFront fetches via OAC
# using the cloudfront.amazonaws.com service principal. Those calls
# are not affected by any of the statements below. No carve-out
# needed for any account or bucket today.
# =============================================================================

data "aws_iam_policy_document" "deny_s3_public_access" {
  statement {
    sid    = "DenyDeletePublicAccessBlock"
    effect = "Deny"

    actions = [
      "s3:DeleteAccountPublicAccessBlock",
      "s3:DeleteBucketPublicAccessBlock",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyDisableBlockPublicAcls"
    effect = "Deny"

    actions = [
      "s3:PutAccountPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "s3:PublicAccessBlockConfiguration:BlockPublicAcls"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyDisableBlockPublicPolicy"
    effect = "Deny"

    actions = [
      "s3:PutAccountPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "s3:PublicAccessBlockConfiguration:BlockPublicPolicy"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyDisableIgnorePublicAcls"
    effect = "Deny"

    actions = [
      "s3:PutAccountPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "s3:PublicAccessBlockConfiguration:IgnorePublicAcls"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyDisableRestrictPublicBuckets"
    effect = "Deny"

    actions = [
      "s3:PutAccountPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "s3:PublicAccessBlockConfiguration:RestrictPublicBuckets"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyPublicCannedAcls"
    effect = "Deny"

    actions = [
      "s3:CreateBucket",
      "s3:PutBucketAcl",
      "s3:PutObjectAcl",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "authenticated-read",
        "public-read",
        "public-read-write",
      ]
    }
  }
}

resource "aws_organizations_policy" "deny_s3_public_access" {
  name        = "DenyS3PublicAccess"
  description = "Forbid public S3 buckets org-wide -- belt-and-braces with module/aws-account's account-level BPA"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_s3_public_access.json
}

resource "aws_organizations_policy_attachment" "deny_s3_public_access_root" {
  policy_id = aws_organizations_policy.deny_s3_public_access.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

# =============================================================================
# DenyAnonymousS3Access RCP -- denies anonymous (non-AWS-service,
# no-PrincipalAccount) requests to S3 resources owned by the org.
# Kills S3 static-website-endpoint anonymous reads org-wide.
#
# CloudFront OAC requests are unaffected because the principal is the
# cloudfront.amazonaws.com service principal (aws:PrincipalIsAWSService
# is true), and the BoolIfExists condition skips them.
#
# RESOURCE_CONTROL_POLICY is enabled in enabled_policy_types above.
# =============================================================================

data "aws_iam_policy_document" "deny_anonymous_s3" {
  statement {
    sid    = "DenyAnonymousS3"
    effect = "Deny"

    actions = ["s3:*"]

    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }

    condition {
      test     = "Null"
      variable = "aws:PrincipalAccount"
      values   = ["true"]
    }
  }
}

resource "aws_organizations_policy" "deny_anonymous_s3" {
  name        = "DenyAnonymousS3Access"
  description = "Deny anonymous (non-org, non-service) S3 access on resources owned by the org"
  type        = "RESOURCE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_anonymous_s3.json
}

resource "aws_organizations_policy_attachment" "deny_anonymous_s3_root" {
  policy_id = aws_organizations_policy.deny_anonymous_s3.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

# =============================================================================
# ServiceAllowlist SCP -- conservative deny-by-omission via NotAction.
# Lists every AWS service we either actively use in terraform today or
# need to keep open for billing/console/support hygiene. Anything not
# in the NotAction list is denied by the FullAWSAccess root default.
#
# Tightening this list further (e.g. log accounts denied ec2:*) is
# planned for a follow-up at the OU level; this v1 covers only the
# org-root allowlist.
# =============================================================================

data "aws_iam_policy_document" "service_allowlist" {
  statement {
    sid    = "DenyServicesNotInAllowlist"
    effect = "Deny"

    not_actions = [
      "access-analyzer:*",
      "account:*",
      "acm:*",
      "artifact:*",
      "bedrock:*",
      "billing:*",
      "billingconductor:*",
      "budgets:*",
      "ce:*",
      "chatbot:*",
      "cloudfront:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "config:*",
      "consoleapp:*",
      "cur:*",
      "ec2:*",
      "ecr:*",
      "ecr-public:*",
      "freetier:*",
      "health:*",
      "iam:*",
      "identitystore:*",
      "invoicing:*",
      "kms:*",
      "notifications:*",
      "notifications-contacts:*",
      "organizations:*",
      "payments:*",
      "pricing:*",
      "purchase-orders:*",
      "ram:*",
      "resource-explorer-2:*",
      "route53:*",
      "route53domains:*",
      "s3:*",
      "secretsmanager:*",
      "shield:*",
      "signin:*",
      "ssm:*",
      "sso:*",
      "sso-directory:*",
      "sts:*",
      "support:*",
      "supportapp:*",
      "supportplans:*",
      "sustainability:*",
      "tag:*",
      "tax:*",
      "trustedadvisor:*",
      "wellarchitected:*",
    ]

    resources = ["*"]
  }
}

resource "aws_organizations_policy" "service_allowlist" {
  name        = "ServiceAllowlist"
  description = "Deny API calls to AWS services not on the conservative allowlist"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.service_allowlist.json
}

resource "aws_organizations_policy_attachment" "service_allowlist_root" {
  policy_id = aws_organizations_policy.service_allowlist.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

# =============================================================================
# Hardening SCP -- combines six independent deny statements that were
# originally drafted as separate Tier-1 SCPs (DenyRootUserActions,
# DenyLeaveOrganization, DenyDisablingSecurityServices,
# DenyKmsKeyDestruction, DenyIAMUserCreation) plus the Tier-3 Bedrock
# allowlist. AWS Organizations limits each target (root, OU, account)
# to 5 SCPs *including* the AWS-managed FullAWSAccess policy, so we
# can attach at most 4 customer SCPs at the org root. This combined
# policy frees up 5 attachment slots that were going to the individual
# policies.
# =============================================================================

data "aws_iam_policy_document" "hardening" {
  statement {
    sid    = "DenyRootUser"
    effect = "Deny"

    actions = ["*"]

    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }

  statement {
    sid    = "DenyLeaveOrganization"
    effect = "Deny"

    actions = ["organizations:LeaveOrganization"]

    resources = ["*"]
  }

  statement {
    sid    = "DenyIAMUserCreation"
    effect = "Deny"

    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyKmsDestruction"
    effect = "Deny"

    actions = [
      "kms:DisableKey",
      "kms:DisableKeyRotation",
      "kms:ScheduleKeyDeletion",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyDisablingSecurityServices"
    effect = "Deny"

    actions = [
      # CloudTrail
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      # IAM Access Analyzer
      "access-analyzer:DeleteAnalyzer",
      # AWS Config
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "config:StopConfigurationRecorder",
      # GuardDuty (forward-protect)
      "guardduty:DeleteDetector",
      "guardduty:DeleteMembers",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:DisassociateMembers",
      "guardduty:StopMonitoringMembers",
      "guardduty:UpdateDetector",
      # SecurityHub (forward-protect)
      "securityhub:BatchDisableStandards",
      "securityhub:DeleteInvitations",
      "securityhub:DisableSecurityHub",
      "securityhub:DisassociateFromMasterAccount",
      "securityhub:DeleteMembers",
      "securityhub:DisassociateMembers",
      # Macie (forward-protect)
      "macie2:DisableMacie",
      "macie2:DisableOrganizationAdminAccount",
      # Inspector (forward-protect)
      "inspector2:Disable",
      "inspector2:DisableDelegatedAdminAccount",
      # Detective (forward-protect)
      "detective:DeleteGraph",
      "detective:DeleteMembers",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DenyNonAnthropicBedrock"
    effect = "Deny"

    actions = [
      "bedrock:CreateModelCustomizationJob",
      "bedrock:CreateProvisionedModelThroughput",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]

    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:ResourceArn"
      values = [
        "arn:aws:bedrock:*::foundation-model/anthropic.*",
        "arn:aws:bedrock:*:*:inference-profile/*anthropic*",
        "arn:aws:bedrock:*:*:provisioned-model/*anthropic*",
        "arn:aws:bedrock:*:*:custom-model/anthropic.*/*",
      ]
    }
  }
}

resource "aws_organizations_policy" "hardening" {
  name        = "Hardening"
  description = "Combined deny: root user, leave org, IAM users, KMS destruction, disabling security services, non-Anthropic Bedrock"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.hardening.json
}

resource "aws_organizations_policy_attachment" "hardening_root" {
  policy_id = aws_organizations_policy.hardening.id
  target_id = aws_organizations_organization.organization.roots[0].id
}

# NOTE: DenyAccessFromOutsideOrg (RCP) and DenyModifyingOrgTrustRoles
# (SCP) were drafted in the original Tier 1 plan but pulled before any
# tofu apply because they break trust relationships:
#
# DenyAccessFromOutsideOrg used aws:PrincipalOrgID != <this-org>. The
# master state account lives in this tenant's AWS Organization; every
# cross-org tofu apply originates from an SSO session there and would
# be denied by every other org's RCP. To re-introduce safely it needs
# an exemption for the state account principal ARN.
#
# DenyModifyingOrgTrustRoles denied iam:AttachRolePolicy,
# iam:UpdateRole, etc. on `*-ops-terraform`. But that role IS what
# terraform uses to manage itself (aws_iam_role.terraform +
# aws_iam_role_policy_attachment.terraform in module/aws-account); on
# the next apply that touches its tags or attachment, terraform calls
# a denied action and fails. To re-introduce safely it needs an
# `aws:PrincipalArn ArnNotLike` exemption for `*-ops-terraform` so
# the role can self-modify.
#
# Both fixes are tracked in ~/TODO.md.

# NOTE: Ec2Hardening (DECLARATIVE_POLICY_EC2) and BedrockAnthropicOnly
# (standalone SCP) were drafted but pulled. The Ec2Hardening JSON
# shape was rejected by AWS with MalformedPolicyDocumentException --
# the @@assign / @@operators_allowed_for_child_policies grammar of
# DECLARATIVE_POLICY_EC2 differs from what was attempted. Tracked in
# ~/TODO.md for a follow-up that uses the AWS-published example
# verbatim. The Bedrock allowlist was folded into the Hardening SCP
# above because AWS Organizations limits each target to 5 SCPs
# including FullAWSAccess.
