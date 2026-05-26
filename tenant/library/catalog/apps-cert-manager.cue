@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: cert-manager (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "cert-manager": {
	name:          "cert-manager"
	kind:          "kustomize"
	path:          "tenant/library/app/cert-manager"
	chart_name:    "cert-manager"
	chart_repo:    "https://charts.jetstack.io"
	chart_version: schema.versions.cert_manager.chart_version
	chart_sha256:  schema.versions.cert_manager.chart_sha256
	desc:          "TLS certificate management"
}
