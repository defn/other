@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "keda-metrics-server": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-metrics-server"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-metrics-server"
		namespace: "keda"
	}
}
objects: ServiceAccount: "keda-operator": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator"
		namespace: "keda"
	}
}
objects: ServiceAccount: "keda-webhook": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-webhook"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-webhook"
		namespace: "keda"
	}
}
objects: Role: "keda-operator-certs": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-certs"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator-certs"
		namespace: "keda"
	}
	rules: [{
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
		apiGroups: [""]
		resourceNames: ["kedaorg-certs"]
		resources: ["secrets"]
		verbs: ["get"]
	}, {
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"create",
			"update",
		]
	}]
}
objects: ClusterRole: "keda-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator"
	}
	rules: [{
		apiGroups: [""]
		resources: [
			"configmaps",
			"configmaps/status",
			"limitranges",
			"pods",
			"services",
			"serviceaccounts",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["*"]
		resources: ["*/scale"]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["*"]
		resources: ["*"]
		verbs: ["get"]
	}, {
		apiGroups: ["apps"]
		resources: [
			"deployments/scale",
			"statefulsets/scale",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: [
			"deployments",
			"statefulsets",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["autoscaling"]
		resources: ["horizontalpodautoscalers"]
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
		apiGroups: ["batch"]
		resources: ["jobs"]
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
		apiGroups: ["eventing.keda.sh"]
		resources: [
			"cloudeventsources",
			"cloudeventsources/status",
			"clustercloudeventsources",
			"clustercloudeventsources/status",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["keda.sh"]
		resources: [
			"scaledjobs",
			"scaledjobs/finalizers",
			"scaledjobs/status",
			"scaledobjects",
			"scaledobjects/finalizers",
			"scaledobjects/status",
			"triggerauthentications",
			"triggerauthentications/status",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}]
}
objects: ClusterRole: "keda-operator-external-metrics-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-external-metrics-reader"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-external-metrics-reader"
	}
	rules: [{
		apiGroups: ["external.metrics.k8s.io"]
		resources: ["externalmetrics"]
		verbs: ["get"]
	}]
}
objects: ClusterRole: "keda-operator-minimal-cluster-role": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-minimal-cluster-role"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-minimal-cluster-role"
	}
	rules: [{
		apiGroups: ["keda.sh"]
		resources: [
			"clustertriggerauthentications",
			"clustertriggerauthentications/status",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["admissionregistration.k8s.io"]
		resources: ["validatingwebhookconfigurations"]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["apiregistration.k8s.io"]
		resources: ["apiservices"]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["eventing.keda.sh"]
		resources: [
			"cloudeventsources",
			"cloudeventsources/status",
			"clustercloudeventsources",
			"clustercloudeventsources/status",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}]
}
objects: ClusterRole: "keda-operator-webhook": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-webhook"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-webhook"
	}
	rules: [{
		apiGroups: ["autoscaling"]
		resources: ["horizontalpodautoscalers"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["keda.sh"]
		resources: ["scaledobjects"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: [
			"deployments",
			"statefulsets",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["limitranges"]
		verbs: ["list"]
	}]
}
objects: RoleBinding: "keda-operator-certs": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-certs"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator-certs"
		namespace: "keda"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "keda-operator-certs"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-operator"
		namespace: "keda"
	}]
}
objects: RoleBinding: "keda-operator-auth-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-auth-reader"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator-auth-reader"
		namespace: "kube-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "extension-apiserver-authentication-reader"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-metrics-server"
		namespace: "keda"
	}]
}
objects: ClusterRoleBinding: "keda-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "keda-operator"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-operator"
		namespace: "keda"
	}]
}
objects: ClusterRoleBinding: "keda-operator-hpa-controller-external-metrics": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-hpa-controller-external-metrics"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-hpa-controller-external-metrics"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "keda-operator-external-metrics-reader"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "horizontal-pod-autoscaler"
		namespace: "kube-system"
	}]
}
objects: ClusterRoleBinding: "keda-operator-minimal": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-minimal"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-minimal"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "keda-operator-minimal-cluster-role"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-operator"
		namespace: "keda"
	}]
}
objects: ClusterRoleBinding: "keda-operator-system-auth-delegator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-system-auth-delegator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-system-auth-delegator"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "system:auth-delegator"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-metrics-server"
		namespace: "keda"
	}]
}
objects: ClusterRoleBinding: "keda-operator-webhook": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-webhook"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-operator-webhook"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "keda-operator-webhook"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "keda-webhook"
		namespace: "keda"
	}]
}
objects: Service: "keda-admission-webhooks": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-admission-webhooks"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-admission-webhooks"
		namespace: "keda"
	}
	spec: {
		ports: [{
			appProtocol: "https"
			name:        "https"
			port:        443
			protocol:    "TCP"
			targetPort:  9443
		}]
		selector: app: "keda-admission-webhooks"
	}
}
objects: Service: "keda-operator": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator"
		namespace: "keda"
	}
	spec: {
		ports: [{
			name:       "metricsservice"
			port:       9666
			targetPort: 9666
		}]
		selector: app: "keda-operator"
	}
}
objects: Service: "keda-operator-metrics-apiserver": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			app:                            "keda-operator-metrics-apiserver"
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-metrics-apiserver"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator-metrics-apiserver"
		namespace: "keda"
	}
	spec: {
		ports: [{
			appProtocol: "https"
			name:        "https"
			port:        443
			protocol:    "TCP"
			targetPort:  6443
		}, {
			name:       "metrics"
			port:       8080
			protocol:   "TCP"
			targetPort: 8080
		}]
		selector: app: "keda-operator-metrics-apiserver"
		type: "ClusterIP"
	}
}
objects: Deployment: "keda-admission-webhooks": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			app:                            "keda-admission-webhooks"
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-admission-webhooks"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
			name:                           "keda-admission-webhooks"
		}
		name:      "keda-admission-webhooks"
		namespace: "keda"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: app: "keda-admission-webhooks"
		template: {
			metadata: labels: {
				app:                            "keda-admission-webhooks"
				"app.kubernetes.io/component":  "operator"
				"app.kubernetes.io/instance":   "keda"
				"app.kubernetes.io/managed-by": "Helm"
				"app.kubernetes.io/name":       "keda-admission-webhooks"
				"app.kubernetes.io/part-of":    "keda-operator"
				"app.kubernetes.io/version":    "2.19.0"
				"helm.sh/chart":                "keda-2.19.0"
				name:                           "keda-admission-webhooks"
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--zap-log-level=info",
						"--zap-encoder=console",
						"--zap-time-encoding=rfc3339",
						"--cert-dir=/certs",
						"--health-probe-bind-address=:8081",
						"--metrics-bind-address=:8080",
					]
					command: ["/keda-admission-webhooks"]
					env: [{
						name:  "WATCH_NAMESPACE"
						value: ""
					}, {
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/kedacore/keda-admission-webhooks:2.19.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/healthz"
							port: 8081
						}
						initialDelaySeconds: 25
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      1
					}
					name: "keda-admission-webhooks"
					ports: [{
						containerPort: 9443
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/readyz"
							port: 8081
						}
						initialDelaySeconds: 20
						periodSeconds:       3
						successThreshold:    1
						timeoutSeconds:      1
					}
					resources: {
						limits: {
							cpu:    1
							memory: "1000Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "100Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/certs"
						name:      "certificates"
						readOnly:  true
					}]
				}]
				enableServiceLinks: true
				hostNetwork:        false
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: runAsNonRoot:    true
				serviceAccountName: "keda-webhook"
				volumes: [{
					name: "certificates"
					secret: {
						defaultMode: 420
						secretName:  "kedaorg-certs"
					}
				}]
			}
		}
	}
}
objects: Deployment: "keda-operator": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			app:                            "keda-operator"
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
			name:                           "keda-operator"
		}
		name:      "keda-operator"
		namespace: "keda"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: app: "keda-operator"
		template: {
			metadata: labels: {
				app:                            "keda-operator"
				"app.kubernetes.io/component":  "operator"
				"app.kubernetes.io/instance":   "keda"
				"app.kubernetes.io/managed-by": "Helm"
				"app.kubernetes.io/name":       "keda-operator"
				"app.kubernetes.io/part-of":    "keda-operator"
				"app.kubernetes.io/version":    "2.19.0"
				"helm.sh/chart":                "keda-2.19.0"
				name:                           "keda-operator"
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--leader-elect",
						"--disable-compression=true",
						"--zap-log-level=info",
						"--zap-encoder=console",
						"--zap-time-encoding=rfc3339",
						"--enable-webhook-patching=true",
						"--cert-dir=/certs",
						"--enable-cert-rotation=true",
						"--cert-secret-name=kedaorg-certs",
						"--operator-service-name=keda-operator",
						"--metrics-server-service-name=keda-operator-metrics-apiserver",
						"--webhooks-service-name=keda-admission-webhooks",
						"--k8s-cluster-name=kubernetes-default",
						"--k8s-cluster-domain=cluster.local",
						"--enable-prometheus-metrics=false",
					]
					command: ["/keda"]
					env: [{
						name:  "WATCH_NAMESPACE"
						value: ""
					}, {
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "OPERATOR_NAME"
						value: "keda-operator"
					}, {
						name:  "KEDA_HTTP_DEFAULT_TIMEOUT"
						value: "3000"
					}, {
						name:  "KEDA_HTTP_MIN_TLS_VERSION"
						value: "TLS12"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/kedacore/keda:2.19.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/healthz"
							port: 8081
						}
						initialDelaySeconds: 25
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      1
					}
					name: "keda-operator"
					ports: [{
						containerPort: 9666
						name:          "metricsservice"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/readyz"
							port: 8081
						}
						initialDelaySeconds: 20
						periodSeconds:       3
						successThreshold:    1
						timeoutSeconds:      1
					}
					resources: {
						limits: {
							cpu:    1
							memory: "1000Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "100Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/certs"
						name:      "certificates"
						readOnly:  true
					}]
				}]
				dnsPolicy:          "ClusterFirst"
				enableServiceLinks: true
				hostNetwork:        false
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: runAsNonRoot:    true
				serviceAccountName: "keda-operator"
				volumes: [{
					name: "certificates"
					secret: {
						defaultMode: 420
						optional:    true
						secretName:  "kedaorg-certs"
					}
				}]
			}
		}
	}
}
objects: Deployment: "keda-operator-metrics-apiserver": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			app:                            "keda-operator-metrics-apiserver"
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-operator-metrics-apiserver"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name:      "keda-operator-metrics-apiserver"
		namespace: "keda"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: app: "keda-operator-metrics-apiserver"
		template: {
			metadata: labels: {
				app:                            "keda-operator-metrics-apiserver"
				"app.kubernetes.io/component":  "operator"
				"app.kubernetes.io/instance":   "keda"
				"app.kubernetes.io/managed-by": "Helm"
				"app.kubernetes.io/name":       "keda-operator-metrics-apiserver"
				"app.kubernetes.io/part-of":    "keda-operator"
				"app.kubernetes.io/version":    "2.19.0"
				"helm.sh/chart":                "keda-2.19.0"
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--port=8080",
						"--secure-port=6443",
						"--logtostderr=true",
						"--stderrthreshold=ERROR",
						"--disable-compression=true",
						"--metrics-service-address=keda-operator.keda.svc.cluster.local:9666",
						"--client-ca-file=/certs/ca.crt",
						"--tls-cert-file=/certs/tls.crt",
						"--tls-private-key-file=/certs/tls.key",
						"--cert-dir=/certs",
						"--v=0",
						"--zap-log-level=info",
						"--zap-encoder=console",
						"--zap-time-encoding=rfc3339",
					]
					command: ["/keda-adapter"]
					env: [{
						name:  "WATCH_NAMESPACE"
						value: ""
					}, {
						name: "POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "KEDA_HTTP_DEFAULT_TIMEOUT"
						value: "3000"
					}, {
						name:  "KEDA_HTTP_MIN_TLS_VERSION"
						value: "TLS12"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/kedacore/keda-metrics-apiserver:2.19.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							path:   "/healthz"
							port:   6443
							scheme: "HTTPS"
						}
						initialDelaySeconds: 5
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      1
					}
					name: "keda-operator-metrics-apiserver"
					ports: [{
						containerPort: 6443
						name:          "https"
						protocol:      "TCP"
					}, {
						containerPort: 8080
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 3
						httpGet: {
							path:   "/readyz"
							port:   6443
							scheme: "HTTPS"
						}
						initialDelaySeconds: 5
						periodSeconds:       3
						successThreshold:    1
						timeoutSeconds:      1
					}
					resources: {
						limits: {
							cpu:    1
							memory: "1000Mi"
						}
						requests: {
							cpu:    "100m"
							memory: "100Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/certs"
						name:      "certificates"
						readOnly:  true
					}]
				}]
				dnsPolicy:          "ClusterFirst"
				enableServiceLinks: true
				hostNetwork:        false
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: runAsNonRoot:    true
				serviceAccountName: "keda-metrics-server"
				volumes: [{
					name: "certificates"
					secret: {
						defaultMode: 420
						secretName:  "kedaorg-certs"
					}
				}]
			}
		}
	}
}
objects: APIService: "v1beta1.external.metrics.k8s.io": {
	apiVersion: "apiregistration.k8s.io/v1"
	kind:       "APIService"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "v1beta1.external.metrics.k8s.io"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "v1beta1.external.metrics.k8s.io"
	}
	spec: {
		group:                "external.metrics.k8s.io"
		groupPriorityMinimum: 100
		service: {
			name:      "keda-operator-metrics-apiserver"
			namespace: "keda"
			port:      443
		}
		version:         "v1beta1"
		versionPriority: 100
	}
}
objects: ValidatingWebhookConfiguration: "keda-admission": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "ValidatingWebhookConfiguration"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "operator"
			"app.kubernetes.io/instance":   "keda"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "keda-admission-webhooks"
			"app.kubernetes.io/part-of":    "keda-operator"
			"app.kubernetes.io/version":    "2.19.0"
			"helm.sh/chart":                "keda-2.19.0"
		}
		name: "keda-admission"
	}
	webhooks: [{
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-keda-sh-v1alpha1-scaledobject"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vscaledobject.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["scaledobjects"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}, {
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-keda-sh-v1alpha1-scaledjob"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vscaledjob.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["scaledjobs"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}, {
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-keda-sh-v1alpha1-triggerauthentication"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vstriggerauthentication.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["triggerauthentications"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}, {
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-keda-sh-v1alpha1-clustertriggerauthentication"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vsclustertriggerauthentication.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["clustertriggerauthentications"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}, {
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-eventing-keda-sh-v1alpha1-cloudeventsource"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vcloudeventsource.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["eventing.keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["cloudeventsources"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}, {
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "keda-admission-webhooks"
			namespace: "keda"
			path:      "/validate-eventing-keda-sh-v1alpha1-clustercloudeventsource"
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vclustercloudeventsource.kb.io"
		namespaceSelector: {}
		objectSelector: {}
		rules: [{
			apiGroups: ["eventing.keda.sh"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["clustercloudeventsources"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 10
	}]
}
