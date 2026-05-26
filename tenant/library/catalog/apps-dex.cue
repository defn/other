@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: dex (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: dex: {
	name:          "dex"
	kind:          "kustomize"
	path:          "tenant/library/app/dex"
	chart_name:    "dex"
	chart_repo:    "https://charts.dexidp.io"
	chart_version: schema.versions.dex.chart_version
	chart_sha256:  schema.versions.dex.chart_sha256
	desc:          "Dex OIDC identity provider"
}
