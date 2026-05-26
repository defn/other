@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: awstofu generator.
//
// Traceability:
//   Go source:      go/lib/gen/awstofu/awstofu.go
//   Reads catalogs: catalog.aws_tofu_apps
//   Reads sources:  infra/org/<org>/[<account>/]main.tf
//
// Why these files exist: the awstofu generator produces a raw-app
// brick per aws_tofu_apps entry by reading an infra/ terraform
// source and wrapping its content in a Tofu CR gen-app.cue. The
// BUILD.bazel for these raw apps is written by the main `app`
// generator (kind: "raw" path), not by awstofu -- awstofu only
// touches gen-app.cue.
//
// Today the catalog has a single entry: acc-jianghu-ops, producing
// app/aws-acc-jianghu-ops/gen-app.cue. New accounts add entries to
// catalog/aws-tofu-apps.cue and this contract's paths list.
//
// See AIDR-00062 and the session history that introduced
// interface/app/policy.cue to catch a namespace-ownership bug that
// originated in awstofu.go.

package contracts

// Bind catalog.aws_tofu_apps from the lattice JSON so the contract
// iterates whatever the catalog declares -- no hand-maintained mirror
// of the app list. default_tenant retargets the path prefix per fork.
aws_tofu_apps: _

generators: awstofu: {
	generator: "awstofu"
	source:    "tenant/library/go/lib/gen/awstofu"
	reason:    "stamps a Tofu CR raw-app gen-app.cue per catalog.aws_tofu_apps entry, wrapping tenant/<default_tenant>/infra/org/<org>/[account/]main.tf source in a Kubernetes-runnable brick"
	read_from: {
		catalog: ["aws_tofu_apps"]
		path_globs: ["tenant/\(default_tenant)/infra/org/**/*"]
	}
	related_aidr: [62, 71, 138]
	// Mirror awstofu.go's appDir derivation: aws-acc-<org>-<account>
	// when account is non-empty, otherwise aws-org-<org>.
	paths: [
		for _, e in aws_tofu_apps
		if e.account != _|_
		if e.account != "" {"tenant/\(default_tenant)/app/aws-acc-\(e.org)-\(e.account)/gen-app.cue"},
		for _, e in aws_tofu_apps
		if !(e.account != _|_ && e.account != "") {"tenant/\(default_tenant)/app/aws-org-\(e.org)/gen-app.cue"},
	]
}
