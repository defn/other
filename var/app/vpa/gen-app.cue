@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "vpa-admission-controller": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "admission-controller"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-admission-controller"
		namespace: "vpa"
	}
}
objects: ServiceAccount: "vpa-recommender": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "recommender"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-recommender"
		namespace: "vpa"
	}
}
objects: ServiceAccount: "vpa-updater": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "updater"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-updater"
		namespace: "vpa"
	}
}
objects: ServiceAccount: "vpa-admission-certgen": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade,post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
}
objects: ServiceAccount: "vpa-test": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation,hook-failed"
		}
		name: "vpa-test"
	}
}
objects: Role: "vpa-admission-certgen": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade,post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
	rules: [{
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"get",
			"create",
		]
	}]
}
objects: Role: "vpa-test": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation,hook-failed"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test"
	}
	rules: [{
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"delete",
		]
	}, {
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalercheckpoints"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resourceNames: [
			"vpa-webhook",
			"vpa-tls-secret",
		]
		resources: [
			"secrets",
			"services",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "vpa-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-actor"
	rules: [{
		apiGroups: [""]
		resources: [
			"pods",
			"nodes",
			"limitranges",
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
			"get",
			"list",
			"watch",
			"create",
		]
	}, {
		apiGroups: ["poc.autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers"]
		verbs: [
			"get",
			"list",
			"watch",
			"patch",
		]
	}]
}
objects: ClusterRole: "vpa-admission-certgen": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade,post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
	rules: [{
		apiGroups: ["admissionregistration.k8s.io"]
		resources: [
			"validatingwebhookconfigurations",
			"mutatingwebhookconfigurations",
		]
		verbs: [
			"get",
			"update",
		]
	}]
}
objects: ClusterRole: "vpa-admission-controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-admission-controller"
	rules: [{
		apiGroups: [""]
		resources: [
			"pods",
			"configmaps",
			"nodes",
			"limitranges",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["admissionregistration.k8s.io"]
		resources: ["mutatingwebhookconfigurations"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
		]
	}, {
		apiGroups: ["poc.autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"create",
			"update",
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "vpa-checkpoint-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-checkpoint-actor"
	rules: [{
		apiGroups: ["poc.autoscaling.k8s.io"]
		resources: ["verticalpodautoscalercheckpoints"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"patch",
			"delete",
		]
	}, {
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalercheckpoints"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [""]
		resources: ["namespaces"]
		verbs: [
			"get",
			"list",
		]
	}]
}
objects: ClusterRole: "vpa-evictioner": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-evictioner"
	rules: [{
		apiGroups: [
			"apps",
			"extensions",
		]
		resources: ["replicasets"]
		verbs: ["get"]
	}, {
		apiGroups: [""]
		resources: ["pods/eviction"]
		verbs: ["create"]
	}]
}
objects: ClusterRole: "vpa-metrics-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-metrics-reader"
	rules: [{
		apiGroups: ["metrics.k8s.io"]
		resources: ["pods"]
		verbs: [
			"get",
			"list",
		]
	}]
}
objects: ClusterRole: "vpa-status-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-status-actor"
	rules: [{
		apiGroups: ["autoscaling.k8s.io"]
		resources: ["verticalpodautoscalers/status"]
		verbs: [
			"get",
			"patch",
		]
	}]
}
objects: ClusterRole: "vpa-status-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-status-reader"
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "vpa-target-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-target-reader"
	rules: [{
		apiGroups: ["*"]
		resources: ["*/scale"]
		verbs: [
			"get",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["replicationcontrollers"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: [
			"daemonsets",
			"deployments",
			"replicasets",
			"statefulsets",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["batch"]
		resources: [
			"jobs",
			"cronjobs",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "vpa-test": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation,hook-failed"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test"
	}
	rules: [{
		apiGroups: ["metrics.k8s.io"]
		resources: ["nodes"]
		verbs: ["list"]
	}, {
		apiGroups: ["apiextensions.k8s.io"]
		resourceNames: [
			"verticalpodautoscalercheckpoints.autoscaling.k8s.io",
			"verticalpodautoscalers.autoscaling.k8s.io",
		]
		resources: ["customresourcedefinitions"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["admissionregistration.k8s.io"]
		resourceNames: ["vpa-webhook-config"]
		resources: ["mutatingwebhookconfigurations"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "vpa-updater-in-place": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "vpa-updater-in-place"
	rules: [{
		apiGroups: [""]
		resources: [
			"pods/resize",
			"pods",
		]
		verbs: ["patch"]
	}]
}
objects: RoleBinding: "vpa-admission-certgen": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade,post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "vpa-admission-certgen"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-admission-certgen"
		namespace: "vpa"
	}]
}
objects: RoleBinding: "vpa-test": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation,hook-failed"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "vpa-test"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-test"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-actor"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-actor"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-recommender"
		namespace: "vpa"
	}, {
		kind:      "ServiceAccount"
		name:      "vpa-updater"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-admission-certgen": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade,post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-admission-certgen"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-admission-certgen"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-admission-controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-admission-controller"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-admission-controller"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-admission-controller"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-checkpoint-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-checkpoint-actor"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-checkpoint-actor"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-recommender"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-evictionter-binding": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-evictionter-binding"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-evictioner"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-updater"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-metrics-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-metrics-reader"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-metrics-reader"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-recommender"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-status-actor": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-status-actor"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-status-actor"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-recommender"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-status-reader-binding": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-status-reader-binding"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-status-reader"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-updater"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-target-reader-binding": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-target-reader-binding"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-target-reader"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-recommender"
		namespace: "vpa"
	}, {
		kind:      "ServiceAccount"
		name:      "vpa-admission-controller"
		namespace: "vpa"
	}, {
		kind:      "ServiceAccount"
		name:      "vpa-updater"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-test": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation,hook-failed"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-test"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-test"
		namespace: "vpa"
	}]
}
objects: ClusterRoleBinding: "vpa-updater-in-place-binding": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "vpa-updater-in-place-binding"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "vpa-updater-in-place"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "vpa-updater"
		namespace: "vpa"
	}]
}
objects: Service: "vpa-webhook": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "vpa-webhook"
		namespace: "vpa"
	}
	spec: {
		ports: [{
			port:       443
			targetPort: 8000
		}]
		selector: {
			"app.kubernetes.io/component": "admission-controller"
			"app.kubernetes.io/instance":  "vpa"
			"app.kubernetes.io/name":      "vpa"
		}
	}
}
objects: Deployment: "vpa-admission-controller": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "admission-controller"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-admission-controller"
		namespace: "vpa"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/component": "admission-controller"
			"app.kubernetes.io/instance":  "vpa"
			"app.kubernetes.io/name":      "vpa"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/component": "admission-controller"
				"app.kubernetes.io/instance":  "vpa"
				"app.kubernetes.io/name":      "vpa"
			}
			spec: {
				containers: [{
					args: [
						"--register-webhook=false",
						"--webhook-service=vpa-webhook",
						"--client-ca-file=/etc/tls-certs/ca",
						"--tls-cert-file=/etc/tls-certs/cert",
						"--tls-private-key=/etc/tls-certs/key",
					]
					env: [{
						name: "NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}]
					image:           "host.k3d.internal:5000/mirror/registry.k8s.io/autoscaling/vpa-admission-controller:1.6.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 6
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					name: "vpa"
					ports: [{
						containerPort: 8000
						name:          "http"
						protocol:      "TCP"
					}, {
						containerPort: 8944
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 120
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					resources: {
						limits: {}
						requests: {
							cpu:    "50m"
							memory: "200Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
					volumeMounts: [{
						mountPath: "/etc/tls-certs"
						name:      "tls-certs"
						readOnly:  true
					}]
				}]
				hostNetwork: false
				securityContext: {
					runAsNonRoot: true
					runAsUser:    65534
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "vpa-admission-controller"
				volumes: [{
					name: "tls-certs"
					secret: secretName: "vpa-tls-secret"
				}]
			}
		}
	}
}
objects: Deployment: "vpa-recommender": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "recommender"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-recommender"
		namespace: "vpa"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/component": "recommender"
			"app.kubernetes.io/instance":  "vpa"
			"app.kubernetes.io/name":      "vpa"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/component": "recommender"
				"app.kubernetes.io/instance":  "vpa"
				"app.kubernetes.io/name":      "vpa"
			}
			spec: {
				containers: [{
					args: [
						"--pod-recommendation-min-cpu-millicores=15",
						"--pod-recommendation-min-memory-mb=100",
						"--v=4",
					]
					image:           "host.k3d.internal:5000/mirror/registry.k8s.io/autoscaling/vpa-recommender:1.6.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 6
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					name: "vpa"
					ports: [{
						containerPort: 8942
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 120
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					resources: {
						limits: {}
						requests: {
							cpu:    "50m"
							memory: "500Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
				}]
				securityContext: {
					runAsNonRoot: true
					runAsUser:    65534
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "vpa-recommender"
			}
		}
	}
}
objects: Deployment: "vpa-updater": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "updater"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name:      "vpa-updater"
		namespace: "vpa"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/component": "updater"
			"app.kubernetes.io/instance":  "vpa"
			"app.kubernetes.io/name":      "vpa"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/component": "updater"
				"app.kubernetes.io/instance":  "vpa"
				"app.kubernetes.io/name":      "vpa"
			}
			spec: {
				containers: [{
					env: [{
						name: "NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}]
					image:           "host.k3d.internal:5000/mirror/registry.k8s.io/autoscaling/vpa-updater:1.6.0"
					imagePullPolicy: "Always"
					livenessProbe: {
						failureThreshold: 6
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					name: "vpa"
					ports: [{
						containerPort: 8943
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 120
						httpGet: {
							path:   "/health-check"
							port:   "metrics"
							scheme: "HTTP"
						}
						periodSeconds:    5
						successThreshold: 1
						timeoutSeconds:   3
					}
					resources: {
						limits: {}
						requests: {
							cpu:    "50m"
							memory: "500Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
				}]
				securityContext: {
					runAsNonRoot: true
					runAsUser:    65534
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "vpa-updater"
			}
		}
	}
}
objects: Job: "vpa-admission-certgen": {
	apiVersion: "batch/v1"
	kind:       "Job"
	metadata: {
		annotations: {
			"helm.sh/hook":               "pre-install,pre-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "-110"
		}
		labels: {
			"app.kubernetes.io/component":  "certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen"
	}
	spec: {
		template: {
			metadata: {
				labels: {
					"app.kubernetes.io/component":  "admission-certgen"
					"app.kubernetes.io/instance":   "vpa"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "vpa"
					"app.kubernetes.io/version":    "1.6.0"
					"helm.sh/chart":                "vpa-4.11.0"
				}
				name: "vpa-admission-certgen"
			}
			spec: {
				containers: [{
					args: [
						"create",
						"--host=vpa-webhook,vpa-webhook.vpa.svc",
						"--namespace=vpa",
						"--secret-name=vpa-tls-secret",
					]
					image: "host.k3d.internal:5000/mirror/registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794"
					name:  "create"
					resources: {}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
				}]
				restartPolicy: "OnFailure"
				securityContext: {
					runAsNonRoot: true
					runAsUser:    65534
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "vpa-admission-certgen"
			}
		}
		ttlSecondsAfterFinished: 300
	}
}
objects: Job: "vpa-admission-certgen-patch": {
	apiVersion: "batch/v1"
	kind:       "Job"
	metadata: {
		annotations: {
			"helm.sh/hook":               "post-install,post-upgrade"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
		}
		labels: {
			"app.kubernetes.io/component":  "admission-certgen"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-admission-certgen-patch"
	}
	spec: {
		template: {
			metadata: {
				labels: {
					"app.kubernetes.io/component":  "admission-certgen"
					"app.kubernetes.io/instance":   "vpa"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "vpa"
					"app.kubernetes.io/version":    "1.6.0"
					"helm.sh/chart":                "vpa-4.11.0"
				}
				name: "vpa-admission-certgen-patch"
			}
			spec: {
				containers: [{
					args: [
						"patch",
						"--webhook-name=vpa-webhook-config",
						"--namespace=vpa",
						"--secret-name=vpa-tls-secret",
						"--patch-validating=false",
						"--log-level=debug",
					]
					image: "host.k3d.internal:5000/mirror/registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230312-helm-chart-4.5.2-28-g66a760794"
					name:  "patch"
					resources: {}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
				}]
				restartPolicy: "OnFailure"
				securityContext: {
					runAsNonRoot: true
					runAsUser:    65534
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "vpa-admission-certgen"
			}
		}
		ttlSecondsAfterFinished: 300
	}
}
objects: Pod: "vpa-test-crds-available": {
	apiVersion: "v1"
	kind:       "Pod"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation"
			"helm.sh/hook-weight":        "10"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test-crds-available"
	}
	spec: {
		containers: [{
			args: [
				"get",
				"crd",
				"verticalpodautoscalercheckpoints.autoscaling.k8s.io",
				"verticalpodautoscalers.autoscaling.k8s.io",
			]
			command: ["kubectl"]
			image:           "host.k3d.internal:5000/mirror/alpine/kubectl:1.35.2"
			imagePullPolicy: "Always"
			name:            "test"
			securityContext: {
				allowPrivilegeEscalation: false
				capabilities: drop: ["ALL"]
				readOnlyRootFilesystem: true
				runAsNonRoot:           true
				runAsUser:              10324
			}
		}]
		restartPolicy:      "Never"
		serviceAccountName: "vpa-test"
	}
}
objects: Pod: "vpa-test-create-vpa": {
	apiVersion: "v1"
	kind:       "Pod"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "20"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test-create-vpa"
	}
	spec: {
		containers: [{
			args: [
				"-c",
				"""
					#!/bin/sh

					set -ex
					cat <<EOF | kubectl -n vpa apply -f -
					apiVersion: autoscaling.k8s.io/v1
					kind: VerticalPodAutoscaler
					metadata:
					  name: test-vpa
					spec:
					  targetRef:
					    apiVersion: "apps/v1"
					    kind:       Deployment
					    name:       my-app
					  updatePolicy:
					    updateMode: "Off"
					EOF

					kubectl -n vpa describe vpa test-vpa
					kubectl -n vpa delete vpa test-vpa

					""",
			]
			command: ["sh"]
			image:           "host.k3d.internal:5000/mirror/alpine/kubectl:1.35.2"
			imagePullPolicy: "Always"
			name:            "test"
			securityContext: {
				allowPrivilegeEscalation: false
				capabilities: drop: ["ALL"]
				readOnlyRootFilesystem: true
				runAsNonRoot:           true
				runAsUser:              10324
			}
		}]
		restartPolicy:      "Never"
		serviceAccountName: "vpa-test"
	}
}
objects: Pod: "vpa-test-metrics-api-available": {
	apiVersion: "v1"
	kind:       "Pod"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "40"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test-metrics-api-available"
	}
	spec: {
		containers: [{
			args: [
				"get",
				"--raw",
				"/apis/metrics.k8s.io/v1beta1/nodes",
			]
			command: ["kubectl"]
			image:           "host.k3d.internal:5000/mirror/alpine/kubectl:1.35.2"
			imagePullPolicy: "Always"
			name:            "test"
			securityContext: {
				allowPrivilegeEscalation: false
				capabilities: drop: ["ALL"]
				readOnlyRootFilesystem: true
				runAsNonRoot:           true
				runAsUser:              10324
			}
		}]
		restartPolicy:      "Never"
		serviceAccountName: "vpa-test"
	}
}
objects: Pod: "vpa-test-webhook-configuration": {
	apiVersion: "v1"
	kind:       "Pod"
	metadata: {
		annotations: {
			"helm.sh/hook":               "test"
			"helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
			"helm.sh/hook-weight":        "30"
		}
		labels: {
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-test-webhook-configuration"
	}
	spec: {
		containers: [{
			args: [
				"-c",
				"""
					#!/bin/sh

					set -ex

					# Get service FQDN
					SERVICE=$(kubectl \\
					  get service \\
					  -n vpa \\
					  vpa-webhook \\
					  -o=jsonpath="{.metadata.name}.{.metadata.namespace}.svc:{.spec.ports[0].port}")

					# Get configured FQDN
					WEBHOOK_SERVICE=$(kubectl \\
					  get mutatingwebhookconfigurations.admissionregistration.k8s.io \\
					  vpa-webhook-config \\
					  -o=jsonpath="{.webhooks[0].clientConfig.service.name}.{.webhooks[0].clientConfig.service.namespace}.svc:{.webhooks[0].clientConfig.service.port}")

					# Get CA bundle
					SECRET_CABUNDLE=$(kubectl \\
					  get secret \\
					  -n vpa \\
					  vpa-tls-secret \\
					  -o=jsonpath="{.data.ca}")

					# Get CA bundle if using cert-manager
					if [ -z "$SECRET_CABUNDLE" ]
					then
					  SECRET_CABUNDLE=$(kubectl \\
					    get secret \\
					    -n vpa \\
					    vpa-tls-secret \\
					    -o=jsonpath="{.data.ca\\.crt}")
					fi

					# Get configured CA bundle
					WEBHOOK_CABUNDLE=$(kubectl \\
					  get mutatingwebhookconfigurations.admissionregistration.k8s.io \\
					  vpa-webhook-config \\
					  -o=jsonpath="{.webhooks[0].clientConfig.caBundle}")

					# All corresponding values must match
					if [ $SERVICE = $WEBHOOK_SERVICE ]
					then
					  echo "$WEBHOOK_SERVICE matches $SERVICE"
					  if [ $WEBHOOK_CABUNDLE = $SECRET_CABUNDLE ]
					  then
					    echo "Webhook CA bundle matches"
					    exit 0;
					  else
					    echo "CA bundle in mutating webhook vpa-webhook-config does not match secret vpa/vpa-tls-secret"
					  fi
					else
					  echo "Service configured in mutating webhook vpa-webhook-config is '$WEBHOOK_SERVICE' not '$SERVICE'"
					fi
					exit 1;

					""",
			]
			command: ["sh"]
			image:           "host.k3d.internal:5000/mirror/alpine/kubectl:1.35.2"
			imagePullPolicy: "Always"
			name:            "test"
			securityContext: {
				allowPrivilegeEscalation: false
				capabilities: drop: ["ALL"]
				readOnlyRootFilesystem: true
				runAsNonRoot:           true
				runAsUser:              10324
			}
		}]
		restartPolicy:      "Never"
		serviceAccountName: "vpa-test"
	}
}
objects: MutatingWebhookConfiguration: "vpa-webhook-config": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "MutatingWebhookConfiguration"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "admission-controller"
			"app.kubernetes.io/instance":   "vpa"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "vpa"
			"app.kubernetes.io/version":    "1.6.0"
			"helm.sh/chart":                "vpa-4.11.0"
		}
		name: "vpa-webhook-config"
	}
	webhooks: [{
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "vpa-webhook"
			namespace: "vpa"
			port:      443
		}
		failurePolicy: "Ignore"
		matchPolicy:   "Equivalent"
		name:          "vpa.k8s.io"
		namespaceSelector: {}
		objectSelector: {}
		reinvocationPolicy: "Never"
		rules: [{
			apiGroups: [""]
			apiVersions: ["v1"]
			operations: ["CREATE"]
			resources: ["pods"]
			scope: "*"
		}, {
			apiGroups: ["autoscaling.k8s.io"]
			apiVersions: ["*"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["verticalpodautoscalers"]
			scope: "*"
		}]
		sideEffects:    "None"
		timeoutSeconds: 5
	}]
}
