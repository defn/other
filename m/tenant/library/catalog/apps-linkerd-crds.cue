@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: linkerd-crds (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "linkerd-crds": {
	name:          "linkerd-crds"
	kind:          "kustomize"
	path:          "tenant/library/app/linkerd-crds"
	chart_name:    "linkerd-crds"
	chart_repo:    "https://helm.linkerd.io/stable"
	chart_version: schema.versions.linkerd_crds.chart_version
	chart_sha256:  schema.versions.linkerd_crds.chart_sha256
	desc:          "Linkerd CRDs"
}
