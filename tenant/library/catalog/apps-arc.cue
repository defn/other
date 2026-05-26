@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: arc (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: arc: {
	name:          "arc"
	kind:          "kustomize"
	path:          "tenant/library/app/arc"
	chart_name:    "gha-runner-scale-set-controller"
	chart_repo:    "oci://ghcr.io/actions/actions-runner-controller-charts"
	chart_version: schema.versions.arc.chart_version
	chart_sha256:  schema.versions.arc.chart_sha256
	desc:          "Actions Runner Controller v2 operator"
}
