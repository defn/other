@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: external-dns-crds (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "external-dns-crds": {
	name: "external-dns-crds"
	kind: "raw"
	path: "tenant/library/app/external-dns-crds"
	desc: "ExternalDNS DNSEndpoint CRD"
}
