@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: ack-iam-crds (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "ack-iam-crds": {
	name: "ack-iam-crds"
	kind: "raw"
	path: "tenant/library/app/ack-iam-crds"
	desc: "ACK IAM controller CRDs"
}
