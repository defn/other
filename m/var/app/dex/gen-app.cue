@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: dex: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name:      "dex"
		namespace: "dex"
	}
}
objects: Role: dex: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name:      "dex"
		namespace: "dex"
	}
	rules: [{
		apiGroups: ["dex.coreos.com"]
		resources: ["*"]
		verbs: ["*"]
	}]
}
objects: ClusterRole: dex: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name: "dex"
	}
	rules: [{
		apiGroups: ["apiextensions.k8s.io"]
		resources: ["customresourcedefinitions"]
		verbs: [
			"list",
			"create",
		]
	}]
}
objects: RoleBinding: dex: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name:      "dex"
		namespace: "dex"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "dex"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "dex"
		namespace: "dex"
	}]
}
objects: ClusterRoleBinding: "dex-cluster": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name: "dex-cluster"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "dex"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "dex"
		namespace: "dex"
	}]
}
objects: Service: dex: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name:      "dex"
		namespace: "dex"
	}
	spec: {
		ports: [{
			appProtocol: "http"
			name:        "http"
			port:        5556
			protocol:    "TCP"
			targetPort:  "http"
		}, {
			appProtocol: "http"
			name:        "telemetry"
			port:        5558
			protocol:    "TCP"
			targetPort:  "telemetry"
		}]
		selector: {
			"app.kubernetes.io/instance": "dex"
			"app.kubernetes.io/name":     "dex"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: dex: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "dex"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "dex"
			"app.kubernetes.io/version":    "2.44.0"
			"helm.sh/chart":                "dex-0.24.0"
		}
		name:      "dex"
		namespace: "dex"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/instance": "dex"
			"app.kubernetes.io/name":     "dex"
		}
		template: {
			metadata: {
				annotations: null
				labels: {
					"app.kubernetes.io/instance": "dex"
					"app.kubernetes.io/name":     "dex"
				}
			}
			spec: {
				containers: [{
					args: [
						"dex",
						"serve",
						"--web-http-addr",
						"0.0.0.0:5556",
						"--telemetry-addr",
						"0.0.0.0:5558",
						"/etc/dex/config.yaml",
					]
					env: [{
						name: "GOOGLE_CLIENT_ID"
						valueFrom: secretKeyRef: {
							key:  "GOOGLE_CLIENT_ID"
							name: "dex-connector-google"
						}
					}, {
						name: "GOOGLE_CLIENT_SECRET"
						valueFrom: secretKeyRef: {
							key:  "GOOGLE_CLIENT_SECRET"
							name: "dex-connector-google"
						}
					}]
					envFrom: [{
						secretRef: name: "dex-oauth2-proxy-secret"
					}, {
						secretRef: name: "dex-argocd-secret"
					}, {
						secretRef: name: "dex-coder-secret"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/dexidp/dex:v2.45.1"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: httpGet: {
						path: "/healthz/live"
						port: "telemetry"
					}
					name: "dex"
					ports: [{
						containerPort: 5556
						name:          "http"
						protocol:      "TCP"
					}, {
						containerPort: 5558
						name:          "telemetry"
						protocol:      "TCP"
					}]
					readinessProbe: httpGet: {
						path: "/healthz/ready"
						port: "telemetry"
					}
					resources: {}
					securityContext: {}
					volumeMounts: [{
						mountPath: "/etc/dex"
						name:      "config"
						readOnly:  true
					}]
				}]
				securityContext: {}
				serviceAccountName: "dex"
				volumes: [{
					name: "config"
					secret: secretName: "dex"
				}]
			}
		}
	}
}
