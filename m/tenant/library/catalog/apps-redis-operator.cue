@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: redis-operator (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "redis-operator": {
	name:          "redis-operator"
	kind:          "kustomize"
	path:          "tenant/library/app/redis-operator"
	chart_name:    "redis-operator"
	chart_repo:    "https://ot-container-kit.github.io/helm-charts"
	chart_version: schema.versions.redis_operator.chart_version
	chart_sha256:  schema.versions.redis_operator.chart_sha256
	desc:          "OpsTree Redis operator"
}
