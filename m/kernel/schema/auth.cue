@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #Auth declares a tenant's AWS profile mappings, one per purpose.
// Closed struct: adding a new purpose (e.g. ghcr, gcp) requires a
// kernel schema PR so all consumers see the same vocabulary.
//
// Required fields:
//   tofu  -- master profile used by Terraform (state, org-level apply,
//            create.clj IAM ops, image-build s3 access).
//
// Defaulted fields:
//   oci   -- profile used to authenticate against AWS public ECR for
//            crane pulls (sync-mirrors). Defaults to tofu when omitted
//            since the master org profile already has ECR-public
//            read access.
#Auth: {
	tofu: string
	oci:  string | *tofu
}
