@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "redis-operator": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "service-account"
			"app.kubernetes.io/instance":   "redis-operator"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "redis-operator"
			"app.kubernetes.io/part-of":    "redis-operator"
			"app.kubernetes.io/version":    "0.24.0"
			"helm.sh/chart":                "redis-operator-0.24.0"
		}
		name:      "redis-operator"
		namespace: "redis-operator"
	}
}
objects: ClusterRole: "redis-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":                  "role"
			"app.kubernetes.io/instance":                   "redis-operator"
			"app.kubernetes.io/managed-by":                 "Helm"
			"app.kubernetes.io/name":                       "redis-operator"
			"app.kubernetes.io/part-of":                    "redis-operator"
			"app.kubernetes.io/version":                    "0.24.0"
			"helm.sh/chart":                                "redis-operator-0.24.0"
			"rbac.authorization.k8s.io/aggregate-to-admin": "true"
		}
		name: "redis-operator"
	}
	rules: [{
		apiGroups: ["redis.redis.opstreelabs.in"]
		resources: [
			"rediss",
			"redisclusters",
			"redisreplications",
			"redis",
			"rediscluster",
			"redissentinel",
			"redissentinels",
			"redisreplication",
		]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		nonResourceURLs: ["*"]
		verbs: ["get"]
	}, {
		apiGroups: ["apiextensions.k8s.io"]
		resources: ["customresourcedefinitions"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["redis.redis.opstreelabs.in"]
		resources: [
			"redis/finalizers",
			"rediscluster/finalizers",
			"redisclusters/finalizers",
			"redissentinel/finalizers",
			"redissentinels/finalizers",
			"redisreplication/finalizers",
			"redisreplications/finalizers",
		]
		verbs: ["update"]
	}, {
		apiGroups: ["redis.redis.opstreelabs.in"]
		resources: [
			"redis/status",
			"rediscluster/status",
			"redisclusters/status",
			"redissentinel/status",
			"redissentinels/status",
			"redisreplication/status",
			"redisreplications/status",
		]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: [
			"secrets",
			"pods/exec",
			"pods",
			"services",
			"configmaps",
			"events",
			"persistentvolumeclaims",
			"namespaces",
		]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: ["statefulsets"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["policy"]
		resources: ["poddisruptionbudgets"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}]
}
objects: ClusterRoleBinding: "redis-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "role-binding"
			"app.kubernetes.io/instance":   "redis-operator"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "redis-operator"
			"app.kubernetes.io/part-of":    "redis-operator"
			"app.kubernetes.io/version":    "0.24.0"
			"helm.sh/chart":                "redis-operator-0.24.0"
		}
		name: "redis-operator"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "redis-operator"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "redis-operator"
		namespace: "redis-operator"
	}]
}
objects: Deployment: "redis-operator": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "redis-operator"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "redis-operator"
			"app.kubernetes.io/part-of":    "redis-operator"
			"app.kubernetes.io/version":    "0.24.0"
			"helm.sh/chart":                "redis-operator-0.24.0"
		}
		name:      "redis-operator"
		namespace: "redis-operator"
	}
	spec: {
		replicas: 1
		selector: matchLabels: name: "redis-operator"
		strategy: {}
		template: {
			metadata: labels: name: "redis-operator"
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--leader-elect",
						"--metrics-bind-address=:8080",
						"--kube-client-timeout=60s",
					]
					command: [
						"/operator",
						"manager",
					]
					env: [{
						name:  "INIT_CONTAINER_IMAGE"
						value: "quay.io/opstree/redis-operator:v0.24.0"
					}, {
						name:  "ENABLE_WEBHOOKS"
						value: "false"
					}, {
						name:  "SERVICE_DNS_DOMAIN"
						value: "cluster.local"
					}, {
						name:  "FEATURE_GATES"
						value: "GenerateConfigInInitContainer=false"
					}]
					image:           "host.k3d.internal:5000/mirror/quay.io/opstree/redis-operator:v0.24.0"
					imagePullPolicy: "Always"
					livenessProbe: httpGet: {
						path: "/healthz"
						port: "probe"
					}
					name: "redis-operator"
					ports: [{
						containerPort: 8081
						name:          "probe"
						protocol:      "TCP"
					}, {
						containerPort: 8080
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: httpGet: {
						path: "/readyz"
						port: "probe"
					}
					resources: {
						limits: {
							cpu:    "500m"
							memory: "500Mi"
						}
						requests: {
							cpu:    "500m"
							memory: "500Mi"
						}
					}
					securityContext: {}
				}]
				securityContext: {}
				serviceAccount:     "redis-operator"
				serviceAccountName: "redis-operator"
			}
		}
	}
}
