@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #AwsOrg defines an AWS organization with its SSO identity center config.
#AwsOrg: {
	name:       string
	sso_region: "us-west-2" | "us-east-2" | "us-east-1"
	sso_url:    string
	// CloudFront price class applied to every pub bucket distribution
	// in this org. Defaults to PriceClass_100 (cheapest) when unset.
	pub_price_class?: "PriceClass_100" | "PriceClass_200" | "PriceClass_All"
}

// #AwsState defines the central Terraform state configuration.
// All infra bricks derive backend and provider settings from this.
#AwsState: {
	profile:    string       // AWS SSO profile for state access
	account_id: =~"^[0-9]+$" // account ID of the state account
	bucket:     string       // S3 bucket for terraform state
	region:     string       // region for state bucket
}

// #AwsAccount defines a single AWS account within an org.
// The account references its org by name; the org's SSO config is
// resolved through the relationship at config generation time.
// id is optional: accounts not yet created by tofu have no id until
// after apply; such accounts appear only in the org-level tfvars.
#AwsAccount: {
	org:                         string             // org name (key into aws_orgs)
	name:                        string             // account name within the org
	id:                          *"" | =~"^[0-9]+$" // 12-digit AWS account ID (empty until created by tofu apply)
	email:                       string
	iam_user_access_to_billing?: "ALLOW"
	role_name?:                  string
	delegated_services?: [...string] // AWS service principals for which this account is a delegated administrator
	// Service principals that are already delegated to this account
	// out-of-band; the generator emits tofu `import` blocks so state
	// adopts the existing delegation instead of trying to create it.
	imported_delegated_services?: [...string]
	// Enable IAM outbound web identity federation for this account so
	// its IAM principals can mint short-lived JWTs for external
	// services. Provisioned by module/aws-account.
	outbound_federation?: bool
	// Parent OU path for this account within the org. When empty the
	// account stays directly under the org root (AWS default for
	// payer/management accounts). Non-empty values must match a key in
	// module/aws-org's ou_tree local (e.g. "Ops", "Shared/Network",
	// "Workloads/Prod").
	parent_ou?: "Ops" | "Shared/Network" | "Shared/Artifacts" | "Shared/Observability" | "Platform" | "Workloads/NonProd" | "Workloads/Prod" | "Edge" | "Sandbox" | "Exceptions" | "Suspended"
	// When true, this account hosts the CloudTrail S3 bucket and KMS key
	// for its org. Exactly one account per org should set this.
	cloudtrail_bucket_host?: bool
	// When true, this account hosts a public S3 bucket and CloudFront
	// distribution provisioned by module/aws-pub-bucket. Typically set on
	// "-pub" accounts in the Edge OU; chamber-3 also sets it because
	// chamber has hit its CreateAccount quota and cannot add a dedicated
	// pub account.
	pub_bucket_host?: bool
}
