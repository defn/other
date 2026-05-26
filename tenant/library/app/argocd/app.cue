// ArgoCD GitOps controller
@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"quay.io/argoproj/argocd",
	"ecr-public.aws.com/docker/library/redis",
	"ghcr.io/dexidp/dex",
]

helm_values: {
	redisSecretInit: enabled: true
	server: extraArgs: ["--insecure"]
	configs: {
		cm: {
			// Auth handled by oauth2-proxy at traefik level.
			// Anonymous access lets ArgoCD UI/API work without a second login.
			"users.anonymous.enabled": "true"
			// CRDs are static -- once applied they're healthy.
			// Without this, ArgoCD reports CRD-only apps as Degraded.
			"resource.customizations.health.apiextensions.k8s.io_CustomResourceDefinition": """
				hs = {}
				hs.status = "Healthy"
				hs.message = "CRD is available"
				return hs
				"""
		}
		rbac: {
			"policy.default": "role:admin"
		}
	}
}

_delete_secret_patch: {
	_name: string
	target: {
		kind: "Secret"
		name: _name
	}
	patch: """
		$patch: delete
		apiVersion: v1
		kind: Secret
		metadata:
		  name: \(_name)
		"""
}

kustomize_patches: [
	// Delete secrets -- managed externally (bootstrap-argocd task creates them).
	_delete_secret_patch & {_name: "argocd-notifications-secret"},
	_delete_secret_patch & {_name: "argocd-secret"},
	{
		// Redis secret init: replace Helm hooks with ArgoCD hooks.
		// Helm hooks (helm.sh/hook) cause ArgoCD to wait forever for deleted Jobs.
		// ArgoCD hooks (PreSync + HookSucceeded) run before each sync and clean up properly.
		target: name: "argocd-redis-secret-init"
		patch: """
			- op: remove
			  path: /metadata/annotations/helm.sh~1hook
			- op: remove
			  path: /metadata/annotations/helm.sh~1hook-delete-policy
			- op: add
			  path: /metadata/annotations/argocd.argoproj.io~1hook
			  value: PreSync
			- op: add
			  path: /metadata/annotations/argocd.argoproj.io~1hook-delete-policy
			  value: HookSucceeded
			"""
	},
]

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

// Secrets managed by External Secrets Operator.
// Each field must be filled by environment-specific CUE overlays.
// Run `cue eval -c` to verify all secrets are concrete.

secrets: "argocd-secret": {
	"admin.password":        string
	"server.secretkey":      string
	"dex.oidc.clientSecret": string
}

secrets: "argocd-notifications-secret": {
	// Notification channel tokens (Slack, GitHub, etc.)
	// Fields vary by configured notification services.
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

route_mappings: "argocd-server": {
	namespace: "argocd"
	host:      "argocd"
	service:   "argocd-server"
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

workloads: "argocd-server": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "server"
	replicas:  1
}

workloads: "argocd-application-controller": {
	kind:      "StatefulSet"
	namespace: "argocd"
	container: "application-controller"
	replicas:  1
}

workloads: "argocd-repo-server": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "repo-server"
	replicas:  1
}

workloads: "argocd-applicationset-controller": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "applicationset-controller"
	replicas:  1
}

workloads: "argocd-notifications-controller": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "notifications-controller"
	replicas:  1
}

workloads: "argocd-redis": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "redis"
	replicas:  1
}

workloads: "argocd-dex-server": {
	kind:      "Deployment"
	namespace: "argocd"
	container: "dex-server"
	replicas:  1
}
