@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: metrics-server (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "metrics-server": {
	name:          "metrics-server"
	kind:          "kustomize"
	path:          "tenant/library/app/metrics-server"
	chart_name:    "metrics-server"
	chart_repo:    "https://kubernetes-sigs.github.io/metrics-server"
	chart_version: schema.versions.metrics_server.chart_version
	chart_sha256:  schema.versions.metrics_server.chart_sha256
	desc:          "Cluster resource metrics API"
}
