@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: karpenter (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: karpenter: {
	name:          "karpenter"
	kind:          "kustomize"
	path:          "tenant/library/app/karpenter"
	chart_name:    "karpenter"
	chart_repo:    "oci://public.ecr.aws/karpenter"
	chart_version: schema.versions.karpenter.chart_version
	chart_sha256:  schema.versions.karpenter.chart_sha256
	desc:          "Karpenter node autoscaler"
}
