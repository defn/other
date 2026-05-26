@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

#ChartVersion: {
	// Per-cluster (version, build_digest, published_digest) tuples.
	// Each cluster owns its own version so a content change for one
	// cluster does not bump the chart tag for the others.
	// Key = cluster name. Non-cluster-scoped apps have identical
	// digests (and therefore identical versions) across clusters;
	// cluster-scoped apps may differ.
	cluster_digests: {[string]: {
		version:          string       // current chart version tag for this cluster
		build_digest:     string       // from Bazel build
		published_digest: *"" | string // set by helm-bump at publish time; "" for clusters that haven't published yet
	}}
}

#Environment: {
	name: string
	path: string // workspace-relative (e.g. "env/defn-a")
	platforms: {[string]: {}} // map of k8s platform names to compose
	cluster:                  string // cluster name (key into k3d_clusters)
	server:                   string // k8s API server URL
	registry:                 string // OCI registry for helm charts
	desc?:                    string
}
