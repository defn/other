output "org_id" {
  value = aws_organizations_organization.organization.id
}

output "account_ids" {
  value = { for k, v in aws_organizations_account.account : k => v.id }
}
