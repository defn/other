@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: goldilocks (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: goldilocks: {
	name:          "goldilocks"
	kind:          "kustomize"
	path:          "tenant/library/app/goldilocks"
	chart_name:    "goldilocks"
	chart_repo:    "https://charts.fairwinds.com/stable"
	chart_version: schema.versions.goldilocks.chart_version
	chart_sha256:  schema.versions.goldilocks.chart_sha256
	desc:          "VPA recommendations dashboard"
}
