@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: temporal (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: temporal: {
	name:          "temporal"
	kind:          "kustomize"
	path:          "tenant/library/app/temporal"
	chart_name:    "temporal"
	chart_repo:    "https://go.temporal.io/helm-charts"
	chart_version: schema.versions.temporal.chart_version
	chart_sha256:  schema.versions.temporal.chart_sha256
	desc:          "Temporal workflow engine"
	stamp_args: {
		chart_repo:    "https://go.temporal.io/helm-charts"
		chart_name:    "temporal"
		chart_version: "1.0.0-rc.3"
	}
}
