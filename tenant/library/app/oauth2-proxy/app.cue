@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "oauth2-proxy"
images: ["quay.io/oauth2-proxy/oauth2-proxy"]

helm_options: includeCRDs: true

helm_values: {
	config: {
		existingSecret: "oauth2-proxy"
		configFile: """
			provider = "oidc"
			provider_display_name = "Dex"
			client_id = "oauth2-proxy"
			email_domains = [ "defn.sh" ]
			scope = "openid profile email groups"
			oidc_groups_claim = "groups"
			cookie_secure = true
			cookie_httponly = true
			cookie_samesite = "lax"
			cookie_expire = "12h"
			cookie_refresh = "1h"
			cookie_csrf_per_request = false
			cookie_csrf_expire = "15m"
			ssl_insecure_skip_verify = true
			upstreams = [ "static://202" ]
			reverse_proxy = true
			set_xauthrequest = true
			pass_user_headers = true
			session_store_type = "redis"
			redis_connection_url = "redis://redis.oauth2-proxy.svc.cluster.local:6379"
			"""
	}
	ingress: enabled: false
	sessionStorage: {
		type: "redis"
		redis: standalone: connectionUrl: "redis://redis.oauth2-proxy.svc.cluster.local:6379"
	}
}

// overlay.cue -- additional objects unified with kustomize-rendered gen-app.cue.
// Adds: ExternalSecret, Redis, ForwardAuth middleware, auth IngressRoute.

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

// Redis for oauth2-proxy session storage
objects: Deployment: "redis": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      "redis"
		namespace: "oauth2-proxy"
		labels: app: "redis"
	}
	spec: {
		replicas: 1
		selector: matchLabels: app: "redis"
		template: {
			metadata: labels: app: "redis"
			spec: containers: [{
				name:  "redis"
				image: "host.k3d.internal:5000/mirror/ecr-public.aws.com/docker/library/redis:8.2.3-alpine"
				ports: [{containerPort: 6379}]
			}]
		}
	}
}

objects: Service: "redis": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "redis"
		namespace: "oauth2-proxy"
	}
	spec: {
		selector: app: "redis"
		ports: [{
			port:       6379
			targetPort: 6379
		}]
	}
}

// ForwardAuth middleware -- delegates auth to oauth2-proxy.
// With Dex as OIDC provider, /oauth2/ handles both auth check and sign-in redirect.
objects: Middleware: "auth": {
	apiVersion: "traefik.io/v1alpha1"
	kind:       "Middleware"
	metadata: {
		name:      "auth"
		namespace: "oauth2-proxy"
	}
	spec: forwardAuth: {
		address:            "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/"
		trustForwardHeader: true
		authResponseHeaders: [
			"X-Auth-Request-User",
			"X-Auth-Request-Email",
			"X-Auth-Request-Access-Token",
		]
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
secrets: "oauth2-proxy": {
	"client-id":     string
	"client-secret": string
	"cookie-secret": string
}

// ESO mappings: K8s secret key -> AWS Secrets Manager property name.
secret_mappings: [string]: {
	namespace: string
	keys: [string]: string
}

secret_mappings: "oauth2-proxy": {
	namespace: "oauth2-proxy"
	keys: {
		"client-id":     "dex-oauth2-proxy-client-id"
		"client-secret": "dex-oauth2-proxy-client-secret"
		"cookie-secret": "oauth2-proxy-cookie-secret"
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

route_mappings: "oauth2-proxy": {
	namespace: "oauth2-proxy"
	host:      "auth"
	service:   "oauth2-proxy"
	auth:      false
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

workloads: "oauth2-proxy": {
	kind:      "Deployment"
	namespace: "oauth2-proxy"
	container: "oauth2-proxy"
	replicas:  1
}
