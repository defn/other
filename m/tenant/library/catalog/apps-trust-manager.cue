@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: trust-manager (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "trust-manager": {
	name:          "trust-manager"
	kind:          "kustomize"
	path:          "tenant/library/app/trust-manager"
	chart_name:    "trust-manager"
	chart_repo:    "https://charts.jetstack.io"
	chart_version: schema.versions.trust_manager.chart_version
	chart_sha256:  schema.versions.trust_manager.chart_sha256
	desc:          "CA trust bundle distribution"
}
