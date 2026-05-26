@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: buildbuddy (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: buildbuddy: {
	name:          "buildbuddy"
	kind:          "kustomize"
	path:          "tenant/library/app/buildbuddy"
	chart_name:    "buildbuddy"
	chart_repo:    "https://helm.buildbuddy.io"
	chart_version: schema.versions.buildbuddy.chart_version
	chart_sha256:  schema.versions.buildbuddy.chart_sha256
	desc:          "BuildBuddy Bazel cache and events server"
}
