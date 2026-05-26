@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["temporalio/server", "temporalio/admin-tools", "temporalio/ui"]

helm_values: {
	// ArgoCD-friendly: chart's default helm pre-install hook for the schema job
	// deadlocks against the CNPG Cluster overlay. Without hooks the schema Job
	// becomes a regular Sync-phase resource whose init container waits on the
	// temporal-db-app secret; CNPG mints that secret from the Cluster during
	// the same Sync phase, so the deadlock never forms.
	schema: useHelmHooks: false
	server: config: persistence: {
		defaultStore:     "default"
		visibilityStore:  "visibility"
		numHistoryShards: 512
		datastores: {
			default: sql: {
				createDatabase:  false // CNPG creates databases via initdb
				manageSchema:    true
				pluginName:      "postgres12_pgx"
				driverName:      "postgres12_pgx"
				databaseName:    "temporal"
				connectAddr:     "temporal-db-rw.temporal.svc:5432"
				connectProtocol: "tcp"
				user:            "temporal"
				existingSecret:  "temporal-db-app"
				secretKey:       "password"
				maxConns:        20
				maxIdleConns:    20
				maxConnLifetime: "1h"
			}
			visibility: sql: {
				createDatabase:  false
				manageSchema:    true
				pluginName:      "postgres12_pgx"
				driverName:      "postgres12_pgx"
				databaseName:    "temporal_visibility"
				connectAddr:     "temporal-db-rw.temporal.svc:5432"
				connectProtocol: "tcp"
				user:            "temporal"
				existingSecret:  "temporal-db-app"
				secretKey:       "password"
				maxConns:        20
				maxIdleConns:    20
				maxConnLifetime: "1h"
			}
		}
	}
	server: config: namespaces: {
		create: true
		namespace: [{
			name:      "default"
			retention: "3d"
		}]
	}
	shims: {
		dockerize:         false
		elasticsearchTool: false
	}
	web: enabled: true
}

// Per-cluster tags.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// CNPG PostgreSQL cluster for Temporal persistence.
objects: Cluster: "temporal-db": {
	apiVersion: "postgresql.cnpg.io/v1"
	kind:       "Cluster"
	metadata: {
		name:      "temporal-db"
		namespace: "temporal"
	}
	spec: {
		instances: 1
		bootstrap: initdb: {
			database: "temporal"
			owner:    "temporal"
			options: ["--encoding=UTF8"]
			postInitSQL: [
				"CREATE DATABASE temporal_visibility OWNER temporal ENCODING 'UTF8'",
			]
		}
		postgresql: parameters: {
			max_connections: "200"
			shared_buffers:  "256MB"
		}
		storage: size: "10Gi"
	}
}

// Generate IngressRoutes from route_mappings.
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

route_mappings: "temporal-web": {
	namespace: "temporal"
	host:      "temporal"
	service:   "temporal-web"
	port:      8080
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

workloads: "temporal-frontend": {
	kind:      "Deployment"
	namespace: "temporal"
	container: "temporal"
	replicas:  1
}

workloads: "temporal-history": {
	kind:      "Deployment"
	namespace: "temporal"
	container: "temporal"
	replicas:  1
}

workloads: "temporal-matching": {
	kind:      "Deployment"
	namespace: "temporal"
	container: "temporal"
	replicas:  1
}

workloads: "temporal-worker": {
	kind:      "Deployment"
	namespace: "temporal"
	container: "temporal"
	replicas:  1
}

workloads: "temporal-web": {
	kind:      "Deployment"
	namespace: "temporal"
	container: "temporal-web"
	replicas:  1
}
