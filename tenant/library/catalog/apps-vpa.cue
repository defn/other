@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: vpa (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: vpa: {
	name:          "vpa"
	kind:          "kustomize"
	path:          "tenant/library/app/vpa"
	chart_name:    "vpa"
	chart_repo:    "https://charts.fairwinds.com/stable"
	chart_version: schema.versions.vpa.chart_version
	chart_sha256:  schema.versions.vpa.chart_sha256
	desc:          "Vertical Pod Autoscaler"
}
