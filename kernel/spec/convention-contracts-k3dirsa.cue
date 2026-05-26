@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: k3dirsa.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-k3dirsa": [
	"kernel/spec/convention-contracts-k3dirsa.cue",
]

// ---- tenant/<t>/k3d/<cluster>/irsa.cue (tofu-emitted, tracked) ----
//
// AIDR-00125: irsa.cue is the tofu output for a per-cluster IRSA
// rotation; tracking it makes `mise run check` deterministic across
// workstations. Pre-AIDR-00127 #9 a manual entry per cluster lived
// in spec/manual-files-tenant.cue (e.g. tenant/defn/k3d/a/irsa.cue),
// requiring a hand-edit any time a new cluster's tofu state landed.
// This convention auto-claims any irsa.cue under any tenant's k3d
// cluster brick whenever the file exists in the lattice.
//
// Driven off lattice presence -- when the operator commits irsa.cue
// after `tofu apply`, this convention picks it up; when the cluster
// is torn down (irsa.cue removed), the claim disappears too. The
// per-brick BUILD.bazel's `has_irsa = True` arg is also driven off
// the same on-disk presence by the k3d generator (AIDR-00125 §5).

generators: k3dirsa: {
	generator: "k3dirsa"
	source:    "(convention-based; no Go generator -- mirrors AIDR-00125's IRSA tracking model)"
	reason:    "tofu-emitted irsa.cue files at tenant/<t>/k3d/<cluster>/irsa.cue are tracked when present (AIDR-00125). Claiming via lattice comprehension keeps spec/manual-files-tenant.cue free of per-cluster-per-tenant entries that would otherwise need a manual edit on every cluster bring-up."
	read_from: {
		lattice: ["tree.dirs.m.dirs.tenant"]
	}
	related_aidr: [62, 66, 125, 127]
	paths: [
		for tName, t in tree.dirs.m.dirs.tenant.dirs
		if t.dirs != _|_
		if t.dirs.k3d != _|_
		if t.dirs.k3d.dirs != _|_
		for cName, c in t.dirs.k3d.dirs
		if c.files != _|_
		if c.files["irsa.cue"] != _|_ {"tenant/\(tName)/k3d/\(cName)/irsa.cue"},
	]
}
