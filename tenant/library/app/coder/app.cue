@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["ghcr.io/coder/coder"]

helm_values: coder: service: type: "ClusterIP"

_ns_remove_patch: {
	patch: """
		- op: remove
		  path: /metadata/namespace
		"""
}

kustomize_patches: [
	_ns_remove_patch & {target: {kind: "ServiceAccount", name: "coder"}},
	_ns_remove_patch & {target: {kind: "Role", name: "coder-workspace-perms"}},
	_ns_remove_patch & {target: {kind: "RoleBinding", name: "coder"}},
	_ns_remove_patch & {target: {kind: "Service", name: "coder"}},
	_ns_remove_patch & {target: {kind: "Deployment", name: "coder"}},
]

// overlay.cue -- per-cluster objects for Coder.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// Generate ExternalSecrets from secret_mappings (defined in secrets.cue)
objects: ExternalSecret: {
	for secretName, mapping in secret_mappings {
		(secretName): {
			apiVersion: "external-secrets.io/v1"
			kind:       "ExternalSecret"
			metadata: {
				name:      secretName
				namespace: mapping.namespace
			}
			spec: {
				refreshInterval: "1h"
				secretStoreRef: {
					name: "aws-secrets-manager"
					kind: "ClusterSecretStore"
				}
				target: name: secretName
				data: [
					for k8sKey, awsProp in mapping.keys {
						secretKey: k8sKey
						remoteRef: {
							key:                "defn/\(_cluster_name)-secrets"
							property:           awsProp
							conversionStrategy: "Default"
							decodingStrategy:   "None"
							metadataPolicy:     "None"
						}
					},
				]
			}
		}
	}
}

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

// Secrets managed by External Secrets Operator.
secrets: "coder-oidc": {
	"client-secret": string
}

// Database connection secret.
secrets: "coder-db-app": {
	uri: string
}

// ESO mappings: K8s secret key -> AWS Secrets Manager property name.
secret_mappings: [string]: {
	namespace: string
	keys: [string]: string
}

secret_mappings: "coder-oidc": {
	namespace: "coder"
	keys: {
		"client-id":     "coder-oidc-client-id"
		"client-secret": "coder-oidc-client-secret"
	}
}

secret_mappings: "coder-db-app": {
	namespace: "coder"
	keys: {
		uri: "coder-db-uri"
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

route_mappings: coder: {
	namespace: "coder"
	host:      "coder"
	service:   "coder"
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

workloads: coder: {
	kind:      "Deployment"
	namespace: "coder"
	container: "coder"
	replicas:  1
	resources: {
		requests: {cpu: "2000m", memory: "4096Mi"}
		limits: {cpu: "2000m", memory: "4096Mi"}
	}
}
