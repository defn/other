@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #ImageBuilder declares where the tenant's packer AMI build runs.
// Closed struct: adding a new field (instance type, base AMI,
// builder SSH key) requires a kernel schema PR so all consumers
// agree on the vocabulary. See AIDR-00106.
//
// region character class follows AWS region naming
// (^[a-z]{2}-[a-z]+-[0-9]+$). Tighter than `string`; loose enough
// to admit any real region. Defensive: the value renders into a
// shell env var (via mise's [env] AWS_REGION) at packer-build time,
// mirroring the AIDR-00105 security major hardening for
// image_bootstrap.
#ImageBuilder: {
	region: =~"^[a-z]{2}-[a-z]+-[0-9]+$"
}
