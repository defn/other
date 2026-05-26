@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: coder (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: coder: {
	name:          "coder"
	kind:          "kustomize"
	path:          "tenant/library/app/coder"
	chart_name:    "coder"
	chart_repo:    "https://helm.coder.com/v2"
	chart_version: schema.versions.coder.chart_version
	chart_sha256:  schema.versions.coder.chart_sha256
	desc:          "Coder IDE workspace manager"
}
