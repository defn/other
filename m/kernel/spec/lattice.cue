@experiment(aliasv2,explicitopen,shortcircuit,try)

package spec

import (
	"github.com/defn/other/kernel/schema"
	"github.com/defn/other/kernel/catalog"
)

// The lattice unifies file metadata (from git ls-files) with catalog
// data (versions, clusters, images).  Exporting this as JSON gives
// spec tests and scripts a single snapshot to query instead of
// hitting the filesystem or running cue export for each piece.
//
// Usage (from m/spec/):
//   cue eval -c -e lattice --out json

lattice: #Lattice

#Lattice: {
	tree: #Dir
	versions: {[string]: schema.#ToolVersion}
	formatters: {[string]: schema.#Formatter}
	apps: {[string]: schema.#App}
	k3d_clusters: {[string]: schema.#K3dCluster}
	k8s_platforms: {[string]: schema.#K8sPlatform}
	environments: {[string]: schema.#Environment}
	chart_versions: {[string]: schema.#ChartVersion}
	oci_images: {[string]: schema.#OciImage}
	container_images: {[string]: schema.#ContainerImage}
	bricks: {[string]: schema.#Brick}
	approved_requires: [...string]
}

// Pull data from schema and catalog packages into the lattice.
lattice: formatters:        catalog.formatters
lattice: versions:          schema.versions
lattice: apps:              catalog.apps
lattice: k3d_clusters:      catalog.k3d_clusters
lattice: k8s_platforms:     catalog.k8s_platforms
lattice: environments:      catalog.environments
lattice: chart_versions:    catalog.chart_versions
lattice: oci_images:        catalog.oci_images
lattice: container_images:  catalog.container_images
lattice: bricks:            catalog.bricks
lattice: approved_requires: catalog.scripting_policy.approved_requires

#Dir: {
	type: "dir"
	files?: {[string]: #File}
	dirs?: {[string]: #Dir}
}

#File: {
	type:     "file" | "symlink"
	mode:     string
	target?:  string // symlink target
	content?: string // raw text (trimmed)
	parsed?:  _      // structured data for JSON/YAML/TOML
}
