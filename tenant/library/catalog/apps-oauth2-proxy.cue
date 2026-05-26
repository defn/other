@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: oauth2-proxy (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "oauth2-proxy": {
	name:          "oauth2-proxy"
	kind:          "kustomize"
	path:          "tenant/library/app/oauth2-proxy"
	chart_name:    "oauth2-proxy"
	chart_repo:    "https://oauth2-proxy.github.io/manifests"
	chart_version: schema.versions.oauth2_proxy.chart_version
	chart_sha256:  schema.versions.oauth2_proxy.chart_sha256
	desc:          "OAuth2 reverse proxy for SSO"
}
