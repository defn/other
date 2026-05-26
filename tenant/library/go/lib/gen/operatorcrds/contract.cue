@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: operatorcrds generator.
//
// Traceability:
//   Go source:      go/lib/gen/operatorcrds/operatorcrds.go
//   Reads sources:  vendored Go API types under v/<vendor>/pkg/apis/...
//   External tool:  controller-gen (invoked via exec)
//
// Why these files exist: operators built from vendored source
// (rather than via a helm chart) need their CRDs materialised as a
// companion -crds raw-app. The generator runs controller-gen on the
// Go API types to produce CRD YAML, imports the YAML into CUE, and
// writes app/<operator>-crds/gen-app.cue.
//
// Today one operator is handled: terraform-operator (from
// v/galleybytes--terraform-operator/pkg/apis/...). The CRDApp list
// is hard-coded in operatorcrds.go; adding a new operator means
// updating both that file and this contract's paths list.
//
// Note: "-crds" apps for helm-based apps (arc-crds, argocd-crds,
// etc.) are NOT generated here. Their gen-app.cue files are
// hand-written today. When that changes, this contract or a new one
// will claim them.
//
// See AIDR-00062.

package contracts

_operatorcrds: crdApps: [
	"terraform-operator-crds",
]

generators: operatorcrds: {
	generator: "operatorcrds"
	source:    "tenant/library/go/lib/gen/operatorcrds"
	reason:    "runs controller-gen against vendored Go API types and wraps the resulting CRD YAML in a raw-app gen-app.cue, so source-built operators ship their CRDs as a companion ArgoCD app"
	read_from: {
		path_globs: ["v/galleybytes--terraform-operator/pkg/apis/**/*"]
	}
	related_aidr: [62]
	paths: [
		for a in _operatorcrds.crdApps {"tenant/library/app/\(a)/gen-app.cue"},
	]
}
