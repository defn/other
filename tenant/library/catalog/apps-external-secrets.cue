@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: external-secrets (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "external-secrets": {
	name:          "external-secrets"
	kind:          "kustomize"
	path:          "tenant/library/app/external-secrets"
	chart_name:    "external-secrets"
	chart_repo:    "https://charts.external-secrets.io"
	chart_version: schema.versions.external_secrets.chart_version
	chart_sha256:  schema.versions.external_secrets.chart_sha256
	desc:          "External Secrets Operator"
}
