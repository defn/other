@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: coder: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "coder"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "coder"
			"app.kubernetes.io/part-of":    "coder"
			"app.kubernetes.io/version":    "2.33.6"
			"helm.sh/chart":                "coder-2.33.6"
		}
		name: "coder"
	}
}
objects: Role: "coder-workspace-perms": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: name: "coder-workspace-perms"
	rules: [{
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["persistentvolumeclaims"]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: ["deployments"]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}]
}
objects: RoleBinding: coder: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: name: "coder"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "coder-workspace-perms"
	}
	subjects: [{
		kind: "ServiceAccount"
		name: "coder"
	}]
}
objects: Service: coder: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "coder"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "coder"
			"app.kubernetes.io/part-of":    "coder"
			"app.kubernetes.io/version":    "2.33.6"
			"helm.sh/chart":                "coder-2.33.6"
		}
		name: "coder"
	}
	spec: {
		ports: [{
			name:       "http"
			port:       80
			protocol:   "TCP"
			targetPort: "http"
		}]
		selector: {
			"app.kubernetes.io/instance": "coder"
			"app.kubernetes.io/name":     "coder"
		}
		sessionAffinity: "None"
		type:            "ClusterIP"
	}
}
objects: Deployment: coder: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "coder"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "coder"
			"app.kubernetes.io/part-of":    "coder"
			"app.kubernetes.io/version":    "2.33.6"
			"helm.sh/chart":                "coder-2.33.6"
		}
		name: "coder"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "coder"
			"app.kubernetes.io/name":     "coder"
		}
		template: {
			metadata: {
				annotations: "app.kubernetes.io/component": "coderd"
				labels: {
					"app.kubernetes.io/instance":   "coder"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "coder"
					"app.kubernetes.io/part-of":    "coder"
					"app.kubernetes.io/version":    "2.33.6"
					"helm.sh/chart":                "coder-2.33.6"
				}
			}
			spec: {
				affinity: podAntiAffinity: preferredDuringSchedulingIgnoredDuringExecution: [{
					podAffinityTerm: {
						labelSelector: matchExpressions: [{
							key:      "app.kubernetes.io/instance"
							operator: "In"
							values: ["coder"]
						}]
						topologyKey: "kubernetes.io/hostname"
					}
					weight: 1
				}]
				containers: [{
					args: ["server"]
					command: ["/opt/coder"]
					env: [{
						name:  "CODER_HTTP_ADDRESS"
						value: "0.0.0.0:8080"
					}, {
						name:  "CODER_PROMETHEUS_ADDRESS"
						value: "0.0.0.0:2112"
					}, {
						name:  "CODER_PPROF_ADDRESS"
						value: "0.0.0.0:6060"
					}, {
						name:  "CODER_ACCESS_URL"
						value: "http://coder.coder.svc.cluster.local"
					}, {
						name: "KUBE_POD_IP"
						valueFrom: fieldRef: fieldPath: "status.podIP"
					}, {
						name:  "CODER_DERP_SERVER_RELAY_URL"
						value: "http://$(KUBE_POD_IP):8080"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/coder/coder:v2.33.3"
					imagePullPolicy: "IfNotPresent"
					lifecycle: {}
					name: "coder"
					ports: [{
						containerPort: 8080
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						httpGet: {
							path:   "/healthz"
							port:   "http"
							scheme: "HTTP"
						}
						initialDelaySeconds: 0
					}
					resources: {
						limits: {
							cpu:    "2000m"
							memory: "4096Mi"
						}
						requests: {
							cpu:    "2000m"
							memory: "4096Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						readOnlyRootFilesystem:   null
						runAsGroup:               1000
						runAsNonRoot:             true
						runAsUser:                1000
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: []
				}]
				restartPolicy:                 "Always"
				serviceAccountName:            "coder"
				terminationGracePeriodSeconds: 60
				volumes: []
			}
		}
	}
}
