@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: argo-rollouts (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "argo-rollouts": {
	name:          "argo-rollouts"
	kind:          "kustomize"
	path:          "tenant/library/app/argo-rollouts"
	chart_name:    "argo-rollouts"
	chart_repo:    "https://argoproj.github.io/argo-helm"
	chart_version: schema.versions.argo_rollouts.chart_version
	chart_sha256:  schema.versions.argo_rollouts.chart_sha256
	desc:          "Canary and blue-green deployments"
}
