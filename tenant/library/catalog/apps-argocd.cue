@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: argocd (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: argocd: {
	name:          "argocd"
	kind:          "kustomize"
	path:          "tenant/library/app/argocd"
	chart_name:    "argo-cd"
	chart_repo:    "https://argoproj.github.io/argo-helm"
	chart_version: schema.versions.argocd.chart_version
	chart_sha256:  schema.versions.argocd.chart_sha256
	desc:          "ArgoCD GitOps controller"
}
