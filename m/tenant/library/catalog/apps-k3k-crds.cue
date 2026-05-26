@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: k3k-crds (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "k3k-crds": {
	name: "k3k-crds"
	kind: "raw"
	path: "tenant/library/app/k3k-crds"
	desc: "k3k CRDs (Cluster, VirtualClusterPolicy)"
}
