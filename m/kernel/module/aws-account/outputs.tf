output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}

output "outbound_federation_issuer" {
  value = try(aws_iam_outbound_web_identity_federation.this[0].issuer_identifier, "")
}
