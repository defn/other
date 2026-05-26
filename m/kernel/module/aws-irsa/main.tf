# Per-k3d-run IRSA infrastructure: S3 bucket for OIDC discovery + IAM OIDC provider.
# Taint time_static.run_id to rotate to a new bucket + OIDC provider.

resource "time_static" "run_id" {}

locals {
  run_id     = formatdate("YYYYMMDDhhmmss", time_static.run_id.rfc3339)
  bucket     = "${var.irsa_role_prefix}${local.run_id}-${var.cluster_name}"
  issuer_url = "https://${local.bucket}.s3.${var.region}.amazonaws.com"
}

# =============================================================================
# S3 bucket -- public OIDC discovery endpoint
# =============================================================================

resource "aws_s3_bucket" "oidc" {
  bucket        = local.bucket
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "oidc" {
  bucket                  = aws_s3_bucket.oidc.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "oidc" {
  bucket     = aws_s3_bucket.oidc.id
  depends_on = [aws_s3_bucket_public_access_block.oidc]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPublicReadOIDC"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource = [
        "${aws_s3_bucket.oidc.arn}/.well-known/*",
        "${aws_s3_bucket.oidc.arn}/openid/*",
      ]
    }]
  })
}

# =============================================================================
# IAM OIDC Identity Provider
# =============================================================================

data "tls_certificate" "s3" {
  url = "https://s3.${var.region}.amazonaws.com"
}

resource "aws_iam_openid_connect_provider" "k3d" {
  url             = local.issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.s3.certificates[0].sha1_fingerprint]
}

# =============================================================================
# ACK IAM controller role -- created in tofu (chicken-egg: ACK IAM needs
# credentials before it can create any roles, including its own)
# =============================================================================

locals {
  oidc_issuer_host = replace(local.issuer_url, "https://", "")
}

data "aws_iam_policy_document" "ack_iam_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.k3d.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:ack-system:ack-iam-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ack_iam" {
  name               = "${var.irsa_role_prefix}${var.cluster_name}-ack-iam"
  assume_role_policy = data.aws_iam_policy_document.ack_iam_trust.json
  description        = "IRSA role for ACK IAM controller in ${var.cluster_name}"
}

resource "aws_iam_role_policy_attachment" "ack_iam" {
  role       = aws_iam_role.ack_iam.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

# =============================================================================
# S3 bucket -- tofu state storage (private, versioned)
# =============================================================================

resource "aws_s3_bucket" "tofu_state" {
  bucket        = "${var.irsa_role_prefix}${local.run_id}-${var.cluster_name}-state"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tofu_state" {
  bucket                  = aws_s3_bucket.tofu_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# Tofu runner role -- IRSA for terraform-operator runner pods (tf-* SAs)
# =============================================================================

data "aws_iam_policy_document" "tofu_runner_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.k3d.arn]
    }

    # Wildcard: any tf-* service account in any namespace.
    # The terraform-operator creates SAs named tf-<resource>-<hash>.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:*:tf-*"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tofu_runner" {
  name               = "${var.irsa_role_prefix}${var.cluster_name}-tofu-runner"
  assume_role_policy = data.aws_iam_policy_document.tofu_runner_trust.json
  description        = "IRSA role for tofu runner pods in ${var.cluster_name}"
}

data "aws_iam_policy_document" "tofu_runner" {
  # S3 state storage
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.tofu_state.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tofu_state.arn]
  }

  # SSM Parameter Store -- runners can manage parameters in the account
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "tofu_runner" {
  name   = "tofu-runner"
  role   = aws_iam_role.tofu_runner.id
  policy = data.aws_iam_policy_document.tofu_runner.json
}

# =============================================================================
# AWS Secrets Manager -- consolidated secret for cluster services.
# Contains cloudflare API token, Google OAuth credentials, cookie secret.
# Values are PLACEHOLDERs on first create; update manually via AWS console.
# =============================================================================

resource "aws_secretsmanager_secret" "k3d_secrets" {
  name                    = "defn/${var.cluster_name}-secrets"
  description             = "Secrets for ${var.cluster_name} cluster (cloudflare, oauth2-proxy)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "k3d_secrets" {
  secret_id = aws_secretsmanager_secret.k3d_secrets.id
  secret_string = jsonencode({
    "cloudflare-api-token"       = "PLACEHOLDER"
    "google-oauth-client-id"     = "PLACEHOLDER"
    "google-oauth-client-secret" = "PLACEHOLDER"
    "oauth2-proxy-cookie-secret" = random_password.cookie_secret.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

# =============================================================================
# CUE output -- written to the k3d brick directory for CUE unification.
# This file is gitignored (dynamic, per-run).
# =============================================================================

resource "local_file" "irsa_cue" {
  content         = <<-EOT
    @experiment(aliasv2,explicitopen,try)

    // irsa.cue -- generated by tofu apply. DO NOT EDIT.
    package k3d

    oidc_provider_arn:    "${aws_iam_openid_connect_provider.k3d.arn}"
    oidc_issuer_url:      "${local.issuer_url}"
    oidc_issuer_host:     "${local.oidc_issuer_host}"
    oidc_bucket_name:     "${local.bucket}"
    ack_iam_role_arn:     "${aws_iam_role.ack_iam.arn}"
    tofu_state_bucket:    "${aws_s3_bucket.tofu_state.bucket}"
    tofu_runner_role_arn: "${aws_iam_role.tofu_runner.arn}"
    run_id:               "${local.run_id}"
  EOT
  filename        = "${path.root}/irsa.cue"
  file_permission = "0644"
}
