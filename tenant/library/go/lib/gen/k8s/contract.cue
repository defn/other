@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: k8s generator.
//
// Traceability:
//   Go source:      go/lib/gen/k8s/k8s.go
//   Reads:          interface/k8s (CUE package with platform defs)
//   Template:       interface/k8s/templates.cue
//
// Why these files exist: each k8s platform brick (k3d-argocd,
// k3d-base, k3d-jianghu) is a composable bundle of apps installed
// on k3d clusters. The generator stamps a thin BUILD.bazel that
// registers the platform's platform.cue file with Bazel; the
// platform.cue itself is hand-written (the composition of apps
// lives there).
//
// Not claimed: tenant/<t>/k8s/BUILD.bazel (top-level tagged_package
// wrapper) or any tenant/<t>/k8s/<platform>/platform.cue (hand-written
// CUE source).
//
// See AIDR-00062.

package contracts

// Bind catalog.k8s_platforms from the lattice JSON so the contract
// can iterate it directly.
k8s_platforms: _

generators: k8s: {
	generator: "k8s"
	source:    "tenant/library/go/lib/gen/k8s"
	reason:    "stamps BUILD.bazel for each k8s platform brick (interface/k8s composes platform.cue bundles of apps installed per cluster)"
	read_from: {
		paths: [
			"kernel/interface/k8s/platforms.cue",
			"kernel/interface/k8s/templates.cue",
		]
	}
	related_aidr: [62]
	// Each platform brick has a fixed file set: generator writes
	// BUILD.bazel, platform.cue is hand-authored.
	paths: [
		for _, p in k8s_platforms
		for f in ["BUILD.bazel", "platform.cue"] {"\(p.path)/\(f)"},
	]
}
