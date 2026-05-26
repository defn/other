@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "external-dns": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "external-dns"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "external-dns"
			"app.kubernetes.io/version":    "0.21.0"
			"helm.sh/chart":                "external-dns-1.21.1"
		}
		name:      "external-dns"
		namespace: "external-dns"
	}
}
objects: ClusterRole: "external-dns": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "external-dns"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "external-dns"
			"app.kubernetes.io/version":    "0.21.0"
			"helm.sh/chart":                "external-dns-1.21.1"
		}
		name: "external-dns"
	}
	rules: [{
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"get",
			"watch",
			"list",
		]
	}, {
		apiGroups: [""]
		resources: ["services"]
		verbs: [
			"get",
			"watch",
			"list",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"get",
			"watch",
			"list",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		]
		resources: ["ingresses"]
		verbs: [
			"get",
			"watch",
			"list",
		]
	}]
}
objects: ClusterRoleBinding: "external-dns-viewer": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "external-dns"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "external-dns"
			"app.kubernetes.io/version":    "0.21.0"
			"helm.sh/chart":                "external-dns-1.21.1"
		}
		name: "external-dns-viewer"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "external-dns"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "external-dns"
		namespace: "external-dns"
	}]
}
objects: Service: "external-dns": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "external-dns"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "external-dns"
			"app.kubernetes.io/version":    "0.21.0"
			"helm.sh/chart":                "external-dns-1.21.1"
		}
		name:      "external-dns"
		namespace: "external-dns"
	}
	spec: {
		ports: [{
			name:       "http"
			port:       7979
			protocol:   "TCP"
			targetPort: "http"
		}]
		selector: {
			"app.kubernetes.io/instance": "external-dns"
			"app.kubernetes.io/name":     "external-dns"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: "external-dns": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "external-dns"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "external-dns"
			"app.kubernetes.io/version":    "0.21.0"
			"helm.sh/chart":                "external-dns-1.21.1"
		}
		name:      "external-dns"
		namespace: "external-dns"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "external-dns"
			"app.kubernetes.io/name":     "external-dns"
		}
		strategy: type: "Recreate"
		template: {
			metadata: labels: {
				"app.kubernetes.io/instance": "external-dns"
				"app.kubernetes.io/name":     "external-dns"
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--log-level=info",
						"--log-format=text",
						"--interval=1m",
						"--source=service",
						"--source=ingress",
						"--policy=upsert-only",
						"--registry=txt",
						"--provider=aws",
					]
					env: [{
						name: "AWS_ACCESS_KEY_ID"
						valueFrom: secretKeyRef: {
							key:      "access-key-id"
							name:     "aws-credentials"
							optional: true
						}
					}, {
						name: "AWS_SECRET_ACCESS_KEY"
						valueFrom: secretKeyRef: {
							key:      "secret-access-key"
							name:     "aws-credentials"
							optional: true
						}
					}, {
						name: "AWS_SESSION_TOKEN"
						valueFrom: secretKeyRef: {
							key:      "session-token"
							name:     "aws-credentials"
							optional: true
						}
					}]
					image:           "host.k3d.internal:5000/mirror/registry.k8s.io/external-dns/external-dns:v0.21.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						failureThreshold: 2
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 10
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      5
					}
					name: "external-dns"
					ports: [{
						containerPort: 7979
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 6
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 5
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      5
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsGroup:             65532
						runAsNonRoot:           true
						runAsUser:              65532
					}
				}]
				securityContext: {
					fsGroup:      65534
					runAsNonRoot: true
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "external-dns"
			}
		}
	}
}
