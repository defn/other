@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: linkerd-control-plane (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "linkerd-control-plane": {
	name:          "linkerd-control-plane"
	kind:          "kustomize"
	path:          "tenant/library/app/linkerd-control-plane"
	chart_name:    "linkerd-control-plane"
	chart_repo:    "https://helm.linkerd.io/stable"
	chart_version: schema.versions.linkerd.chart_version
	chart_sha256:  schema.versions.linkerd.chart_sha256
	desc:          "Linkerd service mesh control plane"
}
