@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: tenantstamp.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-tenantstamp": [
	"kernel/spec/convention-contracts-tenantstamp.cue",
]

// ---- tenant/<t>/{app,bot,k3d,k8s}/ universal-identity stamp set ----
//
// `defn stamp tenant <name>` (go/lib/stamp:StampTenant) emits a
// universal-identity scaffolding under each new tenant: a fixed set of
// BUILD.bazel files plus the bot/ kit's mise.toml + .gitignore. The set
// is pinned by //kernel/spec:tenant_stamp_smoke and is the same for
// every tenant by design (universal identity, no conditionals).
//
// These files are stamped at tenant creation, then become essentially
// hand-written -- but they're not unique per-tenant content (every
// tenant has identical scaffolding shape), so they don't belong in
// spec/manual-files.cue (~18 redundant entries pre-AIDR-00072 follow-up).
// Claiming them here as a convention means: if any tenant ships
// missing one of these files (or has an unexpected file in the same
// slot), it shows up as a missingClaim or orphan with a precise path.
//
// See AIDR-00071 (kernel/tenant decoupling) and AIDR-00072 (chart_versions
// follow-up); the universal-identity set itself is documented in
// m/go/lib/stamp/stamp.go:StampTenant.
generators: tenantstamp: {
	generator: "tenantstamp"
	source:    "(convention-based; no Go generator -- mirrors StampTenant's universal-identity set)"
	reason:    "every tenant under tenant/<t>/ ships StampTenant's universal-identity scaffolding (app/BUILD.bazel, bot/{BUILD.bazel,.gitignore,mise.toml}, k3d/BUILD.bazel, k8s/BUILD.bazel). Claiming the set per-tenant via lattice comprehension keeps spec/manual-files.cue free of redundant per-tenant-per-feature entries."
	read_from: {
		lattice: ["tree.dirs.m.dirs.tenant"]
	}
	related_aidr: [62, 66, 71]
	paths: [
		for tName, t in tree.dirs.m.dirs.tenant.dirs
		if t.dirs != _|_
		for sub, files in {
			"app": ["BUILD.bazel"]
			"bot": ["BUILD.bazel", ".gitignore", "mise.toml"]
			"k3d": ["BUILD.bazel"]
			"k8s": ["BUILD.bazel"]
		}
		if t.dirs[sub] != _|_
		if t.dirs[sub].files != _|_
		for f in files
		if t.dirs[sub].files[f] != _|_ {"tenant/\(tName)/\(sub)/\(f)"},
	]
}
