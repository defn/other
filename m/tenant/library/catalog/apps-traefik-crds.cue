@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: traefik-crds (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "traefik-crds": {
	name: "traefik-crds"
	kind: "raw"
	path: "tenant/library/app/traefik-crds"
	desc: "Traefik CRDs (IngressRoute, Middleware, etc.)"
}
