@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: letsencrypt-issuer (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "letsencrypt-issuer": {
	name: "letsencrypt-issuer"
	kind: "raw"
	path: "tenant/library/app/letsencrypt-issuer"
	desc: "Let's Encrypt ClusterIssuer + wildcard Certificate"
}
