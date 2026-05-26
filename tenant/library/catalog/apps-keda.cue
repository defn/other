@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: keda (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: keda: {
	name:          "keda"
	kind:          "kustomize"
	path:          "tenant/library/app/keda"
	chart_name:    "keda"
	chart_repo:    "https://kedacore.github.io/charts"
	chart_version: schema.versions.keda.chart_version
	chart_sha256:  schema.versions.keda.chart_sha256
	desc:          "Event-driven autoscaling"
}
