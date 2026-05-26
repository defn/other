@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: infra generator.
//
// Traceability:
//   Go source:      go/lib/gen/infra/infra.go
//   Reads catalogs: catalog.aws_orgs, catalog.aws_accounts,
//                   catalog.aws_state, catalog.aws_allowed_regions,
//                   catalog.aws_forbidden_regions
//   Template:       interface/aws/templates.cue
//
// Why these files exist: infra stamps the entire AWS Terraform
// directory tree from catalog data. It's the largest generator in
// the repo by claim count -- 14 orgs x 3-36 accounts each,
// 142 accounts total, plus parent dirs and cross-cutting files.
//
// Layout:
//   infra/BUILD.bazel           -- parent wrapper
//   infra/org/BUILD.bazel       -- bare parent wrapper
//   infra/global/{BUILD.bazel, main.tf, mise.toml}
//                               -- cross-account S3 buckets brick
//   infra/org/<org>/{BUILD.bazel, main.tf, variables.tf, mise.toml,
//                    terraform.auto.tfvars.json}
//                               -- org-management brick (14 orgs)
//   infra/org/<org>/<acct>/{BUILD.bazel, main.tf, mise.toml}
//                               -- per-account brick (142 accounts)
//
// Cross-cutting files:
//   tenant/<owner>/catalog/gen-infra-bricks.cue -- brick catalog
//                                   entries for all infra bricks,
//                                   compiled list.
//   module/aws-account/regions.gen.tf
//                                -- per-region provider plumbing
//                                   derived from aws_allowed_regions.
//
// NOT claimed (hand-written or Terraform-managed):
//   infra/mise.toml              -- top-level mise.toml
//   infra/.mise/tasks/BUILD.bazel
//   infra/**/.terraform.lock.hcl -- managed by `terraform init`
//
// Pre-Stage-7, the org-account roster was a hand-maintained CUE
// literal in this contract. Stage 7 (AIDR-00071) replaced it with
// a comprehension over the lattice tree (the actual on-disk infra/
// subtree under the active tenant). Stamping a new account dir on
// disk is the only change required -- the contract picks up the
// new layout on the next vet, no second edit needed.
//
// See AIDR-00062 and AIDR-00054 (Terraform Operator for AWS Org
// Management) for the terraform-operator pattern this infra tree
// supports.

package contracts

import "list"

// default_tenant defaults to "defn" when the lattice doesn't carry
// one. A fork sets this in their tenant overlay catalog to retarget
// every infra path. See AIDR-00071 (kernel/tenant decoupling).
default_tenant: string | *"defn"
_infraBase:     "tenant/\(default_tenant)/infra"

// _tenantsDir resolves to the lattice tree node at tenant/.
// Looked up here at top-level so downstream comprehensions don't
// have to repeat the long path. Pre-Stage-7 the orgAccounts roster
// was a hand-maintained CUE map of org -> [account names];
// post-Stage-7 it's derived from the on-disk reality at
// tenant/<default_tenant>/infra/org/.
_tenantsDir: tree.dirs.m.dirs.tenant.dirs

_infra: {
	// Orgs and their account dirs, derived from the file tree at
	// tenant/<default_tenant>/infra/org/. Adding or removing an
	// account dir on disk is the only change required.
	//
	// CUE's struct-key dynamic access requires the key to be
	// defined; if a fork sets default_tenant to a tenant without
	// an infra/ subtree the lookup yields _|_, and the
	// comprehension yields zero entries (the != _|_ guards below).
	orgAccounts: {
		if _tenantsDir[default_tenant] != _|_
		if _tenantsDir[default_tenant].dirs != _|_
		if _tenantsDir[default_tenant].dirs.infra != _|_
		if _tenantsDir[default_tenant].dirs.infra.dirs != _|_
		if _tenantsDir[default_tenant].dirs.infra.dirs.org != _|_
		if _tenantsDir[default_tenant].dirs.infra.dirs.org.dirs != _|_ {
			for orgName, org in _tenantsDir[default_tenant].dirs.infra.dirs.org.dirs
			if org.dirs != _|_ {
				(orgName): list.Sort([
					for acctName, _ in org.dirs {acctName},
				], list.Ascending)
			}
		}
	}

	// Parent-level files: infra/BUILD.bazel and infra/org/BUILD.bazel.
	_parentDirs: [
		"\(_infraBase)/BUILD.bazel",
		"\(_infraBase)/org/BUILD.bazel",
	]

	// infra/global -- cross-account S3 buckets brick.
	_globalFiles: [
		"\(_infraBase)/global/BUILD.bazel",
		"\(_infraBase)/global/main.tf",
		"\(_infraBase)/global/mise.toml",
	]

	// Per-org brick: 5 generated files each. Skip orgs whose
	// account set is empty so the contract doesn't claim files in
	// dirs that won't exist on disk.
	_orgFiles: [
		for org, accs in orgAccounts
		if len(accs) > 0
		for name in [
			"BUILD.bazel",
			"main.tf",
			"variables.tf",
			"mise.toml",
			"terraform.auto.tfvars.json",
		] {"\(_infraBase)/org/\(org)/\(name)"},
	]

	// Per-account brick: 3 generated files each.
	_acctFiles: [
		for org, accts in orgAccounts
		for a in accts
		for name in [
			"BUILD.bazel",
			"main.tf",
			"mise.toml",
		] {"\(_infraBase)/org/\(org)/\(a)/\(name)"},
	]

	// Cross-cutting files written outside the infra/ tree.
	// gen-infra-bricks.cue lives in the owning tenant's catalog/
	// per AIDR-00071.
	_crossCutting: [
		"tenant/\(default_tenant)/catalog/gen-infra-bricks.cue",
		"kernel/module/aws-account/regions.gen.tf",
	]

	allPaths: list.Concat([
		_parentDirs,
		_globalFiles,
		_orgFiles,
		_acctFiles,
		_crossCutting,
	])
}

generators: infra: {
	generator: "infra"
	source:    "tenant/library/go/lib/gen/infra"
	reason:    "stamps the entire AWS Terraform directory tree (parents, global, per-org, per-account) from catalog.aws_orgs + aws_accounts, plus the catalog brick index (catalog/gen-infra-bricks.cue) and per-region provider plumbing (module/aws-account/regions.gen.tf)"
	read_from: {
		catalog: [
			"aws_orgs",
			"aws_accounts",
			"aws_state",
			"aws_allowed_regions",
			"aws_forbidden_regions",
		]
		paths: ["kernel/interface/aws/templates.cue"]
	}
	related_aidr: [54, 62, 71]
	paths: list.Concat([
		_infra.allPaths,
		// Per-brick .terraform.lock.hcl files; map populated by the
		// infra generator in the generated inputs block below. Lock
		// files are written by `terraform init` but scoped to each
		// brick dir and previously needed a manual-files entry each
		// (~157 lines).
		[for b, fs in _infra_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _infra_inputs ===
// Per-brick in-brick file roster emitted by infra.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_infra_inputs: [string]: [...string]

_infra_inputs: {}

// === END GENERATED: _infra_inputs ===
