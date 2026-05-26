@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: tailscale-dns-policy (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "tailscale-dns-policy": {
	name: "tailscale-dns-policy"
	kind: "raw"
	path: "tenant/library/app/tailscale-dns-policy"
	desc: "Kyverno policy to generate wildcard DNS from Tailscale IP"
}
