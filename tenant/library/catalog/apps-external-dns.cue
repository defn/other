@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: external-dns (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "external-dns": {
	name:          "external-dns"
	kind:          "kustomize"
	path:          "tenant/library/app/external-dns"
	chart_name:    "external-dns"
	chart_repo:    "https://kubernetes-sigs.github.io/external-dns"
	chart_version: schema.versions.external_dns.chart_version
	chart_sha256:  schema.versions.external_dns.chart_sha256
	desc:          "Automatic DNS from ingress annotations"
}
