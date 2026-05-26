@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: traefik (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: traefik: {
	name:          "traefik"
	kind:          "kustomize"
	path:          "tenant/library/app/traefik"
	chart_name:    "traefik"
	chart_repo:    "https://traefik.github.io/charts"
	chart_version: schema.versions.traefik.chart_version
	chart_sha256:  schema.versions.traefik.chart_sha256
	desc:          "Traefik ingress controller"
}
