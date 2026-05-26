@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: oci generator.
//
// Traceability:
//   Go source:      go/lib/gen/oci/oci.go
//   Reads catalogs: catalog.oci_images
//   Template:       interface/oci/templates.cue
//
// Why these files exist: each OCI image brick (bazel-remote,
// registry, ...) has a BUILD.bazel that declares rules_oci targets
// for pulling and publishing the image. One BUILD.bazel per image.
//
// Not claimed: kernel/oci/BUILD.bazel (top-level tagged_package wrapper).
//
// See AIDR-00062.

package contracts

_oci: images: [
	"bazel-remote",
	"golang",
	"registry",
	"ubuntu",
]

generators: oci: {
	generator: "oci"
	source:    "tenant/library/go/lib/gen/oci"
	reason:    "stamps BUILD.bazel for each OCI image brick from catalog.oci_images so rules_oci pull/publish targets stay in sync with the catalog"
	read_from: {
		catalog: ["oci_images"]
		paths: ["kernel/interface/oci/templates.cue"]
	}
	related_aidr: [62]
	paths: [
		for i in _oci.images {"kernel/oci/\(i)/BUILD.bazel"},
	]
}
