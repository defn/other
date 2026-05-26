@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: kyverno (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: kyverno: {
	name:          "kyverno"
	kind:          "kustomize"
	path:          "tenant/library/app/kyverno"
	chart_name:    "kyverno"
	chart_repo:    "https://kyverno.github.io/kyverno"
	chart_version: schema.versions.kyverno.chart_version
	chart_sha256:  schema.versions.kyverno.chart_sha256
	desc:          "Policy engine and guardrails"
}
