@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #ImageBootstrap declares per-payload S3 sources used by
// kernel-resident packer install scripts that prime an EC2 instance
// before the workload starts. Closed struct: adding a new payload
// (e.g. zfs_workspaces) requires a kernel schema PR so all consumers
// agree on the vocabulary.
//
// Read access to each bucket is expected to be granted to the tenant's
// auth.tofu profile; the install script uses that profile (set via
// AWS_PROFILE in the sibling mise.toml, AIDR-00101). See AIDR-00104.
//
// bucket / key character classes are tighter than full S3 spec by
// design: the values render unquoted into a root shell pipeline
// (`s5cmd cat s3://<bucket>/<key> | pv | zfs receive ...`) at EC2
// first-boot, so a fork's catalog must not be able to inject shell
// metacharacters. bucket follows S3 standard naming (lowercase
// [a-z0-9.-], leading [a-z0-9], 3-63 chars). key permits
// [A-Za-z0-9._/-] -- `/` for hierarchical keys (default
// `zfs/docker.zfs`), no spaces, no shell metas. Per AIDR-00105
// security major.
#ImageBootstrap: {
	// zfs_docker -- pre-built ZFS dataset for /var/lib/docker.
	// Receives via `s5cmd cat s3://<bucket>/<key> | zfs receive`.
	zfs_docker: {
		bucket: =~"^[a-z0-9][a-z0-9.-]{2,62}$"
		key:    =~"^[A-Za-z0-9._/-]+$"
	}
}
