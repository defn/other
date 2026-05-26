@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: awsconfig generator.
//
// Traceability:
//   Go source:      go/lib/gen/awsconfig/awsconfig.go
//   Reads catalogs: catalog.aws_orgs, catalog.aws_accounts,
//                   catalog.aws_state, catalog.auth,
//                   catalog.image_bootstrap (optional)
//
// Why these files exist:
//   - root/.aws/config: every AWS account in catalog.aws_accounts
//     becomes one [profile] section (SSO settings resolved from the
//     account's org). One additional chained [profile <org>-via-defn]
//     is emitted per org-management account, used as a source_profile
//     for account bootstrap; the source profile is auth.tofu.
//   - kernel/image/packer/coder/mise.toml: AWS_PROFILE + AWS_REGION
//     env vars for the coder AMI packer build. AWS_PROFILE is auth.tofu
//     so a fork retargets the AMI builder via catalog only (AIDR-00101);
//     AWS_REGION is image_builder.region when declared, falling back to
//     defaultPackerRegion otherwise (AIDR-00106).
//   - kernel/image/packer/coder/install-ec2.sh: EC2 bootstrap script
//     for the coder AMI; s5cmd s3 URL templated from
//     image_bootstrap.zfs_docker.{bucket,key} (AIDR-00104).
//     Skipped when image_bootstrap is absent.
//
// Replaces the pre-Stage-6 cue-export genrule (lived in the active
// tenant's aws/ BUILD.bazel:aws_config_gen) that was blocked by
// the cue export bypassing the gen.Context tenant catalog overlay.
// Going through the Go path means the generator reads the merged
// catalog (aws.cue can live in tenant/<owner>/catalog/).
//
// See AIDR-00062 (generator contracts), AIDR-00101 (auth profile
// schema, packer mise.toml), AIDR-00104 (image_bootstrap schema),
// AIDR-00106 (image_builder region schema).

package contracts

generators: awsconfig: {
	generator: "awsconfig"
	source:    "tenant/library/go/lib/gen/awsconfig"
	reason:    "emits AWS profile config files (root/.aws/config, the coder packer mise.toml AWS_PROFILE + AWS_REGION overrides, and the coder packer install-ec2.sh s5cmd source URL) from the merged catalog (overlay-aware), reading the master profile from auth.tofu per AIDR-00101, the s3 bootstrap source from image_bootstrap per AIDR-00104, and the AMI build region from image_builder per AIDR-00106"
	read_from: {
		catalog: [
			"aws_orgs",
			"aws_accounts",
			"aws_state",
			"auth",
			"image_bootstrap",
			"image_builder",
		]
	}
	related_aidr: [62, 101, 104, 106]
	paths: [
		"root/.aws/config",
		"kernel/image/packer/coder/mise.toml",
		"kernel/image/packer/coder/install-ec2.sh",
	]
}
