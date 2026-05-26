@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "traefik"
images: ["docker.io/traefik"]

helm_values: {
	providers: kubernetesCRD: allowCrossNamespace: true
	service: spec: type:                           "ClusterIP"
	ingressRoute: dashboard: entryPoints: ["websecure"]
}

helm_options: includeCRDs: false

// overlay.cue -- additional objects unified with kustomize-rendered gen-app.cue.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// Generate IngressRoutes from route_mappings (defined in secrets.cue)
objects: IngressRoute: {
	for routeName, route in route_mappings {
		(routeName): {
			apiVersion: "traefik.io/v1alpha1"
			kind:       "IngressRoute"
			metadata: {
				name:      routeName
				namespace: route.namespace
			}
			spec: {
				entryPoints: ["websecure"]
				routes: [{
					match: "Host(`\(route.host).\(_cluster_domain)`)"
					kind:  "Rule"
					if route.auth {
						middlewares: [{
							name:      "auth"
							namespace: "oauth2-proxy"
						}]
					}
					if route.service_kind != _|_ {
						services: [{
							name: route.service
							kind: route.service_kind
						}]
					}
					if route.service_kind == _|_ {
						services: [{
							name: route.service
							port: route.port
						}]
					}
				}]
				tls: secretName: "wildcard-tls"
			}
		}
	}
}

// Ingress routes served by Traefik.
route_mappings: [string]: {
	namespace:     string
	host:          string
	service:       string
	port:          *80 | number
	auth:          *true | bool
	service_kind?: string // e.g. "TraefikService" for internal services
}

route_mappings: "traefik-dashboard": {
	namespace:    "traefik"
	host:         "traefik"
	service:      "api@internal"
	service_kind: "TraefikService"
	auth:         true
}

// Workload inventory.
workloads: [string]: {
	kind:      "Deployment" | "StatefulSet" | "DaemonSet"
	namespace: string
	container: string
	replicas?: number
	resources?: {
		requests?: {cpu?: string, memory?: string}
		limits?: {cpu?: string, memory?: string}
	}
}

workloads: traefik: {
	kind:      "Deployment"
	namespace: "traefik"
	container: "traefik"
	replicas:  1
}
