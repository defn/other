@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: reloader (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: reloader: {
	name:          "reloader"
	kind:          "kustomize"
	path:          "tenant/library/app/reloader"
	chart_name:    "reloader"
	chart_repo:    "https://stakater.github.io/stakater-charts"
	chart_version: schema.versions.reloader.chart_version
	chart_sha256:  schema.versions.reloader.chart_sha256
	desc:          "ConfigMap/Secret change rollouts"
}
