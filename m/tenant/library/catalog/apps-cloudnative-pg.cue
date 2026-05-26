@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: cloudnative-pg (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "cloudnative-pg": {
	name:          "cloudnative-pg"
	kind:          "kustomize"
	path:          "tenant/library/app/cloudnative-pg"
	chart_name:    "cloudnative-pg"
	chart_repo:    "https://cloudnative-pg.github.io/charts"
	chart_version: schema.versions.cloudnative_pg.chart_version
	chart_sha256:  schema.versions.cloudnative_pg.chart_sha256
	desc:          "CloudNativePG PostgreSQL operator"
}
