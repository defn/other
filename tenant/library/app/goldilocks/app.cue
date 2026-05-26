@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["us-docker.pkg.dev/fairwinds-ops/oss/goldilocks"]

// overlay.cue -- per-cluster objects for Goldilocks.

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
	service_kind?: string
}

route_mappings: "goldilocks-dashboard": {
	namespace: "goldilocks"
	host:      "goldilocks"
	service:   "goldilocks-dashboard"
	auth:      true
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

workloads: "goldilocks-dashboard": {
	kind:      "Deployment"
	namespace: "goldilocks"
	container: "goldilocks"
	replicas:  1
}

workloads: "goldilocks-controller": {
	kind:      "Deployment"
	namespace: "goldilocks"
	container: "goldilocks"
	replicas:  1
}
