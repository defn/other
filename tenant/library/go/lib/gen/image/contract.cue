@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: image generator.
//
// Traceability:
//   Go source:      go/lib/gen/image/image.go
//   Reads catalogs: catalog.container_images
//   Template:       interface/image/templates.cue
//
// Why these files exist: each container image brick (base, edge,
// postgres, redis, registry, bazel-remote) has a BUILD.bazel and a
// mise.toml describing the build. The Dockerfile is hand-written
// per image. Packer images live under image/packer/ and are
// entirely hand-written (no packer generator yet).
//
// Not claimed: image/<brick>/Dockerfile, image/packer/*, top-level
// image/BUILD.bazel + image/docker/BUILD.bazel.
//
// See AIDR-00062.

package contracts

// Bind catalog.container_images from the lattice JSON so the contract
// can iterate it directly.
container_images: _

generators: image: {
	generator: "image"
	source:    "tenant/library/go/lib/gen/image"
	reason:    "stamps BUILD.bazel + mise.toml per container image brick from catalog.container_images so Bazel targets and mise tool resolution stay in sync"
	read_from: {
		catalog: ["container_images"]
		paths: ["kernel/interface/image/templates.cue"]
	}
	related_aidr: [62]
	// Each container brick has a fixed file set: generator writes
	// BUILD.bazel + mise.toml, Dockerfile is hand-authored.
	paths: [
		for k, _ in container_images
		for f in ["BUILD.bazel", "mise.toml", "Dockerfile"] {"kernel/image/docker/\(k)/\(f)"},
	]
}
