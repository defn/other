@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: k3k (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: k3k: {
	name:          "k3k"
	kind:          "kustomize"
	path:          "tenant/library/app/k3k"
	chart_name:    "k3k"
	chart_repo:    "https://rancher.github.io/k3k"
	chart_version: schema.versions.k3k.chart_version
	chart_sha256:  schema.versions.k3k.chart_sha256
	desc:          "Rancher k3k -- Kubernetes-in-Kubernetes"
}
