@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

// #Mirror produces a kustomize images entry that rewrites a container
// image reference to its local OCI registry mirror with a pinned digest.
// It resolves through the alias map when the kustomize name differs from
// the canonical catalog key.
//
// Output fields:
//   name:    original image name (kustomize match key)
//   newName: local mirror path
//   newTag:  version tag for human readability
//   digest:  sha256 digest pin from the catalog lockfile
//
// The resulting image reference is:
//   host.k3d.internal:5000/mirror/image:tag@sha256:...
//
// Usage (in a kustomization.yaml images section):
//
//   import "github.com/defn/other/kernel/catalog"
//
//   images: [
//     catalog.#Mirror & {#name: "quay.io/jetstack/cert-manager-controller"},
//   ]
//
#Mirror: {
	// #name is the image name as kustomize sees it (from Helm chart output).
	#name: string

	// #tag is the version tag to mirror. Required for catalog lookup
	// since the catalog is keyed by source:tag to support multiple
	// versions of the same image.
	#tag: string

	// Resolve: if name is an alias key, use the alias target; otherwise
	// assume it's already a canonical source key.
	#source: *mirror_aliases[#name] | #name

	// Catalog key is source:tag
	#key: #source + ":" + #tag

	// Output: kustomize images transformer entry
	name:    #name
	newName: mirror_registry + "/mirror/" + mirror_images[#key].source
	newTag:  mirror_images[#key].tag
}

// mirror_aliases maps kustomize short/variant image names to their canonical
// catalog source key. When a Helm chart emits a short Docker Hub name or a
// variant registry prefix, kustomize sees that name in the rendered manifest.
// The alias map resolves it back to the catalog entry.
mirror_aliases: [string]: string
mirror_aliases: {}
