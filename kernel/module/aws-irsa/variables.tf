variable "cluster_name" {
  description = "k3d cluster name (e.g. defn-a)"
  type        = string
}

variable "region" {
  description = "AWS region for S3 bucket and OIDC provider"
  type        = string
  default     = "us-east-1"
}


variable "irsa_role_prefix" {
  description = "Prefix for IRSA IAM role names (e.g. defn-tmp- for ephemeral)"
  type        = string
  default     = "defn-tmp-"
}
