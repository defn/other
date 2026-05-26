@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: tailscale-operator (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "tailscale-operator": {
	name:          "tailscale-operator"
	kind:          "kustomize"
	path:          "tenant/library/app/tailscale-operator"
	chart_name:    "tailscale-operator"
	chart_repo:    "https://pkgs.tailscale.com/helmcharts"
	chart_version: schema.versions.tailscale.chart_version
	chart_sha256:  schema.versions.tailscale.chart_sha256
	desc:          "Tailscale Kubernetes operator"
}
