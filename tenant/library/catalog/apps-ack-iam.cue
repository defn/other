@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: ack-iam (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: "ack-iam": {
	name:          "ack-iam"
	kind:          "kustomize"
	path:          "tenant/library/app/ack-iam"
	chart_name:    "iam-chart"
	chart_repo:    "oci://public.ecr.aws/aws-controllers-k8s"
	chart_version: schema.versions.ack_iam.chart_version
	chart_sha256:  schema.versions.ack_iam.chart_sha256
	desc:          "ACK IAM controller"
}
