@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: topolvm (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: topolvm: {
	name:          "topolvm"
	kind:          "kustomize"
	path:          "tenant/library/app/topolvm"
	chart_name:    "topolvm"
	chart_repo:    "https://topolvm.github.io/topolvm"
	chart_version: schema.versions.topolvm.chart_version
	chart_sha256:  schema.versions.topolvm.chart_sha256
	desc:          "TopoLVM dynamic LVM provisioner"
}
