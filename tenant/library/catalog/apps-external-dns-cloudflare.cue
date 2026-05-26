@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: external-dns-cloudflare (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "external-dns-cloudflare": {
	name: "external-dns-cloudflare"
	kind: "raw"
	path: "tenant/library/app/external-dns-cloudflare"
	desc: "ExternalDNS Cloudflare provider for DNSEndpoint CRs"
}
