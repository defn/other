@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: capsule (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: capsule: {
	name:          "capsule"
	kind:          "kustomize"
	path:          "tenant/library/app/capsule"
	chart_name:    "capsule"
	chart_repo:    "https://projectcapsule.github.io/charts"
	chart_version: schema.versions.capsule.chart_version
	chart_sha256:  schema.versions.capsule.chart_sha256
	desc:          "Multi-tenant namespace provisioning"
}
