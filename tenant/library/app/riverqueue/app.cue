@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["ghcr.io/riverqueue/riverui"]

// Per-cluster tags.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// CNPG PostgreSQL cluster for River Queue.
objects: Cluster: "riverqueue-db": {
	apiVersion: "postgresql.cnpg.io/v1"
	kind:       "Cluster"
	metadata: {
		name:      "riverqueue-db"
		namespace: "riverqueue"
	}
	spec: {
		instances: 1
		bootstrap: initdb: {
			database: "riverqueue"
			owner:    "riverqueue"
			options: ["--encoding=UTF8"]
		}
		postgresql: parameters: {
			max_connections: "200"
			shared_buffers:  "128MB"
		}
		storage: size: "5Gi"
	}
}

// River UI Deployment.
objects: Deployment: "riverqueue-ui": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      "riverqueue-ui"
		namespace: "riverqueue"
	}
	spec: {
		replicas: 1
		selector: matchLabels: app: "riverqueue-ui"
		template: {
			metadata: labels: app: "riverqueue-ui"
			spec: {
				initContainers: [{
					name:  "migrate"
					image: "host.k3d.internal:5000/devcontainer/dev:edge"
					command: ["/usr/local/bin/mise", "x", "--", "river", "migrate-up", "--database-url", "$(DATABASE_URL)"]
					env: [{
						name: "DATABASE_URL"
						valueFrom: secretKeyRef: {
							name: "riverqueue-db-app"
							key:  "uri"
						}
					}]
				}]
				containers: [{
					name:  "riverui"
					image: "ghcr.io/riverqueue/riverui:0.15.0"
					ports: [{
						containerPort: 8080
						name:          "http"
					}]
					env: [{
						name: "DATABASE_URL"
						valueFrom: secretKeyRef: {
							name: "riverqueue-db-app"
							key:  "uri"
						}
					}]
					livenessProbe: {
						httpGet: {
							path: "/"
							port: "http"
						}
						initialDelaySeconds: 5
						periodSeconds:       10
					}
					readinessProbe: {
						httpGet: {
							path: "/"
							port: "http"
						}
						initialDelaySeconds: 3
						periodSeconds:       5
					}
				}]
			}
		}
	}
}

// Service for River UI.
objects: Service: "riverqueue-ui": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "riverqueue-ui"
		namespace: "riverqueue"
	}
	spec: {
		selector: app: "riverqueue-ui"
		ports: [{
			name:       "http"
			port:       80
			targetPort: "http"
		}]
	}
}

// IngressRoute for River UI via Traefik.
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
					services: [{
						name: route.service
						port: route.port
					}]
				}]
				tls: secretName: "wildcard-tls"
			}
		}
	}
}

route_mappings: [string]: {
	namespace: string
	host:      string
	service:   string
	port:      *80 | number
	auth:      *true | bool
}

route_mappings: "riverqueue-ui": {
	namespace: "riverqueue"
	host:      "riverqueue"
	service:   "riverqueue-ui"
	port:      80
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

workloads: "riverqueue-ui": {
	kind:      "Deployment"
	namespace: "riverqueue"
	container: "riverui"
	replicas:  1
}
